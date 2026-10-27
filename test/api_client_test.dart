import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suga/models/area.dart';
import 'package:suga/services/api_client.dart';

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(client: MockClient(handler), baseUrl: 'http://test');

Matcher _failsWith(ApiErrorKind kind) =>
    throwsA(isA<ApiException>().having((e) => e.kind, 'kind', kind));

void main() {
  group('failures are classified for the UI', () {
    test('no connection is offline', () async {
      final api = _api((_) async => throw http.ClientException('no route'));
      await expectLater(api.get('/api/areas'), _failsWith(ApiErrorKind.offline));
    });

    test('a slow server is a timeout', () async {
      final api = _api((_) async => throw TimeoutException('slow'));
      await expectLater(api.get('/api/areas'), _failsWith(ApiErrorKind.timeout));
    });

    test('a 5xx without a message gets a friendly server message', () async {
      final api = _api((_) async => http.Response(jsonEncode({'success': false}), 503));
      await expectLater(
        api.get('/api/areas'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.server)
            .having((e) => e.message, 'message', contains('Try again'))),
      );
    });

    test('a reply that is not JSON is a bad response', () async {
      final api = _api((_) async => http.Response('<html>Bad gateway</html>', 502));
      await expectLater(api.get('/api/areas'), _failsWith(ApiErrorKind.badResponse));
    });

    test('a validation error keeps its message and is not a connection problem', () async {
      final api = _api((_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'VALIDATION_ERROR', 'message': 'Title is required'},
            }),
            400,
          ));
      await expectLater(
        api.get('/api/areas'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.other)
            .having((e) => e.isConnectionProblem, 'isConnectionProblem', isFalse)
            .having((e) => e.message, 'message', 'Title is required')),
      );
    });
  });

  group('parsing the data list', () {
    Map<String, dynamic> area(Object? id) =>
        {'id': id, 'name': 'Jaro', 'city': 'Iloilo City', 'latitude': 10.7, 'longitude': 122.5};

    test('skips a record the app cannot read and keeps the rest', () {
      final areas = ApiClient.parseList(
        {'data': [area(1), {'name': 'No id'}, area(3)]},
        Area.fromJson,
      );
      expect(areas.map((a) => a.id), [1, 3]);
    });

    test('an empty list is fine', () {
      expect(ApiClient.parseList({'data': <dynamic>[]}, Area.fromJson), isEmpty);
    });

    test('a reply without a list is a bad response', () {
      expect(
        () => ApiClient.parseList({'data': null}, Area.fromJson),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badResponse)),
      );
    });

    test('a single record the app cannot read is a bad response', () {
      expect(
        () => ApiClient.parseOne({'data': {'name': 'No id'}}, Area.fromJson),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badResponse)),
      );
    });
  });

  test('friendlyError never shows a raw exception', () {
    expect(friendlyError(const ApiException('Could not reach the server.')), 'Could not reach the server.');
    expect(friendlyError(StateError('unexpected')), 'Something went wrong. Please try again.');
  });
}
