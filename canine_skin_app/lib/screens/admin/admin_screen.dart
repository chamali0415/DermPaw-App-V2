import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _pendingVets = [];
  final Set<int> _verifying = {};

  @override
  void initState() {
    super.initState();
    _loadPendingVets();
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

  Future<void> _loadPendingVets() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getPendingVets();
      if (result["statusCode"] == 200) {
        setState(() {
          _pendingVets = result["body"];
          _errorMessage = null;
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = result["body"]["error"] ?? "Could not load pending vets");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyVet(int userId, String name) async {
    setState(() => _verifying.add(userId));
    try {
      final result = await ApiService.verifyVet(userId);
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$name has been verified")),
          );
        }
        _loadPendingVets();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to verify vet")),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _verifying.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Vet Verifications")),
      body: RefreshIndicator(
        onRefresh: _loadPendingVets,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : _pendingVets.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 64),
                            child: Center(child: Text("No vets pending verification")),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _pendingVets.length,
                        itemBuilder: (context, index) {
                          final vet = _pendingVets[index];
                          final userId = vet["user_id"];
                          final isVerifying = _verifying.contains(userId);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vet["name"] ?? "Unknown",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(vet["email"] ?? "",
                                      style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "B.V.Sc. Registration No: ${vet["vet_licence_no"] ?? "N/A"}",
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: isVerifying
                                          ? null
                                          : () => _verifyVet(userId, vet["name"] ?? "This vet"),
                                      icon: isVerifying
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.check_circle_outline, size: 18),
                                      label: Text(isVerifying ? "Verifying..." : "Verify"),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}