import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/threat_gauge.dart';

class UrlResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const UrlResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final prediction = result['prediction']?.toString() ?? 'Unknown';
    final probability = (result['probability'] as num?)?.toDouble() ?? 0.0;
    final url = result['url']?.toString() ?? '';
    final isMalicious = prediction.toLowerCase() == 'malicious';
    final statusColor = isMalicious ? AppColors.threatRed : AppColors.safeGreen;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('URL Scan Result'),
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
                isMalicious ? 'Malicious URL Detected' : 'No Threats Detected',
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
                    ? 'This link matches patterns commonly used in phishing, malware delivery, or fraudulent clone domains.'
                    : 'The destination domain shows no indicators of active phishing campaigns or malicious behavior.',
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

              // 4. Scanned URL Section with copy button
              const SectionHeader(title: 'Scanned URL'),
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
                      icon: Icons.link_rounded,
                      color: statusColor,
                      backgroundColor: statusColor.withValues(alpha: 0.12),
                      size: 40,
                      iconSize: 20,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        url,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy URL',
                      icon: const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 5. Action button
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Scan Another URL',
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
                'URLs can change behavior dynamically based on geolocation or user agent. Exercise caution before entering credentials.',
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
