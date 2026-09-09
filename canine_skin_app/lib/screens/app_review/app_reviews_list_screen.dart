import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';

class AppReviewsListScreen extends StatefulWidget {
  const AppReviewsListScreen({super.key});

  @override
  State<AppReviewsListScreen> createState() => _AppReviewsListScreenState();
}

class _AppReviewsListScreenState extends State<AppReviewsListScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  double _averageRating = 0;
  int _totalReviews = 0;
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
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

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getAllAppReviews();
      if (result["statusCode"] == 200) {
        final body = result["body"];
        setState(() {
          _averageRating = (body["average_rating"] ?? 0).toDouble();
          _totalReviews = body["total_reviews"] ?? 0;
          _reviews = body["reviews"] ?? [];
          _errorMessage = null;
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = "Could not load reviews");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStarRow(num rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.round();
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("App Reviews")),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                _averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 40, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              _buildStarRow(_averageRating, size: 24),
                              const SizedBox(height: 4),
                              Text(
                                "$_totalReviews review${_totalReviews == 1 ? '' : 's'}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text("No reviews yet")),
                        )
                      else
                        ..._reviews.map((review) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        review["reviewer_name"] ?? "Anonymous",
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        (review["updated_at"] ?? "")
                                            .toString()
                                            .split("T")
                                            .first,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  _buildStarRow(review["rating"] ?? 0),
                                  if ((review["comment"] ?? "").toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(review["comment"]),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}