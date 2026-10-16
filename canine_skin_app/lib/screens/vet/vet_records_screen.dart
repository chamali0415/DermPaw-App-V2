import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
import '../auth/login_screen.dart';
import 'vet_case_detail_screen.dart';

/// "All Records" for vets: every case waiting for verification,
/// with filters. Tap a case (or "Verify Now") to open it.
class VetRecordsScreen extends StatefulWidget {
  /// 0 = all, 1 = owner requested, 2 = low confidence
  final int initialFilter;

  const VetRecordsScreen({super.key, this.initialFilter = 0});

  @override
  State<VetRecordsScreen> createState() => _VetRecordsScreenState();
}

class _VetRecordsScreenState extends State<VetRecordsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _pending = [];
  late int _filter = widget.initialFilter;

  static const _filters = ["All cases", "Owner requested", "Low confidence"];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
        setState(() => _errorMessage = result["body"]["error"] ?? "Could not load cases");
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

  List<dynamic> get _filtered {
    switch (_filter) {
      case 1:
        return _pending.where((c) => c["review_requested"] == true).toList();
      case 2:
        return _pending
            .where((c) => ((c["confidence_score"] ?? 0) as num).toDouble() < 0.5)
            .toList();
      default:
        return _pending;
    }
  }

  Future<void> _openCase(dynamic item) async {
    final reviewed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VetCaseDetailScreen(resultId: item["result_id"])),
    );
    if (reviewed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cases = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text("All Records")),
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
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      const DpPageHeader(
                        eyebrow: "Patient records",
                        title: "Cases for verification",
                        subtitle: "Every dog skin case waiting for a veterinarian's review.",
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_filters.length, (i) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_filters[i]),
                                selected: _filter == i,
                                selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  fontWeight: _filter == i ? FontWeight.w800 : FontWeight.w500,
                                  color: _filter == i ? AppColors.primaryBlue : null,
                                ),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                onSelected: (_) => setState(() => _filter = i),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DpSectionLabel("Waiting (${cases.length})"),
                      if (cases.isEmpty)
                        const DpNotice(
                          tone: DpTone.success,
                          icon: Icons.celebration_outlined,
                          title: "All caught up!",
                          text: "No cases match this filter right now.",
                        )
                      else
                        ...List.generate(cases.length, (i) => VetCaseRow(
                              index: i + 1,
                              item: cases[i],
                              onVerify: () => _openCase(cases[i]),
                              boxed: true,
                            )),
                    ],
                  ),
      ),
    );
  }
}

/// One pending case: photo, numbered title, status line, confidence chip
/// and a "Verify Now" button. Shared by the dashboard and All Records.
class VetCaseRow extends StatelessWidget {
  final int index;
  final dynamic item;
  final VoidCallback onVerify;
  final bool boxed;

  const VetCaseRow({
    super.key,
    required this.index,
    required this.item,
    required this.onVerify,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    final double confidence = ((item["confidence_score"] ?? 0) as num).toDouble();
    final color = dpConfidenceColor(confidence);
    final requested = item["review_requested"] == true;

    final row = InkWell(
      onTap: onVerify,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.all(boxed ? 0 : 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DpScanImage(imageId: item["image_id"], width: 66, height: 66),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "$index. ${item["predicted_disease"] ?? "Unknown"}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      DpChip(dpConfidenceLabel(confidence), color: color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 12.5, color: dpMuted(context), height: 1.35),
                      children: [
                        const TextSpan(
                            text: "Status: ", style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(
                          text: requested
                              ? "Owner requested a review "
                              : "Pending verification ",
                        ),
                        TextSpan(text: "(AI confidence ${(confidence * 100).toStringAsFixed(0)}%)"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(fontSize: 12.5, color: dpMuted(context)),
                            children: [
                              const TextSpan(
                                  text: "Submitted: ",
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: dpRelativeDay(item["result_date"])),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: onVerify,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle:
                                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                          child: const Text("Verify Now"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!boxed) return row;
    return DpCard(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), child: row);
  }
}
