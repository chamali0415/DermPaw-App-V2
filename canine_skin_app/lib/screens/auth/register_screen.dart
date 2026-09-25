import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
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
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
              const SizedBox(height: 16),
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
                controller: _phoneController,
<<<<<<< Updated upstream
                decoration: const InputDecoration(labelText: "Phone Number"),
=======
                decoration: const InputDecoration(hintText: "(+94) 74 4567258"),
>>>>>>> Stashed changes
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const Text("User Role", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_isVetRole ? Colors.blue[50] : null,
                        side: BorderSide(color: !_isVetRole ? Colors.blue : Colors.grey),
                      ),
                      onPressed: () => setState(() => _isVetRole = false),
                      child: Text(
                        "Dog Owner",
                        style: TextStyle(color: !_isVetRole ? Colors.blue : Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _isVetRole ? Colors.blue[50] : null,
                        side: BorderSide(color: _isVetRole ? Colors.blue : Colors.grey),
                      ),
                      onPressed: () => setState(() => _isVetRole = true),
                      child: Text(
                        "Veterinarian",
                        style: TextStyle(color: _isVetRole ? Colors.blue : Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isVetRole) ...[
                TextField(
                  controller: _vetLicenceController,
                  decoration: const InputDecoration(
                    labelText: "B.V.Sc. Registration No.",
                    hintText: "e.g. 1847",
                    helperText: "Your Veterinary Council of Sri Lanka registration number",
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
              ],
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
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  "Must be 8+ characters with uppercase, lowercase, number, and special character",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Register"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text("Already have an account? Log in"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}