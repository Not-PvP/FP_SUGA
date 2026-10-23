import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suga/models/admin_session.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/services/auth_service.dart';
import 'package:suga/services/session_storage.dart';

final _now = DateTime.utc(2026, 10, 23, 8);

Map<String, dynamic> _admin() => {'id': 1, 'email': 'admin@suga.ph', 'name': 'SUGA Admin'};

http.Response _ok(Object data, [int status = 200]) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);

http.Response _error(int status, String code, String message) => http.Response(
      jsonEncode({
        'success': false,
        'error': {'code': code, 'message': message},
      }),
      status,
    );

AdminSession _session({DateTime? expiresAt}) => AdminSession(
      token: 'saved-token',
      expiresAt: expiresAt ?? _now.add(const Duration(hours: 12)),
      admin: Admin.fromJson(_admin()),
    );

// Disposed after each test, which also cancels its session-expiry timer.
AuthProvider _provider(
  Future<http.Response> Function(http.Request) handler, {
  SessionStorage? storage,
}) {
  final auth = AuthProvider(
    service: AuthService(client: MockClient(handler), baseUrl: 'http://test'),
    storage: storage ?? MemorySessionStorage(),
    now: () => _now,
  );
  addTearDown(auth.dispose);
  return auth;
}

void main() {
  test('login stores the session and exposes the token', () async {
    late http.Request sent;
    final storage = MemorySessionStorage();
    final auth = _provider((r) async {
      sent = r;
      return _ok({
        'token': 'new-token',
        'token_type': 'Bearer',
        'expires_at': '2026-10-23T20:00:00.000Z',
        'admin': _admin(),
      });
    }, storage: storage);

    final signedIn = await auth.login(' admin@suga.ph ', 'secret password');

    expect(signedIn, isTrue);
    expect(sent.url.path, '/api/auth/login');
    expect(jsonDecode(sent.body), {'email': 'admin@suga.ph', 'password': 'secret password'});
    expect(auth.isSignedIn, isTrue);
    expect(auth.token, 'new-token');
    expect(auth.admin!.displayName, 'SUGA Admin');
    expect(auth.isSigningIn, isFalse);
    expect((await storage.read())!.token, 'new-token', reason: 'saved for the next launch');
  });

  test('a wrong password shows a friendly error and stays signed out', () async {
    final auth = _provider((_) async => _error(401, 'INVALID_CREDENTIALS', 'Incorrect email or password'));

    expect(await auth.login('admin@suga.ph', 'wrong'), isFalse);
    expect(auth.isSignedIn, isFalse);
    expect(auth.error, 'Incorrect email or password.');

    auth.clearError();
    expect(auth.error, isNull);
  });

  test('too many attempts and offline errors pass the server message through', () async {
    final response = _error(429, 'TOO_MANY_ATTEMPTS', 'Too many failed sign-in attempts. Try again in 15 minutes.');
    final auth = _provider((_) async => response);

    await auth.login('admin@suga.ph', 'guess');
    expect(auth.error, contains('Too many failed sign-in attempts'));

    final offline = _provider((_) async => throw Exception('no network'));
    await offline.login('admin@suga.ph', 'guess');
    expect(offline.error, 'Could not reach the server. Check your connection.');
  });

  test('restoreSession keeps a saved session that the server still accepts', () async {
    late http.Request sent;
    final auth = _provider((r) async {
      sent = r;
      return _ok({'admin': _admin(), 'expires_at': '2026-10-23T20:00:00.000Z'});
    }, storage: MemorySessionStorage(_session()));

    await auth.restoreSession();

    expect(auth.hasRestored, isTrue);
    expect(auth.isSignedIn, isTrue);
    expect(sent.url.path, '/api/auth/me');
    expect(sent.headers['authorization'], 'Bearer saved-token');
  });

  test('restoreSession drops a session that expired while the app was closed', () async {
    var requests = 0;
    final storage = MemorySessionStorage(_session(expiresAt: _now.subtract(const Duration(minutes: 1))));
    final auth = _provider((_) async {
      requests++;
      return _ok({});
    }, storage: storage);

    await auth.restoreSession();

    expect(auth.isSignedIn, isFalse);
    expect(auth.notice, AuthProvider.expiredMessage);
    expect(requests, 0, reason: 'no need to ask the server about an expired token');
    expect(await storage.read(), isNull);
  });

  test('restoreSession signs out when the server rejects the saved token', () async {
    final storage = MemorySessionStorage(_session());
    final auth = _provider(
      (_) async => _error(401, 'INVALID_TOKEN', 'Your session is no longer valid. Sign in again.'),
      storage: storage,
    );

    await auth.restoreSession();

    expect(auth.isSignedIn, isFalse);
    expect(auth.notice, AuthProvider.signedOutMessage);
    expect(await storage.read(), isNull);
  });

  test('restoreSession stays signed in when the server cannot be reached', () async {
    final auth = _provider((_) async => throw Exception('offline'), storage: MemorySessionStorage(_session()));

    await auth.restoreSession();

    expect(auth.isSignedIn, isTrue);
  });

  test('a SESSION_EXPIRED 401 from an admin request signs out with a notice', () async {
    final storage = MemorySessionStorage(_session());
    final auth = _provider(
      (_) async => _ok({'admin': _admin(), 'expires_at': '2026-10-23T20:00:00.000Z'}),
      storage: storage,
    );
    await auth.restoreSession();

    auth.handleUnauthorized(const ApiException('expired', statusCode: 401, code: 'SESSION_EXPIRED'));

    expect(auth.isSignedIn, isFalse);
    expect(auth.token, isNull);
    expect(auth.notice, AuthProvider.expiredMessage);
  });

  test('logout signs out at once and ends the session on the server', () async {
    final requests = <http.Request>[];
    final storage = MemorySessionStorage(_session());
    final auth = _provider((r) async {
      requests.add(r);
      if (r.url.path == '/api/auth/logout') return http.Response('', 204);
      return _ok({'admin': _admin(), 'expires_at': '2026-10-23T20:00:00.000Z'});
    }, storage: storage);
    await auth.restoreSession();

    await auth.logout();

    expect(auth.isSignedIn, isFalse);
    expect(auth.notice, isNull, reason: 'signing out on purpose is not an error');
    expect(await storage.read(), isNull);
    final logout = requests.last;
    expect(logout.method, 'POST');
    expect(logout.url.path, '/api/auth/logout');
    expect(logout.headers['authorization'], 'Bearer saved-token');
  });

  test('logout still signs out on the device when offline', () async {
    var calls = 0;
    final auth = _provider((r) async {
      calls++;
      if (r.url.path == '/api/auth/logout') throw Exception('offline');
      return _ok({'admin': _admin(), 'expires_at': '2026-10-23T20:00:00.000Z'});
    }, storage: MemorySessionStorage(_session()));
    await auth.restoreSession();

    await auth.logout();

    expect(auth.isSignedIn, isFalse);
    expect(calls, 2);
  });
}
