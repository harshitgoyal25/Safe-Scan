import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Malicious',
    'Safe',
    'APK',
    'URL',
    'SMS',
  ];

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

  bool _matchesFilter(Map<String, dynamic> data) {
    if (_selectedFilter == 'All') return true;

    final isMalicious = data['isMalicious'] == true;
    final type = (data['scanType']?.toString() ?? '').toLowerCase();

    if (_selectedFilter == 'Malicious') return isMalicious;
    if (_selectedFilter == 'Safe') return !isMalicious;
    if (_selectedFilter == 'APK') return type == 'apk';
    if (_selectedFilter == 'URL') return type == 'url';
    if (_selectedFilter == 'SMS') return type == 'sms';

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Please sign in again.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.history_rounded, size: 20, color: AppColors.lightTeal),
            SizedBox(width: 8),
            Text('Scan History'),
          ],
        ),
        centerTitle: true,
      ),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.threatRedContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.threatRed.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        size: 40,
                        color: AppColors.threatRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not load scan history from Firebase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your internet connection and try again.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.lightTeal),
              ),
            );
          }

          final loadResult = snapshot.data!;
          final allDocuments = loadResult.snapshot.docs;

          if (allDocuments.isEmpty) {
            return const _EmptyHistory();
          }

          final filteredDocs = allDocuments.where((doc) => _matchesFilter(doc.data())).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Offline Notice
              if (loadResult.fromCache)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.warningAmberContainer,
                  child: Row(
                    children: const [
                      Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.warningAmber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline mode: showing locally cached telemetry logs.',
                          style: TextStyle(
                            color: AppColors.warningAmber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Filter pills row
              Container(
                height: 48,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = filter == _selectedFilter;

                    return Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryTeal : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.lightTeal : AppColors.border,
                            ),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // List of history items
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No scans found for filter "$_selectedFilter"',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _HistoryCard(data: filteredDocs[index].data());
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

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _HistoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['scanType']?.toString() ?? 'Scan';
    final input = data['inputValue']?.toString() ?? 'Unknown input';
    final prediction = data['prediction']?.toString() ?? 'Unknown';
    final percent = (data['probabilityPercent'] as num?)?.toDouble() ?? 0;
    final isMalicious = data['isMalicious'] == true;
    final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
    final statusColor = isMalicious ? AppColors.threatRed : AppColors.safeGreen;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: IconBox(
            icon: _iconFor(type),
            color: statusColor,
            backgroundColor: statusColor.withValues(alpha: 0.12),
            size: 40,
            iconSize: 20,
            borderRadius: 10,
          ),
          title: Text(
            input,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${type.toUpperCase()} • ${timestamp == null ? 'Just now' : _formatDate(timestamp)}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 10),
                  _DetailRow(label: 'Result', value: prediction),
                  _DetailRow(
                    label: 'Classification',
                    value: isMalicious ? 'Threat / Malicious' : 'Safe / Benign',
                    valueColor: statusColor,
                  ),
                  _DetailRow(label: 'Scanned Input', value: input),
                  if (data['result'] is Map) ...[
                    const SizedBox(height: 4),
                    _DetailRow(
                      label: 'Raw Telemetry',
                      value: data['result'].toString(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${monthNames[local.month - 1]} ${local.day}, $hour:$minute';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.tealContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.4)),
              ),
              child: const Center(
                child: Icon(
                  Icons.history_rounded,
                  size: 32,
                  color: AppColors.lightTeal,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Telemetry Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your APK, SMS, and URL scan results will appear here as they are processed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
