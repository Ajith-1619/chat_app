import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedLogin {
  const SavedLogin({
    required this.employeeId,
    required this.password,
    this.sessionCookie = '',
  });

  final String employeeId;
  final String password;
  final String sessionCookie;
}

class SessionStore {
  SessionStore._();

  static final instance = SessionStore._();

  static const _employeeIdKey = 'skylink_employee_id';
  static const _passwordKey = 'skylink_password';
  static const _sessionCookieKey = 'skylink_session_cookie';
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  Future<void> save({
    required String employeeId,
    required String password,
    String sessionCookie = '',
  }) async {
    final cleanEmployeeId = employeeId.trim();
    var secureSaved = false;
    try {
      await _storage.write(key: _employeeIdKey, value: cleanEmployeeId);
      await _storage.write(key: _passwordKey, value: password);
      if (sessionCookie.isNotEmpty) {
        await _storage.write(key: _sessionCookieKey, value: sessionCookie);
      }
      secureSaved = true;
    } catch (_) {
      // Web builds served over plain HTTP do not have a secure browser context.
      // Fall back below so Remember me still works on chat.skylinkonline.net/chat/.
    }

    if (kIsWeb || !secureSaved) {
      await _saveFallback(
        employeeId: cleanEmployeeId,
        password: password,
        sessionCookie: sessionCookie,
      );
    }
  }

  Future<SavedLogin?> read() async {
    try {
      final values = await _storage.readAll();
      final saved = _fromValues(values);
      if (saved != null) return saved;
    } catch (_) {
      // Secure storage is unavailable on some web contexts; use fallback below.
    }
    return _readFallback();
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _employeeIdKey);
      await _storage.delete(key: _passwordKey);
      await _storage.delete(key: _sessionCookieKey);
    } catch (_) {
      // Ignore storage cleanup failures in unsupported web storage contexts.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_employeeIdKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_sessionCookieKey);
  }

  SavedLogin? _fromValues(Map<String, String?> values) {
    final employeeId = values[_employeeIdKey]?.trim() ?? '';
    final password = values[_passwordKey] ?? '';
    if (employeeId.isEmpty || password.isEmpty) return null;
    return SavedLogin(
      employeeId: employeeId,
      password: password,
      sessionCookie: values[_sessionCookieKey] ?? '',
    );
  }

  Future<void> _saveFallback({
    required String employeeId,
    required String password,
    required String sessionCookie,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_employeeIdKey, employeeId);
    await prefs.setString(_passwordKey, password);
    if (sessionCookie.isNotEmpty) {
      await prefs.setString(_sessionCookieKey, sessionCookie);
    }
  }

  Future<SavedLogin?> _readFallback() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = (prefs.getString(_employeeIdKey) ?? '').trim();
    final password = prefs.getString(_passwordKey) ?? '';
    if (employeeId.isEmpty || password.isEmpty) return null;
    return SavedLogin(
      employeeId: employeeId,
      password: password,
      sessionCookie: prefs.getString(_sessionCookieKey) ?? '',
    );
  }
}