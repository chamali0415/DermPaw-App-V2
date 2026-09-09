import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';

class VetCaseHistoryScreen extends StatefulWidget {
  const VetCaseHistoryScreen({super.key});

  @override
  State<VetCaseHistoryScreen> createState() => _VetCaseHistoryScreenState();
}

class _VetCaseHistoryScreenState extends State<VetCaseHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _handleSessionExpired() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your session has expired. Please log in again.")),
      );
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getVetCaseHistory();
      if (result["statusCode"] == 200) {
        setState(() {
          _history = result["body"];
          _errorMessage = null;
        });
      } else if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      } else {
        setState(() => _errorMessage = "Could not load case history");
      }
    } catch (e) {
      setState(() => _errorMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Case History")),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : _history.isEmpty
                    ? const Center(child: Text("No reviewed cases yet"))
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final entry = _history[index];
                          final result = entry["result"] ?? {};
                          final review = entry["review"] ?? {};

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text(result["predicted_disease"] ?? "Unknown"),
                              subtitle: Text(
                                "Decision: ${review["decision"] ?? "Unknown"}\n"
                                "Confidence: ${((result["confidence_score"] ?? 0) * 100).toStringAsFixed(1)}%",
                              ),
                              isThreeLine: true,
                              trailing: Text(
                                (result["result_date"] ?? "").toString().split("T").first,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}