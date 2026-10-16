import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/dp_ui.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../home/home_screen.dart';
import '../vet/vet_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result["statusCode"] == 200) {
        if (mounted) {
          final isVet = result["body"]["user"]["is_vet"] == true;
          ApiService.currentUserName = result["body"]["user"]["name"];
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login successful!")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => isVet ? const VetDashboardScreen() : const HomeScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result["body"]["error"] ?? "Login failed";
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
                  DpChip("AI skin scan", color: AppColors.tealAccent, icon: Icons.auto_awesome),
                ],
              ),
              const SizedBox(height: 20),

              // ---- Hero image (same as the dashboard banner)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: Image.asset(
                    "assets/images/dashboard_hero.jpg",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        ),
                      ),
                      child: const Icon(Icons.pets, color: Colors.white, size: 56),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              const DpPageHeader(
                eyebrow: "Pet Health Monitor",
                title: "Welcome back",
                subtitle: "Sign in to check on your dog's skin health.",
              ),
              const SizedBox(height: 18),

              // ---- Form card
              DpCard(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DpFieldLabel("Email"),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: "your.email@example.com",
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const DpFieldLabel("Password"),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onSubmitted: (_) {
                        if (!_isLoading) _handleLogin();
                      },
                      decoration: InputDecoration(
                        hintText: "Enter your password",
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text("Forgot Password?"),
                      ),
                    ),
                    DpErrorText(_errorMessage),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading ? dpButtonSpinner : const Text("Login"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account?", style: TextStyle(color: dpMuted(context))),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text("Sign up"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
