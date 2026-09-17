import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sms_scan_screen.dart';
import 'scan_screen.dart';
import 'url_scan_screen.dart';
import 'history_screen.dart';

import '../models/scan_result.dart';
import '../services/apk_auto_scan_service.dart';
import '../services/sms_background_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAutoProtectEnabled = false;
  bool _isAutoApkScanEnabled = false;
  double _activationProgress = 0;
  bool _isActivating = false;
  double _apkActivationProgress = 0;
  bool _isApkActivating = false;

  final ApkAutoScanService _apkAutoScanService = ApkAutoScanService();

  @override
  void initState() {
    super.initState();
    _initializeAutomaticSmsScan();
    _initializeAutomaticApkScan();
    _apkAutoScanService.listenForResults(_openAutomaticApkResult);
  }

  Future<void> _initializeAutomaticSmsScan() async {
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool('automatic_sms_scan_enabled') ?? false;
    if (!enabled || !mounted) return;

    setState(() {
      _isAutoProtectEnabled = true;
      _activationProgress = 1;
    });
    final started = await SmsBackgroundService().init();
    if (!started) {
      await preferences.setBool('automatic_sms_scan_enabled', false);
      if (mounted) {
        setState(() {
          _isAutoProtectEnabled = false;
          _activationProgress = 0;
        });
      }
    }
  }

  Future<void> _initializeAutomaticApkScan() async {
    final enabled = await _apkAutoScanService.isEnabled();
    if (!mounted) return;
    setState(() => _isAutoApkScanEnabled = enabled);
    final pendingResult = await _apkAutoScanService.getPendingResult();
    if (pendingResult != null && mounted) {
      _openAutomaticApkResult(pendingResult);
    }
  }

  void _openAutomaticApkResult(ScanResult result) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
  }

  Future<void> _setAutomaticApkScanEnabled(bool enabled) async {
    try {
      if (enabled) {
        await _apkAutoScanService.start();
      } else {
        await _apkAutoScanService.stop();
      }
      if (!mounted) return;
      setState(() {
        _isAutoApkScanEnabled = enabled;
        _apkActivationProgress = enabled ? 1 : 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAutoApkScanEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Automatic APK scan could not start: $error')),
      );
    }
  }

  Future<void> _activateAutoProtect() async {
    if (_isActivating || _isAutoProtectEnabled) return;

    setState(() => _isActivating = true);
    final started = await SmsBackgroundService().init();

    if (!mounted) return;
    if (!started) {
      setState(() {
        _isActivating = false;
        _activationProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permissions were not granted.')),
      );
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('automatic_sms_scan_enabled', true);
    setState(() {
      _isAutoProtectEnabled = true;
      _isActivating = false;
      _activationProgress = 1;
    });
  }

  Future<void> _setAutoProtectEnabled(bool enabled) async {
    if (enabled) {
      _activateAutoProtect();
      return;
    }

    setState(() {
      _isAutoProtectEnabled = false;
      _activationProgress = 0;
      _isActivating = false;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('automatic_sms_scan_enabled', false);

    await openAppSettings();
  }

  Future<void> _activateAutomaticApkScan() async {
    if (_isApkActivating || _isAutoApkScanEnabled) return;

    setState(() => _isApkActivating = true);
    try {
      await _apkAutoScanService.start();
      if (!mounted) return;
      setState(() {
        _isAutoApkScanEnabled = true;
        _isApkActivating = false;
        _apkActivationProgress = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isApkActivating = false;
        _apkActivationProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('APK permissions are required: $error')),
      );
    }
  }

  void _updateApkActivationProgress(DragUpdateDetails details, double width) {
    if (_isAutoApkScanEnabled || _isApkActivating) return;
    setState(() {
      _apkActivationProgress =
          (_apkActivationProgress + details.delta.dx / width).clamp(0.0, 1.0);
    });
    if (_apkActivationProgress >= 0.82) {
      _activateAutomaticApkScan();
    }
  }

  void _resetApkActivationProgress() {
    if (_isAutoApkScanEnabled || _isApkActivating) return;
    setState(() => _apkActivationProgress = 0);
  }

  void _updateActivationProgress(DragUpdateDetails details, double width) {
    if (_isAutoProtectEnabled || _isActivating) return;

    setState(() {
      _activationProgress = (_activationProgress + details.delta.dx / width)
          .clamp(0.0, 1.0);
    });

    if (_activationProgress >= 0.82) {
      _activateAutoProtect();
    }
  }

  void _resetActivationProgress() {
    if (_isAutoProtectEnabled || _isActivating) return;
    setState(() => _activationProgress = 0);
  }

  int get _activeProtectionsCount {
    int count = 0;
    if (_isAutoProtectEnabled) count++;
    if (_isAutoApkScanEnabled) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.tealContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.tealBorder),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: AppColors.lightTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SafeScan',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showProfile(context),
            tooltip: 'Profile',
            icon: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.lightTeal,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. YOUR PROTECTION SUMMARY CARD
              _buildProtectionStatusCard(),
              const SizedBox(height: 24),

              // 2. AUTOMATIC PROTECTION SECTION
              const SectionHeader(title: 'Automatic Protection'),
              _buildSmsProtectionTile(),
              const SizedBox(height: 12),
              _buildApkProtectionTile(),
              const SizedBox(height: 28),

              // 3. SCAN SOMETHING SECTION
              const SectionHeader(title: 'Scan Something'),
              _buildManualScannerCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtectionStatusCard() {
    final activeCount = _activeProtectionsCount;
    final isFullyProtected = activeCount == 2;
    final isProtected = activeCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isProtected ? AppColors.tealBorder : AppColors.border,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            isProtected ? const Color(0xFF162B28) : AppColors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR PROTECTION',
                style: TextStyle(
                  color: AppColors.lightTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isProtected ? AppColors.safeGreen : AppColors.warningAmber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$activeCount active',
                    style: TextStyle(
                      color: isProtected ? AppColors.safeGreen : AppColors.warningAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isFullyProtected
                ? 'Device Shield Active'
                : (isProtected ? 'Partial Shield Enabled' : 'Protection Disabled'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFullyProtected
                ? 'SafeScan is monitoring incoming messages & downloads in the background.'
                : 'Enable automatic scanning below to guard against malicious links & files.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          // Protection pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeaturePill(
                label: 'SMS SHIELD',
                isActive: _isAutoProtectEnabled,
              ),
              _buildFeaturePill(
                label: 'APK SHIELD',
                isActive: _isAutoApkScanEnabled,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill({required String label, required bool isActive}) {
    final color = isActive ? AppColors.lightTeal : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? AppColors.tealContainer : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.tealBorder : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsProtectionTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isAutoProtectEnabled ? AppColors.tealBorder : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.sms_rounded,
                color: Color(0xFFFCD34D),
                backgroundColor: Color(0x26FCD34D),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Automatic SMS scan',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Checks incoming messages in background',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: _isAutoProtectEnabled ? 'ACTIVE' : 'OFF',
                color: _isAutoProtectEnabled ? AppColors.safeGreen : AppColors.textMuted,
              ),
            ],
          ),
          if (!_isAutoProtectEnabled) ...[
            const SizedBox(height: 14),
            _buildSwipeSlider(
              isActivating: _isActivating,
              progress: _activationProgress,
              onUpdate: _updateActivationProgress,
              onEnd: _resetActivationProgress,
              hintText: 'Swipe to activate SMS scan',
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.safeGreenContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.safeGreen, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Protection active • Monitoring messages',
                      style: TextStyle(
                        color: AppColors.safeGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _setAutoProtectEnabled(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Turn off',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApkProtectionTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isAutoApkScanEnabled ? AppColors.tealBorder : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.android_rounded,
                color: AppColors.lightTeal,
                backgroundColor: AppColors.tealContainer,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Automatic APK scan',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Scans new APKs in Downloads & WhatsApp',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: _isAutoApkScanEnabled ? 'ACTIVE' : 'OFF',
                color: _isAutoApkScanEnabled ? AppColors.safeGreen : AppColors.textMuted,
              ),
            ],
          ),
          if (!_isAutoApkScanEnabled) ...[
            const SizedBox(height: 14),
            _buildSwipeSlider(
              isActivating: _isApkActivating,
              progress: _apkActivationProgress,
              onUpdate: _updateApkActivationProgress,
              onEnd: _resetApkActivationProgress,
              hintText: 'Swipe to activate APK scan',
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.safeGreenContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.safeGreen, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Protection active • Monitoring downloads',
                      style: TextStyle(
                        color: AppColors.safeGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _setAutomaticApkScanEnabled(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Turn off',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwipeSlider({
    required bool isActivating,
    required double progress,
    required void Function(DragUpdateDetails details, double width) onUpdate,
    required VoidCallback onEnd,
    required String hintText,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        const thumbWidth = 52.0;
        final thumbOffset = (trackWidth - thumbWidth) * progress;

        return GestureDetector(
          onHorizontalDragUpdate: (details) => onUpdate(details, trackWidth),
          onHorizontalDragEnd: (_) => onEnd(),
          child: Container(
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Center(
                  child: Text(
                    isActivating ? 'Activating...' : hintText,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  left: thumbOffset,
                  child: Container(
                    width: thumbWidth,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualScannerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildScannerRow(
            icon: Icons.android_rounded,
            title: 'Scan an APK',
            subtitle: 'Check an Android app before installing it',
            iconColor: AppColors.lightTeal,
            iconBg: AppColors.tealContainer,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanScreen()),
            ),
          ),
          const Divider(color: AppColors.border, height: 1, indent: 64),
          _buildScannerRow(
            icon: Icons.sms_rounded,
            title: 'Scan an SMS',
            subtitle: 'Spot suspicious messages and scam language',
            iconColor: const Color(0xFFFCD34D),
            iconBg: const Color(0x26FCD34D),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SmsScanScreen()),
            ),
          ),
          const Divider(color: AppColors.border, height: 1, indent: 64),
          _buildScannerRow(
            icon: Icons.link_rounded,
            title: 'Scan a URL',
            subtitle: 'Check a link before opening the website',
            iconColor: const Color(0xFFA5B4FC),
            iconBg: const Color(0x26A5B4FC),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UrlScanScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            IconBox(
              icon: icon,
              color: iconColor,
              backgroundColor: iconBg,
              size: 42,
              iconSize: 20,
              borderRadius: 12,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (settingsContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Control real-time and background scanning services.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: const Text(
                              'Automatic SMS scan',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Check incoming messages in the background',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            value: _isAutoProtectEnabled,
                            activeThumbColor: AppColors.lightTeal,
                            activeTrackColor: AppColors.primaryTeal,
                            onChanged: (value) {
                              setModalState(() {});
                              _setAutoProtectEnabled(value);
                            },
                          ),
                          const Divider(color: AppColors.border, height: 1),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: const Text(
                              'Automatic APK scan',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Scan new APKs in Downloads and WhatsApp documents',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            value: _isAutoApkScanEnabled,
                            activeThumbColor: AppColors.lightTeal,
                            activeTrackColor: AppColors.primaryTeal,
                            onChanged: (val) {
                              setModalState(() {});
                              _setAutomaticApkScanEnabled(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showProfile(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.lightTeal),
                    ),
                  ),
                ),
              );
            }

            final profile = snapshot.data?.data() ?? <String, dynamic>{};
            final name = _profileValue(
              profile['name'],
              user.displayName ?? 'Security Operator',
            );
            final email = _profileValue(
              profile['email'],
              user.email ?? 'Not available',
            );
            final mobile = _profileValue(profile['mobile'], 'Not available');

            // Generate initials
            final nameParts = name.trim().split(' ');
            final initials = nameParts.length >= 2
                ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
                : (name.isNotEmpty ? name[0].toUpperCase() : 'U');

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // User header
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.tealContainer,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryTeal,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: AppColors.lightTeal,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const StatusBadge(
                                      text: 'VERIFIED',
                                      color: AppColors.safeGreen,
                                      icon: Icons.verified_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (mobile != 'Not available') ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    mobile,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 8),

                      // Profile Actions
                      _buildProfileItem(
                        icon: Icons.history_rounded,
                        title: 'Scan History',
                        subtitle: 'View past telemetry & results',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          );
                        },
                      ),
                      _buildProfileItem(
                        icon: Icons.tune_rounded,
                        title: 'Settings',
                        subtitle: 'Configure scanning preferences',
                        onTap: () {
                          Navigator.pop(context);
                          _showSettings(context);
                        },
                      ),
                      _buildProfileItem(
                        icon: Icons.verified_outlined,
                        title: 'Licence',
                        subtitle: 'Open-source software licenses',
                        onTap: () {
                          Navigator.pop(context);
                          showLicensePage(
                            context: context,
                            applicationName: 'SafeScan',
                            applicationVersion: '2.6 Core',
                          );
                        },
                      ),
                      _buildProfileItem(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        subtitle: 'Terminate active session',
                        iconColor: AppColors.threatRed,
                        onTap: () async {
                          Navigator.pop(context);
                          await FirebaseAuth.instance.signOut();
                        },
                      ),
                      const SizedBox(height: 16),
                      // Footnote
                      const Center(
                        child: Text(
                          'SafeScan v2.6 Core • Encrypted Session',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? AppColors.lightTeal;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: IconBox(
        icon: icon,
        color: effectiveColor,
        backgroundColor: effectiveColor.withValues(alpha: 0.12),
        size: 40,
        iconSize: 20,
        borderRadius: 12,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: iconColor ?? AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
        size: 18,
      ),
      onTap: onTap,
    );
  }

  String _profileValue(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
