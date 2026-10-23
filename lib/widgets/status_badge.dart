import 'package:flutter/material.dart';
import 'package:suga/theme/app_theme.dart';

// Coloured pill for an advisory status: scheduled, ongoing, restored or cancelled.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  // Amber is kept for the brand and buttons, so "scheduled" gets its own colour.
  static Color colorFor(String status) => switch (status.toLowerCase()) {
        'scheduled' => AppColors.planned,
        'ongoing' => AppColors.outage,
        'restored' => AppColors.powerOn,
        'cancelled' || 'canceled' => AppColors.textMuted,
        _ => AppColors.textMuted,
      };

  static String labelFor(String status) {
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        labelFor(status),
        style: TextStyle(
          fontFamily: AppText.font,
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
