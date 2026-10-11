import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';

/// Dog-owner view of vet reviews: only the owner's OWN scans that were sent
/// to a vet (or flagged for review because of low confidence), with the
/// vet's decision once it arrives. This replaces the old behaviour where the
/// owner's "Vet Reviews" button opened the veterinarian dashboard.
class OwnerVetReviewsScreen extends StatefulWidget {
  const OwnerVetReviewsScreen({super.key});

  @override
  State<OwnerVetReviewsScreen> createState() => _OwnerVetReviewsScreenState();
}

class _OwnerVetReviewsScreenState extends State<OwnerVetReviewsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getHistory();
      if (result["statusCode"] == 200) {
        final all = result["body"] as List<dynamic>;
        setState(() {
          _items = all
              .where((r) => r["vet_review"] != null || r["review_requested"] == true)
              .toList();
          _errorMessage = null;
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = result["body"]["error"] ?? "Could not load vet reviews");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSessionExpired() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Your session has expired. Please log in again.")),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return "";
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return "";
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final reviewed = _items.where((r) => r["vet_review"] != null).length;
    final waiting = _items.length - reviewed;

    return Scaffold(
      appBar: AppBar(title: const Text("Vet Reviews")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.errorRed)),
                    ),
                  Row(
                    children: [
                      _countChip("$reviewed Ready", AppColors.confidenceGreen),
                      const SizedBox(width: 8),
                      _countChip("$waiting Waiting", AppColors.amberText),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_items.isEmpty && _errorMessage == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.medical_services_outlined, size: 48, color: AppColors.textGrey),
                          const SizedBox(height: 12),
                          const Text(
                            "No vet reviews yet.\nAfter a scan, tap \"Request Vet Review\" to send it to a veterinarian.",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ..._items.map(_buildCard),
                ],
              ),
      ),
    );
  }

  Widget _countChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCard(dynamic item) {
    final review = item["vet_review"];
    final isReviewed = review != null;
    final aiDisease = item["predicted_disease"] ?? "Unknown";
    final confidence = ((item["confidence_score"] ?? 0) * 100).toStringAsFixed(1);
    final decision = isReviewed ? review["decision"] : null;
    final corrected = isReviewed && decision != aiDisease;
    final comments = isReviewed ? (review["comments"] ?? "") : "";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ApiService.imageFileUrl(item["image_id"]),
                headers: ApiService.imageHeaders,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  child: const Icon(Icons.pets, color: AppColors.primaryBlue),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(aiDisease,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      _countChip(isReviewed ? "Reviewed" : "Waiting",
                          isReviewed ? AppColors.confidenceGreen : AppColors.amberText),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("AI confidence: $confidence%  •  ${_formatDate(item["result_date"])}",
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (!isReviewed)
                    const Text("A veterinarian has not reviewed this case yet.",
                        style: TextStyle(fontSize: 13))
                  else ...[
                    Text(
                      corrected
                          ? "Vet corrected the diagnosis to: $decision"
                          : "Vet confirmed the AI result: $decision",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: corrected ? AppColors.amberText : AppColors.confidenceGreen,
                      ),
                    ),
                    if (comments.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text("Vet's note: $comments", style: const TextStyle(fontSize: 13)),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
