import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'scan_history_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  final preferences = await SharedPreferences.getInstance();
  final isEnabled = preferences.getBool('automatic_sms_scan_enabled') ?? false;
  if (!isEnabled) {
    return;
  }

  final notificationService = NotificationService();
  await notificationService.init();

  final apiService = ApiService();

  try {
    if (message.body != null && message.body!.isNotEmpty) {
      final response = await apiService.scanSms(message.body!);
      final prediction = response['prediction']?.toString() ?? 'Unknown';
      final isMalicious = prediction.toLowerCase() == 'malicious';

      try {
        await ScanHistoryService().saveScan(
          scanType: 'sms',
          inputLabel: message.address ?? 'Incoming SMS',
          inputValue: message.body!,
          result: response,
        );
      } catch (_) {
        // Background notifications should continue even if history is unavailable.
      }

      await notificationService.showSmsScanResult(message.address, isMalicious);
    }
  } catch (e) {
    debugPrint("Background SMS scan failed: $e");
  }
}

class SmsBackgroundService {
  static final SmsBackgroundService _instance =
      SmsBackgroundService._internal();
  factory SmsBackgroundService() => _instance;

  final Telephony telephony = Telephony.instance;

  SmsBackgroundService._internal();

  Future<bool> init() async {
    bool? result = await telephony.requestPhoneAndSmsPermissions;

    if (result != null && result) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          // Trigger the same background handler for foreground messages as well
          backgroundMessageHandler(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
    }

    return result == true;
  }
}
