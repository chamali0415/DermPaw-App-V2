import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
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

  /// The AI model's ORIGINAL result. Every refinement starts from this, so
  /// pressing "Get Refined Prediction" again never stacks the symptom effects.
  late final Map<String, dynamic> _originalResult;

  @override
  void initState() {
    super.initState();
    final data = Map<String, dynamic>.from(widget.resultData);
    // If this result was refined before, its original AI values were saved
    // under "original_result" - always go back to those.
    _originalResult = Map<String, dynamic>.from(
      (data["original_result"] as Map?) ??
          {
            "predicted_disease": data["predicted_disease"],
            "confidence_score": data["confidence_score"],
            "needs_vet_review": data["needs_vet_review"],
            "probabilities": data["probabilities"],
          },
    );
    _currentData = {...data, "original_result": _originalResult};
  }

  /// Back to the AI-only result (used when no symptom is selected).
  void _resetToOriginal() {
    setState(() {
      _currentData = {..._currentData, ..._originalResult, "original_result": _originalResult};
    });
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
    if (_isRefining) return;
    if (_selectedSymptoms.isEmpty) {
      _resetToOriginal();
      return;
    }

    setState(() => _isRefining = true);
    try {
      final result = await ApiService.refineWithSymptoms(
        // Always the ORIGINAL AI probabilities, never the last refined ones
        probabilities: Map<String, dynamic>.from(_originalResult["probabilities"]),
        symptoms: _selectedSymptoms.toList(),
      );
      if (result["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (result["statusCode"] == 200) {
        setState(() {
          _currentData = {
            ..._currentData,
            ...result["body"],
            "original_result": _originalResult,
          };
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

    final color = needsReview ? AppColors.orange : AppColors.confidenceGreen;
    return DpCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text("Refined Prediction", style: TextStyle(fontSize: 13, color: dpMuted(context))),
          const SizedBox(height: 14),
          DpConfidenceRing(confidence: confidence, color: color, size: 104),
          const SizedBox(height: 12),
          Text(disease,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          DpChip(
            _selectedSymptoms.isEmpty
                ? "AI result only"
                : "Using ${_selectedSymptoms.length} symptom${_selectedSymptoms.length == 1 ? '' : 's'}",
            color: AppColors.tealAccent,
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          ...sortedProbabilities.map((entry) => DpProgressRow(
                label: entry.key,
                percent: (entry.value as num).toDouble(),
                highlight: entry.key == sortedProbabilities.first.key,
              )),
        ],
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
                const DpPageHeader(
                  eyebrow: "Refine prediction",
                  title: "What do you notice?",
                  subtitle: "Tick the symptoms you see on your dog. The example photos can help you decide.",
                ),
                const SizedBox(height: 14),
                DpSectionLabel(
                  "Symptoms",
                  trailing: _selectedSymptoms.isEmpty
                      ? null
                      : DpChip("${_selectedSymptoms.length} selected", icon: Icons.check),
                ),
                ..._symptomLabels.entries.map((entry) {
                  final isSelected = _selectedSymptoms.contains(entry.key);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    color: isSelected ? AppColors.primaryBlue.withOpacity(0.06) : null,
                    shape: isSelected
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
                          )
                        : null,
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
                              // No symptoms left -> show the AI-only result again
                              if (_selectedSymptoms.isEmpty) _resetToOriginal();
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
                  child: _isRefining ? dpButtonSpinner : const Text("Get Refined Prediction"),
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