import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suga/models/admin_session.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/services/session_storage.dart';
import 'package:suga/theme/app_theme.dart';

import 'support/fake_device.dart';

// End-to-end flows through the real screens and providers. Only the network is
// replaced: every request in these tests goes to [_FakeApi], through
// http.runWithClient, so screens that create their own services use it too.

final _soon = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 3)));

Map<String, dynamic> _area(int id, String name) => {
      'id': id,
      'name': name,
      'city': 'Iloilo City',
      'latitude': 10.72,
      'longitude': 122.56,
      'feeders': [
        {'id': id, 'name': '$name Feeder 1'},
      ],
    };

Map<String, dynamic> _advisory(int id, String title, int areaId, String areaName) => {
      'id': id,
      'title': title,
      'description': 'Line maintenance',
      'reason': 'Maintenance',
      'affected_areas': [areaName],
      'area_ids': [areaId],
      'feeders': ['$areaName Feeder 1'],
      'feeder_ids': [areaId],
      'date': _soon,
      'start_time': '09:00',
      'end_time': '14:00',
      'status': 'scheduled',
    };

class _FakeApi {
  bool areasDown = false;
  bool interruptionsDown = false;
  final areas = [_area(1, 'Jaro'), _area(2, 'Molo')];
  final advisories = [
    _advisory(1, 'Jaro Power Interruption', 1, 'Jaro'),
    _advisory(2, 'Molo Line Work', 2, 'Molo'),
  ];

  http.Response _ok(Object data) => http.Response(
        jsonEncode({'success': true, if (data is List) 'count': data.length, 'data': data}),
        200,
      );

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    // The weather service is not under test. Report it as down.
    if (request.url.host == 'api.open-meteo.com') return http.Response('{}', 500);
    if (path == '/api/auth/me') {
      return _ok({
        'admin': {'id': 1, 'email': 'admin@suga.ph', 'name': 'SUGA Admin'},
        'expires_at': '2099-01-01T00:00:00.000Z',
      });
    }
    if (path == '/api/areas') {
      if (areasDown) {
        return http.Response(
          jsonEncode({'success': false, 'error': {'code': 'INTERNAL_ERROR', 'message': 'Something went wrong'}}),
          500,
        );
      }
      return _ok(areas);
    }
    if (path.startsWith('/api/areas/')) {
      final id = int.parse(path.split('/').last);
      return _ok(areas.firstWhere((area) => area['id'] == id));
    }
    if (path == '/api/interruptions') {
      if (interruptionsDown) throw http.ClientException('no route to host');
      return _ok(advisories);
    }
    return http.Response(jsonEncode({'success': false, 'error': {'message': 'Not found'}}), 404);
  }
}

// The same provider tree as main.dart, with the device and session storage faked.
Widget _app(FakeDevice device, {AdminSession? admin}) => MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(storage: MemorySessionStorage(admin))..restoreSession(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PowerInterruptionProvider>(
          create: (_) => PowerInterruptionProvider(),
          update: (_, auth, interruptions) => interruptions!
            ..authToken = auth.token
            ..onUnauthorized = auth.handleUnauthorized,
        ),
        ChangeNotifierProxyProvider<PowerInterruptionProvider, NotificationProvider>(
          create: (_) => NotificationProvider(device: device)..load(),
          update: (_, advisories, notifications) => notifications!..updateFrom(advisories),
        ),
      ],
      child: MaterialApp(
        theme: buildSugaTheme(),
        initialRoute: AppRoutes.home,
        routes: AppRoutes.routes,
      ),
    );

// Pumps a few frames. pumpAndSettle is avoided because spinners never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

