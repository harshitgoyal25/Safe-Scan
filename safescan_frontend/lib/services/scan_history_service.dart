import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ScanHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveScan({
    required String scanType,
    required String inputLabel,
    required String inputValue,
    required Map<String, dynamic> result,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('Scan history not saved: no authenticated Firebase user.');
      return;
    }

    debugPrint('Saving scan history to users/${user.uid}/scan_history');

    final prediction = result['prediction']?.toString() ?? 'Unknown';
    final probability = (result['probability'] as num?)?.toDouble() ?? 0.0;
    final normalizedProbability = probability.clamp(0.0, 1.0).toDouble();

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('scan_history')
          .add({
            'scanType': scanType,
            'inputLabel': inputLabel,
            'inputValue': inputValue,
            'prediction': prediction,
            'probability': normalizedProbability,
            'probabilityPercent': normalizedProbability * 100,
            'isMalicious': prediction.toLowerCase() == 'malicious',
            'result': _sanitize(result),
            'createdAt': FieldValue.serverTimestamp(),
          });
      debugPrint('Scan history saved successfully for ${user.uid}.');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Scan history save failed for users/${user.uid}/scan_history: '
        '${error.code}: ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  dynamic _sanitize(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(key.toString(), _sanitize(nestedValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_sanitize).toList();
    }
    return value.toString();
  }
}
