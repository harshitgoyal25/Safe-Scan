import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'sms_result_screen.dart';

class SmsScanScreen extends StatefulWidget {
  const SmsScanScreen({super.key});

  @override
  State<SmsScanScreen> createState() => _SmsScanScreenState();
}

class _SmsScanScreenState extends State<SmsScanScreen> {
  final TextEditingController _messageController =
      TextEditingController();

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
        const SnackBar(
          content: Text(
            'Please enter an SMS message.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final result = await _apiService.scanSms(
        message,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SmsResultScreen(
            message: message,
            result: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SMS scan failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan SMS'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // ------------------------------------------------
              // Icon
              // ------------------------------------------------

              const Icon(
                Icons.sms_outlined,
                size: 80,
                color: Colors.blue,
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // Title
              // ------------------------------------------------

              const Text(
                'SMS Security Scan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Enter an SMS message to check whether '
                'it is benign or potentially malicious.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 30),

              // ------------------------------------------------
              // SMS input
              // ------------------------------------------------

              TextField(
                controller: _messageController,
                maxLines: 8,
                maxLength: 10000,
                textInputAction:
                    TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                      'Paste or type the SMS message here...',
                  labelText: 'SMS Message',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // Scan button
              // ------------------------------------------------

              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed:
                      _isScanning ? null : _scanSms,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.security,
                        ),
                  label: Text(
                    _isScanning
                        ? 'Scanning...'
                        : 'Scan SMS',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // Information
              // ------------------------------------------------

              Container(
                padding:
                    const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'SafeScan analyzes the message '
                        'using a machine-learning model. '
                        'Do not enter passwords, PINs, or '
                        'other sensitive information.',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}