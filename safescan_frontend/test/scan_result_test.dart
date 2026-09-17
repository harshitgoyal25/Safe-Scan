import 'package:flutter_test/flutter_test.dart';
import 'package:safescan_frontend/models/scan_result.dart';

void main() {
  test('recognizes both backend malware labels', () {
    final base = <String, dynamic>{
      'filename': 'sample.apk',
      'probability': 0.9,
      'threshold': 0.52,
      'matched_features': 4,
      'active_features': 2,
    };

    expect(
      ScanResult.fromJson({...base, 'prediction': 'Malware'}).isMalware,
      isTrue,
    );
    expect(
      ScanResult.fromJson({...base, 'prediction': 'Malicious'}).isMalware,
      isTrue,
    );
    expect(
      ScanResult.fromJson({...base, 'prediction': 'Benign'}).isMalware,
      isFalse,
    );
  });
}
