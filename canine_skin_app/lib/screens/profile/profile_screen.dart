import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;
  String? _phoneError;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getProfile();
      if (result["statusCode"] == 200) {
        setState(() {
          _profile = result["body"];
          _nameController.text = _profile?["name"] ?? "";
          ApiService.rememberUser(_profile);
          _phoneController.text = PhoneUtils.toLocal(_profile?["phone_number"]);
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = "Could not load profile");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final phone = PhoneUtils.normalize(_phoneController.text);
    if (phone == null) {
      setState(() => _phoneError = PhoneUtils.errorText);
      return;
    }
    setState(() {
      _phoneError = null;
      _isLoading = true;
    });
    try {
      final result = await ApiService.updateProfile(
        name: _nameController.text.trim(),
        phoneNumber: phone,
      );
      if (result["statusCode"] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully")),
          );
        }
        await _loadProfile();
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = result["body"]["error"] ?? "Could not update profile");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    _deletePasswordController.clear();
    bool obscureDeletePassword = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Delete Account"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "This will permanently delete your account and all associated data. This cannot be undone.",
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _deletePasswordController,
                obscureText: obscureDeletePassword,
                decoration: InputDecoration(
                  labelText: "Enter your password to confirm",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureDeletePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setDialogState(() => obscureDeletePassword = !obscureDeletePassword);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.deleteAccount(
        password: _deletePasswordController.text,
      );
      if (result["statusCode"] == 200) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
);
        }
      } else {
        setState(() {
          _errorMessage = result["body"]["error"] ?? "Could not delete account";
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------- profile picture
  bool _isUpdatingPicture = false;

  Future<void> _changePicture(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return;
    setState(() => _isUpdatingPicture = true);
    try {
      final result = await ApiService.uploadProfilePicture(File(picked.path));
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        setState(() => _profile = result["body"]["user"]);
        _snack("Profile picture updated");
      } else {
        _snack(result["body"]["error"] ?? "Could not update picture");
      }
    } catch (e) {
      _snack("Could not connect to server");
    } finally {
      if (mounted) setState(() => _isUpdatingPicture = false);
    }
  }

  Future<void> _removePicture() async {
    setState(() => _isUpdatingPicture = true);
    try {
      final result = await ApiService.deleteProfilePicture();
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        setState(() => _profile = result["body"]["user"]);
        _snack("Profile picture removed");
      } else {
        _snack(result["body"]["error"] ?? "Could not remove picture");
      }
    } catch (e) {
      _snack("Could not connect to server");
    } finally {
      if (mounted) setState(() => _isUpdatingPicture = false);
    }
  }

  void _showPictureOptions() {
    final hasPicture = _profile?["has_profile_picture"] == true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text("Take a photo"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changePicture(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choose from gallery"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changePicture(ImageSource.gallery);
                },
              ),
              if (hasPicture)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                  title: const Text("Remove photo", style: TextStyle(color: AppColors.errorRed)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removePicture();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _handleSessionExpired() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your session has expired. Please log in again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile?["name"] ?? "").toString();
    final email = (_profile?["email"] ?? "").toString();
    final isVet = _profile?["is_vet"] == true;
    final isVerified = _profile?["is_verified"] != false;
    final isAdmin = _profile?["is_admin"] == true;

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: _isLoading && _profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ---- Identity card
                DpCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _isUpdatingPicture
                          ? const SizedBox(
                              width: 76,
                              height: 76,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : DpProfileAvatar(
                              userId: _profile?["user_id"],
                              hasPicture: _profile?["has_profile_picture"] == true,
                              version: _profile?["profile_picture_version"] ?? 0,
                              name: name,
                              size: 76,
                              showEditBadge: true,
                              onTap: _showPictureOptions,
                            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.isEmpty ? "Your profile" : name,
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: dpMuted(context), fontSize: 13)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                DpChip(
                                  isVet ? "Veterinarian" : "Dog Owner",
                                  icon: isVet ? Icons.medical_services_outlined : Icons.pets,
                                ),
                                if (isVet)
                                  DpChip(
                                    isVerified ? "Verified" : "Pending verification",
                                    color: isVerified ? AppColors.confidenceGreen : AppColors.orange,
                                    icon: isVerified ? Icons.verified_outlined : Icons.hourglass_empty,
                                  ),
                                if (isAdmin)
                                  const DpChip("Admin",
                                      color: AppColors.purple, icon: Icons.admin_panel_settings_outlined),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ---- Editable details
                const DpSectionLabel("Personal details"),
                DpCard(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DpFieldLabel("Full Name"),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
                      ),
                      const DpFieldLabel("Phone Number"),
                      PhoneUtils.field(
                        controller: _phoneController,
                        errorText: _phoneError,
                      ),
                      const DpFieldLabel("Email"),
                      InputDecorator(
                        decoration: const InputDecoration(
                          enabled: false,
                          prefixIcon: Icon(Icons.mail_outline),
                          helperText: "Email can't be changed",
                        ),
                        child: Text(email, style: TextStyle(color: dpMuted(context))),
                      ),
                      const SizedBox(height: 18),
                      DpErrorText(_errorMessage),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading ? dpButtonSpinner : const Text("Save Changes"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ---- Danger zone
                const DpSectionLabel("Danger zone"),
                DpCard(
                  onTap: _confirmDeleteAccount,
                  child: Row(
                    children: [
                      const DpIconTile(Icons.delete_forever_outlined,
                          color: AppColors.errorRed, size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Delete Account",
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, color: AppColors.errorRed)),
                            const SizedBox(height: 2),
                            Text("Permanently remove your account and all scans",
                                style: TextStyle(fontSize: 12.5, color: dpMuted(context))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.errorRed),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
