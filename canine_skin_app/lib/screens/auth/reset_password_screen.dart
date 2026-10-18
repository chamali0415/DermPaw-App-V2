import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
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
            SnackBar(content: Text(context.tr('reset_success'))),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _message = result["body"]["error"] ?? context.tr('reset_failed');
        });
      }
    } catch (e) {
      setState(() {
        _message = context.tr('server_error');
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
      appBar: AppBar(title: Text(context.tr('reset_password'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: DpIconTile(Icons.mark_email_read_outlined, size: 72)),
            const SizedBox(height: 18),
            DpPageHeader(
              eyebrow: context.tr('check_inbox'),
              title: context.tr('enter_your_code'),
              subtitle: context.tr('reset_code_sent').replaceAll('{email}', widget.email),
              align: TextAlign.center,
            ),
            const SizedBox(height: 22),
            DpCard(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DpFieldLabel(context.tr('reset_code')),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: context.tr('six_digit_code'),
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                  ),
                  DpFieldLabel(context.tr('new_password')),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: context.tr('strong_password_hint'),
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
                    context.tr('password_rule_short'),
                    style: TextStyle(fontSize: 12, color: dpMuted(context)),
                  ),
                  const SizedBox(height: 18),
                  DpErrorText(_message),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleReset,
                    child: _isLoading ? dpButtonSpinner : Text(context.tr('reset_password')),
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
