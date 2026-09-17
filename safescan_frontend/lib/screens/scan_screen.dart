import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../services/scan_history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
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
        _errorMessage = 'Please select an APK file first.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.scanApk(_selectedApk!);

      if (!mounted) return;

      final result = ScanResult.fromJson(response);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
      unawaited(_saveHistory(response, result));
    } catch (e) {
      debugPrint('APK scan failed: $e');

      setState(() {
        _errorMessage = 'Scan failed. Please check network connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _saveHistory(
    Map<String, dynamic> response,
    ScanResult result,
  ) async {
    try {
      await ScanHistoryService().saveScan(
        scanType: 'apk',
        inputLabel: 'APK file',
        inputValue: result.filename.isEmpty ? _fileName : result.filename,
        result: response,
      );
    } catch (error, stackTrace) {
      debugPrint('APK history save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String get _fileName {
    if (_selectedApk == null) return '';

    return _selectedApk!.path.split(Platform.pathSeparator).last;
  }

  int get _fileSizeBytes {
    if (_selectedApk == null) return 0;
    try {
      return _selectedApk!.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  String get _formattedFileSize {
    final bytes = _fileSizeBytes;
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scan APK'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: StatusBadge(
              text: 'ENGINE v2.6',
              color: AppColors.lightTeal,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drop / Select Zone Card
              InkWell(
                onTap: _isScanning ? null : _selectApk,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedApk != null ? AppColors.lightTeal : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.tealContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryTeal.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.android_rounded,
                            size: 38,
                            color: AppColors.lightTeal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select an APK file to scan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'SafeScan performs static analysis and ML-based malware detection on Android packages.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Browse Files',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Selected APK File Card
              if (_selectedApk != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.tealBorder),
                  ),
                  child: Row(
                    children: [
                      const IconBox(
                        icon: Icons.insert_drive_file_rounded,
                        color: AppColors.lightTeal,
                        size: 40,
                        iconSize: 20,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (_formattedFileSize.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _formattedFileSize,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                        onPressed: _isScanning
                            ? null
                            : () => setState(() => _selectedApk = null),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.threatRedContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.threatRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.threatRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Scan Action Button
              ElevatedButton(
                onPressed: (_isScanning || _selectedApk == null) ? null : _scanApk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  disabledBackgroundColor: AppColors.surfaceSecondary,
                  disabledForegroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isScanning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Analyzing APK...',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Scan APK',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
