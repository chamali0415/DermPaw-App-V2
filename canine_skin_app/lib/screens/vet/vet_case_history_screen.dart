import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
import '../auth/login_screen.dart';

class VetCaseHistoryScreen extends StatefulWidget {
  const VetCaseHistoryScreen({super.key});

  @override
  State<VetCaseHistoryScreen> createState() => _VetCaseHistoryScreenState();
}

class _VetCaseHistoryScreenState extends State<VetCaseHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
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

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getVetCaseHistory();
      if (result["statusCode"] == 200) {
        setState(() {
          _history = result["body"];
          _errorMessage = null;
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = "Could not load case history");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------ delete
  // For vets, "delete" removes the case from THIS vet's history list only.
  // The owner's case and the vet's decision stay, because the owner relies on them.

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

  Future<void> _deleteCase(dynamic entry) async {
    final review = entry["review"] ?? {};
    final reviewId = review["review_id"];
    if (reviewId == null) return;

    final ok = await _confirm(
      "Remove this case?",
      "This removes the case from your case history. The dog owner will still see your review.",
      "Remove",
    );
    if (!ok) return;

    try {
      final result = await ApiService.deleteVetCase(reviewId);
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        setState(() => _history.removeWhere((e) => (e["review"] ?? {})["review_id"] == reviewId));
        _showSnack("Case removed from your history");
      } else {
        _showSnack(result["body"]["error"] ?? "Could not remove case");
      }
    } catch (e) {
      _showSnack("Could not connect to server");
    }
  }

  Future<void> _deleteAllCases() async {
    final ok = await _confirm(
      "Remove all cases?",
      "This clears all ${_history.length} cases from your case history. Dog owners will still see your reviews.",
      "Remove All",
    );
    if (!ok) return;

    try {
      final result = await ApiService.deleteAllVetCases();
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        setState(() => _history = []);
        _showSnack(result["body"]["message"] ?? "Case history cleared");
      } else {
        _showSnack(result["body"]["error"] ?? "Could not remove cases");
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Case History"),
        actions: [
          if (!_isLoading && _history.isNotEmpty)
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
                : _history.isEmpty
                    ? const DpEmptyState(
                        icon: Icons.history,
                        title: "No reviewed cases yet",
                        message: "Cases you review will appear here.",
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          const DpPageHeader(
                            eyebrow: "Veterinary portal",
                            title: "Cases you reviewed",
                            subtitle: "Removing a case here only clears your list. The owner keeps your review.",
                          ),
                          const SizedBox(height: 18),
                          DpSectionLabel("Reviewed (${_history.length})"),
                          ..._history.map(_buildCaseCard),
                        ],
                      ),
      ),
    );
  }

  Widget _buildCaseCard(dynamic entry) {
    final result = entry["result"] ?? {};
    final review = entry["review"] ?? {};
    final String ai = result["predicted_disease"] ?? "Unknown";
    final String decision = review["decision"] ?? "Unknown";
    final double confidence = ((result["confidence_score"] ?? 0) as num).toDouble();
    final corrected = decision != ai;
    final comments = (review["comments"] ?? "").toString();

    return DpCard(
      margin: const EdgeInsets.only(bottom: 12),
      accent: corrected ? AppColors.orange : AppColors.confidenceGreen,
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DpScanImage(imageId: result["image_id"], width: 60, height: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(decision,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  "AI said $ai (${(confidence * 100).toStringAsFixed(1)}%)",
                  style: TextStyle(fontSize: 12, color: dpMuted(context)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DpChip(
                      corrected ? "Overridden" : "Confirmed",
                      color: corrected ? AppColors.orange : AppColors.confidenceGreen,
                      icon: corrected ? Icons.edit_outlined : Icons.check,
                    ),
                    Text(dpFormatDate(result["result_date"]),
                        style: TextStyle(fontSize: 12, color: dpMuted(context))),
                  ],
                ),
                if (comments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text("Notes: $comments",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: dpMuted(context))),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
            tooltip: "Remove from history",
            onPressed: () => _deleteCase(entry),
          ),
        ],
      ),
    );
  }
}
