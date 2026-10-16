import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
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
      appBar: AppBar(title: const Text("Verify Vets")),
      body: RefreshIndicator(
        onRefresh: _loadPendingVets,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? DpEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: _errorMessage!,
                    message: "Pull down to try again.",
                    color: AppColors.errorRed,
                  )
                : _pendingVets.isEmpty
                    ? const DpEmptyState(
                        icon: Icons.verified_user_outlined,
                        title: "No vets pending verification",
                        message: "New veterinarian registrations will appear here.",
                        color: AppColors.purple,
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          const DpPageHeader(
                            eyebrow: "Administrator",
                            title: "Pending verifications",
                            subtitle: "Check each B.V.Sc. number against the Veterinary Council of Sri Lanka register before verifying.",
                          ),
                          const SizedBox(height: 18),
                          DpSectionLabel("Waiting (${_pendingVets.length})"),
                          ..._pendingVets.map(_buildVetCard),
                        ],
                      ),
      ),
    );
  }

  Widget _buildVetCard(dynamic vet) {
    final userId = vet["user_id"];
    final isVerifying = _verifying.contains(userId);
    final String name = vet["name"] ?? "Unknown";

    return DpCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DpInitialAvatar(name: name, size: 48, color: AppColors.purple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(vet["email"] ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: dpMuted(context), fontSize: 13)),
                  ],
                ),
              ),
              const DpChip("Pending", color: AppColors.orange),
            ],
          ),
          const SizedBox(height: 10),
          DpInfoRow(
            icon: Icons.badge_outlined,
            label: "B.V.Sc. Reg. No.",
            value: (vet["vet_licence_no"] ?? "N/A").toString(),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: isVerifying ? null : () => _verifyVet(userId, name),
            icon: isVerifying ? dpButtonSpinner : const Icon(Icons.check_circle_outline),
            label: Text(isVerifying ? "Verifying..." : "Verify"),
          ),
        ],
      ),
    );
  }
}
