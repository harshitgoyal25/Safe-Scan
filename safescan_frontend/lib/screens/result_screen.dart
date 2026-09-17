import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/threat_gauge.dart';

class ResultScreen extends StatelessWidget {
  final ScanResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final bool isMalware = result.isMalware;
    final statusColor = isMalware ? AppColors.threatRed : AppColors.safeGreen;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('APK Scan Result'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Circular Threat Indicator
              ThreatCircleGauge(
                score: result.probability,
                isMalicious: isMalware,
                size: 130,
              ),
              const SizedBox(height: 20),

              // 2. Headline & Subtitle
              Text(
                isMalware ? 'Malware Detected' : 'No Threats Detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMalware
                    ? 'The APK exhibits behavioral patterns characteristic of malicious or unauthorized Android packages.'
                    : 'Static analysis found no known malicious signatures in this application package.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // 3. 3-Segment Probability Gauge
              ThreeSegmentProbabilityBar(
                score: result.probability,
                isMalicious: isMalware,
              ),
              const SizedBox(height: 16),

              // 4. File Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconBox(
                      icon: Icons.android_rounded,
                      color: statusColor,
                      backgroundColor: statusColor.withValues(alpha: 0.12),
                      size: 42,
                      iconSize: 22,
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SCANNED PACKAGE',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.filename.isNotEmpty ? result.filename : 'Unknown Package',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
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
              const SizedBox(height: 20),

              // 5. Analysis Details Section
              const SectionHeader(title: 'Analysis Details'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Matched Features',
                      value: result.matchedFeatures.toString(),
                      isHighlight: result.matchedFeatures > 0,
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _DetailRow(
                      label: 'Active Model Features',
                      value: result.activeFeatures.toString(),
                      isHighlight: false,
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _DetailRow(
                      label: 'Classification Engine',
                      value: 'SafeScan Heuristic ML v2.6',
                      isHighlight: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 6. Action Button
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Scan Another APK',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),

              // Footnote disclaimer
              const Text(
                'Static heuristic and ML analysis cannot guarantee absolute safety. Always verify application sources before installing.',
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? AppColors.warningAmber : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
