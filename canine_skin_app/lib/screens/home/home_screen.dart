import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../upload/upload_screen.dart';
import '../history/history_screen.dart';
import '../owner/owner_vet_reviews_screen.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../app_review/app_review_screen.dart';
import '../app_review/app_reviews_list_screen.dart';
import '../admin/admin_screen.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../core/widgets/language_toggle_button.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/dp_ui.dart';

/// Dog-owner dashboard ("Pet Health Monitor").
/// Every card and button opens a real screen:
///   Total diagnoses / Records / History / Full Details -> HistoryScreen
///   Upload card / New Scan                             -> UploadScreen
///   My Profile / Profile / Manage                      -> ProfileScreen
///   Vet Reviews / Vets / bell                          -> OwnerVetReviewsScreen
///   Rate the App                                       -> AppReviewScreen
///   View App Reviews                                   -> AppReviewsListScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;
  List<dynamic> _history = [];
  double _averageRating = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ---------------------------------------------------------------- data

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getHistory();
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        _history = result["body"] as List<dynamic>;
      }

      final profileResult = await ApiService.getProfile();
      if (profileResult["statusCode"] == 200) {
        final profile = profileResult["body"];
        _isAdmin = profile["is_admin"] ?? false;
        ApiService.rememberUser(profile);
      }

      final reviewsResult = await ApiService.getAllAppReviews();
      if (reviewsResult["statusCode"] == 200) {
        _averageRating = ((reviewsResult["body"]["average_rating"] ?? 0) as num).toDouble();
      }
    } catch (e) {
      // Dashboard summary only; individual screens show their own errors
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Backend stores UTC without a "Z"; treat it as UTC, show local time.
  DateTime? _parseDate(String? iso) {
    if (iso == null) return null;
    final hasZone = iso.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(iso);
    return DateTime.tryParse(hasZone ? iso : "${iso}Z")?.toLocal();
  }

  int get _thisMonthCount {
    final now = DateTime.now();
    return _history.where((r) {
      final d = _parseDate(r["result_date"]);
      return d != null && d.year == now.year && d.month == now.month;
    }).length;
  }

  int get _reviewedCount => _history.where((r) => r["vet_review"] != null).length;

  String _formatWhen(DateTime? d) {
    if (d == null) return "";
    final now = DateTime.now();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final time = "$hour:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}";
    if (d.year == now.year && d.month == now.month && d.day == now.day) return context.tr('today_time').replaceAll('{time}', time);
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${d.day} ${months[d.month - 1]}, $time";
  }

  // ---------------------------------------------------------- navigation

  void _handleSessionExpired() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('session_expired'))),
    );
  }

  void _handleLogout() {
    ApiService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Opens a screen and refreshes the dashboard when the user comes back.
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    if (mounted) _loadDashboardData();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(context.tr('dashboard')),
        actions: [
          const ThemeToggleButton(),
          const LanguageToggleButton(),
          IconButton(
            tooltip: context.tr('vet_review_updates'),
            onPressed: () => _open(const OwnerVetReviewsScreen()),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (_reviewedCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: context.tr('logout'),
            onPressed: _handleLogout,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: "newScanFab",
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: context.tr('new_scan'),
        onPressed: () => _open(const UploadScreen()),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: _buildBottomBar(scheme),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildGreeting(),
            const SizedBox(height: 16),
            _buildHero(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildTotalCard(),
              const SizedBox(height: 16),
              _buildRecentDiagnosisCard(),
            ],
            const SizedBox(height: 16),
            _buildUploadCard(),
            const SizedBox(height: 24),
            _sectionHeader(context.tr('quick_services'),
                trailing: TextButton(
                  onPressed: () => _open(const ProfileScreen()),
                  child: Text(context.tr('manage')),
                )),
            const SizedBox(height: 8),
            _buildQuickServices(),
            if (_isAdmin) ...[
              const SizedBox(height: 12),
              _listTileCard(
                icon: Icons.verified_user_outlined,
                iconColor: Colors.deepPurple,
                title: context.tr('verify_vets_admin'),
                subtitle: context.tr('approve_vet_regs'),
                onTap: () => _open(const AdminScreen()),
              ),
            ],
            const SizedBox(height: 24),
            _sectionHeader(context.tr('community_support')),
            const SizedBox(height: 8),
            _buildCommunityCard(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- sections

  Widget _buildGreeting() {
    // Greet with the FIRST name only ("Chamali Tharushika" -> "Chamali")
    final fullName = (ApiService.currentUserName ?? "").trim();
    final firstName = fullName.isEmpty ? "" : fullName.split(RegExp(r'\s+')).first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('pet_health_monitor'),
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                firstName.isEmpty
                    ? context.tr('welcome')
                    : context.tr('welcome_name').replaceAll('{name}', firstName),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('today_overview'),
                style: TextStyle(color: AppColors.textGrey, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        DpProfileAvatar(
          size: 56,
          onTap: () => _open(const ProfileScreen()),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.asset(
          "assets/images/dashboard_hero.jpg",
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.tealAccent, AppColors.primaryBlue],
              ),
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 64),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    final monthCount = _thisMonthCount;
    return _card(
      onTap: () => _open(const HistoryScreen()),
      child: Row(
        children: [
          _iconTile(Icons.description_outlined, AppColors.primaryBlue, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text("${_history.length}",
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    if (monthCount > 0)
                      _chip(context.tr('this_month').replaceAll('{n}', '$monthCount'),
                          AppColors.confidenceGreen),
                  ],
                ),
                const SizedBox(height: 2),
                Text(context.tr('total_ai_diagnoses'),
                    style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _buildRecentDiagnosisCard() {
    if (_history.isEmpty) {
      return _card(
        child: Row(
          children: [
            _iconTile(Icons.pets, AppColors.primaryBlue, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                context.tr('no_diagnoses_yet'),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    final item = _history.first;
    final String disease = item["predicted_disease"] ?? "Unknown";
    // "Hypersensitivity Allergy(Tick dermatitis)" -> title + subtitle
    final parts = RegExp(r'^(.*?)\s*\((.*)\)\s*$').firstMatch(disease);
    final title = parts != null ? parts.group(1)! : disease;
    final subtitle = parts != null ? "${parts.group(2)} manifestation" : _describe(disease);
    final double confidence = ((item["confidence_score"] ?? 0) as num).toDouble();
    final review = item["vet_review"];

    final String level;
    final Color levelColor;
    if (confidence >= 0.8) {
      level = context.tr('level_high');
      levelColor = AppColors.confidenceGreen;
    } else if (confidence >= 0.5) {
      level = context.tr('level_moderate');
      levelColor = AppColors.amberText;
    } else {
      level = context.tr('level_low');
      levelColor = AppColors.errorRed;
    }

    final String footer;
    if (review != null) {
      footer = review["decision"] == disease
          ? context.tr('confirmed_by_vet')
          : context.tr('vet_updated_to')
              .replaceAll('{name}', context.trDisease(review["decision"]));
    } else if (item["review_requested"] == true) {
      footer = context.tr('review_requested_waiting');
    } else if (confidence < 0.5) {
      footer = context.tr('vet_review_recommended');
    } else {
      footer = context.tr('ai_result_consult');
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.orange,
      ),
      padding: const EdgeInsets.only(left: 4),
      child: _card(
        onTap: () => _open(const HistoryScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(context.tr('most_recent_diagnosis'),
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    )),
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                ),
                const Spacer(),
                Text(_formatWhen(_parseDate(item["result_date"])),
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    ApiService.imageFileUrl(item["image_id"]),
                    headers: ApiService.imageHeaders,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _iconTile(Icons.image_outlined, AppColors.primaryBlue, size: 64),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(context.trDisease(title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          _chip(level, levelColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(context.tr('model_ai_confidence'), style: const TextStyle(fontSize: 14)),
                const Spacer(),
                Text("${(confidence * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: confidence.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.textGrey.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(Colors.orange),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(footer,
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      )),
                ),
                Text(context.tr('full_details'),
                    style: const TextStyle(
                        color: AppColors.primaryBlue, fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right, color: AppColors.primaryBlue, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(const UploadScreen()),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF6D5BD0)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('upload_dog_image'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(context.tr('instant_ai_scan'),
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickServices() {
    final reviewed = _reviewedCount;
    return Row(
      children: [
        Expanded(
          child: _serviceTile(
            icon: Icons.person_outline,
            color: AppColors.primaryBlue,
            title: context.tr('my_profile'),
            subtitle: context.tr('edit_info'),
            onTap: () => _open(const ProfileScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _serviceTile(
            icon: Icons.history,
            color: AppColors.primaryBlue,
            title: context.tr('history'),
            subtitle: context.tr('records_count').replaceAll('{n}', '${_history.length}'),
            onTap: () => _open(const HistoryScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _serviceTile(
            icon: Icons.verified_outlined,
            color: AppColors.tealAccent,
            title: context.tr('vet_reviews'),
            subtitle: context.tr('ready_count').replaceAll('{n}', '$reviewed'),
            subtitleColor: AppColors.tealAccent,
            showDot: reviewed > 0,
            onTap: () => _open(const OwnerVetReviewsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: _iconTile(Icons.star_rounded, Colors.amber, size: 44),
            title: Text(context.tr('rate_the_app'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(context.tr('help_improve')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_averageRating > 0)
                  Text("${_averageRating.toStringAsFixed(1)} ",
                      style: const TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.w800)),
                if (_averageRating > 0)
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                Icon(Icons.chevron_right, color: AppColors.textGrey),
              ],
            ),
            onTap: () => _open(const AppReviewScreen()),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: _iconTile(Icons.chat_bubble_outline, AppColors.primaryBlue, size: 44),
            title: Text(context.tr('view_app_reviews'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(context.tr('user_stories')),
            trailing: Icon(Icons.chevron_right, color: AppColors.textGrey),
            onTap: () => _open(const AppReviewsListScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme scheme) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      height: 68,
      child: Row(
        children: [
          _navItem(Icons.home_rounded, context.tr('nav_home'), selected: true, onTap: () {}),
          _navItem(Icons.assignment_outlined, context.tr('nav_records'),
              onTap: () => _open(const HistoryScreen())),
          Expanded(
            child: InkWell(
              onTap: () => _open(const UploadScreen()),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(context.tr('new_scan'),
                      style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          _navItem(Icons.groups_outlined, context.tr('nav_vets'),
              onTap: () => _open(const OwnerVetReviewsScreen())),
          _navItem(Icons.person_outline, context.tr('nav_profile'),
              onTap: () => _open(const ProfileScreen())),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- helpers

  String _describe(String disease) {
    switch (disease) {
      case "Ringworm":
        return context.tr('describe_ringworm');
      case "Mange":
        return context.tr('describe_mange');
      case "Healthy":
        return context.tr('describe_healthy');
      default:
        return context.tr('describe_default');
    }
  }

  Widget _navItem(IconData icon, String label,
      {bool selected = false, required VoidCallback onTap}) {
    final color = selected ? AppColors.primaryBlue : AppColors.textGrey;
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
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, {Widget? trailing}) {
    return Row(
      children: [
        Text(text,
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            )),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      ),
    );
  }

  Widget _iconTile(IconData icon, Color color, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _serviceTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
    bool showDot = false,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              child: Column(
                children: [
                  _iconTile(icon, color, size: 48),
                  const SizedBox(height: 12),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subtitleColor ?? AppColors.textGrey, fontSize: 12)),
                ],
              ),
            ),
            if (showDot)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _listTileCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: _iconTile(icon, iconColor, size: 44),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: AppColors.textGrey),
        onTap: onTap,
      ),
    );
  }
}