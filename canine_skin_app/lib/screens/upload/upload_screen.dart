import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  String? _statusMessage;
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _statusMessage = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedImage == null) {
      setState(() => _statusMessage = "Please select an image first");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {

      // Step A: create a dog record first
      final dogResult = await ApiService.addDog(age: 3, ownerType: "Dog Owner");
      if (dogResult["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }
      if (dogResult["statusCode"] != 201) {
        setState(() => _statusMessage = "Could not create dog record");
        return;
      }
      final dogId = dogResult["body"]["dog"]["dog_id"];

      // Step B: upload the image for that dog
      final imageResult = await ApiService.uploadImage(
        dogId: dogId,
        imageFile: _selectedImage!,
      );

      if (imageResult["statusCode"] == 401) {
        _handleSessionExpired();
        return;
      }

      if (imageResult["statusCode"] == 201) {
        final imageId = imageResult["body"]["image"]["image_id"];

        // Step C: classify the uploaded image
        final classifyResult = await ApiService.classifyImage(imageId);
        if (classifyResult["statusCode"] == 401) {
          _handleSessionExpired();
          return;
        }
        if (classifyResult["statusCode"] == 201) {
          final body = classifyResult["body"];
          setState(() {
            _statusMessage =
                "Predicted: ${body["predicted_disease"]} "
                "(confidence: ${(body["confidence_score"] * 100).toStringAsFixed(1)}%)"
                "${body["needs_vet_review"] ? "\nFlagged for vet review." : ""}";
            _lastResultId = body["result_id"];
            _reviewRequested = false;
          });
        } else {
          setState(() => _statusMessage = "Uploaded, but classification failed");
        }
      } else {
        setState(() => _statusMessage = imageResult["body"]["error"] ?? "Upload failed");
      }
    } catch (e) {
      setState(() => _statusMessage = "Could not connect to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Dog Image")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 250)
            else
              Container(
                height: 250,
                color: Colors.grey[300],
                child: const Center(child: Text("No image selected")),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusMessage!.startsWith("Predicted")
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Upload Image"),
            ),
            if (_lastResultId != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _reviewRequested ? null : _requestVetReview,
                child: Text(
                  _reviewRequested ? "Vet Review Requested ✓" : "Request Vet Review",
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}