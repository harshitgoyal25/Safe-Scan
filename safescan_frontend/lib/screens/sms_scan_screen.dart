import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/scan_history_service.dart';
import '../theme/app_theme.dart';
import 'sms_result_screen.dart';

class SmsScanScreen extends StatefulWidget {
  const SmsScanScreen({super.key});

  @override
  State<SmsScanScreen> createState() => _SmsScanScreenState();
}

class _SmsScanScreenState extends State<SmsScanScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isScanning = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _scanSms() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or paste an SMS message.')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final result = await _apiService.scanSms(message);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SmsResultScreen(message: message, result: result),
        ),
      );
      unawaited(_saveHistory(message, result));
    } catch (e) {
      debugPrint('SMS scan failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS scan failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _saveHistory(String message, Map<String, dynamic> result) async {
    try {
      await ScanHistoryService().saveScan(
        scanType: 'sms',
        inputLabel: 'SMS text',
        inputValue: message,
        result: result,
      );
    } catch (error, stackTrace) {
      debugPrint('SMS history save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scan SMS'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Header Container
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0x26FCD34D),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFCD34D).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sms_rounded,
                      size: 34,
                      color: Color(0xFFFCD34D),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Analyze a Message',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter an SMS message to check whether it contains phishing links, suspicious claims, or social engineering tactics.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Message Input Box
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(4),
                child: TextField(
                  controller: _messageController,
                  maxLines: 7,
                  minLines: 6,
                  maxLength: 5000,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Paste or type the SMS message content here...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action button
              ElevatedButton(
                onPressed: _isScanning ? null : _scanSms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isScanning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Analyzing Content...',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Analyze Content',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              const Text(
                'SafeScan checks NLP language patterns against active threat signatures. Do not input confidential credentials or OTPs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
