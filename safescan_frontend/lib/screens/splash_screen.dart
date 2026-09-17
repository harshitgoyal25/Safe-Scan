import 'dart:async';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/startup_service.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathingController;
  late final Animation<double> _scaleAnimation;

  double _progress = 0.05;
  String _statusMessage = 'Initializing SafeScan';
  bool _hasError = false;
  String? _errorDetails;

  @override
  void initState() {
    super.initState();

    // Breathing logo animation: 0.94 -> 1.00 -> 0.94 (2.6s complete cycle)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );

    _breathingController.repeat(reverse: true);

    // Start real startup initialization
    _startInitialization();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  Future<void> _startInitialization() async {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _errorDetails = null;
      _progress = 0.05;
      _statusMessage = 'Initializing SafeScan';
    });

    try {
      await StartupService().initialize(
        onProgress: (progress, status) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _statusMessage = status;
          });
        },
      );

      // Brief acknowledgment of completion state before transition
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      // Smooth subtle fade transition to AuthGate
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorDetails = e.toString();
        _statusMessage = 'Initialization failed';
      });
    }
  }

  void _onRetry() {
    StartupService().reset();
    _startInitialization();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // SafeScan Logo with breathing animation and subtle ambient glow
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryTeal.withValues(alpha: 0.16),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/safescan_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Brand Name
                const Text(
                  'SafeScan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 14),

                if (!_hasError) ...[
                  // Animated Status Text
                  SizedBox(
                    height: 22,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: Text(
                        _statusMessage,
                        key: ValueKey<String>(_statusMessage),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Thin horizontal progress bar
                  Container(
                    width: 220,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0.0, end: _progress),
                        builder: (context, value, child) {
                          return FractionallySizedBox(
                            widthFactor: value.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryTeal,
                                    AppColors.lightTeal,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  // Polished error state
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warningAmber,
                          size: 28,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Unable to initialize SafeScan',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Something went wrong while preparing SafeScan.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_errorDetails != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _errorDetails!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontFamily: 'Inter',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _onRetry,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 38),
                            side: const BorderSide(color: AppColors.primaryTeal),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: AppColors.lightTeal,
                          ),
                          label: const Text(
                            'Retry',
                            style: TextStyle(
                              color: AppColors.lightTeal,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
