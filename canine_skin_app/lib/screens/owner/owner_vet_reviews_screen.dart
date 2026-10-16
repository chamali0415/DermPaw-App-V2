import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
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
            : _errorMessage != null
                ? DpEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: _errorMessage!,
                    message: "Pull down to try again.",
                    color: AppColors.errorRed,
                  )
                : _items.isEmpty
                    ? const DpEmptyState(
                        icon: Icons.medical_services_outlined,
                        title: "No vet reviews yet",
                        message:
                            "After a scan, tap \"Request Veterinarian Review\" to send it to a vet.",
                        color: AppColors.tealAccent,
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          const DpPageHeader(
                            eyebrow: "Veterinary care",
                            title: "Your vet reviews",
                            subtitle: "Cases you sent to a veterinarian and their decisions.",
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _statTile(Icons.verified_outlined, "$reviewed", "Ready",
                                    AppColors.confidenceGreen),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _statTile(
                                    Icons.hourglass_empty, "$waiting", "Waiting", AppColors.orange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          DpSectionLabel("Cases (${_items.length})"),
                          ..._items.map(_buildCard),
                        ],
                      ),
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return DpCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          DpIconTile(icon, color: color, size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(fontSize: 12, color: dpMuted(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic item) {
    final review = item["vet_review"];
    final isReviewed = review != null;
    final String aiDisease = item["predicted_disease"] ?? "Unknown";
    final double confidence = ((item["confidence_score"] ?? 0) as num).toDouble();
    final decision = isReviewed ? review["decision"] : null;
    final corrected = isReviewed && decision != aiDisease;
    final comments = isReviewed ? (review["comments"] ?? "").toString() : "";

    return DpCard(
      margin: const EdgeInsets.only(bottom: 12),
      accent: isReviewed ? (corrected ? AppColors.orange : AppColors.confidenceGreen) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DpScanImage(imageId: item["image_id"], width: 60, height: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(aiDisease,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      "AI ${(confidence * 100).toStringAsFixed(1)}%  •  ${_formatDate(item["result_date"])}",
                      style: TextStyle(color: dpMuted(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              DpChip(
                isReviewed ? "Reviewed" : "Waiting",
                color: isReviewed ? AppColors.confidenceGreen : AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isReviewed)
            const DpNotice(
              tone: DpTone.info,
              icon: Icons.hourglass_empty,
              text: "A veterinarian has not reviewed this case yet.",
            )
          else
            DpNotice(
              tone: corrected ? DpTone.warning : DpTone.success,
              title: corrected
                  ? "Vet corrected the diagnosis to: $decision"
                  : "Vet confirmed the AI result: $decision",
              text: comments.isNotEmpty ? "Vet's note: $comments" : "",
            ),
        ],
      ),
    );
  }
}
