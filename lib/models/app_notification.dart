import 'package:intl/intl.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/utils/advisory_time.dart';

enum NotificationKind { upcoming, ongoing, restored, updated, scheduled, cancelled }

// One entry on the Notifications screen, made from an advisory in a followed area.
class AppNotification {
  const AppNotification({
    required this.key,
    required this.kind,
    required this.advisory,
    required this.time,
    required this.title,
    required this.area,
    required this.message,
    required this.badge,
    required this.actionLabel,
  });

  // Stays the same until the advisory changes, so read/unread survives reloads.
  final String key;
  final NotificationKind kind;
  final PowerInterruption advisory;

  // When this happened (UTC): posted, updated, restored, or when the reminder was due.
  final DateTime time;
  final String title;

  // Shown in bold at the start of the message, e.g. "Jaro".
  final String area;
  final String message;
  final String badge;
  final String actionLabel;
}

// Builds the notification list from the advisories. Kept separate from the provider
// so it can be tested with a fixed clock.
class NotificationBuilder {
  // Older entries are dropped from the list.
  static const window = Duration(days: 7);

  static List<AppNotification> build({
    required Iterable<PowerInterruption> advisories,
    required Set<int> areaIds,
    required DateTime now,
    required Duration leadTime,
    Set<String> advisoryIds = const {},
    bool includeRestored = true,
  }) {
    final result = <AppNotification>[];
    for (final item in advisories) {
      // In a followed area, or the user tapped "Notify me" on this advisory.
      if (!item.areaIds.any(areaIds.contains) && !advisoryIds.contains(item.id)) continue;
      final entry = _entryFor(item, now: now, leadTime: leadTime);
      if (entry == null) continue;
      if (entry.kind == NotificationKind.restored && !includeRestored) continue;
      if (entry.time.isAfter(now) || now.difference(entry.time) > window) continue;
      result.add(entry);
    }
    result.sort((a, b) => b.time.compareTo(a.time));
    return result;
  }

  static AppNotification? _entryFor(
    PowerInterruption item, {
    required DateTime now,
    required Duration leadTime,
  }) {
    final start = advisoryStart(item);
    if (start == null) return null;
    final changed = item.updatedAt ?? item.createdAt ?? start;
    final posted = item.createdAt ?? changed;
    final area = _areaNames(item);
    final schedule = _schedule(item);
    final version = (item.updatedAt ?? item.createdAt)?.millisecondsSinceEpoch ?? 0;

    AppNotification make(
      NotificationKind kind, {
      required DateTime time,
      required String title,
      required String message,
      required String badge,
      required String actionLabel,
    }) =>
        AppNotification(
          key: '${item.id}:${kind.name}:$version',
          kind: kind,
          advisory: item,
          time: time.toUtc(),
          title: title,
          area: area,
          message: message,
          badge: badge,
          actionLabel: actionLabel,
        );

    switch (item.status.toLowerCase()) {
      case 'restored':
        return make(
          NotificationKind.restored,
          time: changed,
          title: 'Power Restored',
          message: ': power is back on after the $schedule interruption.',
          badge: 'Resolved',
          actionLabel: 'View details',
        );
      case 'ongoing':
        final until = item.estimatedRestorationTime;
        return make(
          NotificationKind.ongoing,
          time: changed,
          title: 'Brownout Ongoing',
          message: ': power is out now. Expected back by '
              '${_time(until != null && until.isNotEmpty ? until : item.endTime)}.',
          badge: 'Ongoing',
          actionLabel: 'Brownout details',
        );
      case 'cancelled':
      case 'canceled':
        return make(
          NotificationKind.cancelled,
          time: changed,
          title: 'Brownout Cancelled',
          message: ': the $schedule interruption will not push through.',
          badge: 'Cancelled',
          actionLabel: 'View advisory',
        );
    }

    // Scheduled: a reminder once the lead time is reached, otherwise the announcement.
    final remindAt = start.subtract(leadTime);
    final feederNote = item.feeders.isEmpty ? '' : ' ${_feeders(item.feeders)} affected.';
    if (!now.isBefore(remindAt) && now.isBefore(start)) {
      return make(
        NotificationKind.upcoming,
        time: remindAt.isAfter(changed) ? remindAt : changed,
        title: 'Upcoming Brownout',
        message: ': $schedule.$feederNote',
        badge: timeUntil(start, now),
        actionLabel: 'Brownout details',
      );
    }
    final edited = item.createdAt != null &&
        item.updatedAt != null &&
        item.updatedAt!.difference(item.createdAt!) > const Duration(minutes: 1);
    if (edited) {
      return make(
        NotificationKind.updated,
        time: changed,
        title: 'Advisory Updated',
        message: ': now $schedule.',
        badge: 'Schedule Change',
        actionLabel: 'View updated advisory',
      );
    }
    return make(
      NotificationKind.scheduled,
      time: posted,
      title: item.title.isEmpty ? 'Scheduled Brownout' : item.title,
      message: ': $schedule.${item.reason.isEmpty ? '' : ' ${item.reason}.'}',
      badge: 'Notice',
      actionLabel: 'Review schedule',
    );
  }

  // "Jaro, Iloilo City" -> "Jaro". Several areas are joined: "Jaro and Molo".
  static String _areaNames(PowerInterruption item) {
    final names = item.affectedAreas.map((a) => a.split(',').first.trim()).where((a) => a.isNotEmpty).toList();
    if (names.isEmpty) return 'Your area';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names.take(names.length - 1).join(', ')} and ${names.last}';
  }

  static String _feeders(List<String> feeders) =>
      feeders.length == 1 ? feeders.first : '${feeders.length} feeders';

  // "Oct 12, 9:00 AM – 2:00 PM"
  static String _schedule(PowerInterruption item) {
    final day = DateTime.tryParse(item.date);
    final date = day == null ? item.date : DateFormat('MMM d').format(day);
    return '$date, ${_time(item.startTime)} – ${_time(item.endTime)}';
  }

  static String _time(String hhmm) {
    try {
      return DateFormat('h:mm a').format(DateFormat('HH:mm').parseStrict(hhmm));
    } catch (_) {
      return hhmm;
    }
  }
}
