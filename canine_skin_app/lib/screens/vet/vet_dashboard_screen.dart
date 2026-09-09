import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';
import 'vet_case_detail_screen.dart';
import 'vet_case_history_screen.dart';
import '../admin/admin_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
    _loadPending();
  }

    Future<void> _loadVerificationStatus() async {
    final result = await ApiService.getProfile();
    if (result["statusCode"] == 200) {
      setState(() {
        _isVerified = result["body"]["is_verified"] ?? true;
        _isAdmin = result["body"]["is_admin"] ?? false;
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ApiService.currentUserName ?? "Doctor";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Veterinarian Dashboard"),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.verified_user),
              tooltip: "Verify Vets (Admin)",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Case History",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VetCaseHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadVerificationStatus();
          await _loadPending();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isVerified)
              Container(
                width: double.infinity,
                color: Colors.orange[100],
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[900], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Your veterinary registration is pending admin verification. You can browse cases but cannot submit reviews yet.",
                        style: TextStyle(color: Colors.orange[900], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, Dr. $name",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text("${_pending.length} case(s) awaiting your review"),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                      : _pending.isEmpty
                          ? const Center(child: Text("No pending reviews"))
                          : ListView.builder(
                              itemCount: _pending.length,
                              itemBuilder: (context, index) {
                                final item = _pending[index];
                                return GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VetCaseDetailScreen(
                                          resultId: item["result_id"],
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      _loadPending();
                                    }
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.all(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item["predicted_disease"] ?? "Unknown",
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Confidence: ${(item["confidence_score"] * 100).toStringAsFixed(1)}%",
                                          ),
                                          const SizedBox(height: 8),
                                          const Row(
                                            children: [
                                              Icon(Icons.chevron_right,
                                                  size: 18, color: Colors.grey),
                                              SizedBox(width: 4),
                                              Text("Tap to review",
                                                  style: TextStyle(color: Colors.grey)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}