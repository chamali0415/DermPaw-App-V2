import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
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
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  /// How many reviews gave 5, 4, 3, 2, 1 stars
  Map<int, int> get _distribution {
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final v = ((r["rating"] ?? 0) as num).round();
      if (counts.containsKey(v)) counts[v] = counts[v]! + 1;
    }
    return counts;
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
                ? DpEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: _errorMessage!,
                    message: "Pull down to try again.",
                    color: AppColors.errorRed,
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      const DpPageHeader(
                        eyebrow: "Community & support",
                        title: "What users say",
                        subtitle: "User stories and veterinary testimonials.",
                      ),
                      const SizedBox(height: 18),
                      DpCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Text(
                                  _averageRating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
                                ),
                                _buildStarRow(_averageRating, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  "$_totalReviews review${_totalReviews == 1 ? '' : 's'}",
                                  style: TextStyle(color: dpMuted(context), fontSize: 12.5),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: _distribution.entries.map((e) {
                                  final share = _reviews.isEmpty ? 0.0 : e.value / _reviews.length;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          child: Text("${e.key}",
                                              style: const TextStyle(
                                                  fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                        const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: share,
                                              minHeight: 7,
                                              backgroundColor: dpMuted(context).withOpacity(0.15),
                                              valueColor:
                                                  const AlwaysStoppedAnimation(Colors.amber),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      DpSectionLabel("Reviews ($_totalReviews)"),
                      if (_reviews.isEmpty)
                        const DpNotice(
                          tone: DpTone.info,
                          icon: Icons.chat_bubble_outline,
                          text: "No reviews yet. Be the first to rate DermPaw!",
                        )
                      else
                        ..._reviews.map((review) {
                          final comment = (review["comment"] ?? "").toString();
                          return DpCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    DpInitialAvatar(name: review["reviewer_name"], size: 40),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review["reviewer_name"] ?? "Anonymous",
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                          const SizedBox(height: 2),
                                          _buildStarRow(review["rating"] ?? 0, size: 16),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      dpFormatDate(review["updated_at"]),
                                      style: TextStyle(fontSize: 12, color: dpMuted(context)),
                                    ),
                                  ],
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(comment, style: const TextStyle(height: 1.4)),
                                ],
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}
