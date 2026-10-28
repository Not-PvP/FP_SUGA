import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Why a request failed, so screens can show the right icon, title and advice.
enum ApiErrorKind {
  // The phone has no connection or the server could not be reached.
  offline,

  // The server did not answer in time.
  timeout,

  // The server answered with a 5xx error.
  server,

  // The server answered, but the reply could not be read.
  badResponse,

  // Any other error response, e.g. validation (400) or sign-in (401).
  other,
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.details = const {},
    this.kind = ApiErrorKind.other,
  });

  final String message;

  final ApiErrorKind kind;

  // True when the problem is the connection, so trying again later may work.
  bool get isConnectionProblem =>
      kind == ApiErrorKind.offline || kind == ApiErrorKind.timeout;

  // HTTP status of the error response, or null when the server could not be reached.
  final int? statusCode;

  // The API's error code, e.g. 'SESSION_EXPIRED' or 'INVALID_CREDENTIALS'.
  final String? code;

  // 401: not signed in, wrong password, or the session ended. The admin has to sign in again.
  bool get isUnauthorized => statusCode == 401;

  // Per-field validation messages from the API, e.g. {'end_time': 'must be later than start_time'}.
  final Map<String, String> details;

  @override
  String toString() => message;
}

// Shared HTTP helper: unwraps the { success, data } envelope and turns every failure
// (network, bad JSON, error response) into an ApiException with a readable message.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl;

  final http.Client _client;
  final String baseUrl;

  // The signed-in admin's session token, sent as "Authorization: Bearer <token>".
  // AuthProvider sets it after login and clears it on logout. Never hard-code it.
  String? authToken;

  // Override with --dart-define=API_BASE_URL=https://... for a real device or deployment.
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');

  // The Android emulator reaches the host machine at 10.0.2.2, not localhost.
  static String get defaultBaseUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body: body);

  Future<void> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final request = http.Request(method, uri);
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ApiException(
        'The server is taking too long to respond. Try again in a moment.',
        kind: ApiErrorKind.timeout,
      );
    } catch (_) {
      throw const ApiException(
        'Could not reach the server. Check your connection.',
        kind: ApiErrorKind.offline,
      );
    }

    // DELETE answers 204 No Content, with no body to decode.
    if (response.statusCode == 204) return const {};

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'The server sent a reply the app could not read (${response.statusCode}).',
        statusCode: response.statusCode,
        kind: ApiErrorKind.badResponse,
      );
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok || decoded['success'] != true) {
      final error = decoded['error'];
      final message = error is Map<String, dynamic> ? error['message'] as String? : null;
      final code = error is Map<String, dynamic> ? error['code'] as String? : null;
      final details = error is Map<String, dynamic> ? error['details'] : null;
      final serverProblem = response.statusCode >= 500;
      throw ApiException(
        message ??
            (serverProblem
                ? 'The server had a problem. Try again in a moment.'
                : 'The request could not be completed (${response.statusCode}).'),
        statusCode: response.statusCode,
        code: code,
        kind: serverProblem ? ApiErrorKind.server : ApiErrorKind.other,
        details: details is Map<String, dynamic>
            ? details.map((field, text) => MapEntry(field, text.toString()))
            : const {},
      );
    }
    return decoded;
  }

  // Turns the "data" list of a response into models. A row the app cannot read is
  // skipped instead of failing the whole list, so one bad record never blanks a
  // screen. A reply without a list at all is reported as a bad response.
  static List<T> parseList<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final data = body['data'];
    if (data is! List) {
      throw const ApiException(
        'The server sent a reply the app could not read.',
        kind: ApiErrorKind.badResponse,
      );
    }
    final items = <T>[];
    for (final row in data) {
      try {
        items.add(fromJson(row as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Skipped an unreadable record: $e');
      }
    }
    return items;
  }

  // Reads one record from a response, reporting a bad reply as an ApiException.
  static T parseOne<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    try {
      return fromJson(body['data'] as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException(
        'The server sent a reply the app could not read.',
        kind: ApiErrorKind.badResponse,
      );
    }
  }
}

// The text to show for any error: the API's own message when there is one,
// otherwise a generic one. Never a raw exception like "type 'Null' is not...".
String friendlyError(Object error) =>
    error is ApiException ? error.message : 'Something went wrong. Please try again.';
