import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suga/services/interruption_service.dart';

const _item = {
  'id': 4,
  'title': 'Feeder maintenance',
  'description': 'Planned work',
  'affected_areas': ['Jaro, Iloilo City'],
  'date': '2026-10-12',
  'start_time': '09:00',
  'end_time': '12:00',
  'reason': 'Maintenance',
  'status': 'scheduled',
  'estimated_restoration': null,
};

InterruptionService _service(Future<http.Response> Function(http.Request) handler) =>
    InterruptionService(client: MockClient(handler), baseUrl: 'http://test');

void main() {
  test('fetchInterruptions converts the JSON into PowerInterruption objects', () async {
    late Uri requested;
    final service = _service((r) async {
      requested = r.url;
      return http.Response(jsonEncode({'success': true, 'count': 1, 'data': [_item]}), 200);
    });

    final list = await service.fetchInterruptions(areaId: 2);

    expect(requested.toString(), 'http://test/api/interruptions?area_id=2');
    expect(list, hasLength(1));
    expect(list.first.id, '4');
    expect(list.first.startTime, '09:00');
    expect(list.first.affectedAreas, ['Jaro, Iloilo City']);
    expect(list.first.estimatedRestorationTime, isNull);
  });

  test('fetchInterruption returns a single interruption', () async {
    final service = _service(
      (_) async => http.Response(jsonEncode({'success': true, 'data': _item}), 200),
    );
    expect((await service.fetchInterruption(4)).title, 'Feeder maintenance');
  });

  test('an error response becomes an ApiException with the server message', () async {
    final service = _service((_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'INTERRUPTION_NOT_FOUND', 'message': 'Interruption not found'},
          }),
          404,
        ));
    expect(
      service.fetchInterruption(999),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Interruption not found')),
    );
  });

  test('a failed network request becomes an ApiException', () async {
    final service = _service((_) async => throw http.ClientException('offline'));
    expect(service.fetchInterruptions(), throwsA(isA<ApiException>()));
  });

  test('a non-JSON response becomes an ApiException', () async {
    final service = _service((_) async => http.Response('<html>Bad gateway</html>', 502));
    expect(
      service.fetchInterruptions(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('502'))),
    );
  });
}
