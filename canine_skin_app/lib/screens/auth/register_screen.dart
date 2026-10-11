import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
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
  final _phoneController = TextEditingController();
  final _vetLicenceController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _isVetRole = false;
  bool _consentGiven = false;
  String? _phoneError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email verified - registration successful!")),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo()),
              const SizedBox(height: 16),
              const Text(
                "Join DermPaw",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                "Smart Skin Care for Your Best Friend",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 28),

              const Text("Full Name", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: "Enter your full name"),
              ),
              const SizedBox(height: 16),

              const Text("Email", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: "your.email@example.com"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              PhoneUtils.field(
                controller: _phoneController,
                errorText: _phoneError,
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
              ),
              const SizedBox(height: 16),

              const Text("User Role", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isVetRole = false),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_isVetRole ? Colors.white : const Color(0xFFF5F7FB),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                          border: Border.all(
                            color: !_isVetRole ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
                            width: !_isVetRole ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          "Dog Owner",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: !_isVetRole ? AppColors.primaryBlue : AppColors.textGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isVetRole = true),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isVetRole ? Colors.white : const Color(0xFFF5F7FB),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                          border: Border.all(
                            color: _isVetRole ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
                            width: _isVetRole ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          "Veterinarian",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _isVetRole ? AppColors.primaryBlue : AppColors.textGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_isVetRole) ...[
                const SizedBox(height: 16),
                const Text("B.V.Sc. Registration No.", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _vetLicenceController,
                  decoration: const InputDecoration(
                    hintText: "e.g. 1847",
                    helperText: "Your Veterinary Council of Sri Lanka registration number",
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Text("Password", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: "Enter a strong password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textGrey,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "At least 8 characters with uppercase, lowercase, a number and a special character (e.g. !@#)",
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amberBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amberBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentGiven,
                      onChanged: (value) => setState(() => _consentGiven = value ?? false),
                      activeColor: AppColors.amberText,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          "I understand that DermPaw's AI predictions are advisory only and do not constitute a professional veterinary diagnosis.",
                          style: TextStyle(color: AppColors.amberText, fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.errorRed),
                  ),
                ),

              ElevatedButton(
                onPressed: (_isLoading || !_consentGiven) ? null : _handleRegister,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Create Account"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text("Already have an account? Login"),
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
