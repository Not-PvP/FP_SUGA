import 'package:http/http.dart' as http;
import 'package:suga/models/admin_session.dart';
import 'package:suga/services/api_client.dart';

export 'package:suga/services/api_client.dart' show ApiException;

// Admin sign-in endpoints: /api/auth/login, /api/auth/me and /api/auth/logout.
class AuthService {
  AuthService({http.Client? client, String? baseUrl})
      : _api = ApiClient(client: client, baseUrl: baseUrl);

  final ApiClient _api;

  // Throws ApiException with code 'INVALID_CREDENTIALS' (401) for a wrong email or
  // password, and 'TOO_MANY_ATTEMPTS' (429) after too many wrong tries.
  Future<AdminSession> login(String email, String password) async {
    final body = await _api.post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    return AdminSession.fromJson(body['data'] as Map<String, dynamic>);
  }

  // Checks that a saved token still works. Throws ApiException (401) when it does not.
  Future<Admin> fetchCurrentAdmin(String token) async {
    _api.authToken = token;
    try {
      final body = await _api.get('/api/auth/me');
      final data = body['data'] as Map<String, dynamic>;
      return Admin.fromJson(data['admin'] as Map<String, dynamic>);
    } finally {
      _api.authToken = null;
    }
  }

  // Ends the session on the server, so the token cannot be used again.
  Future<void> logout(String token) async {
    _api.authToken = token;
    try {
      await _api.post('/api/auth/logout', const {});
    } finally {
      _api.authToken = null;
    }
  }
}
