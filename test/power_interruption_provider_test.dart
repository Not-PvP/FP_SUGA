import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/services/interruption_service.dart';

Map<String, dynamic> _json(int id, {String date = '2026-10-12', String start = '09:00', List<int> areaIds = const [3]}) => {
      'id': id,
      'title': 'Interruption $id',
      'description': '',
      'affected_areas': ['Area'],
      'area_ids': areaIds,
      'feeders': <String>[],
      'feeder_ids': <int>[],
      'date': date,
      'start_time': start,
      'end_time': '23:00',
      'reason': '',
      'status': 'scheduled',
      'estimated_restoration': null,
    };

http.Response _ok(Object data, [int status = 200]) => http.Response(
      jsonEncode({'success': true, if (data is List) 'count': data.length, 'data': data}),
      status,
    );

http.Response _error(int status, String message, [Map<String, String>? details]) => http.Response(
      jsonEncode({
        'success': false,
        'error': {'code': 'ERROR', 'message': message, 'details': ?details},
      }),
      status,
    );

PowerInterruptionProvider _provider(Future<http.Response> Function(http.Request) handler) =>
    PowerInterruptionProvider(
      service: InterruptionService(client: MockClient(handler), baseUrl: 'http://test'),
    );

final _new = PowerInterruption(
  id: '',
  title: 'New interruption',
  description: '',
  date: '2026-10-20',
  startTime: '08:00',
  endTime: '10:00',
  affectedAreas: const [],
  reason: '',
  status: '',
  areaIds: const [3],
);

void main() {
  test('loadInterruptions stores the list sorted by date and time, and tracks loading', () async {
    final provider = _provider((_) async => _ok([
          _json(2, date: '2026-10-14'),
          _json(1, date: '2026-10-12', start: '17:00'),
          _json(3, date: '2026-10-12', start: '09:00'),
        ]));
    final loadingStates = <bool>[];
    provider.addListener(() => loadingStates.add(provider.isLoading));

    await provider.loadInterruptions();

    expect(provider.interruptions.map((i) => i.id), ['3', '1', '2']);
    expect(provider.hasLoaded, isTrue);
    expect(provider.error, isNull);
    expect(loadingStates, [true, false]);
  });

  test('a failed load sets error and keeps the previous data', () async {
    var fail = false;
    final provider = _provider((_) async => fail ? _error(500, 'Something went wrong') : _ok([_json(1)]));
    await provider.loadInterruptions();

    fail = true;
    await provider.loadInterruptions();

    expect(provider.error, 'Something went wrong');
    expect(provider.isLoading, isFalse);
    expect(provider.interruptions, hasLength(1));
  });

  test('two loads at the same time send only one request', () async {
    var requests = 0;
    final provider = _provider((_) async {
      requests++;
      return _ok([_json(1)]);
    });
    await Future.wait([provider.loadInterruptions(), provider.loadInterruptions()]);
    expect(requests, 1);
  });

  test('setAreaFilter shows only the interruptions for that area', () async {
    final provider = _provider((_) async => _ok([
          _json(1, areaIds: [3]),
          _json(2, areaIds: [4]),
          _json(3, areaIds: [3, 4]),
        ]));
    await provider.loadInterruptions();

    provider.setAreaFilter(4);
    expect(provider.interruptions.map((i) => i.id), unorderedEquals(['2', '3']));
    expect(provider.allInterruptions, hasLength(3));

    provider.setAreaFilter(null);
    expect(provider.interruptions, hasLength(3));
    expect(provider.interruptionsForArea(3).map((i) => i.id), unorderedEquals(['1', '3']));
  });

  test('addInterruption POSTs snake_case JSON and adds the saved item', () async {
    late http.Request sent;
    final provider = _provider((r) async {
      if (r.method == 'GET') return _ok(<Object>[]);
      sent = r;
      return _ok(_json(9, date: '2026-10-20'), 201);
    });
    provider.authToken = 'secret';
    await provider.loadInterruptions();

    final saved = await provider.addInterruption(_new);

    expect(saved, isTrue);
    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/interruptions');
    expect(sent.headers['authorization'], 'Bearer secret');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['start_time'], '08:00');
    expect(body['area_ids'], [3]);
    expect(body.containsKey('id'), isFalse);
    expect(body.containsKey('status'), isFalse);
    expect(provider.interruptions.single.id, '9');
    expect(provider.isSaving, isFalse);
  });

  test('a rejected add sets actionError and fieldErrors and stores nothing', () async {
    final provider = _provider((r) async => r.method == 'GET'
        ? _ok(<Object>[])
        : _error(400, 'Invalid power interruption data', {'end_time': 'must be later than start_time'}));
    await provider.loadInterruptions();

    final saved = await provider.addInterruption(_new);

    expect(saved, isFalse);
    expect(provider.actionError, 'Invalid power interruption data');
    expect(provider.fieldErrors['end_time'], 'must be later than start_time');
    expect(provider.error, isNull, reason: 'a failed save must not put the list into an error state');
    expect(provider.interruptions, isEmpty);

    provider.clearActionError();
    expect(provider.actionError, isNull);
    expect(provider.fieldErrors, isEmpty);
  });

  test('updateInterruption PATCHes by id and replaces the item', () async {
    late http.Request sent;
    final provider = _provider((r) async {
      if (r.method == 'GET') return _ok([_json(1), _json(2)]);
      sent = r;
      return _ok({..._json(1), 'status': 'ongoing'});
    });
    await provider.loadInterruptions();

    final item = provider.findById('1')!;
    final saved = await provider.updateInterruption(item.copyWith(status: 'ongoing'));

    expect(saved, isTrue);
    expect(sent.method, 'PATCH');
    expect(sent.url.path, '/api/interruptions/1');
    expect(provider.findById('1')!.status, 'ongoing');
    expect(provider.interruptions, hasLength(2));
  });

  test('deleteInterruption removes the item only after the server confirms', () async {
    var deleteFails = true;
    final provider = _provider((r) async {
      if (r.method == 'GET') return _ok([_json(1), _json(2)]);
      return deleteFails ? _error(401, 'Your session has expired. Sign in again.') : http.Response('', 204);
    });
    ApiException? unauthorized;
    provider.onUnauthorized = (e) => unauthorized = e;
    await provider.loadInterruptions();

    expect(await provider.deleteInterruption('1'), isFalse);
    expect(provider.actionError, 'Your session has expired. Sign in again.');
    expect(unauthorized?.statusCode, 401, reason: 'a 401 must be reported so the app can sign out');
    expect(provider.interruptions, hasLength(2));

    deleteFails = false;
    expect(await provider.deleteInterruption('1'), isTrue);
    expect(provider.interruptions.map((i) => i.id), ['2']);
    expect(provider.actionError, isNull);
  });

  test('update and delete without a valid id fail without calling the API', () async {
    var requests = 0;
    final provider = _provider((_) async {
      requests++;
      return _ok(<Object>[]);
    });

    expect(await provider.updateInterruption(_new), isFalse);
    expect(await provider.deleteInterruption(''), isFalse);
    expect(provider.actionError, isNotNull);
    expect(requests, 0);
  });

  test('a request finishing after dispose does not throw', () async {
    final provider = _provider((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _ok([_json(1)]);
    });
    final load = provider.loadInterruptions();
    provider.dispose();
    await expectLater(load, completes);
  });
}
