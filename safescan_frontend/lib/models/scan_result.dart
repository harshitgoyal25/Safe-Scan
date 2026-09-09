class ScanResult {
  final String filename;
  final String prediction;
  final double probability;
  final double threshold;
  final int matchedFeatures;
  final int activeFeatures;

  ScanResult({
    required this.filename,
    required this.prediction,
    required this.probability,
    required this.threshold,
    required this.matchedFeatures,
    required this.activeFeatures,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      filename: json['filename'] as String,
      prediction: json['prediction'] as String,
      probability: (json['probability'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
      matchedFeatures: json['matched_features'] as int,
      activeFeatures: json['active_features'] as int,
    );
  }

  bool get isMalware => prediction == 'Malware';

  double get probabilityPercent => probability * 100;
}