import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';

class AppReviewScreen extends StatefulWidget {
  const AppReviewScreen({super.key});

  @override
  State<AppReviewScreen> createState() => _AppReviewScreenState();
}

class _AppReviewScreenState extends State<AppReviewScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  @override
  void dispose() {
    _commentController.dispose();
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

  Future<void> _loadExistingReview() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getAppReview();
      if (result["statusCode"] == 200) {
        final review = result["body"]["review"];
        if (review != null) {
          setState(() {
            _rating = review["rating"] ?? 0;
            _commentController.text = review["comment"] ?? "";
            _lastUpdated = (review["updated_at"] ?? "").toString().split("T").first;
          });
        }
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = "Could not load your review");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.submitAppReview(
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200 || result["statusCode"] == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Thank you for your feedback!")),
          );
          Navigator.pop(context);
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

  Widget _buildStar(int index) {
    final filled = index <= _rating;
    return IconButton(
      iconSize: 40,
      icon: Icon(
        filled ? Icons.star : Icons.star_border,
        color: filled ? Colors.amber : Colors.grey,
      ),
      onPressed: () => setState(() => _rating = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rate the App")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        "How would you rate DermPaw?",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) => _buildStar(i + 1)),
                      ),
                      if (_lastUpdated != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "You last updated your review on $_lastUpdated",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        "Comments (optional)",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Tell us what you liked or what could be better...",
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_lastUpdated != null ? "Update Review" : "Submit Review"),
                      ),
                    ],
                  ),
                ),
    );
  }
}