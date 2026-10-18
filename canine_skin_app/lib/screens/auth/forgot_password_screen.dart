import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/dp_ui.dart';
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
          _message = result["body"]["error"] ?? context.tr('something_wrong');
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
      appBar: AppBar(title: Text(context.tr('forgot_password'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: DpIconTile(Icons.lock_reset, size: 72)),
            const SizedBox(height: 18),
            DpPageHeader(
              eyebrow: context.tr('account_recovery'),
              title: context.tr('reset_your_password'),
              subtitle: context.tr('forgot_subtitle'),
              align: TextAlign.center,
            ),
            const SizedBox(height: 22),
            DpCard(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
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
                  const SizedBox(height: 18),
                  DpErrorText(_message),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRequestCode,
                    child: _isLoading ? dpButtonSpinner : Text(context.tr('send_reset_code')),
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
