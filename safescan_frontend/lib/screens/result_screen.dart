import 'package:flutter/material.dart';

import '../models/scan_result.dart';

class ResultScreen extends StatelessWidget {
  final ScanResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final bool isMalware = result.isMalware;

    final statusColor = isMalware ? Colors.red : Colors.green;

    final statusIcon = isMalware
        ? Icons.warning_rounded
        : Icons.verified_rounded;
    final riskLabel = result.probability >= 0.75
        ? 'High threat likelihood'
        : result.probability >= 0.40
        ? 'Moderate threat likelihood'
        : 'Low threat likelihood';

    return Scaffold(
      appBar: AppBar(title: const Text('APK Scan Result'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: result.probability.clamp(0.0, 1.0),
                      strokeWidth: 12,
                      backgroundColor: const Color(0xFF1A1A1A),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Icon(statusIcon, size: 60, color: statusColor),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                isMalware ? 'Malware Detected' : 'No Malware Detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                isMalware
                    ? 'The APK shows characteristics associated '
                          'with potentially malicious software.'
                    : 'No significant malicious characteristics were '
                          'detected in this APK. Stay cautious with unknown apps.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),

              const SizedBox(height: 20),

              // APK filename
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.android),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          result.filename,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Probability
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Threat likelihood',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        '${result.probabilityPercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        riskLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Technical information
              const Text(
                'Analysis Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Matched features',
                        value: result.matchedFeatures.toString(),
                      ),
                      _InfoRow(
                        label: 'Active model features',
                        value: result.activeFeatures.toString(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text(
                    'Scan Another APK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Automated static analysis using a machine-learning model. '
                'Results are not a guarantee of safety.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
