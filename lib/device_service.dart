import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppDeviceInfo {
  const AppDeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.source,
  });

  final String id;
  final String name;
  final String platform;
  final String source;
}

class DeviceService {
  DeviceService._();

  static final instance = DeviceService._();
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'skylink_device_id';
  AppDeviceInfo? _cached;

  Future<AppDeviceInfo> get info async {
    if (_cached != null) return _cached!;
    String? id;
    try {
      id = await _storage.read(key: _deviceIdKey);
    } catch (_) {
      // Plain HTTP web builds do not always have a secure storage context.
      // Fall back to an in-memory id so message sending is never blocked.
    }
    if (id == null || id.isEmpty) {
      final random = Random.secure();
      id =
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
          '${List.generate(12, (_) => random.nextInt(16).toRadixString(16)).join()}';
      try {
        await _storage.write(key: _deviceIdKey, value: id);
      } catch (_) {
        // Keep the generated id in memory for this browser session.
      }
    }

    final plugin = DeviceInfoPlugin();
    String name;
    String platform;
    String source;
    if (kIsWeb) {
      final data = await plugin.webBrowserInfo;
      name = '${data.browserName.name} browser';
      platform = 'web';
      source = 'web';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final data = await plugin.androidInfo;
          name = '${data.manufacturer} ${data.model}'.trim();
          platform = 'android';
          source = 'mobile';
        case TargetPlatform.iOS:
          final data = await plugin.iosInfo;
          name = data.name.isEmpty ? data.model : data.name;
          platform = 'ios';
          source = 'mobile';
        case TargetPlatform.windows:
          final data = await plugin.windowsInfo;
          name = data.computerName;
          platform = 'windows';
          source = 'desktop';
        case TargetPlatform.linux:
          final data = await plugin.linuxInfo;
          name = data.prettyName;
          platform = 'linux';
          source = 'desktop';
        case TargetPlatform.macOS:
          final data = await plugin.macOsInfo;
          name = data.computerName;
          platform = 'macos';
          source = 'desktop';
        case TargetPlatform.fuchsia:
          name = 'Fuchsia device';
          platform = 'fuchsia';
          source = 'mobile';
      }
    }
    _cached = AppDeviceInfo(
      id: id,
      name: name.trim().isEmpty ? 'Unknown device' : name.trim(),
      platform: platform,
      source: source,
    );
    return _cached!;
  }
}
