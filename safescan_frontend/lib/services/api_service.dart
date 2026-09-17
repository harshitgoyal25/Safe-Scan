import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'SAFESCAN_API_URL',
    defaultValue: 'https://safe-scan-hhw5.onrender.com',
  );

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('You must be signed in to scan.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  // ==========================================================
  // APK SCANNING
  // ==========================================================

  Future<Map<String, dynamic>> scanApk(File apkFile) async {
    final uri = Uri.parse('$baseUrl/scan');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers());

    request.files.add(await http.MultipartFile.fromPath('file', apkFile.path));

    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw Exception(
        'The backend timed out. Render may still be starting up; try again.',
      ),
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('APK scan failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ==========================================================
  // SMS SCANNING
  // ==========================================================

  Future<Map<String, dynamic>> scanSms(String message) async {
    final uri = Uri.parse('$baseUrl/scan/sms');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...await _headers()},
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(minutes: 3));
    } on TimeoutException {
      throw Exception(
        'The backend timed out. Render may still be starting up; try again.',
      );
    } on SocketException {
      throw Exception('Could not connect to the SafeScan backend.');
    } on http.ClientException catch (error) {
      throw Exception('Network error while contacting SafeScan: $error');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'SMS scan failed (${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scanUrl(String url) async {
    final uri = Uri.parse('$baseUrl/scan/url');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', ...await _headers()},
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(minutes: 3));

    if (response.statusCode != 200) {
      throw Exception(
        'URL scan failed (${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
