import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import '../firebase_options.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'scan_history_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint("Firebase init in background isolate failed: $e");
    }
  }

  final preferences = await SharedPreferences.getInstance();
  final isEnabled = preferences.getBool('automatic_sms_scan_enabled') ?? false;
  debugPrint("Automatic SMS scanning enabled: $isEnabled");
  if (!isEnabled) {
    return;
  }

  debugPrint("SMS receiver triggered");
  final hasBody = message.body != null && message.body!.isNotEmpty;
  debugPrint("SMS body received: $hasBody");

  final notificationService = NotificationService();
  await notificationService.init();

  final apiService = ApiService();

  try {
    if (hasBody) {
      debugPrint("SMS analysis request started");
      final response = await apiService.scanSms(message.body!);
      debugPrint("SMS analysis completed");

      final prediction = response['prediction']?.toString() ?? 'Unknown';
      final isMalicious = prediction.toLowerCase() == 'malicious';

      try {
        await ScanHistoryService().saveScan(
          scanType: 'sms',
          inputLabel: message.address ?? 'Incoming SMS',
          inputValue: message.body!,
          result: response,
        );
      } catch (historyError) {
        debugPrint("Background scan history save skipped: $historyError");
      }

      await notificationService.showSmsScanResult(message.address, isMalicious);
      debugPrint("Notification triggered");
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
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Permission request fallback for non-supported platforms/testing
    }

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

