import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';
import 'vet_case_detail_screen.dart';
import 'vet_case_history_screen.dart';
import 'vet_records_screen.dart';
import 'vet_analytics_screen.dart';
import 'vet_stats.dart';
import '../admin/admin_screen.dart';
import '../upload/upload_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../app_review/app_review_screen.dart';
import '../app_review/app_reviews_list_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../core/widgets/language_toggle_button.dart';
import '../../core/localization/app_strings.dart';

/// Veterinarian dashboard.
/// Every card and button opens a real screen:
///   Bell / All Records / "View all"          -> VetRecordsScreen (cases waiting)
///   Verify Now / case row                    -> VetCaseDetailScreen
///   START NEW SCAN VERIFICATION / + button   -> UploadScreen (upload + AI prediction)
///   Verification History / Cases Completed   -> VetCaseHistoryScreen
///   My Scans                                 -> HistoryScreen (scans the vet ran)
///   Analytics                                -> VetAnalyticsScreen
///   Avatar / Profile / Manage                -> ProfileScreen
///   View Ratings / Rate the App              -> AppReviewsListScreen / AppReviewScreen
class VetDashboardScreen extends StatefulWidget {
  const VetDashboardScreen({super.key});

  @override
  State<VetDashboardScreen> createState() => _VetDashboardScreenState();
}

