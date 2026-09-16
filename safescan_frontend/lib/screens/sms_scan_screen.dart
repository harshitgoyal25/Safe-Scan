import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/scan_history_service.dart';
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
        const SnackBar(content: Text('Please enter an SMS message.')),
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
      debugPrint('SMS scan history save failed.');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('SMS scan failed: $e')));
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
      appBar: AppBar(title: const Text('Scan SMS'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              const Icon(Icons.sms_rounded, size: 64, color: Color(0xFF80D5CB)),

              const SizedBox(height: 24),

              const Text(
                'Analyze a Message',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Enter an SMS message to check whether it is benign or potentially malicious.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),

              const SizedBox(height: 32),

              TextField(
                controller: _messageController,
                maxLines: 8,
                minLines: 8,
                maxLength: 10000,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Paste or type the SMS message here...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  contentPadding: EdgeInsets.all(20),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanSms,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.security),
                  label: Text(
                    _isScanning ? 'Analyzing Content...' : 'Analyze Content',
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'SafeScan checks against known threat databases and analyzes language patterns. Do not enter sensitive information.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
