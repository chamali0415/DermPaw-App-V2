import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'refine_symptoms_screen.dart';


class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  bool _showResult = false;
  Map<String, dynamic>? _resultData;
  int? _lastResultId;
  bool _reviewRequested = false;

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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _showResult = false;
        _resultData = null;
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text("Take a photo"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text("Choose from gallery"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closeDialogIfOpen() {
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showAnalyzingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                child: const Icon(Icons.pets, color: AppColors.primaryBlue, size: 30),
              ),
              const SizedBox(height: 16),
              const Text("Analyzing Image",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                "Our AI is examining your pet's skin condition. This may take a few moments...",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const LinearProgressIndicator(minHeight: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showFailureDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.errorBg,
                child: const Icon(Icons.error_outline, color: AppColors.errorRed, size: 28),
              ),
              const SizedBox(height: 16),
              const Text("Analysis Failed",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                "We couldn't complete the analysis. Please check your internet connection and try again.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _submit();
                  },
                  child: const Text("Retry"),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    void _showInvalidImageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.errorBg,
                child: const Icon(Icons.pets_outlined, color: AppColors.errorRed, size: 28),
              ),
              const SizedBox(height: 16),
              const Text("Invalid Photo",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                "We couldn't recognize this as a dog's skin. Please upload a clear, close-up photo of the affected area.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _selectedImage = null);
                  },
                  child: const Text("Choose Another Photo"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedImage == null) return;

    setState(() => _isLoading = true);
    _showAnalyzingDialog();

    try {
      final dogResult = await ApiService.addDog(age: 3, ownerType: "Dog Owner");
      if (dogResult["statusCode"] == 401) {
        _closeDialogIfOpen();
        _handleSessionExpired();
        return;
      }
      if (dogResult["statusCode"] != 201) {
        _closeDialogIfOpen();
        _showFailureDialog();
        return;
      }
      final dogId = dogResult["body"]["dog"]["dog_id"];

      final imageResult = await ApiService.uploadImage(
        dogId: dogId,
        imageFile: _selectedImage!,
      );

      if (imageResult["statusCode"] == 401) {
        _closeDialogIfOpen();
        _handleSessionExpired();
        return;
      }

      if (imageResult["statusCode"] == 201) {
        final imageId = imageResult["body"]["image"]["image_id"];

        final classifyResult = await ApiService.classifyImage(imageId);
        if (classifyResult["statusCode"] == 401) {
          _closeDialogIfOpen();
          _handleSessionExpired();
          return;
        }
        if (classifyResult["statusCode"] == 201) {
          _closeDialogIfOpen();
          final body = classifyResult["body"];
          if (body["is_valid_image"] == false) {
            _showInvalidImageDialog();
          } else {
            setState(() {
              _resultData = body;
              _lastResultId = body["result_id"];
              _reviewRequested = false;
              _showResult = true;
            });
          }
        } else {
          _closeDialogIfOpen();
          _showFailureDialog();
        }
      } else {
        _closeDialogIfOpen();
        _showFailureDialog();
      }
    } catch (e) {
      _closeDialogIfOpen();
      _showFailureDialog();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestVetReview() async {
    if (_lastResultId == null) return;

    final result = await ApiService.requestVetReview(_lastResultId!);
    if (result["statusCode"] == 401) {
      _handleSessionExpired();
      return;
    }
    if (result["statusCode"] == 200) {
      setState(() => _reviewRequested = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vet review requested successfully")),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not request vet review")),
        );
      }
    }
  }

  Future<void> _openRefineScreen() async {
    if (_resultData == null) return;
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => RefineSymptomsScreen(resultData: _resultData!),
      ),
    );
    if (updated != null) {
      setState(() {
        _resultData = updated;
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _showResult = false;
      _resultData = null;
      _lastResultId = null;
      _reviewRequested = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analyze Skin Condition")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _showResult && _resultData != null
              ? _buildResultView()
              : _buildUploadView(),
        ),
      ),
    );
  }

  Widget _buildUploadView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Analyze Skin Condition",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          "Upload a clear photo of your dog's skin condition",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 14),
        ),
        const SizedBox(height: 20),
        if (_selectedImage == null)
          GestureDetector(
            onTap: _showImageSourceSheet,
            child: Container(
              height: 230,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.35),
                  width: 1.4,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: AppColors.primaryBlue, size: 26),
                  ),
                  const SizedBox(height: 14),
                  const Text("Tap to Capture or Upload",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text("Take a photo or choose from gallery",
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Image.file(_selectedImage!,
                        height: 260, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black.withOpacity(0.5),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedImage!.path.split(Platform.pathSeparator).last,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: const Text("Submit for Analysis"),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => setState(() => _selectedImage = null),
                child: const Text("Retake Photo"),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amberBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.amberBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: AppColors.amberText),
                  const SizedBox(width: 6),
                  Text("Tips for best results:",
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.amberText, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              ...[
                "Use good lighting",
                "Focus clearly on the affected area",
                "Accepted formats: JPG, PNG",
                "Max size: 10MB",
              ].map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("•  $t",
                        style: TextStyle(color: AppColors.amberText, fontSize: 12.5)),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final data = _resultData!;
    final confidence = (data["confidence_score"] ?? 0).toDouble();
    final disease = data["predicted_disease"] ?? "Unknown";
    final needsReview = data["needs_vet_review"] == true;

    final Map<String, dynamic> rawProbabilities =
        (data["probabilities"] as Map<String, dynamic>?) ?? {};
    final sortedProbabilities = rawProbabilities.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: needsReview
              ? AppColors.amberBg
              : AppColors.confidenceGreen.withOpacity(0.15),
          child: Icon(
            needsReview ? Icons.help_outline : Icons.check,
            color: needsReview ? AppColors.amberText : AppColors.confidenceGreen,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          needsReview ? "Not Sure — Possibly $disease" : "Analysis Complete",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (_selectedImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(_selectedImage!,
                height: 220, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("Predicted Condition",
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  width: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 110,
                        width: 110,
                        child: CircularProgressIndicator(
                          value: confidence,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: needsReview
                              ? AppColors.amberText
                              : AppColors.confidenceGreen,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${(confidence * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          const Text("Confidence",
                              style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(disease,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (sortedProbabilities.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Confidence Breakdown",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _openRefineScreen,
            child: const Text("Refine Prediction"),
          ),
        ),
        const SizedBox(height: 16),
        if (needsReview)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.amberBorder),
            ),
            child: Text(
              "The model is not confident about this photo. Try a closer, sharper photo in daylight, and ask a vet to check.",
              style: TextStyle(color: AppColors.amberText, fontSize: 12.5),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amberBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.amberBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.amberText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: AppColors.amberText, fontSize: 12.5),
                        children: const [
                          TextSpan(
                              text: "NOTICE: ", style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(
                              text:
                                  "This result is generated by AI and is for informational purposes only."),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "It is NOT a definitive diagnosis. Always consult a veterinarian for treatment.",
                style: TextStyle(color: AppColors.amberText, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealAccent),
            onPressed: _reviewRequested ? null : _requestVetReview,
            child: Text(
                _reviewRequested ? "Vet Review Requested ✓" : "Request Veterinarian Review"),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _reset,
            child: const Text("Done"),
          ),
        ),
      ],
    );
  }
}