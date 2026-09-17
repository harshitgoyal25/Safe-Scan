import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'notification_service.dart';

typedef StartupProgressCallback = void Function(double progress, String status);

class StartupService {
  static final StartupService _instance = StartupService._internal();
  factory StartupService() => _instance;
  StartupService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize({required StartupProgressCallback onProgress}) async {
    if (_isInitialized) {
      onProgress(1.0, 'Ready');
      return;
    }

    // Stage 1: Framework ready
    onProgress(0.15, 'Initializing SafeScan');

    // Stage 2: Firebase platform initialization
    onProgress(0.35, 'Loading security services');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Stage 3: Notification channels & service
    onProgress(0.65, 'Checking protection status');
    final notificationService = NotificationService();
    await notificationService.init();

    // Stage 4: Persistent preferences & Auth readiness
    onProgress(0.85, 'Preparing your workspace');
    await SharedPreferences.getInstance();

    // Ensure FirebaseAuth has resolved its initial cached user state
    try {
      await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => FirebaseAuth.instance.currentUser,
      );
    } catch (_) {
      // Gracefully continue even if network/timeout occurs;
      // AuthGate will continue to listen to the auth stream as usual.
    }

    // Stage 5: Wrap up
    onProgress(0.95, 'Almost ready');

    _isInitialized = true;

    // Stage 6: Completed
    onProgress(1.0, 'Ready');
  }

  void reset() {
    _isInitialized = false;
  }
}
