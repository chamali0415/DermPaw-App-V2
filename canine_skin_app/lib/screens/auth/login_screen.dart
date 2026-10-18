import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
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
            SnackBar(content: Text(context.tr('login_successful'))),
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
          _errorMessage = result["body"]["error"] ?? context.tr('login_failed');
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = context.tr('server_error');
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
                  DpChip(context.tr('ai_skin_scan'), color: AppColors.tealAccent, icon: Icons.auto_awesome),
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

              DpPageHeader(
                eyebrow: context.tr('pet_health_monitor'),
                title: context.tr('welcome_back'),
                subtitle: context.tr('sign_in_subtitle'),
              ),
              const SizedBox(height: 18),

              // ---- Form card
              DpCard(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DpFieldLabel(context.tr('email')),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: context.tr('email_hint'),
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                    ),
                    DpFieldLabel(context.tr('password')),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onSubmitted: (_) {
                        if (!_isLoading) _handleLogin();
                      },
                      decoration: InputDecoration(
                        hintText: context.tr('password_hint'),
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
                        child: Text(context.tr('forgot_password_q')),
                      ),
                    ),
                    DpErrorText(_errorMessage),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading ? dpButtonSpinner : Text(context.tr('login')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.tr('no_account'), style: TextStyle(color: dpMuted(context))),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: Text(context.tr('sign_up')),
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
