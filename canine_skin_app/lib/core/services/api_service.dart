import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService {
  static const String baseUrl = "http://172.31.98.93:5000";

  // Stores the logged-in user's token in memory for this app session
  static String? authToken;
  static String? currentUserName;

  static Map<String, String> get _authHeaders => {
        "Content-Type": "application/json",
        if (authToken != null) "Authorization": "Bearer $authToken",
      };

    static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
    required bool isVet,
    String? vetLicenceNo,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        if (phoneNumber != null && phoneNumber.isNotEmpty) "phone_number": phoneNumber,
        "role": isVet ? "vet" : "owner",
        if (isVet && vetLicenceNo != null && vetLicenceNo.isNotEmpty)
          "vet_licence_no": vetLicenceNo,
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 201) {
      authToken = decoded["access_token"];
      currentUserName = decoded["user"]["name"];
    }
    return {"statusCode": response.statusCode, "body": decoded};
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      authToken = decoded["access_token"];
    }
    return {"statusCode": response.statusCode, "body": decoded};
  }
  static void logout() {
    authToken = null;
    currentUserName = null;
  }

 static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/forgot-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "reset_code": resetCode,
        "new_password": newPassword,
      }),
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse("$baseUrl/profile"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phoneNumber,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/profile"),
      headers: _authHeaders,
      body: jsonEncode({
        if (name != null) "name": name,
        if (phoneNumber != null) "phone_number": phoneNumber,
      }),
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

static Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/profile"),
      headers: _authHeaders,
      body: jsonEncode({"password": password}),
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }


static Future<Map<String, dynamic>> addDog({
    required int age,
    required String ownerType,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/dogs"),
      headers: _authHeaders,
      body: jsonEncode({"age": age, "owner_type": ownerType}),
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> uploadImage({
    required int dogId,
    required File imageFile,
  }) async {
    final uri = Uri.parse("$baseUrl/dogs/$dogId/images");
    final request = http.MultipartRequest("POST", uri);
    request.headers["Authorization"] = "Bearer $authToken";
    request.files.add(await http.MultipartFile.fromPath("file", imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

static Future<Map<String, dynamic>> classifyImage(int imageId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/images/$imageId/classify"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> refineWithSymptoms({
    required Map<String, dynamic> probabilities,
    required List<String> symptoms,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/results/refine"),
      headers: _authHeaders,
      body: jsonEncode({
        "probabilities": probabilities,
        "symptoms": symptoms,
      }),
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

static Future<Map<String, dynamic>> requestVetReview(int resultId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/results/$resultId/request-review"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

static Future<Map<String, dynamic>> getHistory() async {
    final response = await http.get(
      Uri.parse("$baseUrl/history"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

static Future<Map<String, dynamic>> getPendingReviews() async {
    final response = await http.get(
      Uri.parse("$baseUrl/vet/reviews"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> getCaseDetails(int resultId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/vet/reviews/$resultId/details"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> getVetCaseHistory() async {
    final response = await http.get(
      Uri.parse("$baseUrl/vet/history"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> submitReview({
    required int resultId,
    required String decision,
    String comments = "",
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/vet/reviews/$resultId"),
      headers: _authHeaders,
      body: jsonEncode({"decision": decision, "comments": comments}),
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> submitFeedback({
  required int resultId,
  required String feedbackText,
}) async {
  final response = await http.post(
    Uri.parse("$baseUrl/results/$resultId/feedback"),
    headers: _authHeaders,
    body: jsonEncode({"feedback_text": feedbackText}),
  );
  return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
}

  static Future<Map<String, dynamic>> getAppReview() async {
    final response = await http.get(
      Uri.parse("$baseUrl/app-review"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> submitAppReview({
    required int rating,
    String comment = "",
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/app-review"),
      headers: _authHeaders,
      body: jsonEncode({"rating": rating, "comment": comment}),
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> getAllAppReviews() async {
    final response = await http.get(
      Uri.parse("$baseUrl/app-reviews"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> getPendingVets() async {
    final response = await http.get(
      Uri.parse("$baseUrl/admin/pending-vets"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> verifyVet(int userId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/admin/vets/$userId/verify"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": jsonDecode(response.body)};
  }
}