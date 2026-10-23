import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/admin_session.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/screens/scheduled_brownouts_screen.dart';
import 'package:suga/services/auth_service.dart';
import 'package:suga/services/interruption_service.dart';
import 'package:suga/services/session_storage.dart';

Widget _app(http.Response Function(http.Request) handler, {AdminSession? signedIn}) {
  final client = MockClient((r) async => handler(r));
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          service: AuthService(client: client, baseUrl: 'http://test'),
          storage: MemorySessionStorage(signedIn),
        )..restoreSession(),
      ),
      ChangeNotifierProvider(
        create: (_) => PowerInterruptionProvider(
          service: InterruptionService(client: client, baseUrl: 'http://test'),
        ),
      ),
    ],
    child: const MaterialApp(home: ScheduledBrownoutsScreen()),
  );
}

Map<String, dynamic> _advisory(int id, String title, String status) => {
      'id': id,
      'title': title,
      'affected_areas': ['Jaro, Iloilo City'],
      'area_ids': [3],
      'date': '2099-10-12',
      'start_time': '09:00',
      'end_time': '14:00',
      'status': status,
    };

http.Response _respond(http.Request r) {
  if (r.url.path == '/api/auth/me') {
    return http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'admin': {'id': 1, 'email': 'admin@suga.ph', 'name': ''},
          'expires_at': '2099-01-01T00:00:00.000Z',
        },
      }),
      200,
    );
  }
  return http.Response(
    jsonEncode({
      'success': true,
      'count': 2,
      'data': [
        _advisory(1, 'Jaro Power Interruption', 'scheduled'),
        _advisory(2, 'Molo Cancelled Work', 'cancelled'),
      ],
    }),
    200,
  );
}

void main() {
  testWidgets('Scheduled Brownouts lists interruptions from the provider', (tester) async {
    await tester.pumpWidget(_app((_) => http.Response(
          jsonEncode({
            'success': true,
            'count': 1,
            'data': [
              {
                'id': 1,
                'title': 'Jaro Power Interruption',
                'affected_areas': ['Jaro, Iloilo City'],
                'area_ids': [3],
                'date': '2026-10-12',
                'start_time': '09:00',
                'end_time': '14:00',
                'status': 'scheduled',
              },
            ],
          }),
          200,
        )));
    await tester.pumpAndSettle();

    expect(find.text('Jaro Power Interruption'), findsOneWidget);
    expect(find.textContaining('Jaro, Iloilo City'), findsOneWidget);
  });

  testWidgets('Scheduled Brownouts shows the error and a Retry button', (tester) async {
    await tester.pumpWidget(_app((_) => http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'INTERNAL_ERROR', 'message': 'Something went wrong'},
          }),
          500,
        )));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Normal users do not see the admin switch', (tester) async {
    await tester.pumpWidget(_app(_respond));
    await tester.pumpAndSettle();

    expect(find.text('All advisories'), findsNothing);
    expect(find.text('Molo Cancelled Work'), findsNothing, reason: 'cancelled ones are hidden from users');
  });

  testWidgets('A signed-in admin can switch to all advisories, including cancelled ones', (tester) async {
    final session = AdminSession(
      token: 'token',
      expiresAt: DateTime.utc(2099),
      admin: const Admin(id: 1, email: 'admin@suga.ph'),
    );
    await tester.pumpWidget(_app(_respond, signedIn: session));
    await tester.pumpAndSettle();

    expect(find.text('All advisories'), findsOneWidget);
    expect(find.text('Molo Cancelled Work'), findsNothing);

    await tester.tap(find.text('All advisories'));
    await tester.pumpAndSettle();

    expect(find.text('Molo Cancelled Work'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });
}
