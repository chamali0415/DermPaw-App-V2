import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
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
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
<<<<<<< Updated upstream
                decoration: const InputDecoration(labelText: "Email"),
=======
                decoration: const InputDecoration(hintText: "your_email@example.com"),
>>>>>>> Stashed changes
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Login"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text("Don't have an account? Register"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                  );
                },
                child: const Text("Forgot Password?"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}