import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThreatCircleGauge extends StatelessWidget {
  final double score; // 0.0 to 1.0
  final bool isMalicious;
  final double size;

  const ThreatCircleGauge({
    super.key,
    required this.score,
    required this.isMalicious,
    this.size = 130,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isMalicious ? AppColors.threatRed : AppColors.safeGreen;
    final containerColor = isMalicious
        ? AppColors.threatRedContainer
        : AppColors.safeGreenContainer;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow / background circle
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: containerColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
            ),
            // Circular progress indicator
            SizedBox(
              width: size - 16,
              height: size - 16,
              child: CircularProgressIndicator(
                value: score.clamp(0.05, 1.0),
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            // Center icon
            Container(
              width: size - 44,
              height: size - 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceSecondary,
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  isMalicious
                      ? Icons.warning_amber_rounded
                      : Icons.verified_user_rounded,
                  color: statusColor,
                  size: size * 0.32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThreeSegmentProbabilityBar extends StatelessWidget {
  final double score; // 0.0 to 1.0
  final bool isMalicious;

  const ThreeSegmentProbabilityBar({
    super.key,
    required this.score,
    required this.isMalicious,
  });

  @override
  Widget build(BuildContext context) {
    // 3 segments: Low (0 - 0.33), Moderate (0.33 - 0.66), High (0.66 - 1.0)
    final clampedScore = score.clamp(0.0, 1.0);
    final statusColor = isMalicious ? AppColors.threatRed : AppColors.safeGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Threat likelihood',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isMalicious
                      ? AppColors.threatRedContainer
                      : AppColors.safeGreenContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${(clampedScore * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3 segments bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      color: clampedScore >= 0.01
                          ? (clampedScore < 0.35
                              ? AppColors.safeGreen
                              : (clampedScore < 0.7
                                  ? AppColors.warningAmber
                                  : AppColors.threatRed))
                          : AppColors.surfaceSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      color: clampedScore >= 0.35
                          ? (clampedScore < 0.7
                              ? AppColors.warningAmber
                              : AppColors.threatRed)
                          : AppColors.surfaceSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      color: clampedScore >= 0.7
                          ? AppColors.threatRed
                          : AppColors.surfaceSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Low',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Moderate',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'High',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
