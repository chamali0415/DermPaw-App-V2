import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/dp_ui.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _message;
  bool _obscurePassword = true;

  Future<void> _handleReset() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await ApiService.resetPassword(
        email: widget.email,
        resetCode: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      if (result["statusCode"] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password reset successfully! Please log in.")),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _message = result["body"]["error"] ?? "Reset failed";
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
      appBar: AppBar(title: const Text("Reset Password")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: DpIconTile(Icons.mark_email_read_outlined, size: 72)),
            const SizedBox(height: 18),
            DpPageHeader(
              eyebrow: "Check your inbox",
              title: "Enter your code",
              subtitle: "A reset code was sent to ${widget.email}",
              align: TextAlign.center,
            ),
            const SizedBox(height: 22),
            DpCard(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DpFieldLabel("Reset Code"),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: "6-digit code",
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  const DpFieldLabel("New Password"),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: "Create a strong password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: dpMuted(context),
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Must be 8+ characters with uppercase, lowercase, number, and special character",
                    style: TextStyle(fontSize: 12, color: dpMuted(context)),
                  ),
                  const SizedBox(height: 18),
                  DpErrorText(_message),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleReset,
                    child: _isLoading ? dpButtonSpinner : const Text("Reset Password"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
