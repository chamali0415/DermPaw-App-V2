import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
import '../auth/login_screen.dart';

class VetCaseDetailScreen extends StatefulWidget {
  final int resultId;

  const VetCaseDetailScreen({super.key, required this.resultId});

  @override
  State<VetCaseDetailScreen> createState() => _VetCaseDetailScreenState();
}

class _VetCaseDetailScreenState extends State<VetCaseDetailScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _details;

  // Fallback list in case the predicted class isn't in this set for some reason
  static const List<String> _diseaseOptions = [
    "Fungal(Dandruff)",
    "Healthy",
    "Hypersensitivity Allergy(Tick dermatitis)",
    "Mange",
    "Ringworm",
  ];

  String? _selectedDecision;
  final TextEditingController _commentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
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

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getCaseDetails(widget.resultId);
      if (result["statusCode"] == 200) {
        final data = result["body"];
        final predicted = data["result"]?["predicted_disease"];

        setState(() {
          _details = data;
          _errorMessage = null;
          // Pre-select the AI's prediction; vet can change it to override
          _selectedDecision = predicted != null && _diseaseOptions.contains(predicted)
              ? predicted
              : (_diseaseOptions.isNotEmpty ? _diseaseOptions.first : null);
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = "Could not load case details");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_selectedDecision == null) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.submitReview(
        resultId: widget.resultId,
        decision: _selectedDecision!,
        comments: _commentsController.text.trim(),
      );
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Review submitted: $_selectedDecision")),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to submit review")),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Case Details")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? DpEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: _errorMessage!,
                  color: AppColors.errorRed,
                )
              : _buildDetails(),
    );
  }

  Widget _buildDetails() {
    final result = _details?["result"] ?? {};
    final image = _details?["image"];
    final feedback = _details?["feedback"] as List<dynamic>? ?? [];
    final previousReview = _details?["review"];
    final String predictedDisease = result["predicted_disease"] ?? "Unknown";
    final double confidence = ((result["confidence_score"] ?? 0) as num).toDouble();
    final isOverride = _selectedDecision != null && _selectedDecision != predictedDisease;
    final color = dpConfidenceColor(confidence);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ---- Photo
        if (image != null && image["image_id"] != null) ...[
          DpScanImage(imageId: image["image_id"], height: 280, radius: 24),
          const SizedBox(height: 16),
        ],

        // ---- AI prediction
        DpCard(
          accent: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text("AI PREDICTION",
                      style: TextStyle(
                        color: dpMuted(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      )),
                  const Spacer(),
                  DpChip(dpConfidenceLabel(confidence), color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(predictedDisease,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              DpProgressRow(
                label: "Model AI confidence",
                percent: confidence * 100,
                highlight: true,
                color: color,
              ),
              const Divider(),
              const SizedBox(height: 6),
              DpInfoRow(
                icon: Icons.flag_outlined,
                label: "Status",
                value: (result["validation_status"] ?? "Pending").toString(),
              ),
              DpInfoRow(
                icon: Icons.event_outlined,
                label: "Scanned",
                value: dpFormatDate(result["result_date"], withTime: true),
              ),
              if (image != null)
                DpInfoRow(
                  icon: Icons.image_outlined,
                  label: "Image",
                  value: "${image["image_format"] ?? ""}  •  ${image["resolution"] ?? ""}",
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ---- Owner feedback
        DpSectionLabel("Owner feedback (${feedback.length})"),
        if (feedback.isEmpty)
          const DpNotice(
            tone: DpTone.info,
            icon: Icons.chat_bubble_outline,
            text: "No feedback submitted by the owner.",
          )
        else
          ...feedback.map((f) => DpCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote_rounded, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(child: Text("${f["feedback_text"]}", style: const TextStyle(height: 1.4))),
                  ],
                ),
              )),
        const SizedBox(height: 20),

        if (previousReview != null) ...[
          const DpSectionLabel("Previous review"),
          DpNotice(
            tone: DpTone.success,
            title: "Decision: ${previousReview["decision"]}",
            text: (previousReview["comments"] ?? "").toString().isNotEmpty
                ? "Comments: ${previousReview["comments"]}"
                : "",
          ),
          const SizedBox(height: 20),
        ],

        // ---- Review form
        const DpSectionLabel("Your review"),
        DpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Final diagnosis",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _diseaseOptions.map((d) {
                  final selected = d == _selectedDecision;
                  return ChoiceChip(
                    label: Text(d),
                    selected: selected,
                    showCheckmark: true,
                    selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                    labelStyle: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? AppColors.primaryBlue : null,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) => setState(() => _selectedDecision = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              DpNotice(
                tone: isOverride ? DpTone.warning : DpTone.success,
                text: isOverride
                    ? "This overrides the AI's prediction ($predictedDisease)."
                    : "This confirms the AI's prediction.",
              ),
              const SizedBox(height: 16),
              const Text("Treatment notes",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _commentsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "e.g. Recommend antifungal shampoo twice weekly for 3 weeks.",
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReview,
                icon: _isSubmitting ? dpButtonSpinner : const Icon(Icons.send_rounded),
                label: const Text("Submit Review"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
