import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/screens/scheduled_brownouts_screen.dart';
import 'package:suga/services/interruption_service.dart';

Widget _app(http.Response Function(http.Request) handler) {
  final service = InterruptionService(client: MockClient((r) async => handler(r)), baseUrl: 'http://test');
  return ChangeNotifierProvider(
    create: (_) => PowerInterruptionProvider(service: service),
    child: const MaterialApp(home: ScheduledBrownoutsScreen()),
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
}
