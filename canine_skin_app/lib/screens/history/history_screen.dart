import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
import '../auth/login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _results = [];
  final Map<int, TextEditingController> _feedbackControllers = {};
  final Set<int> _submittedFeedback = {};
  final Set<int> _submittingFeedback = {};

  TextEditingController _controllerFor(int resultId) {
    return _feedbackControllers.putIfAbsent(resultId, () => TextEditingController());
  }

  void _handleSessionExpired() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your session has expired. Please log in again.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getHistory();
      if (result["statusCode"] == 200) {
        setState(() => _results = result["body"]);
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = "Could not load history");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitFeedback(int resultId) async {
    final text = _controllerFor(resultId).text.trim();
    if (text.isEmpty) return;

    setState(() => _submittingFeedback.add(resultId));
    try {
      final result = await ApiService.submitFeedback(
        resultId: resultId,
        feedbackText: text,
      );
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 201) {
        setState(() => _submittedFeedback.add(resultId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Feedback submitted, thank you!")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to submit feedback")),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _submittingFeedback.remove(resultId));
    }
  }

  // ------------------------------------------------------------ delete

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteCase(dynamic item) async {
    final ok = await _confirm(
      "Delete this case?",
      "This permanently deletes the ${item["predicted_disease"] ?? "diagnosis"} result, its photo and any vet review. This cannot be undone.",
      "Delete",
    );
    if (!ok) return;

    try {
      final result = await ApiService.deleteCase(item["result_id"]);
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        setState(() => _results.removeWhere((r) => r["result_id"] == item["result_id"]));
        _showSnack("Case deleted");
      } else {
        _showSnack(result["body"]["error"] ?? "Could not delete case");
      }
    } catch (e) {
      _showSnack("Could not connect to server");
    }
  }

  Future<void> _deleteAllCases() async {
    final ok = await _confirm(
      "Delete all cases?",
      "This permanently deletes all ${_results.length} cases in your history, with their photos and vet reviews. This cannot be undone.",
      "Delete All",
    );
    if (!ok) return;

    try {
      final result = await ApiService.deleteAllCases();
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        setState(() => _results = []);
        _showSnack(result["body"]["message"] ?? "All cases deleted");
      } else {
        _showSnack(result["body"]["error"] ?? "Could not delete cases");
      }
    } catch (e) {
      _showSnack("Could not connect to server");
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    for (final controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Diagnosis History"),
        actions: [
          if (!_isLoading && _results.isNotEmpty)
            TextButton.icon(
              onPressed: _deleteAllCases,
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.errorRed),
              label: const Text("Delete all", style: TextStyle(color: AppColors.errorRed)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? DpEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: _errorMessage!,
                    message: "Pull down to try again.",
                    color: AppColors.errorRed,
                  )
                : _results.isEmpty
                    ? const DpEmptyState(
                        icon: Icons.assignment_outlined,
                        title: "No diagnosis history yet",
                        message: "Your AI skin scans will appear here after you upload a photo.",
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          _buildSummary(),
                          const SizedBox(height: 20),
                          DpSectionLabel("All scans (${_results.length})"),
                          ..._results.map(_buildCaseCard),
                        ],
                      ),
      ),
    );
  }

  Widget _buildSummary() {
    final reviewed = _results.where((r) => r["vet_review"] != null).length;
    final pending = _results
        .where((r) => r["vet_review"] == null && r["review_requested"] == true)
        .length;
    return Row(
      children: [
        Expanded(child: _statTile(Icons.description_outlined, "${_results.length}", "Total scans", AppColors.primaryBlue)),
        const SizedBox(width: 10),
        Expanded(child: _statTile(Icons.verified_outlined, "$reviewed", "Vet reviewed", AppColors.tealAccent)),
        const SizedBox(width: 10),
        Expanded(child: _statTile(Icons.hourglass_empty, "$pending", "Waiting", AppColors.orange)),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return DpCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DpIconTile(icon, color: color, size: 34),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: dpMuted(context))),
        ],
      ),
    );
  }

  Widget _buildCaseCard(dynamic item) {
    final vetReview = item["vet_review"];
    final hasReview = vetReview != null;
    final String disease = item["predicted_disease"] ?? "Unknown";
    final double confidence = ((item["confidence_score"] ?? 0) as num).toDouble();
    final parts = RegExp(r'^(.*?)\s*\((.*)\)\s*$').firstMatch(disease);
    final title = parts != null ? parts.group(1)! : disease;
    final int resultId = item["result_id"];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          leading: DpScanImage(imageId: item["image_id"], width: 54, height: 54),
          title: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DpChip("${(confidence * 100).toStringAsFixed(1)}%",
                    color: dpConfidenceColor(confidence)),
                if (hasReview)
                  const DpChip("Vet reviewed", color: AppColors.confidenceGreen, icon: Icons.verified_outlined)
                else if (item["review_requested"] == true)
                  const DpChip("Pending review", color: AppColors.orange, icon: Icons.hourglass_empty),
                Text(dpFormatDate(item["result_date"]),
                    style: TextStyle(fontSize: 12, color: dpMuted(context))),
              ],
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
            tooltip: "Delete case",
            onPressed: () => _deleteCase(item),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DpScanImage(imageId: item["image_id"], height: 210, radius: 16),
            const SizedBox(height: 12),
            DpInfoRow(icon: Icons.coronavirus_outlined, label: "AI prediction", value: disease),
            DpInfoRow(
              icon: Icons.speed,
              label: "Confidence",
              value: "${(confidence * 100).toStringAsFixed(1)}% (${dpConfidenceLabel(confidence)})",
            ),
            DpInfoRow(
              icon: Icons.event_outlined,
              label: "Scanned",
              value: dpFormatDate(item["result_date"], withTime: true),
            ),
            const SizedBox(height: 12),

            // ---- Vet review
            if (hasReview)
              DpNotice(
                tone: vetReview["decision"] != item["predicted_disease"]
                    ? DpTone.warning
                    : DpTone.success,
                title: vetReview["decision"] != item["predicted_disease"]
                    ? "Vet corrected the diagnosis to: ${vetReview["decision"]}"
                    : "Vet confirmed the AI's diagnosis",
                text: (vetReview["comments"] ?? "").toString().isNotEmpty
                    ? "Treatment notes: ${vetReview["comments"]}"
                    : "",
              )
            else if (item["review_requested"] == true)
              const DpNotice(
                tone: DpTone.info,
                icon: Icons.hourglass_empty,
                text: "Waiting for a vet to review this case.",
              ),
            const SizedBox(height: 16),

            // ---- Feedback
            const DpSectionLabel("Your feedback"),
            if (_submittedFeedback.contains(resultId))
              const DpNotice(tone: DpTone.success, text: "Feedback submitted. Thank you!")
            else ...[
              TextField(
                controller: _controllerFor(resultId),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "How was your experience? Any comments on this diagnosis?",
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _submittingFeedback.contains(resultId)
                    ? null
                    : () => _submitFeedback(resultId),
                child: _submittingFeedback.contains(resultId)
                    ? dpButtonSpinner
                    : const Text("Submit Feedback"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
