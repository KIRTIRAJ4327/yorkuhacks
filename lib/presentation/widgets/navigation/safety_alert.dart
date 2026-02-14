import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/alert_engine.dart';

/// Slide-down safety alert banner
class SafetyAlertBanner extends StatelessWidget {
  final SafetyAlert alert;
  final VoidCallback? onDismiss;

  const SafetyAlertBanner({
    super.key,
    required this.alert,
    this.onDismiss,
  });

  Color get _color {
    switch (alert.level) {
      case AlertLevel.info:
        return AppColors.brand;
      case AlertLevel.warning:
        return AppColors.alertAccent;
      case AlertLevel.danger:
        return AppColors.dangerAccent;
    }
  }

  IconData get _icon {
    switch (alert.level) {
      case AlertLevel.info:
        return Icons.info_outline;
      case AlertLevel.warning:
        return Icons.warning_amber;
      case AlertLevel.danger:
        return Icons.dangerous;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.message,
                  style: TextStyle(
                    color: _color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (alert.aiTip != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    alert.aiTip!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Got it',
                  style: TextStyle(
                    color: _color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
