import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/services/interruption_service.dart';
import 'package:suga/services/notification_service.dart';

import 'support/fake_device.dart';

// 2026-10-12 06:00 in Manila.
final _now = DateTime.utc(2026, 10, 11, 22);

Map<String, dynamic> _json(int id, {String date = '2026-10-12', String start = '09:00', String status = 'scheduled', int area = 3}) => {
      'id': id,
      'title': 'Advisory $id',
      'affected_areas': ['Jaro, Iloilo City'],
      'area_ids': [area],
      'date': date,
      'start_time': start,
      'end_time': '14:00',
      'status': status,
      'created_at': '2026-10-10 02:00:00',
      'updated_at': status == 'scheduled' ? '2026-10-10 02:00:00' : '2026-10-11 21:00:00',
    };

Future<(NotificationProvider, PowerInterruptionProvider)> _setUp(
  List<Map<String, dynamic>> Function() data, {
  FakeDevice? device,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final advisories = PowerInterruptionProvider(
    service: InterruptionService(
      client: MockClient((_) async => http.Response(
            jsonEncode({'success': true, 'count': data().length, 'data': data()}),
            200,
          )),
      baseUrl: 'http://test',
    ),
  );
  final notifications = NotificationProvider(device: device ?? FakeDevice(), now: () => _now);
  addTearDown(notifications.dispose);
  advisories.addListener(() => notifications.updateFrom(advisories));
  await notifications.load();
  return (notifications, advisories);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lists alerts only for followed areas', () async {
    final (notifications, advisories) = await _setUp(() => [_json(1), _json(2, area: 5)]);

    await advisories.loadInterruptions();
    expect(notifications.hasFollowedAreas, isFalse);
    expect(notifications.notifications, isEmpty);

    advisories.setAreaFilter(3);
    expect(notifications.notifications.map((n) => n.advisory.id), ['1']);
  });

  test('schedules a phone reminder lead time before each followed brownout', () async {
    final device = FakeDevice();
    final (notifications, advisories) = await _setUp(
      () => [_json(1), _json(2, date: '2026-10-13'), _json(3, status: 'cancelled')],
      device: device,
    );
    advisories.setAreaFilter(3);
    await advisories.loadInterruptions();

    await notifications.reschedule();

    expect(device.scheduled.map((s) => s.id), [1, 2], reason: 'cancelled ones get no reminder');
    // 09:00 Manila minus 2 hours = 07:00 Manila = 23:00 UTC.
    expect(device.scheduled.first.when.toUtc(), DateTime.utc(2026, 10, 11, 23));
    expect(device.scheduled.first.title, 'Brownout in 2 hours');

    await notifications.setLeadMinutes(10);
    expect(device.scheduled.first.when.toUtc(), DateTime.utc(2026, 10, 12, 0, 50));
  });

  test('turning push notifications off cancels the reminders and is saved', () async {
    final device = FakeDevice();
    final (notifications, advisories) = await _setUp(() => [_json(1)], device: device);
    advisories.setAreaFilter(3);
    await advisories.loadInterruptions();
    await notifications.reschedule();
    expect(device.scheduled, hasLength(1));

    await notifications.setPushEnabled(false);

    expect(device.scheduled, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notifications.pushEnabled'), isFalse);
  });

  test('mark read and mark all read update the unread count and are saved', () async {
    final (notifications, advisories) = await _setUp(() => [
          _json(1, status: 'restored'),
          _json(2, status: 'ongoing'),
        ]);
    advisories.setAreaFilter(3);
    await advisories.loadInterruptions();
    expect(notifications.unreadCount, 2);

    notifications.markRead(notifications.notifications.first);
    expect(notifications.unreadCount, 1);

    notifications.markAllRead();
    expect(notifications.unreadCount, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('notifications.read'), hasLength(2));
  });

  test('asks for permission once, when the first area is followed', () async {
    final device = FakeDevice(permission: NotificationPermission.denied, grantOnRequest: false);
    final (notifications, advisories) = await _setUp(() => [_json(1)], device: device);

    await advisories.loadInterruptions();
    expect(device.permissionRequests, 0, reason: 'no area yet, so no prompt');

    advisories.setAreaFilter(3);
    await pumpEventQueue();
    expect(device.permissionRequests, 1);
    expect(notifications.isBlocked, isTrue);

    advisories.setAreaFilter(4);
    await pumpEventQueue();
    expect(device.permissionRequests, 1, reason: 'the prompt is only shown once');

    // "Allow" on the banner: the system no longer prompts, so open settings.
    await notifications.enableNotifications();
    expect(device.settingsOpened, 1);
  });

  test('shows a Power restored phone alert when a followed advisory is restored', () async {
    var status = 'ongoing';
    final device = FakeDevice();
    final (_, advisories) = await _setUp(() => [_json(1, status: status)], device: device);
    advisories.setAreaFilter(3);
    await advisories.loadInterruptions();
    expect(device.shown, isEmpty, reason: 'not on the first load');

    status = 'restored';
    await advisories.loadInterruptions();

    expect(device.shown, ['Power restored']);
  });

  test('remembers followed areas, so a restart does not cancel reminders', () async {
    final device = FakeDevice();
    final (notifications, advisories) = await _setUp(
      () => [_json(1)],
      device: device,
      prefs: {'notifications.areaIds': ['3']},
    );

    await advisories.loadInterruptions();
    await notifications.reschedule();

    expect(notifications.hasFollowedAreas, isTrue);
    expect(device.scheduled.map((s) => s.id), [1]);
  });

  test('remindMe adds an advisory outside the followed areas', () async {
    final device = FakeDevice();
    final (notifications, advisories) = await _setUp(() => [_json(7, area: 5)], device: device);
    await advisories.loadInterruptions();
    final item = advisories.findById('7')!;
    expect(notifications.hasReminder(item), isFalse);

    expect(await notifications.remindMe(item), isTrue);

    expect(notifications.hasReminder(item), isTrue);
    expect(device.scheduled.map((s) => s.id), [7]);
    expect(notifications.notifications, hasLength(1));
  });
}
