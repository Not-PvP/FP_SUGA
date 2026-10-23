import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suga/models/app_notification.dart';

// One alert on the Notifications screen: icon, title, badge, message, time and a link.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.isUnread,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isUnread;
  final VoidCallback onTap;

  static const _secondary = Color(0xFF9CA3AF);

  // Colour and icon for each kind of alert.
  static (Color, IconData) styleFor(NotificationKind kind) => switch (kind) {
        NotificationKind.restored => (const Color(0xFF34D399), Icons.bolt_rounded),
        NotificationKind.upcoming => (const Color(0xFFFFBF00), Icons.notifications_active_outlined),
        NotificationKind.ongoing => (const Color(0xFFF97316), Icons.power_off_outlined),
        NotificationKind.updated => (const Color(0xFF60A5FA), Icons.sync_rounded),
        NotificationKind.scheduled => (const Color(0xFF9CA3AF), Icons.calendar_today_outlined),
        NotificationKind.cancelled => (const Color(0xFFF87171), Icons.event_busy_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = styleFor(notification.kind);
    final time = DateFormat('h:mm a').format(notification.time.toLocal());

    return Semantics(
      button: true,
      label: '${isUnread ? 'Unread. ' : ''}${notification.title}. ${notification.area}${notification.message}',
      excludeSemantics: true,
      child: Material(
        color: isUnread ? const Color(0xFF161D28) : const Color(0xFF111720),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUnread ? color.withValues(alpha: 0.45) : const Color(0xFF292F38),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                notification.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Badge(text: notification.badge, color: color),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: notification.area,
                              style: TextStyle(
                                color: notification.kind == NotificationKind.upcoming
                                    ? color
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: notification.message),
                          ],
                        ),
                        style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12.5, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, color: _secondary, size: 14),
                          const SizedBox(width: 5),
                          Text(time, style: const TextStyle(color: _secondary, fontSize: 12)),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              '${notification.actionLabel} →',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color == _secondary ? const Color(0xFFD1D5DB) : color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
