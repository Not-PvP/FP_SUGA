import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:suga/models/admin_session.dart';

// Keeps the admin's session between app launches.
abstract class SessionStorage {
  Future<AdminSession?> read();
  Future<void> write(AdminSession session);
  Future<void> clear();
}

// Stores the session with flutter_secure_storage: the Android Keystore on Android and
// the Keychain on iOS, so the token is encrypted and other apps cannot read it.
// It is never put in SharedPreferences or a plain file.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'suga_admin_session';
  final FlutterSecureStorage _storage;

  @override
  Future<AdminSession?> read() async {
    try {
      final text = await _storage.read(key: _key);
      if (text == null) return null;
      return AdminSession.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      // Unreadable or from an older format: treat it as signed out.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AdminSession session) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    } catch (_) {
      // If the device cannot store it, the admin just signs in again next launch.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing more to do: the next read fails to parse and clears it again.
    }
  }
}

// Keeps the session only while the app is running. Used in tests.
class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([this._session]);

  AdminSession? _session;

  @override
  Future<AdminSession?> read() async => _session;

  @override
  Future<void> write(AdminSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
