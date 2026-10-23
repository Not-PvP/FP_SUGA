import 'package:flutter/material.dart';

// Coloured pill for an advisory status: scheduled, ongoing, restored or cancelled.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  static Color colorFor(String status) => switch (status.toLowerCase()) {
        'scheduled' => const Color(0xFFFBBF24),
        'ongoing' => const Color(0xFFF97316),
        'restored' => const Color(0xFF34D399),
        'cancelled' || 'canceled' => const Color(0xFFF87171),
        _ => const Color(0xFF64748B),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        labelFor(status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
