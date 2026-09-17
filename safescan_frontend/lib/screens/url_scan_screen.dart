import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/scan_history_service.dart';
import '../theme/app_theme.dart';
import 'url_result_screen.dart';

class UrlScanScreen extends StatefulWidget {
  const UrlScanScreen({super.key});

  @override
  State<UrlScanScreen> createState() => _UrlScanScreenState();
}

class _UrlScanScreenState extends State<UrlScanScreen> {
  final TextEditingController _urlController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isScanning = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _scanUrl() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or paste a URL.')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final result = await _apiService.scanUrl(url);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UrlResultScreen(result: result)),
      );
      unawaited(_saveHistory(url, result));
    } catch (e) {
      debugPrint('URL scan failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URL scan failed: $e')),
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

  Future<void> _saveHistory(String url, Map<String, dynamic> result) async {
    try {
      await ScanHistoryService().saveScan(
        scanType: 'url',
        inputLabel: 'URL',
        inputValue: url,
        result: result,
      );
    } catch (error, stackTrace) {
      debugPrint('URL history save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scan URL'),
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
                    color: const Color(0x26A5B4FC),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFA5B4FC).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.link_rounded,
                      size: 34,
                      color: Color(0xFFA5B4FC),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Analyze a URL',
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
                'Enter a website link or domain to detect phishing pages, deceptive redirects, and malicious hosting infrastructure.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // URL Input Box
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(4),
                child: TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 2000,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/login...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.all(14),
                  ),
                  onSubmitted: (_) {
                    if (!_isScanning) _scanUrl();
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Action button
              ElevatedButton(
                onPressed: _isScanning ? null : _scanUrl,
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
                'SafeScan parses destination structure and compares against security blacklists. Always ensure browser certificates match intended hosts.',
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
