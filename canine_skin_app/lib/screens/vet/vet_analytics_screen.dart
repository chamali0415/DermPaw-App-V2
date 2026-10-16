import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
import '../auth/login_screen.dart';
import 'vet_stats.dart';

/// Vet analytics: how many cases this vet reviewed, how often they agreed
/// with the AI, weekly activity and the final diagnoses they gave.
class VetAnalyticsScreen extends StatefulWidget {
  const VetAnalyticsScreen({super.key});

  @override
  State<VetAnalyticsScreen> createState() => _VetAnalyticsScreenState();
}

class _VetAnalyticsScreenState extends State<VetAnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  VetStats _stats = VetStats.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getVetCaseHistory();
      if (result["statusCode"] == 200) {
        setState(() {
          _stats = VetStats.fromHistory(result["body"] as List<dynamic>);
          _errorMessage = null;
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = result["body"]["error"] ?? "Could not load analytics");
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
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final agreement = s.total == 0 ? 0.0 : s.confirmed / s.total;
    final sortedDecisions = s.byDecision.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text("Analytics")),
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
                        eyebrow: "Analytics",
                        title: "Your review activity",
                        subtitle: "How your decisions compare with the AI model.",
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: _tile("${s.total}", "Reviewed", Icons.task_alt, AppColors.primaryBlue)),
                          const SizedBox(width: 10),
                          Expanded(child: _tile("${s.confirmed}", "Confirmed", Icons.check_circle_outline, AppColors.confidenceGreen)),
                          const SizedBox(width: 10),
                          Expanded(child: _tile("${s.corrected}", "Corrected", Icons.edit_outlined, AppColors.orange)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DpCard(
                        child: Row(
                          children: [
                            DpConfidenceRing(
                              confidence: agreement,
                              color: AppColors.confidenceGreen,
                              size: 96,
                              caption: "Agreement",
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("AI agreement rate",
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 6),
                                  Text(
                                    s.total == 0
                                        ? "Review a case to see how often you agree with the AI."
                                        : "You confirmed the AI's diagnosis in ${s.confirmed} of ${s.total} cases and corrected it in ${s.corrected}.",
                                    style: TextStyle(fontSize: 13, color: dpMuted(context), height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const DpSectionLabel("Reviews per week (last 8 weeks)"),
                      DpCard(
                        child: DpLineChart(
                          values: s.last8Weeks,
                          labels: const ["8w", "7w", "6w", "5w", "4w", "3w", "2w", "This wk"],
                          height: 140,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const DpSectionLabel("Your final diagnoses"),
                      DpCard(
                        child: sortedDecisions.isEmpty
                            ? Text("No reviews yet.", style: TextStyle(color: dpMuted(context)))
                            : Column(
                                children: sortedDecisions
                                    .map((e) => DpProgressRow(
                                          label: "${e.key} (${e.value})",
                                          percent: s.total == 0 ? 0 : e.value / s.total * 100,
                                          highlight: e.key == sortedDecisions.first.key,
                                        ))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _tile(String value, String label, IconData icon, Color color) {
    return DpCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DpIconTile(icon, color: color, size: 34),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: dpMuted(context))),
        ],
      ),
    );
  }
}
