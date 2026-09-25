import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';

class RefineSymptomsScreen extends StatefulWidget {
  final Map<String, dynamic> resultData;

  const RefineSymptomsScreen({super.key, required this.resultData});

  @override
  State<RefineSymptomsScreen> createState() => _RefineSymptomsScreenState();
}

class _RefineSymptomsScreenState extends State<RefineSymptomsScreen> {
  final Map<String, String> _symptomLabels = {
    "circular_lesions": "Round, ring-shaped bald patch",
    "brittle_claws": "Claws look weak, dry, or breaking",
    "low_itch_despite_lesions": "Not very itchy, even with visible marks",
    "severe_itch_worse_at_night": "Very itchy, especially at night",
    "heavy_crusting": "Thick, crusty, or scabby skin",
    "greasy_coat": "Coat feels oily or greasy",
    "coat_odor": "Bad smell from the skin or coat",
    "ear_involvement": "Ears look affected too",
    "localized_lesion_at_bite_point": "One small red spot, like a bite mark",
    "only_one_area_not_spreading": "Only in one spot, not spreading",
    "normal_coat_no_issues": "Coat and skin look normal",
  };

  final Set<String> _selectedSymptoms = {};
  bool _isRefining = false;
  bool _isRequestingReview = false;
  bool _reviewRequested = false;
  late Map<String, dynamic> _currentData;

  @override
  void initState() {
    super.initState();
    _currentData = Map<String, dynamic>.from(widget.resultData);
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

  Future<void> _getRefinedPrediction() async {
    if (_selectedSymptoms.isEmpty) return;

    setState(() => _isRefining = true);
    try {
      final result = await ApiService.refineWithSymptoms(
        probabilities: Map<String, dynamic>.from(_currentData["probabilities"]),
        symptoms: _selectedSymptoms.toList(),
      );
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        setState(() {
          _currentData = {..._currentData, ...result["body"]};
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not refine prediction")),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefining = false);
    }
  }

  Future<void> _requestVetReview() async {
    final resultId = _currentData["result_id"];
    if (resultId == null) return;

    setState(() => _isRequestingReview = true);
    final result = await ApiService.requestVetReview(resultId);
    if (result["statusCode"] == 401) {
      _handleSessionExpired();
      if (mounted) setState(() => _isRequestingReview = false);
      return;
    }
    if (result["statusCode"] == 200) {
      setState(() => _reviewRequested = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vet review requested successfully")),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not request vet review")),
      );
    }
    if (mounted) setState(() => _isRequestingReview = false);
  }

  Widget _buildSymptomImage(String key) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        "assets/symptoms/$key.jpg",
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 120,
            width: double.infinity,
            color: const Color(0xFFE5E7EB),
            alignment: Alignment.center,
            child: const Text(
              "Example photo coming soon",
              style: TextStyle(color: AppColors.textGrey, fontSize: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRefinedResult() {
    final confidence = (_currentData["confidence_score"] ?? 0).toDouble();
    final disease = _currentData["predicted_disease"] ?? "Unknown";
    final needsReview = _currentData["needs_vet_review"] == true;

    final Map<String, dynamic> rawProbabilities =
        (_currentData["probabilities"] as Map<String, dynamic>?) ?? {};
    final sortedProbabilities = rawProbabilities.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Refined Prediction",
                style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: CircularProgressIndicator(
                      value: confidence,
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: needsReview
                          ? AppColors.amberText
                          : AppColors.confidenceGreen,
                    ),
                  ),
                  Text("${(confidence * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(disease, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...sortedProbabilities.map((entry) {
              final isTop = entry.key == sortedProbabilities.first.key;
              final pct = (entry.value as num).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                            )),
                        Text("${pct.toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                            )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE5E7EB),
                        color: isTop
                            ? AppColors.confidenceGreen
                            : AppColors.primaryBlue.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _currentData);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Refine Prediction"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _currentData),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Select any symptoms you notice on your dog",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Comparing to the example photos below can help you decide.",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ..._symptomLabels.entries.map((entry) {
                  final isSelected = _selectedSymptoms.contains(entry.key);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(entry.value,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedSymptoms.add(entry.key);
                                } else {
                                  _selectedSymptoms.remove(entry.key);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildSymptomImage(entry.key),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: (_selectedSymptoms.isEmpty || _isRefining)
                      ? null
                      : _getRefinedPrediction,
                  child: Text(_isRefining ? "Refining..." : "Get Refined Prediction"),
                ),
                if (_currentData["probabilities"] != null) ...[
                  const SizedBox(height: 20),
                  _buildRefinedResult(),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealAccent),
                  onPressed: (_reviewRequested || _isRequestingReview)
                      ? null
                      : _requestVetReview,
                  child: Text(_reviewRequested
                      ? "Vet Review Requested ✓"
                      : _isRequestingReview
                          ? "Requesting..."
                          : "Request Veterinarian Review"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}