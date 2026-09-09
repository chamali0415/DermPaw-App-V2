import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
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
      appBar: AppBar(title: const Text("Diagnosis History")),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : _results.isEmpty
                    ? const Center(child: Text("No diagnosis history yet"))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final vetReview = item["vet_review"];
                          final hasReview = vetReview != null;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ExpansionTile(
                              title: Text(item["predicted_disease"] ?? "Unknown"),
                              subtitle: Text(
                                "Confidence: ${(item["confidence_score"] * 100).toStringAsFixed(1)}%",
                              ),
                              trailing: hasReview
                                  ? Chip(
                                      label: const Text(
                                        "Vet Reviewed",
                                        style: TextStyle(fontSize: 11, color: Colors.white),
                                      ),
                                      backgroundColor: Colors.green[600],
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    )
                                  : item["review_requested"] == true
                                      ? Chip(
                                          label: const Text(
                                            "Pending Review",
                                            style: TextStyle(fontSize: 11, color: Colors.white),
                                          ),
                                          backgroundColor: Colors.orange[600],
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        )
                                      : null,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (item["image_id"] != null) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            "${ApiService.baseUrl}/images/${item["image_id"]}/file",
                                            headers: {
                                              if (ApiService.authToken != null)
                                                "Authorization": "Bearer ${ApiService.authToken}",
                                            },
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 220,
                                            loadingBuilder: (context, child, progress) {
                                              if (progress == null) return child;
                                              return Container(
                                                height: 220,
                                                alignment: Alignment.center,
                                                child: const CircularProgressIndicator(),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              height: 220,
                                              alignment: Alignment.center,
                                              color: Colors.grey[300],
                                              child: const Text("Image could not be loaded"),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      Text(
                                        "Date: ${(item["result_date"] ?? "").toString().split("T").first}",
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 12),
                                      if (hasReview) ...[
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Veterinarian's Review",
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        if (vetReview["decision"] != item["predicted_disease"])
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[50],
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.orange[200]!),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.info_outline,
                                                    size: 16, color: Colors.orange[800]),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    "The vet corrected the diagnosis to: ${vetReview["decision"]}",
                                                    style: TextStyle(
                                                        fontSize: 13, color: Colors.orange[900]),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.green[200]!),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.check_circle_outline,
                                                    size: 16, color: Colors.green[800]),
                                                const SizedBox(width: 6),
                                                const Expanded(
                                                  child: Text(
                                                    "Vet confirmed the AI's diagnosis",
                                                    style: TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if ((vetReview["comments"] ?? "")
                                            .toString()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          const Text(
                                            "Treatment Notes:",
                                            style: TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(vetReview["comments"]),
                                        ],
                                      ] else if (item["review_requested"] == true) ...[
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.hourglass_empty,
                                                size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Waiting for a vet to review this case",
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Your Feedback",
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_submittedFeedback.contains(item["result_id"]))
                                        Row(
                                          children: [
                                            Icon(Icons.check_circle_outline,
                                                size: 16, color: Colors.green[700]),
                                            const SizedBox(width: 6),
                                            const Text(
                                              "Feedback submitted",
                                              style: TextStyle(
                                                  color: Colors.green,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        )
                                      else ...[
                                        TextField(
                                          controller: _controllerFor(item["result_id"]),
                                          maxLines: 3,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            hintText:
                                                "How was your experience? Any comments on this diagnosis?",
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton(
                                            onPressed: _submittingFeedback
                                                    .contains(item["result_id"])
                                                ? null
                                                : () => _submitFeedback(item["result_id"]),
                                            child: _submittingFeedback
                                                    .contains(item["result_id"])
                                                ? const SizedBox(
                                                    height: 16,
                                                    width: 16,
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2),
                                                  )
                                                : const Text("Submit Feedback"),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}