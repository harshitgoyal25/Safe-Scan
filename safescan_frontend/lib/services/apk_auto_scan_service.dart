import 'dart:convert';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../models/scan_result.dart';

class ApkAutoScanService {
  static const MethodChannel _channel = MethodChannel('safescan/apk_auto_scan');

  Future<void> start() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.storage.request();
    }
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('You must be signed in to enable automatic APK scans.');
    }
    await _channel.invokeMethod<void>('start', token);
  }

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<bool> isEnabled() async {
    return await _channel.invokeMethod<bool>('isEnabled') ?? false;
  }

  Future<ScanResult?> getPendingResult() async {
    final raw = await _channel.invokeMethod<String>('getPendingResult');
    if (raw == null || raw.isEmpty) return null;
    return ScanResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  void listenForResults(void Function(ScanResult result) onResult) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'apkScanResult' || call.arguments is! String) {
        return;
      }
      final result = ScanResult.fromJson(
        jsonDecode(call.arguments as String) as Map<String, dynamic>,
      );
      onResult(result);
    });
  }
}
