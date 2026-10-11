import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

// Shared GET helper: unwraps the { success, data } envelope and turns every failure
// (network, bad JSON, error response) into an ApiException with a readable message.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl;

  final http.Client _client;
  final String baseUrl;

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

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const ApiException('Could not reach the server. Check your connection.');
    }
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (${response.statusCode})');
    }
    if (response.statusCode != 200 || decoded['success'] != true) {
      final error = decoded['error'];
      final message = error is Map<String, dynamic> ? error['message'] as String? : null;
      throw ApiException(message ?? 'Request failed (${response.statusCode})');
    }
    return decoded;
  }
}
