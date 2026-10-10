import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suga/screens/areas_screen.dart';
import 'package:suga/services/area_service.dart';

AreaService _service(http.Response Function(http.Request) handler) =>
    AreaService(client: MockClient((r) async => handler(r)), baseUrl: 'http://test');

void main() {
  testWidgets('Areas screen lists areas from the API', (tester) async {
    final service = _service((_) => http.Response(
          jsonEncode({
            'success': true,
            'count': 1,
            'data': [
              {'id': 1, 'name': 'Jaro', 'city': 'Iloilo City', 'latitude': 10.72, 'longitude': 122.56},
            ],
          }),
          200,
        ));

    await tester.pumpWidget(MaterialApp(home: AreasScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Jaro'), findsOneWidget);
    expect(find.text('Iloilo City'), findsOneWidget);
  });

  testWidgets('Areas screen shows an error when the API fails', (tester) async {
    final service = _service((_) => http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'INTERNAL_ERROR', 'message': 'Something went wrong'},
          }),
          500,
        ));

    await tester.pumpWidget(MaterialApp(home: AreasScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
