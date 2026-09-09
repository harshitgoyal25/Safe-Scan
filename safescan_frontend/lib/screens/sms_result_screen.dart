import 'package:flutter/material.dart';

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

    final probabilityPercent = probability * 100;

    final statusColor = isMalicious ? Colors.red : Colors.green;

    final statusIcon = isMalicious
        ? Icons.warning_rounded
        : Icons.verified_rounded;
    final riskLabel = probability >= 0.75
        ? 'High threat likelihood'
        : probability >= 0.40
        ? 'Moderate threat likelihood'
        : 'Low threat likelihood';

    return Scaffold(
      appBar: AppBar(title: const Text('SMS Scan Result'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              Icon(statusIcon, size: 90, color: statusColor),

              const SizedBox(height: 18),

              Text(
                isMalicious ? 'Malicious SMS Detected' : 'No Threat Detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                isMalicious
                    ? 'This message shows characteristics associated '
                          'with potentially malicious or spam SMS.'
                    : 'No significant malicious characteristics were '
                          'detected in this message. Stay cautious with unknown senders.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),

              const SizedBox(height: 28),

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
                        '${probabilityPercent.toStringAsFixed(2)}%',
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

                      LinearProgressIndicator(
                        value: probability.clamp(0.0, 1.0),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Scanned message
              const Text(
                'Scanned Message',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    message,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Scan again
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text(
                    'Scan Another SMS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Automated machine-learning analysis. '
                'Results are not a guarantee of safety.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