// Runs [body] with a tall screen, the fake API and the given saved preferences.
Future<void> _run(
  WidgetTester tester,
  _FakeApi api,
  Future<void> Function(FakeDevice device) body, {
  Map<String, Object> prefs = const {},
  AdminSession? admin,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Skips the bulb's endless glow animation.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final device = FakeDevice();
  await http.runWithClient(() async {
    await tester.pumpWidget(_app(device, admin: admin));
    await _settle(tester);
    await body(device);
    // Remove the app so providers cancel their timers.
    await tester.pumpWidget(const SizedBox.shrink());
  }, () => MockClient(api.handle));
}

const _savedJaro = <String, Object>{
  'areas.savedAreaIds': ['1'],
  'areas.mainAreaId': 1,
};

void main() {
  testWidgets('first launch asks for an area and every tab opens', (tester) async {
    await _run(tester, _FakeApi(), (_) async {
      expect(find.text('Pick your area'), findsOneWidget);
      expect(find.text('Choose area'), findsOneWidget);

      await _tap(tester, find.text('Scheduled'));
      expect(find.text('Scheduled brownouts'), findsOneWidget);

      await _tap(tester, find.text('Settings'));
      expect(find.text('Saved areas'), findsOneWidget);

      await _tap(tester, find.text('Home'));
      expect(find.text('Pick your area'), findsOneWidget);
    });
  });

  testWidgets('choosing an area on the Areas tab updates the Home dashboard', (tester) async {
    await _run(tester, _FakeApi(), (_) async {
      await _tap(tester, find.text('Choose area'));
      expect(find.text('Jaro'), findsOneWidget);
      expect(find.text('Molo'), findsOneWidget);

      await _tap(tester, find.text('Jaro'));
      expect(find.text('Set as home area'), findsOneWidget);

      await _tap(tester, find.text('Set as home area'));

      // Back on Home with the new area.
      expect(find.text('Jaro, Iloilo City'), findsOneWidget);
      expect(find.text('Power is on'), findsOneWidget);
      expect(find.text('Jaro Power Interruption'), findsOneWidget);
      expect(find.text('Molo Line Work'), findsNothing, reason: 'Home only lists the home area');
    });
  });

  testWidgets('a saved home area is restored on the next launch', (tester) async {
    await _run(tester, _FakeApi(), (_) async {
      expect(find.text('Pick your area'), findsNothing);
      expect(find.text('Jaro, Iloilo City'), findsOneWidget);
      expect(find.text('Jaro Power Interruption'), findsOneWidget);
    }, prefs: _savedJaro);
  });

  testWidgets('the Scheduled tab filters by saved areas and opens a brownout', (tester) async {
    await _run(tester, _FakeApi(), (_) async {
      await _tap(tester, find.text('Scheduled'));
      expect(find.text('Jaro Power Interruption'), findsOneWidget);
      expect(find.text('Molo Line Work'), findsNothing, reason: 'only saved areas at first');

      await _tap(tester, find.text('All areas'));
      expect(find.text('Molo Line Work'), findsOneWidget);

      await _tap(tester, find.text('Jaro Power Interruption'));
      expect(find.text('Notify Me Before Interruption'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
    }, prefs: _savedJaro);
  });

  testWidgets('a saved area gets a phone reminder scheduled', (tester) async {
    await _run(tester, _FakeApi(), (device) async {
      await tester.pump(const Duration(seconds: 1));
      expect(device.scheduled.map((s) => s.id), contains(1));
      expect(device.scheduled.map((s) => s.id), isNot(contains(2)), reason: 'Molo is not followed');
    }, prefs: _savedJaro);
  });

  testWidgets('the Areas tab shows an error and recovers when Retry is tapped', (tester) async {
    final api = _FakeApi()..areasDown = true;
    await _run(tester, api, (_) async {
      await _tap(tester, find.text('Areas'));
      expect(find.text("Couldn't load areas"), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);

      api.areasDown = false;
      await _tap(tester, find.text('Retry'));
      expect(find.text("Couldn't load areas"), findsNothing);
      expect(find.text('Jaro'), findsOneWidget);
    });
  });

  testWidgets('the Scheduled tab says offline and recovers when Retry is tapped', (tester) async {
    final api = _FakeApi()..interruptionsDown = true;
    await _run(tester, api, (_) async {
      await _tap(tester, find.text('Scheduled'));
      expect(find.text("You're offline"), findsOneWidget);

      api.interruptionsDown = false;
      await _tap(tester, find.text('Retry'));
      expect(find.text("You're offline"), findsNothing);
      expect(find.text('Jaro Power Interruption'), findsOneWidget);
    });
  });

  testWidgets('admin tools show only to a signed-in admin', (tester) async {
    await _run(tester, _FakeApi(), (_) async {
      await _tap(tester, find.text('Scheduled'));
      expect(find.text('+ Add'), findsNothing);
      expect(find.text('All advisories'), findsNothing);
    });

    final session = AdminSession(
      token: 'token',
      expiresAt: DateTime.utc(2099),
      admin: const Admin(id: 1, email: 'admin@suga.ph'),
    );
    await _run(tester, _FakeApi(), (_) async {
      await _tap(tester, find.text('Scheduled'));
      expect(find.text('+ Add'), findsOneWidget);
      expect(find.text('All advisories'), findsOneWidget);
    }, admin: session);
  });
}
