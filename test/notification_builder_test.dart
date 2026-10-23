import 'package:flutter_test/flutter_test.dart';
import 'package:suga/models/app_notification.dart';
import 'package:suga/models/power_interruption.dart';

// 2026-10-12 08:00 in Manila (UTC+8).
final _now = DateTime.utc(2026, 10, 12, 0);

PowerInterruption _advisory({
  String id = '1',
  String date = '2026-10-12',
  String start = '09:00',
  String end = '14:00',
  String status = 'scheduled',
  List<int> areaIds = const [3],
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
    PowerInterruption(
      id: id,
      title: 'Jaro Power Interruption',
      description: '',
      date: date,
      startTime: start,
      endTime: end,
      affectedAreas: const ['Jaro, Iloilo City'],
      reason: 'Line maintenance',
      status: status,
      areaIds: areaIds,
      feeders: const ['Jaro Feeder 1', 'Jaro Feeder 2'],
      createdAt: createdAt ?? DateTime.utc(2026, 10, 10, 2),
      updatedAt: updatedAt ?? DateTime.utc(2026, 10, 10, 2),
    );

List<AppNotification> _build(List<PowerInterruption> items, {Set<int> areas = const {3}, Duration lead = const Duration(hours: 2)}) =>
    NotificationBuilder.build(advisories: items, areaIds: areas, now: _now, leadTime: lead);

void main() {
  test('a brownout inside the lead time becomes an Upcoming Brownout with a countdown', () {
    final list = _build([_advisory()]);

    expect(list, hasLength(1));
    final item = list.single;
    expect(item.kind, NotificationKind.upcoming);
    expect(item.title, 'Upcoming Brownout');
    expect(item.area, 'Jaro');
    expect(item.badge, 'In 1 hr');
    expect(item.message, contains('Oct 12, 9:00 AM – 2:00 PM'));
    expect(item.message, contains('2 feeders affected'));
    // Shown from when the reminder was due: 07:00 Manila = 23:00 UTC the day before.
    expect(item.time, DateTime.utc(2026, 10, 11, 23));
  });

  test('a brownout further away shows as the posted notice, not a reminder', () {
    final item = _build([_advisory(date: '2026-10-14')]).single;

    expect(item.kind, NotificationKind.scheduled);
    expect(item.badge, 'Notice');
    expect(item.time, DateTime.utc(2026, 10, 10, 2));
  });

  test('an edited advisory shows as Advisory Updated', () {
    final item = _build([
      _advisory(date: '2026-10-14', updatedAt: DateTime.utc(2026, 10, 11, 9)),
    ]).single;

    expect(item.kind, NotificationKind.updated);
    expect(item.message, contains('now Oct 14'));
  });

  test('restored, ongoing and cancelled advisories get their own alerts', () {
    final list = _build([
      _advisory(id: '1', status: 'restored', updatedAt: DateTime.utc(2026, 10, 11, 8)),
      _advisory(id: '2', status: 'ongoing', updatedAt: DateTime.utc(2026, 10, 11, 7)),
      _advisory(id: '3', status: 'cancelled', updatedAt: DateTime.utc(2026, 10, 11, 6)),
    ]);

    expect(list.map((n) => n.kind), [
      NotificationKind.restored,
      NotificationKind.ongoing,
      NotificationKind.cancelled,
    ], reason: 'newest first');
    expect(list.first.badge, 'Resolved');
  });

  test('includeRestored: false hides Power Restored alerts', () {
    final list = NotificationBuilder.build(
      advisories: [_advisory(status: 'restored', updatedAt: DateTime.utc(2026, 10, 11))],
      areaIds: {3},
      now: _now,
      leadTime: const Duration(hours: 2),
      includeRestored: false,
    );
    expect(list, isEmpty);
  });

  test('only followed areas, or advisories with a reminder, are included', () {
    final other = _advisory(id: '9', areaIds: const [5]);

    expect(_build([other]), isEmpty);
    expect(
      NotificationBuilder.build(
        advisories: [other],
        areaIds: {3},
        advisoryIds: {'9'},
        now: _now,
        leadTime: const Duration(hours: 2),
      ),
      hasLength(1),
    );
  });

  test('alerts older than 7 days, or not due yet, are left out', () {
    final old = _advisory(
      date: '2026-10-01',
      status: 'restored',
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    final future = _advisory(date: '2026-10-20', createdAt: DateTime.utc(2026, 10, 13), updatedAt: DateTime.utc(2026, 10, 13));

    expect(_build([old, future]), isEmpty);
  });

  test('the key changes when the advisory is edited, so it shows as unread again', () {
    final before = _build([_advisory(date: '2026-10-14')]).single.key;
    final after = _build([_advisory(date: '2026-10-14', updatedAt: DateTime.utc(2026, 10, 11, 9))]).single.key;

    expect(after, isNot(before));
  });

  test('PowerInterruption reads the API timestamps as UTC', () {
    final item = PowerInterruption.fromJson({
      'id': 1,
      'date': '2026-10-12',
      'start_time': '09:00',
      'end_time': '14:00',
      'created_at': '2026-10-09 13:41:03',
      'updated_at': '2026-10-10 01:00:00',
    });

    expect(item.createdAt, DateTime.utc(2026, 10, 9, 13, 41, 3));
    expect(item.updatedAt!.isUtc, isTrue);
  });
}
