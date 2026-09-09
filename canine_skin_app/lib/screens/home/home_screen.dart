import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../upload/upload_screen.dart';
import '../history/history_screen.dart';
import '../vet/vet_dashboard_screen.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';
import '../app_review/app_review_screen.dart';
import '../app_review/app_reviews_list_screen.dart';
import '../admin/admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getHistory();
      if (result["statusCode"] == 200) {
        setState(() => _history = result["body"]);
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }

      final profileResult = await ApiService.getProfile();
      if (profileResult["statusCode"] == 200) {
        setState(() => _isAdmin = profileResult["body"]["is_admin"] ?? false);
      }
    } catch (e) {
      // Silently ignore for the dashboard summary; the History screen will show the real error
    } finally {
      setState(() => _isLoading = false);
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

  void _handleLogout(BuildContext context) {
    ApiService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Welcome, ${ApiService.currentUserName ?? "there"}!",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            "${_history.length}",
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const Text("Total Diagnoses"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  "Most Recent Diagnosis",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    title: Text(_history.first["predicted_disease"] ?? "Unknown"),
                    subtitle: Text(
                      "Confidence: ${(_history.first["confidence_score"] * 100).toStringAsFixed(1)}%",
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: const Text("View My Profile"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UploadScreen()),
                );
              },
              child: const Text("Upload Dog Image"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                );
              },
              child: const Text("Diagnosis History"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VetDashboardScreen()),
                );
              },
              child: const Text("Vet Reviews"),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppReviewScreen()),
                );
              },
              icon: const Icon(Icons.star_outline),
              label: const Text("Rate the App"),
            ),
            
                        const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppReviewsListScreen()),
                );
              },
              icon: const Icon(Icons.reviews_outlined),
              label: const Text("View App Reviews"),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminScreen()),
                  );
                },
                icon: const Icon(Icons.verified_user, color: Colors.white),
                label: const Text("Verify Vets (Admin)",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}