import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dp_ui.dart';
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
    // Downscale big camera/internet photos before upload: faster on mobile
    // data and keeps the request under the server's upload size limit.
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
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

  void _showFailureDialog({
    String title = "Analysis Failed",
    String message = "Something went wrong while analysing this photo. Please try again.",
    bool canRetry = true,
  }) {
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
              Text(title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (canRetry) ...[
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
              ],
              SizedBox(
                width: double.infinity,
                child: canRetry
                    ? OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      )
                    : ElevatedButton(
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

  /// Shows the right message for a failed server response instead of
  /// always blaming the internet connection.
  void _showServerError(Map<String, dynamic> result) {
    final code = result["statusCode"] as int;
    final body = result["body"];
    final serverMsg = body is Map ? body["error"] : null;

    if (code == 413) {
      _showFailureDialog(
        title: "Photo Too Large",
        message: "This photo is too large to upload. Please choose a smaller photo.",
        canRetry: false,
      );
    } else if (code == 400 || code == 415) {
      _showFailureDialog(
        title: "Photo Not Accepted",
        message: serverMsg ?? "This photo could not be used. Please choose another photo.",
        canRetry: false,
      );
    } else {
      _showFailureDialog(
        title: "Server Busy",
        message: serverMsg ??
            "The analysis server had a problem (error $code). Please try again in a moment.",
      );
    }
  }

  void _showNetworkError() {
    _showFailureDialog(
      title: "Connection Problem",
      message: "We couldn't reach the DermPaw server. Please check your internet connection and try again.",
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
    if (_selectedImage == null || _isLoading) return;

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
        _showServerError(dogResult);
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
      if (imageResult["statusCode"] != 201) {
        _closeDialogIfOpen();
        _showServerError(imageResult);
        return;
      }
      final imageId = imageResult["body"]["image"]["image_id"];

      final classifyResult = await ApiService.classifyImage(imageId);
      _closeDialogIfOpen();

      if (classifyResult["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }

      final body = classifyResult["body"];
      // 422 = the server decided this is not a dog-skin photo
      if (classifyResult["statusCode"] == 422 ||
          (body is Map && body["is_valid_image"] == false)) {
        _showInvalidImageDialog();
        return;
      }
      if (classifyResult["statusCode"] != 201) {
        _showServerError(classifyResult);
        return;
      }

      setState(() {
        _resultData = body;
        _lastResultId = body["result_id"];
        _reviewRequested = false;
        _showResult = true;
      });
    } on SocketException {
      _closeDialogIfOpen();
      _showNetworkError();
    } on TimeoutException {
      _closeDialogIfOpen();
      _showFailureDialog(
        title: "Taking Too Long",
        message: "The server is taking longer than usual. Please check your connection and try again.",
      );
    } on http.ClientException {
      _closeDialogIfOpen();
      _showNetworkError();
    } catch (e) {
      debugPrint("Upload/classify error: $e");
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
      appBar: AppBar(title: Text(_showResult ? "Scan Result" : "New Scan")),
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
        const DpPageHeader(
          eyebrow: "AI skin scan",
          title: "Analyze skin condition",
          subtitle: "Upload a clear, close-up photo of the affected area.",
        ),
        const SizedBox(height: 20),
        if (_selectedImage == null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _showImageSourceSheet,
              child: Ink(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.gradientStart.withOpacity(0.10),
                      AppColors.gradientEnd.withOpacity(0.10),
                    ],
                  ),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.35), width: 1.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        ),
                      ),
                      child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text("Tap to capture or upload",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text("Take a photo or choose one from your gallery",
                        style: TextStyle(color: dpMuted(context), fontSize: 12.5)),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DpChip("Camera", icon: Icons.camera_alt_outlined),
                        SizedBox(width: 8),
                        DpChip("Gallery", icon: Icons.photo_library_outlined),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Image.file(_selectedImage!,
                        height: 280, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.black.withOpacity(0.5),
                          child: const Icon(Icons.close, color: Colors.white, size: 17),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text("Photo ready",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Analyze Photo"),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedImage = null),
                icon: const Icon(Icons.refresh),
                label: const Text("Choose Another Photo"),
              ),
            ],
          ),
        const SizedBox(height: 20),
        const DpNotice(
          tone: DpTone.info,
          icon: Icons.lightbulb_outline,
          title: "Tips for best results",
          text: "",
          bullets: [
            "Use good, natural lighting",
            "Focus clearly on the affected area",
            "Accepted formats: JPG, PNG",
            "Max size: 10MB",
          ],
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final data = _resultData!;
    final double confidence = ((data["confidence_score"] ?? 0) as num).toDouble();
    final String disease = data["predicted_disease"] ?? "Unknown";
    final needsReview = data["needs_vet_review"] == true;
    final color = needsReview ? AppColors.orange : dpConfidenceColor(confidence);

    final Map<String, dynamic> rawProbabilities =
        (data["probabilities"] as Map<String, dynamic>?) ?? {};
    final sortedProbabilities = rawProbabilities.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DpPageHeader(
          eyebrow: needsReview ? "Not sure" : "Analysis complete",
          title: needsReview ? "Possibly $disease" : disease,
          subtitle: needsReview
              ? "The AI isn't confident about this photo. A vet review is recommended."
              : "Here is what the AI found in your photo.",
        ),
        const SizedBox(height: 16),
        if (_selectedImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.file(_selectedImage!,
                height: 220, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),
        DpCard(
          accent: color,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Text("PREDICTED CONDITION",
                      style: TextStyle(
                        color: dpMuted(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      )),
                  const Spacer(),
                  DpChip(dpConfidenceLabel(confidence), color: color),
                ],
              ),
              const SizedBox(height: 16),
              DpConfidenceRing(confidence: confidence, color: color),
              const SizedBox(height: 12),
              Text(disease,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (sortedProbabilities.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Confidence Breakdown",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 12),
                ...sortedProbabilities.map((entry) => DpProgressRow(
                      label: entry.key,
                      percent: (entry.value as num).toDouble(),
                      highlight: entry.key == sortedProbabilities.first.key,
                    )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Blue main button, same as the other primary buttons
        ElevatedButton.icon(
          onPressed: _openRefineScreen,
          icon: const Icon(Icons.tune),
          label: const Text("Refine Prediction with Symptoms"),
        ),
        const SizedBox(height: 16),
        if (needsReview) ...[
          const DpNotice(
            tone: DpTone.warning,
            text: "The model is not confident about this photo. Try a closer, sharper photo in daylight, and ask a vet to check.",
          ),
          const SizedBox(height: 12),
        ],
        const DpNotice(
          tone: DpTone.info,
          icon: Icons.health_and_safety_outlined,
          title: "AI result - not a diagnosis",
          text: "This result is for information only. Always consult a veterinarian for treatment.",
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealAccent),
          onPressed: _reviewRequested ? null : _requestVetReview,
          icon: Icon(_reviewRequested ? Icons.check : Icons.medical_services_outlined),
          label: Text(_reviewRequested ? "Vet Review Requested" : "Request Veterinarian Review"),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _reset,
          child: const Text("Done"),
        ),
      ],
    );
  }
}
