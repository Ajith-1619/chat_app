import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppCache {
  AppCache._();

  static final instance = AppCache._();

  Future<void> writeJson(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<dynamic> readJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    if (value == null || value.isEmpty) return null;
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
