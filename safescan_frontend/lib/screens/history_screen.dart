import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<_HistoryLoadResult> _loadHistory(String userId) async {
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('scan_history')
        .orderBy('createdAt', descending: true);

    try {
      return _HistoryLoadResult(
        snapshot: await query.get(const GetOptions(source: Source.server)),
        fromCache: false,
      );
    } on FirebaseException {
      return _HistoryLoadResult(
        snapshot: await query.get(const GetOptions(source: Source.cache)),
        fromCache: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: FutureBuilder<_HistoryLoadResult>(
        future: _loadHistory(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 52,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load scan history from Firebase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No server connection. Cached results are shown when available.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final loadResult = snapshot.data!;
          final documents = loadResult.snapshot.docs;
          if (documents.isEmpty) {
            return _EmptyHistory();
          }

          return Column(
            children: [
              if (loadResult.fromCache)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF7C4D00),
                  child: const Text(
                    'Offline mode: showing cached history. New scans will appear in Firebase when connection is restored.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  itemCount: documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _HistoryTile(data: documents[index].data());
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryLoadResult {
  final QuerySnapshot<Map<String, dynamic>> snapshot;
  final bool fromCache;

  const _HistoryLoadResult({required this.snapshot, required this.fromCache});
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _HistoryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['scanType']?.toString() ?? 'Scan';
    final input = data['inputValue']?.toString() ?? 'Unknown input';
    final prediction = data['prediction']?.toString() ?? 'Unknown';
    final percent = (data['probabilityPercent'] as num?)?.toDouble() ?? 0;
    final isMalicious = data['isMalicious'] == true;
    final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
    final color = isMalicious ? Colors.redAccent : Colors.greenAccent;

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.16),
          child: Icon(_iconFor(type), color: color),
        ),
        title: Text(
          input,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${type.toUpperCase()}  •  ${timestamp == null ? 'Just now' : _formatDate(timestamp)}',
        ),
        trailing: Text(
          '${percent.toStringAsFixed(1)}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailRow(label: 'Result', value: prediction),
                _DetailRow(
                  label: 'Status',
                  value: isMalicious ? 'Malicious' : 'Not malicious',
                ),
                _DetailRow(label: 'Input', value: input),
                if (data['result'] is Map)
                  _DetailRow(
                    label: 'Raw response',
                    value: data['result'].toString(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'apk':
        return Icons.android_rounded;
      case 'sms':
        return Icons.sms_rounded;
      case 'url':
        return Icons.link_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No scans yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your APK, SMS, and URL scan results will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
