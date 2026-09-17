import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/threat_gauge.dart';

class SmsResultScreen extends StatelessWidget {
  final String message;
  final Map<String, dynamic> result;

  const SmsResultScreen({
    super.key,
    required this.message,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final prediction = result['prediction']?.toString() ?? 'Unknown';
    final probability = (result['probability'] as num?)?.toDouble() ?? 0.0;
    final isMalicious = prediction.toLowerCase() == 'malicious';
    final statusColor = isMalicious ? AppColors.threatRed : AppColors.safeGreen;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SMS Scan Result'),
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
                score: probability,
                isMalicious: isMalicious,
                size: 130,
              ),
              const SizedBox(height: 20),

              // 2. Headline
              Text(
                isMalicious ? 'Malicious SMS Detected' : 'No Threats Detected',
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
                isMalicious
                    ? 'This SMS exhibits linguistic characteristics frequently associated with phishing campaigns, spoofing, or fraudulent lures.'
                    : 'No malicious phrasing, social engineering, or high-risk URL patterns were found in this SMS.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // 3. 3-Segment Probability Bar
              ThreeSegmentProbabilityBar(
                score: probability,
                isMalicious: isMalicious,
              ),
              const SizedBox(height: 20),

              // 4. Scanned Message Preview Section
              const SectionHeader(title: 'Scanned Message'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 5. Action button
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Scan Another SMS',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Natural language processing and threat telemetry cannot replace human caution. Verify sender identities directly.',
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
