import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
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
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _buildDetails(),
    );
  }

  Widget _buildDetails() {
    final result = _details?["result"] ?? {};
    final image = _details?["image"];
    final feedback = _details?["feedback"] as List<dynamic>? ?? [];
    final previousReview = _details?["review"];
    final predictedDisease = result["predicted_disease"] ?? "Unknown";
    final isOverride = _selectedDecision != null && _selectedDecision != predictedDisease;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- IMAGE DISPLAY ----
          if (image != null && image["image_id"] != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                "${ApiService.baseUrl}/images/${image["image_id"]}/file",
                headers: {
                  if (ApiService.authToken != null)
                    "Authorization": "Bearer ${ApiService.authToken}",
                },
                fit: BoxFit.cover,
                width: double.infinity,
                height: 280,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 280,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 280,
                  alignment: Alignment.center,
                  color: Colors.grey[300],
                  child: const Text("Image could not be loaded"),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---- AI PREDICTION ----
          Text(
            "AI Prediction: $predictedDisease",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Confidence: ${((result["confidence_score"] ?? 0) * 100).toStringAsFixed(1)}%",
          ),
          const SizedBox(height: 4),
          Text("Status: ${result["validation_status"] ?? "Pending"}"),
          const SizedBox(height: 4),
          Text("Date: ${(result["result_date"] ?? "Unknown").toString().split("T").first}"),
          const SizedBox(height: 16),

          if (image != null) ...[
            const Text("Image Details", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Format: ${image["image_format"]}, Resolution: ${image["resolution"]}"),
            const SizedBox(height: 16),
          ],

          // ---- OWNER FEEDBACK ----
          const Text("Owner Feedback", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          feedback.isEmpty
              ? const Text("No feedback submitted")
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: feedback
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text("• ${f["feedback_text"]}"),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 16),

          if (previousReview != null) ...[
            const Text("Previous Review", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Decision: ${previousReview["decision"]}"),
            if ((previousReview["comments"] ?? "").toString().isNotEmpty)
              Text("Comments: ${previousReview["comments"]}"),
            const SizedBox(height: 16),
          ],

          const Divider(),
          const SizedBox(height: 8),

          // ---- STRUCTURED REVIEW FORM ----
          const Text(
            "Your Review",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          const Text("Final Diagnosis"),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _selectedDecision,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _diseaseOptions
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (value) => setState(() => _selectedDecision = value),
          ),
          const SizedBox(height: 8),
          if (isOverride)
            const Text(
              "This overrides the AI's prediction",
              style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
            )
          else
            const Text(
              "This confirms the AI's prediction",
              style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 16),

          const Text("Treatment Notes"),
          const SizedBox(height: 4),
          TextField(
            controller: _commentsController,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "e.g. Recommend antifungal shampoo twice weekly for 3 weeks.",
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Submit Review"),
            ),
          ),
        ],
      ),
    );
  }
}