import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;

  Future<void> _handleRequestCode() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await ApiService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (result["statusCode"] == 200) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(
                email: _emailController.text.trim(),
              ),
            ),
          );
        }
      } else {
        setState(() {
          _message = result["body"]["error"] ?? "Something went wrong";
        });
      }
    } catch (e) {
      setState(() {
        _message = "Could not connect to server. Check your connection.";
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
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Enter your registered email address. We'll send you a code to reset your password.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_message!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleRequestCode,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Send Reset Code"),
            ),
          ],
        ),
      ),
    );
  }
}