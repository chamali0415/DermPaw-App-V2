import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
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
      iconSize: 44,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      icon: AnimatedScale(
        scale: filled ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: filled ? Colors.amber : dpMuted(context),
        ),
      ),
      onPressed: () => setState(() => _rating = index),
    );
  }

  static const List<String> _ratingWords = ["", "Poor", "Fair", "Good", "Very good", "Excellent"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rate the App")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? DpEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: _errorMessage!,
                  color: AppColors.errorRed,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DpPageHeader(
                        eyebrow: "Community & support",
                        title: "How would you rate DermPaw?",
                        subtitle: "Your rating helps us improve canine diagnostic models.",
                      ),
                      const SizedBox(height: 18),
                      DpCard(
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) => _buildStar(i + 1)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _rating == 0 ? "Tap a star to rate" : _ratingWords[_rating],
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: _rating == 0 ? dpMuted(context) : Colors.amber[800],
                              ),
                            ),
                            if (_lastUpdated != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                "You last updated your review on $_lastUpdated",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: dpMuted(context), fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const DpSectionLabel("Comments (optional)"),
                      TextField(
                        controller: _commentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: "Tell us what you liked or what could be better...",
                        ),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        child: _isSubmitting
                            ? dpButtonSpinner
                            : Text(_lastUpdated != null ? "Update Review" : "Submit Review"),
                      ),
                    ],
                  ),
                ),
    );
  }
}
