import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/app_notification.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/widgets/notification_card.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  // MORE Power's 24/7 hotline, from morepower.com.ph.
  static const hotlineLabel = '(033) 526-6673';
  static const hotlineNumber = '0335266673';

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  static const amber = Color(0xFFFFBF00);
  static const background = Color(0xFF070A0F);
  static const cardColor = Color(0xFF111720);
  static const borderColor = Color(0xFF292F38);
  static const secondaryText = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final advisories = context.read<PowerInterruptionProvider>();
      if (!advisories.hasLoaded && !advisories.isLoading) advisories.loadInterruptions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from system settings: the user may have allowed notifications there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<NotificationProvider>().refreshPermission();
    }
  }

  void _open(AppNotification item) {
    context.read<NotificationProvider>().markRead(item);
    Navigator.pushNamed(context, AppRoutes.brownoutDetails, arguments: item.advisory);
  }

  Future<void> _callHotline() async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(Uri(scheme: 'tel', path: NotificationsScreen.hotlineNumber))
        .catchError((_) => false);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Call MORE Power at ${NotificationsScreen.hotlineLabel}.')),
      );
    }
  }

  // "Today", "Yesterday", or the weekday, with the date on the right.
  static (String, String) _dayLabel(DateTime day, DateTime today) {
    final date = DateFormat('MMM d, y').format(day);
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(day.year, day.month, day.day))
        .inDays;
    if (diff == 0) return ('TODAY', date);
    if (diff == 1) return ('YESTERDAY', date);
    return (DateFormat('EEEE').format(day).toUpperCase(), date);
  }

  Widget _buildHeader(NotificationProvider notifications) {
    final unread = notifications.unreadCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Material(
            color: cardColor,
            shape: const CircleBorder(side: BorderSide(color: borderColor)),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              tooltip: 'Back',
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Notifications',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF292315),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: amber.withValues(alpha: 0.6)),
              ),
              child: Text(
                '$unread New',
                style: const TextStyle(color: amber, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: unread > 0 ? notifications.markAllRead : null,
            style: TextButton.styleFrom(
              foregroundColor: secondaryText,
              disabledForegroundColor: const Color(0xFF4B5563),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Mark all read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Shown when the user wants phone alerts but the system blocks them,
  // or when this device cannot show them at all.
  Widget? _buildPermissionBanner(NotificationProvider notifications) {
    if (notifications.permission == NotificationPermission.unsupported) {
      return _banner(
        icon: Icons.info_outline_rounded,
        color: secondaryText,
        text: 'Phone alerts work in the Android app. This list still updates here.',
      );
    }
    if (!notifications.pushEnabled) {
      return _banner(
        icon: Icons.notifications_off_outlined,
        color: secondaryText,
        text: 'Phone alerts are off. You will only see alerts here.',
        action: 'Turn on',
        onAction: notifications.enableNotifications,
      );
    }
    if (notifications.isBlocked) {
      return _banner(
        icon: Icons.notifications_off_outlined,
        color: amber,
        text: 'Notifications are blocked for SUGA, so you will not get brownout reminders.',
        action: 'Allow',
        onAction: notifications.enableNotifications,
      );
    }
    return null;
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
    String? action,
    Future<void> Function()? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 12.5, height: 1.4)),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: amber),
              child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty({required IconData icon, required String title, required String body, Widget? action}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: amber, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: secondaryText, fontSize: 13, height: 1.4),
          ),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }

  List<Widget> _buildList(NotificationProvider notifications) {
    final advisories = context.read<PowerInterruptionProvider>();
    final items = notifications.notifications;

    if (!notifications.hasFollowedAreas) {
      return [
        _buildEmpty(
          icon: Icons.location_searching_rounded,
          title: 'Follow an area to get alerts',
          body: 'Save your area and SUGA will remind you before each scheduled brownout there.',
          action: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.areas),
            style: OutlinedButton.styleFrom(
              foregroundColor: amber,
              side: BorderSide(color: amber.withValues(alpha: 0.5)),
            ),
            child: const Text('Browse areas'),
          ),
        ),
      ];
    }
    if (items.isEmpty && notifications.loadError != null) {
      return [
        _buildEmpty(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load alerts',
          body: notifications.loadError!,
          action: OutlinedButton(
            onPressed: advisories.loadInterruptions,
            child: const Text('Retry'),
          ),
        ),
      ];
    }
    if (items.isEmpty && !notifications.advisoriesLoaded) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator(color: amber)),
        ),
      ];
    }
    if (items.isEmpty) {
      return [
        _buildEmpty(
          icon: Icons.notifications_none_rounded,
          title: "You're all caught up",
          body: 'No brownout alerts for your areas in the last 7 days.',
        ),
      ];
    }

    final today = DateTime.now();
    final widgets = <Widget>[];
    String? currentDay;
    for (final item in items) {
      final local = item.time.toLocal();
      final dayKey = DateFormat('yyyy-MM-dd').format(local);
      if (dayKey != currentDay) {
        currentDay = dayKey;
        final (label, date) = _dayLabel(local, today);
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 4 : 18, bottom: 10),
          child: Row(
            children: [
              if (label == 'TODAY') ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: amber, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(date, style: const TextStyle(color: secondaryText, fontSize: 12)),
            ],
          ),
        ));
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NotificationCard(
          notification: item,
          isUnread: notifications.isUnread(item),
          onTap: () => _open(item),
        ),
      ));
    }
    return widgets;
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          'Showing alerts from the last 7 days · MORE Power',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7A90), fontSize: 11),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.call_outlined, color: Color(0xFF34D399), size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'MORE Hotline: ${NotificationsScreen.hotlineLabel}',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              TextButton(
                onPressed: _callHotline,
                style: TextButton.styleFrom(foregroundColor: amber),
                child: const Text(
                  'REPORT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();
    final banner = _buildPermissionBanner(notifications);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(notifications),
            Expanded(
              child: RefreshIndicator(
                color: amber,
                onRefresh: context.read<PowerInterruptionProvider>().loadInterruptions,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    ?banner,
                    ..._buildList(notifications),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
