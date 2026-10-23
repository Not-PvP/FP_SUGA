import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:suga/models/admin_session.dart';
import 'package:suga/services/auth_service.dart';
import 'package:suga/services/session_storage.dart';

// Shared admin sign-in state.
// Screens read it with context.watch<AuthProvider>(). main.dart passes [token] to
// PowerInterruptionProvider, so admin requests are sent as the signed-in admin.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? service,
    SessionStorage? storage,
    DateTime Function()? now,
  })  : _service = service ?? AuthService(),
        _storage = storage ?? SecureSessionStorage(),
        _now = now ?? DateTime.now;

  static const expiredMessage = 'Your session has expired. Please sign in again.';
  static const signedOutMessage = 'You were signed out. Please sign in again.';

  final AuthService _service;
  final SessionStorage _storage;
  final DateTime Function() _now;

  AdminSession? _session;
  bool _isSigningIn = false;
  bool _hasRestored = false;
  String? _error;
  String? _notice;
  Timer? _expiryTimer;
  bool _disposed = false;

  bool get isSignedIn => _session != null;
  Admin? get admin => _session?.admin;
  String? get token => _session?.token;
  DateTime? get expiresAt => _session?.expiresAt;
  bool get isSigningIn => _isSigningIn;

  // False until the saved session (if any) has been read at startup.
  bool get hasRestored => _hasRestored;

  // Why the last sign-in failed, e.g. 'Incorrect email or password.'
  String? get error => _error;

  // Why the admin was signed out without asking, e.g. the session expired.
  String? get notice => _notice;

  // Reads the session saved on the device, then asks the server if it still works.
  Future<void> restoreSession() async {
    final saved = await _storage.read();
    if (saved != null && saved.isExpiredAt(_now())) {
      await _storage.clear();
      _notice = expiredMessage;
    } else if (saved != null && _session == null) {
      _start(saved);
    }
    _hasRestored = true;
    _notify();

    final restored = _session;
    if (restored == null || restored != saved) return;
    try {
      final admin = await _service.fetchCurrentAdmin(restored.token);
      if (_session != restored) return; // signed out or in again meanwhile
      _session = AdminSession(token: restored.token, expiresAt: restored.expiresAt, admin: admin);
      _notify();
    } on ApiException catch (e) {
      // 401: the token was revoked or expired on the server. Offline: keep it for now,
      // the server will still reject it later if it is no longer valid.
      if (e.isUnauthorized && _session == restored) handleUnauthorized(e);
    }
  }

  // Returns true when signed in. On false, [error] says why.
  Future<bool> login(String email, String password) async {
    _isSigningIn = true;
    _error = null;
    _notice = null;
    _notify();
    try {
      final session = await _service.login(email, password);
      _start(session);
      await _storage.write(session);
      return true;
    } on ApiException catch (e) {
      _error = _loginError(e);
      return false;
    } finally {
      _isSigningIn = false;
      _notify();
    }
  }

  // Signs out on this device at once, then tells the server to end the session.
  Future<void> logout() async {
    final current = _session;
    if (current == null) return;
    await _end();
    try {
      await _service.logout(current.token);
    } on ApiException {
      // Offline or already expired: the token is gone from the device either way.
    }
  }

  // Called when the server answers 401 to an admin request.
  void handleUnauthorized(ApiException error) {
    if (_session == null) return;
    _end(notice: error.code == 'SESSION_EXPIRED' ? expiredMessage : signedOutMessage);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  void _start(AdminSession session) {
    _session = session;
    _expiryTimer?.cancel();
    // Sign out on this device when the session runs out, without waiting for a 401.
    final remaining = session.expiresAt.difference(_now());
    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_session == session) _end(notice: expiredMessage);
    });
  }

  Future<void> _end({String? notice}) async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _session = null;
    _notice = notice;
    _notify();
    await _storage.clear();
  }

  static String _loginError(ApiException e) {
    switch (e.code) {
      case 'INVALID_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'VALIDATION_ERROR':
        return 'Enter a valid email address and password.';
      default:
        // TOO_MANY_ATTEMPTS, server errors and "Could not reach the server" already read well.
        return e.message;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiryTimer?.cancel();
    super.dispose();
  }
}
