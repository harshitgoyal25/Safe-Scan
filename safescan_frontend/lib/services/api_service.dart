import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ==========================================================
  // APK SCANNING
  // ==========================================================

  Future<Map<String, dynamic>> scanApk(File apkFile) async {
    final uri = Uri.parse('$baseUrl/scan');

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        apkFile.path,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'APK scan failed: ${response.body}',
      );
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }

  // ==========================================================
  // SMS SCANNING
  // ==========================================================

  Future<Map<String, dynamic>> scanSms(
    String message,
  ) async {
    final uri = Uri.parse('$baseUrl/scan/sms');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': message,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'SMS scan failed: ${response.body}',
      );
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>> scanUrl(String url) async {
  final uri = Uri.parse('$baseUrl/scan/url');

  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'url': url,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'URL scan failed: ${response.body}',
    );
  }

  return jsonDecode(response.body)
      as Map<String, dynamic>;
}
}