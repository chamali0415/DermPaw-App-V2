import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneController.text.trim(),
        isVet: _isVetRole,
        vetLicenceNo: _vetLicenceController.text.trim(),
      );

      if (result["statusCode"] == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registration successful!")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => _isVetRole ? const VetDashboardScreen() : const HomeScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result["body"]["error"] ?? "Registration failed";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Could not connect to server. Check your connection.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(hintText: "(555) 123-4567"),
                keyboardType: TextInputType.phone,
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
                "Must be at least 8 characters with uppercase, lowercase, and numbers",
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