class _VetDashboardScreenState extends State<VetDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _pending = [];
  bool _isVerified = true;
  bool _isAdmin = false;
  bool _isVet = ApiService.currentUserIsVet;

  VetStats _stats = VetStats.empty();
  bool _statsLoaded = false;
  double _averageRating = 0;
  int _myScans = 0;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
    _loadPending();
    _loadStats();
    _loadExtras();
  }

  // ------------------------------------------------------------------ data

  Future<void> _loadStats() async {
    try {
      final result = await ApiService.getVetCaseHistory();
      if (result["statusCode"] == 200 && mounted) {
        setState(() {
          _stats = VetStats.fromHistory(result["body"] as List<dynamic>);
          _statsLoaded = true;
        });
      }
    } catch (_) {
      // Summary numbers only - ignore errors here
    }
  }

  Future<void> _loadExtras() async {
    try {
      final reviews = await ApiService.getAllAppReviews();
      if (reviews["statusCode"] == 200 && mounted) {
        setState(() => _averageRating =
            ((reviews["body"]["average_rating"] ?? 0) as num).toDouble());
      }
      final scans = await ApiService.getHistory();
      if (scans["statusCode"] == 200 && mounted) {
        setState(() => _myScans = (scans["body"] as List).length);
      }
    } catch (_) {
      // Summary numbers only
    }
  }

  Future<void> _loadVerificationStatus() async {
    final result = await ApiService.getProfile();
    if (result["statusCode"] == 200) {
      setState(() {
        _isVerified = result["body"]["is_verified"] ?? true;
        _isAdmin = result["body"]["is_admin"] ?? false;
        _isVet = result["body"]["is_vet"] == true;
        ApiService.rememberUser(result["body"]);
      });
    }
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

  void _handleLogout() {
    ApiService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadVerificationStatus();
    await _loadPending();
    await _loadStats();
    await _loadExtras();
  }

  // ------------------------------------------------------------ navigation

  /// Opens a screen and refreshes the dashboard when the vet comes back.
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    if (mounted) _refreshAll();
  }

  Future<void> _openCase(dynamic item) async {
    final reviewed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VetCaseDetailScreen(resultId: item["result_id"]),
      ),
    );
    if (reviewed == true) {
      _loadPending();
      _loadStats();
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    // Dog owners must never see the veterinarian dashboard
    if (!_isVet && !_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text("Veterinarian Dashboard")),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text("This area is only for registered veterinarians.",
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
                title: Text(context.tr('vet_dashboard')),
        actions: [
          _buildBell(),
          const ThemeToggleButton(),
          const LanguageToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
            onPressed: _handleLogout,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: "vetNewScanFab",
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: "New Verification",
        onPressed: () => _open(const UploadScreen()),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildGreeting(),
            const SizedBox(height: 16),
            if (!_isVerified) ...[
              const DpNotice(
                tone: DpTone.warning,
                icon: Icons.hourglass_empty,
                title: "Verification pending",
                text:
                    "Your veterinary registration is pending admin verification. You can browse cases but cannot submit reviews yet.",
              ),
              const SizedBox(height: 16),
            ],
            _buildCasesCompletedCard(),
            const SizedBox(height: 14),
            _buildConfirmedCard(),
            const SizedBox(height: 14),
            _buildRecentCasesCard(),
            const SizedBox(height: 18),
            _buildStartScanButton(),
            if (_isAdmin) ...[
              const SizedBox(height: 14),
              _buildAdminCard(),
            ],
            const SizedBox(height: 24),
            DpSectionLabel(
              "Quick services",
              trailing: TextButton(
                onPressed: () => _open(const ProfileScreen()),
                child: const Text("Manage"),
              ),
            ),
            _buildQuickServices(),
            const SizedBox(height: 24),
            const DpSectionLabel("App performance & ratings"),
            _buildRatingsCard(),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- sections

  Widget _buildBell() {
    final count = _pending.length;
    return IconButton(
      tooltip: "Cases waiting for you",
      onPressed: () => _open(const VetRecordsScreen()),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? "99+" : "$count"),
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }

  Widget _buildGreeting() {
    final rawName = (ApiService.currentUserName ?? "").trim();
    // Avoid "Dr. Dr. Name" if the vet already typed "Dr." in their name
    final name = rawName.isEmpty
        ? "Doctor"
        : rawName.replaceFirst(RegExp(r'^dr\.?\s*', caseSensitive: false), "");

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DpPageHeader(
            title: "Welcome, Dr. $name!",
            subtitle: "Here is today's overview of dog skin cases.",
          ),
        ),
        const SizedBox(width: 12),
        DpProfileAvatar(
          size: 64,
          onTap: () => _open(const ProfileScreen()),
        ),
      ],
    );
  }

  Widget _buildCasesCompletedCard() {
    return DpCard(
      onTap: () => _open(const VetCaseHistoryScreen()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Cases Completed",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text("Your reviews in the last 7 days",
                    style: TextStyle(fontSize: 11.5, color: dpMuted(context))),
                const SizedBox(height: 10),
                DpLineChart(values: _stats.last7Days, labels: _stats.last7Labels, height: 84),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text("Cases:", style: TextStyle(fontSize: 12.5, color: dpMuted(context))),
                const SizedBox(height: 4),
                Text(_statsLoaded ? "${_stats.total}" : "–",
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmedCard() {
    Widget line(String label, int value, int week) {
      return Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14),
          children: [
            TextSpan(text: "$label: "),
            TextSpan(
                text: _statsLoaded ? "$value" : "–",
                style: const TextStyle(fontWeight: FontWeight.w800)),
            if (_statsLoaded)
              TextSpan(
                text: "  (+$week this week)",
                style: const TextStyle(
                    fontSize: 12, color: AppColors.confidenceGreen, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      );
    }

    return DpCard(
      onTap: () => _open(const VetAnalyticsScreen()),
      child: Row(
        children: [
          const DpIconTile(Icons.description_outlined, size: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line("My Confirmed Cases", _stats.confirmed, _stats.confirmedThisWeek),
                const SizedBox(height: 6),
                line("AI Corrected Cases", _stats.corrected, _stats.correctedThisWeek),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCasesCard() {
    final cases = _pending;
    final shown = cases.take(3).toList();

    Widget body;
    if (_isLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_errorMessage != null) {
      body = DpNotice(tone: DpTone.danger, text: "$_errorMessage. Pull down to try again.");
    } else if (shown.isEmpty) {
      body = const DpNotice(
        tone: DpTone.success,
        icon: Icons.celebration_outlined,
        title: "All caught up!",
        text: "There are no cases waiting for verification.",
      );
    } else {
      body = Column(
        children: [
          for (int i = 0; i < shown.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
            VetCaseRow(index: i + 1, item: shown[i], onVerify: () => _openCase(shown[i])),
          ],
          if (cases.length > shown.length) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _open(const VetRecordsScreen()),
              child: Text("View all ${cases.length} cases"),
            ),
          ],
        ],
      );
    }

    return DpCard(
      accent: AppColors.orange,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text("RECENT CASES FOR VERIFICATION",
                    style: TextStyle(
                      color: dpMuted(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    )),
              ),
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
              ),
              const Spacer(),
              if (shown.isNotEmpty)
                Text("1-${shown.length} of ${cases.length}",
                    style: TextStyle(fontSize: 12, color: dpMuted(context))),
            ],
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }

  Widget _buildStartScanButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(const UploadScreen()),
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.document_scanner_outlined, color: Colors.white),
              SizedBox(width: 10),
              Text(
                "START NEW SCAN VERIFICATION",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard() {
    return DpCard(
      onTap: () => _open(const AdminScreen()),
      child: Row(
        children: [
          const DpIconTile(Icons.verified_user_outlined, color: AppColors.purple, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Verify Vets (Admin)",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text("Approve veterinarian registrations",
                    style: TextStyle(fontSize: 12.5, color: dpMuted(context))),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: dpMuted(context)),
        ],
      ),
    );
  }

  Widget _buildQuickServices() {
    return Row(
      children: [
        Expanded(
          child: _serviceTile(
            icon: Icons.manage_history,
            color: AppColors.purple,
            title: "Verification History",
            subtitle: "Records: ${_statsLoaded ? _stats.total : '–'}",
            onTap: () => _open(const VetCaseHistoryScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _serviceTile(
            icon: Icons.assignment_outlined,
            color: AppColors.primaryBlue,
            title: "Patient Records",
            subtitle: "Waiting: ${_isLoading ? '–' : _pending.length}",
            onTap: () => _open(const VetRecordsScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _serviceTile(
            icon: Icons.photo_camera_back_outlined,
            color: AppColors.tealAccent,
            title: "My Scans",
            subtitle: "Total: $_myScans",
            onTap: () => _open(const HistoryScreen()),
          ),
        ),
      ],
    );
  }

  Widget _serviceTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return DpCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          DpIconTile(icon, color: color, size: 46),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 2),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: dpMuted(context))),
        ],
      ),
    );
  }

  Widget _buildRatingsCard() {
    final stars = List.generate(5, (i) {
      final value = _averageRating - i;
      return Icon(
        value >= 0.75
            ? Icons.star_rounded
            : value >= 0.25
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
        color: Colors.amber,
        size: 20,
      );
    });

    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: const DpIconTile(Icons.star_rounded, color: Colors.amber, size: 44),
            title: const Text("App Ratings", style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Row(
              children: [
                ...stars,
                const SizedBox(width: 6),
                Text(_averageRating > 0 ? _averageRating.toStringAsFixed(1) : "–",
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            trailing: TextButton(
              onPressed: () => _open(const AppReviewsListScreen()),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text("View Ratings"), Icon(Icons.chevron_right, size: 18)],
              ),
            ),
            onTap: () => _open(const AppReviewsListScreen()),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const DpIconTile(Icons.rate_review_outlined, size: 44),
            title: const Text("Rate the App", style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text("Share feedback as a veterinarian"),
            trailing: Icon(Icons.chevron_right, color: dpMuted(context)),
            onTap: () => _open(const AppReviewScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      height: 68,
      child: Row(
        children: [
          _navItem(Icons.home_rounded, "Dashboard", selected: true, onTap: () {}),
          _navItem(Icons.assignment_outlined, "All Records",
              onTap: () => _open(const VetRecordsScreen())),
          Expanded(
            child: InkWell(
              onTap: () => _open(const UploadScreen()),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("New Verification",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
          _navItem(Icons.insights_outlined, "Analytics",
              onTap: () => _open(const VetAnalyticsScreen())),
          _navItem(Icons.person_outline, "Profile",
              onTap: () => _open(const ProfileScreen())),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label,
      {bool selected = false, required VoidCallback onTap}) {
    final color = selected ? AppColors.primaryBlue : dpMuted(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}