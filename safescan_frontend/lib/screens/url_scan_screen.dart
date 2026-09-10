import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'url_result_screen.dart';

class UrlScanScreen extends StatefulWidget {
  const UrlScanScreen({super.key});

  @override
  State<UrlScanScreen> createState() => _UrlScanScreenState();
}

class _UrlScanScreenState extends State<UrlScanScreen> {
  final TextEditingController _urlController =
      TextEditingController();

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
        const SnackBar(
          content: Text('Please enter a URL.'),
        ),
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
        MaterialPageRoute(
          builder: (_) => UrlResultScreen(
            result: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'URL scan failed: $e',
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
        title: const Text('Scan URL'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),

            const Icon(
              Icons.link_rounded,
              size: 64,
              color: Color(0xFF80D5CB),
            ),

            const SizedBox(height: 24),

            const Text(
              'Analyze a URL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Enter a URL to check whether it is potentially malicious.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 32),

            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              maxLength: 10000,
              maxLines: 4,
              minLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Paste a URL here to analyze...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                contentPadding: EdgeInsets.all(20),
              ),
              onSubmitted: (_) {
                if (!_isScanning) {
                  _scanUrl();
                }
              },
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed:
                    _isScanning ? null : _scanUrl,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.security),
                label: Text(
                  _isScanning
                      ? 'Analyzing Content...'
                      : 'Analyze Content',
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            Text(
              'SafeScan checks against known threat databases and analyzes language patterns.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}