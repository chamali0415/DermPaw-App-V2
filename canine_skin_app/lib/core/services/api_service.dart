import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService {
  static const String baseUrl = "http://20.205.10.143";

  // Upload + classification can take a while on a slow mobile connection
  static const Duration uploadTimeout = Duration(seconds: 60);
  static const Duration requestTimeout = Duration(seconds: 30);

  // Stores the logged-in user's details in memory for this app session
  static String? authToken;
  static String? currentUserName;
  static bool currentUserIsVet = false;
  static int? currentUserId;
  static bool currentUserHasPicture = false;
  static int currentUserPictureVersion = 0;

  /// Keep the logged-in user's details (from login / register / profile).
  static void rememberUser(dynamic user) {
    if (user is! Map) return;
    currentUserName = user["name"] ?? currentUserName;
    currentUserIsVet = user["is_vet"] == true;
    currentUserId = user["user_id"] ?? currentUserId;
    currentUserHasPicture = user["has_profile_picture"] == true;
    currentUserPictureVersion = user["profile_picture_version"] ?? 0;
  }

  /// Decodes a JSON body safely. If the server returned an HTML error page
  /// (e.g. nginx 502/504 or a Flask crash), we still get a usable map instead
  /// of a FormatException that the UI would mistake for "no internet".
  static dynamic _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {
        "error": "Server error (${response.statusCode}). Please try again in a moment."
      };
    }
  }

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
    String? verificationCode,
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
        if (verificationCode != null) "verification_code": verificationCode,
      }),
    );
    final decoded = _decode(response);
    if (response.statusCode == 201) {
      authToken = decoded["access_token"];
      rememberUser(decoded["user"]);
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
    final decoded = _decode(response);
    if (response.statusCode == 200) {
      authToken = decoded["access_token"];
      rememberUser(decoded["user"]);
    }
    return {"statusCode": response.statusCode, "body": decoded};
  }
  static void logout() {
    authToken = null;
    currentUserName = null;
    currentUserIsVet = false;
    currentUserId = null;
    currentUserHasPicture = false;
    currentUserPictureVersion = 0;
  }

 static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/forgot-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
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
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse("$baseUrl/profile"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
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
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

static Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/profile"),
      headers: _authHeaders,
      body: jsonEncode({"password": password}),
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }


static Future<Map<String, dynamic>> addDog({
    required int age,
    required String ownerType,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/dogs"),
      headers: _authHeaders,
      body: jsonEncode({"age": age, "owner_type": ownerType}),
    ).timeout(requestTimeout);
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  static Future<Map<String, dynamic>> uploadImage({
    required int dogId,
    required File imageFile,
  }) async {
    final uri = Uri.parse("$baseUrl/dogs/$dogId/images");
    final request = http.MultipartRequest("POST", uri);
    request.headers["Authorization"] = "Bearer $authToken";
    request.files.add(await http.MultipartFile.fromPath("file", imageFile.path));

    final streamedResponse = await request.send().timeout(uploadTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

static Future<Map<String, dynamic>> classifyImage(int imageId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/images/$imageId/classify"),
      headers: _authHeaders,
    ).timeout(uploadTimeout);
    return {"statusCode": response.statusCode, "body": _decode(response)};
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
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

static Future<Map<String, dynamic>> requestVetReview(int resultId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/results/$resultId/request-review"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

static Future<Map<String, dynamic>> getHistory() async {
    final response = await http.get(
      Uri.parse("$baseUrl/history"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

static Future<Map<String, dynamic>> getPendingReviews() async {
    final response = await http.get(
      Uri.parse("$baseUrl/vet/reviews"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  static Future<Map<String, dynamic>> getCaseDetails(int resultId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/vet/reviews/$resultId/details"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  static Future<Map<String, dynamic>> getVetCaseHistory() async {
    final response = await http.get(
      Uri.parse("$baseUrl/vet/history"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
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
    return {"statusCode": response.statusCode, "body": _decode(response)};
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
  return {"statusCode": response.statusCode, "body": _decode(response)};
}

  static Future<Map<String, dynamic>> getAppReview() async {
    final response = await http.get(
      Uri.parse("$baseUrl/app-review"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
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
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  static Future<Map<String, dynamic>> getAllAppReviews() async {
    final response = await http.get(
      Uri.parse("$baseUrl/app-reviews"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  static Future<Map<String, dynamic>> getPendingVets() async {
    final response = await http.get(
      Uri.parse("$baseUrl/admin/pending-vets"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  static Future<Map<String, dynamic>> verifyVet(int userId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/admin/vets/$userId/verify"),
      headers: _authHeaders,
    );
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  /// URL + header for showing a stored scan image with Image.network
  static String imageFileUrl(int imageId) => "$baseUrl/images/$imageId/file";
  static Map<String, String> get imageHeaders =>
      {if (authToken != null) "Authorization": "Bearer $authToken"};

  // ---------------------------------------------------- email verification

  /// Step 1 of registration: e-mails a 4-digit code to [email].
  static Future<Map<String, dynamic>> sendVerificationCode(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register/send-code"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    ).timeout(requestTimeout);
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  // ---------------------------------------------------------- delete cases

  /// Owner: permanently delete one case (result, photo, vet review).
  static Future<Map<String, dynamic>> deleteCase(int resultId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/history/$resultId"),
      headers: _authHeaders,
    ).timeout(requestTimeout);
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  /// Owner: permanently delete ALL of their cases.
  static Future<Map<String, dynamic>> deleteAllCases() async {
    final response = await http.delete(
      Uri.parse("$baseUrl/history"),
      headers: _authHeaders,
    ).timeout(requestTimeout);
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  /// Vet: remove one reviewed case from the vet's own history list.
  static Future<Map<String, dynamic>> deleteVetCase(int reviewId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/vet/history/$reviewId"),
      headers: _authHeaders,
    ).timeout(requestTimeout);
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  /// Vet: remove ALL reviewed cases from the vet's own history list.
  static Future<Map<String, dynamic>> deleteAllVetCases() async {
    final response = await http.delete(
      Uri.parse("$baseUrl/vet/history"),
      headers: _authHeaders,
    ).timeout(requestTimeout);
    return {"statusCode": response.statusCode, "body": _decode(response)};
  }

  // ------------------------------------------------------- profile picture

  /// URL of a user's profile picture. [version] changes when the picture
  /// changes, so the app does not show an old cached photo.
  static String profilePictureUrl(int userId, int version) =>
      "$baseUrl/users/$userId/picture?v=$version";

  static Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/profile/picture"));
    request.headers["Authorization"] = "Bearer $authToken";
    request.files.add(await http.MultipartFile.fromPath("file", imageFile.path));
    final streamed = await request.send().timeout(uploadTimeout);
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response);
    if (response.statusCode == 200) rememberUser(decoded["user"]);
    return {"statusCode": response.statusCode, "body": decoded};
  }

  static Future<Map<String, dynamic>> deleteProfilePicture() async {
    final response = await http.delete(
      Uri.parse("$baseUrl/profile/picture"),
      headers: _authHeaders,
    ).timeout(requestTimeout);
    final decoded = _decode(response);
    if (response.statusCode == 200) rememberUser(decoded["user"]);
    return {"statusCode": response.statusCode, "body": decoded};
  }
}
