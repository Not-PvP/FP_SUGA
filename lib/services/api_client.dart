import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.details = const {}});

  final String message;

  // HTTP status of the error response, or null when the server could not be reached.
  final int? statusCode;

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

  // Sent as the x-api-key header on POST, PATCH and DELETE (admin routes).
  // Set it after the admin logs in. Never hard-code it in the app.
  String? adminKey;

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
    final key = adminKey;
    if (method != 'GET' && key != null && key.isNotEmpty) {
      request.headers['x-api-key'] = key;
    }

    final http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const ApiException('Could not reach the server. Check your connection.');
    }

    // DELETE answers 204 No Content, with no body to decode.
    if (response.statusCode == 204) return const {};

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Unexpected server response (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok || decoded['success'] != true) {
      final error = decoded['error'];
      final message = error is Map<String, dynamic> ? error['message'] as String? : null;
      final details = error is Map<String, dynamic> ? error['details'] : null;
      throw ApiException(
        message ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
        details: details is Map<String, dynamic>
            ? details.map((field, text) => MapEntry(field, text.toString()))
            : const {},
      );
    }
    return decoded;
  }
}
