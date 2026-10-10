import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:suga/models/area.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AreaService {
  AreaService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

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

  Future<List<Area>> fetchAreas({String? search}) async {
    final uri = Uri.parse('$_baseUrl/api/areas').replace(
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final body = await _get(uri);
    return [
      for (final item in body['data'] as List<dynamic>)
        Area.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<Area> fetchArea(int id) async {
    final body = await _get(Uri.parse('$_baseUrl/api/areas/$id'));
    return Area.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
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
      final error = decoded['error'] as Map<String, dynamic>?;
      throw ApiException(error?['message'] as String? ?? 'Request failed (${response.statusCode})');
    }
    return decoded;
  }
}
