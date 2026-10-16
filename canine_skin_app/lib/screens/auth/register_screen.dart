import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/dp_ui.dart';
import '../../core/utils/phone_utils.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';
import '../vet/vet_dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vetLicenceController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  File? _profileImage; // optional - can be skipped
  bool _isVetRole = false;
  bool _consentGiven = false;
  String? _phoneError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _vetLicenceController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_consentGiven) {
      setState(() => _errorMessage = "Please confirm you understand the AI advisory notice");
      return;
    }
    if (_isVetRole && _vetLicenceController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Veterinary registration number is required");
      return;
    }
    final phone = PhoneUtils.normalize(_phoneController.text);
    if (phone == null || phone.isEmpty) {
      setState(() {
        _phoneError = PhoneUtils.errorText;
        _errorMessage = "Please enter a valid Sri Lankan phone number";
      });
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter your full name");
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim())) {
      setState(() => _errorMessage = "Please enter a valid email address");
      return;
    }
    // Same rule as the server, checked before we send the email code
    final pw = _passwordController.text;
    final strong = pw.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(pw) &&
        RegExp(r'[a-z]').hasMatch(pw) &&
        RegExp(r'[0-9]').hasMatch(pw) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pw);
    if (!strong) {
      setState(() => _errorMessage =
          "Password must be at least 8 characters with an uppercase letter, a lowercase letter, a number and a special character");
      return;
    }
    if (_confirmPasswordController.text != pw) {
      setState(() => _errorMessage = "Passwords do not match. Please type the same password twice.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Step 1: e-mail a 4-digit code
    final email = _emailController.text.trim();
    try {
      final sent = await ApiService.sendVerificationCode(email);
      // 429 = a code was sent less than a minute ago; it is still valid
      if (sent["statusCode"] != 200 && sent["statusCode"] != 429) {
        setState(() => _errorMessage = sent["body"]["error"] ?? "Could not send verification code");
        return;
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server. Check your connection.");
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (!mounted) return;

    // Step 2: ask for the code, then create the account with it
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _VerifyEmailDialog(
        email: email,
        register: (code) => ApiService.register(
          name: _nameController.text.trim(),
          email: email,
          password: _passwordController.text,
          phoneNumber: phone,
          isVet: _isVetRole,
          vetLicenceNo: _vetLicenceController.text.trim(),
          verificationCode: code,
        ),
      ),
    );

    if (result == null || !mounted) return; // user cancelled

    if (result["statusCode"] == 201) {
      // Optional profile photo - uploaded now that the account exists
      String message = "Email verified - registration successful!";
      if (_profileImage != null) {
        setState(() => _isLoading = true);
        try {
          final up = await ApiService.uploadProfilePicture(_profileImage!);
          if (up["statusCode"] != 200) {
            message = "Account created. The photo could not be uploaded - add it later in your profile.";
          }
        } catch (e) {
          message = "Account created. The photo could not be uploaded - add it later in your profile.";
        }
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => _isVetRole ? const VetDashboardScreen() : const HomeScreen(),
        ),
      );
    } else {
      // A problem with the form itself (e.g. phone already registered)
      setState(() => _errorMessage = result["body"]["error"] ?? "Registration failed");
    }
  }

  // ------------------------------------------------ optional profile photo

  Future<void> _pickProfileImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  void _showPhotoOptions() {
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
                  _pickProfileImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choose from gallery"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickProfileImage(ImageSource.gallery);
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                  title: const Text("Remove photo", style: TextStyle(color: AppColors.errorRed)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() => _profileImage = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return DpCard(
      onTap: _showPhotoOptions,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue.withOpacity(0.10),
                  image: _profileImage != null
                      ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: _profileImage == null
                    ? const Icon(Icons.person_outline, color: AppColors.primaryBlue, size: 34)
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera, color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_profileImage == null ? "Add a profile photo" : "Profile photo added",
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  _profileImage == null
                      ? "Optional - you can skip this and add it later in your profile."
                      : "Tap to change or remove it.",
                  style: TextStyle(fontSize: 12.5, color: dpMuted(context)),
                ),
              ],
            ),
          ),
          if (_profileImage != null)
            IconButton(
              tooltip: "Remove photo",
              icon: const Icon(Icons.close, color: AppColors.errorRed),
              onPressed: () => setState(() => _profileImage = null),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Brand bar
              Row(
                children: [
                  const AppLogo(size: 44),
                  const SizedBox(width: 12),
                  const Text("DermPaw",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text("Login"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const DpPageHeader(
                eyebrow: "Create account",
                title: "Join DermPaw",
                subtitle: "Smart skin care for your best friend.",
              ),
              const SizedBox(height: 20),

              // ---- Optional profile photo
              const DpSectionLabel("Profile photo"),
              _buildPhotoPicker(),
              const SizedBox(height: 20),

              // ---- Role choice
              const DpSectionLabel("I am a"),
              Row(
                children: [
                  Expanded(
                    child: _roleCard(
                      selected: !_isVetRole,
                      icon: Icons.pets,
                      title: "Dog Owner",
                      subtitle: "Scan & track",
                      onTap: () => setState(() => _isVetRole = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _roleCard(
                      selected: _isVetRole,
                      icon: Icons.medical_services_outlined,
                      title: "Veterinarian",
                      subtitle: "Review cases",
                      onTap: () => setState(() => _isVetRole = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ---- Details
              const DpSectionLabel("Your details"),
              DpCard(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DpFieldLabel("Full Name"),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: "Enter your full name",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const DpFieldLabel("Email"),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: "your.email@example.com",
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const DpFieldLabel("Phone Number"),
                    PhoneUtils.field(
                      controller: _phoneController,
                      errorText: _phoneError,
                      onChanged: (_) {
                        if (_phoneError != null) setState(() => _phoneError = null);
                      },
                    ),
                    if (_isVetRole) ...[
                      const DpFieldLabel("B.V.Sc. Registration No."),
                      TextField(
                        controller: _vetLicenceController,
                        decoration: const InputDecoration(
                          hintText: "e.g. 1847",
                          prefixIcon: Icon(Icons.badge_outlined),
                          helperText: "Your Veterinary Council of Sri Lanka registration number",
                        ),
                      ),
                    ],
                    const DpFieldLabel("Password"),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Create a strong password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: dpMuted(context),
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "At least 8 characters with uppercase, lowercase, a number and a special character (e.g. !@#)",
                      style: TextStyle(fontSize: 12, color: dpMuted(context)),
                    ),
                    const DpFieldLabel("Confirm Password"),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Type the same password again",
                        prefixIcon: const Icon(Icons.lock_reset),
                        errorText: _confirmPasswordController.text.isNotEmpty &&
                                _confirmPasswordController.text != _passwordController.text
                            ? "Passwords do not match"
                            : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            color: dpMuted(context),
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),
                    if (_confirmPasswordController.text.isNotEmpty &&
                        _confirmPasswordController.text == _passwordController.text) ...[
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: AppColors.confidenceGreen),
                          SizedBox(width: 6),
                          Text("Passwords match",
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.confidenceGreen,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- AI advisory consent
              DpCard(
                padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                onTap: () => setState(() => _consentGiven = !_consentGiven),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentGiven,
                      onChanged: (value) => setState(() => _consentGiven = value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          "I understand that DermPaw's AI predictions are advisory only and do not constitute a professional veterinary diagnosis.",
                          style: TextStyle(fontSize: 12.5, color: dpMuted(context), height: 1.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              DpErrorText(_errorMessage),
              ElevatedButton(
                onPressed: (_isLoading || !_consentGiven) ? null : _handleRegister,
                child: _isLoading ? dpButtonSpinner : const Text("Create Account"),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 16, color: dpMuted(context)),
                  const SizedBox(width: 6),
                  Text("We'll email you a 4-digit code to verify",
                      style: TextStyle(fontSize: 12.5, color: dpMuted(context))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppColors.primaryBlue : dpMuted(context);
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected ? AppColors.primaryBlue.withOpacity(0.08) : null,
            border: Border.all(
              color: selected
                  ? AppColors.primaryBlue
                  : (dpIsDark(context) ? AppColors.darkCardBorder : AppColors.cardBorder),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              DpIconTile(icon, color: color, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: selected ? AppColors.primaryBlue : null)),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: dpMuted(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog that asks for the 4-digit e-mail code and creates the account.
/// Returns the register() result, or null if the user cancels.
class _VerifyEmailDialog extends StatefulWidget {
  final String email;
  final Future<Map<String, dynamic>> Function(String code) register;

  const _VerifyEmailDialog({required this.email, required this.register});

  @override
  State<_VerifyEmailDialog> createState() => _VerifyEmailDialogState();
}

class _VerifyEmailDialogState extends State<_VerifyEmailDialog> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;
  String? _info;
  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 4) {
      setState(() => _error = "Enter the 4-digit code");
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
      _info = null;
    });
    try {
      final result = await widget.register(code);
      if (!mounted) return;
      final body = result["body"];
      final isCodeError = body is Map && body["code_error"] == true;
      if (result["statusCode"] == 400 && isCodeError) {
        // Wrong / expired code: stay in the dialog
        setState(() {
          _error = body["error"];
          _codeController.clear();
        });
      } else {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Could not connect to server");
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _error = null;
      _info = null;
    });
    try {
      final result = await ApiService.sendVerificationCode(widget.email);
      if (!mounted) return;
      if (result["statusCode"] == 200) {
        _codeController.clear();
        setState(() => _info = "A new code was sent. Check your inbox (and spam folder).");
        _startCountdown();
      } else {
        setState(() => _error = result["body"]["error"] ?? "Could not resend code");
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Could not connect to server");
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Verify your email"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "We sent a 4-digit code to\n${widget.email}",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey, fontSize: 13.5),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 14),
            decoration: const InputDecoration(hintText: "••••", counterText: ""),
            onChanged: (value) {
              if (_error != null) setState(() => _error = null);
              if (value.length == 4 && !_isVerifying) _verify();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
          ],
          if (_info != null) ...[
            const SizedBox(height: 10),
            Text(_info!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.confidenceGreen, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: (_resendSeconds > 0 || _isResending) ? null : _resend,
            child: Text(_resendSeconds > 0 ? "Resend code in ${_resendSeconds}s" : "Resend code"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
          onPressed: _isVerifying ? null : _verify,
          child: _isVerifying
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text("Verify"),
        ),
      ],
    );
  }
}
