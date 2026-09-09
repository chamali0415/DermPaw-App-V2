import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';


class VetReviewScreen extends StatefulWidget {
  const VetReviewScreen({super.key});

  @override
  State<VetReviewScreen> createState() => _VetReviewScreenState();
}

class _VetReviewScreenState extends State<VetReviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _pending = [];

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
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getPendingReviews();
      if (result["statusCode"] == 200) {
        setState(() {
          _pending = result["body"];
          _errorMessage = null;
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = result["body"]["error"] ?? "Could not load reviews");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitDecision(int resultId, String decision) async {
    final result = await ApiService.submitReview(resultId: resultId, decision: decision);
    if (result["statusCode"] == 401) {
      _handleSessionExpired();
      return;
    }
    if (result["statusCode"] == 201) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Review submitted: $decision")),
        );
      }
      _loadPending();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to submit review")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Vet Reviews")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _pending.isEmpty
                  ? const Center(child: Text("No pending reviews"))
                  : ListView.builder(
                      itemCount: _pending.length,
                      itemBuilder: (context, index) {
                        final item = _pending[index];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item["predicted_disease"] ?? "Unknown",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Confidence: ${(item["confidence_score"] * 100).toStringAsFixed(1)}%",
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () =>
                                          _submitDecision(item["result_id"], "Confirmed"),
                                      child: const Text("Confirm"),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _submitDecision(item["result_id"], "Rejected"),
                                      child: const Text("Reject"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}