import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ApiService _apiService = ApiService();

  File? _selectedApk;
  bool _isScanning = false;
  String? _errorMessage;

  Future<void> _selectApk() async {
    setState(() {
      _errorMessage = null;
    });

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (files.isEmpty) return;

    final path = files.first.path;

    if (path == null) {
      setState(() {
        _errorMessage = 'Could not access the selected APK.';
      });
      return;
    }

    setState(() {
      _selectedApk = File(path);
      _errorMessage = null;
    });
  }

  Future<void> _scanApk() async {
    if (_selectedApk == null) {
      setState(() {
        _errorMessage = 'Please select an APK first.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.scanApk(
        _selectedApk!,
      );

      if (!mounted) return;

      final result = ScanResult.fromJson(response);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Scan failed. Please try again.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isScanning = false;
      });
    }
  }

  String get _fileName {
    if (_selectedApk == null) return '';

    return _selectedApk!.path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan APK'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              InkWell(
                onTap: _isScanning ? null : _selectApk,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF0F766E).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.android_rounded,
                          size: 48,
                          color: Color(0xFF80D5CB),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Select an APK file to scan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SafeScan performs static analysis and machine-learning based malware detection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Browse Files', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_selectedApk != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            _fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _scanApk,
                  child: _isScanning
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Analyzing APK...'),
                          ],
                        )
                      : const Text('Scan APK'),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}