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

              const Icon(
                Icons.android,
                size: 72,
              ),

              const SizedBox(height: 20),

              const Text(
                'Analyze an APK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'SafeScan performs static analysis and '
                'machine-learning based malware detection.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              OutlinedButton.icon(
                onPressed: _isScanning ? null : _selectApk,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select APK'),
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