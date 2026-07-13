import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _trackingTokenKey = 'skylink_location_tracking_token';
const _trackingEnabledKey = 'skylink_location_tracking_enabled';
const _locationEndpoint =
    'https://dns.watchtower247.in/router_login/chat/location_update.php';
const _offlineAlertEndpoint =
    'https://dns.watchtower247.in/router_login/chat/offline_alert.php';

class LocationTrackingService {
  LocationTrackingService._();

  static final instance = LocationTrackingService._();

  Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      'skylink_location_tracking',
      'Attendance location tracking',
      description: 'Tracks location while an attendance shift is active',
      importance: Importance.low,
    );
    const alertChannel = AndroidNotificationChannel(
      'skylink_location_alerts',
      'Location alerts',
      description: 'Alerts when GPS is disabled during an active shift',
      importance: Importance.high,
    );
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alertChannel);
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: locationServiceEntryPoint,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: channel.id,
        initialNotificationTitle: 'Skylink attendance',
        initialNotificationContent: 'Location tracking is active',
        foregroundServiceNotificationId: 9201,
        foregroundServiceTypes: const [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: locationServiceEntryPoint,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_trackingEnabledKey) == true) {
      await FlutterBackgroundService().startService();
    }
  }

  Future<void> start(String token) async {
    if (kIsWeb || !Platform.isAndroid || token.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trackingTokenKey, token);
    await prefs.setBool(_trackingEnabledKey, true);
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) await service.startService();
    service.invoke('refreshTracking');
  }

  Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, false);
    await prefs.remove(_trackingTokenKey);
    FlutterBackgroundService().invoke('stopService');
  }
}

@pragma('vm:entry-point')
void locationServiceEntryPoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  Timer? timer;
  DateTime? offlineSince;
  bool offlineAlertSent = false;

  Future<void> recordOfflineState(String token) async {
    offlineSince ??= DateTime.now();
    final duration = DateTime.now().difference(offlineSince!).inSeconds;
    final notifications = FlutterLocalNotificationsPlugin();
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Skylink attendance: offline',
        content: 'Enable mobile data or Wi-Fi to continue tracking.',
      );
    }
    await notifications.show(
      id: 9203,
      title: 'Attendance tracking is offline',
      body: 'Enable mobile data or connect to Wi-Fi now.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'skylink_location_alerts',
          'Location alerts',
          channelDescription: 'Attendance tracking visibility alerts',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
        ),
      ),
    );
    if (duration < const Duration(minutes: 5).inSeconds || offlineAlertSent) {
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse(_offlineAlertEndpoint),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'tracking_token': token,
              'offline_seconds': duration,
            }),
          )
          .timeout(const Duration(seconds: 12));
      offlineAlertSent =
          response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      // Retry until connectivity returns; the final duration is preserved.
    }
  }

  Future<void> saveLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(_trackingEnabledKey) != true) {
      timer?.cancel();
      service.stopSelf();
      return;
    }
    final token = prefs.getString(_trackingTokenKey) ?? '';
    if (token.isEmpty) return;
    final notifications = FlutterLocalNotificationsPlugin();
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'GPS is off',
          content: 'Turn on location to continue attendance tracking.',
        );
      }
      await notifications.show(
        id: 9202,
        title: 'Skylink attendance: GPS is off',
        body: 'Turn on location now to continue attendance tracking.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'skylink_location_alerts',
            'Location alerts',
            channelDescription:
                'Alerts when GPS is disabled during an active shift',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
          ),
        ),
      );
      return;
    }
    await notifications.cancel(id: 9202);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 40),
        ),
      );
      final response = await http
          .post(
            Uri.parse(_locationEndpoint),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'tracking_token': token,
              'latitude': position.latitude,
              'longitude': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Location endpoint returned ${response.statusCode}',
        );
      }
      if (offlineSince != null && !offlineAlertSent) {
        await recordOfflineState(token);
      }
      offlineSince = null;
      offlineAlertSent = false;
      await notifications.cancel(id: 9203);
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Skylink attendance',
          content:
              'Location saved at ${DateTime.now().hour.toString().padLeft(2, '0')}:'
              '${DateTime.now().minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (_) {
      await recordOfflineState(token);
    }
  }

  service.on('stopService').listen((_) {
    timer?.cancel();
    service.stopSelf();
  });
  service.on('refreshTracking').listen((_) => saveLocation());
  await saveLocation();
  timer = Timer.periodic(const Duration(minutes: 1), (_) => saveLocation());
}
