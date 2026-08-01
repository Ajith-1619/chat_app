import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _chatNotificationChannelId = 'skylink_messages';
const _infoNotificationChannelId = 'skylink_system_info';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.notification == null) {
    await NotificationService.instance.initializeLocalNotifications();
    final sender = message.data['sender_name']?.toString() ?? 'Skylink';
    final body =
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        'New message';
    await NotificationService.instance.showMessage(
      sender: sender,
      message: body,
      jid: message.data['jid']?.toString() ?? message.messageId ?? 'skylink',
      silent: NotificationService.isMutedOperationalInfo(
        data: message.data,
        title: sender,
        body: body,
      ),
    );
  }
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _fcmToken;
  final _tokenController = StreamController<String>.broadcast();

  String? get fcmToken => _fcmToken;
  Stream<String> get onTokenRefresh => _tokenController.stream;

  static bool isMutedOperationalInfo({
    Map<String, dynamic>? data,
    String? title,
    String? body,
  }) {
    final eventType = (data?['event_type']?.toString() ?? '').toLowerCase();
    const mutedEvents = {
      'punch_in',
      'punch_out',
      'location_off',
      'location_disabled',
      'location_permission_off',
    };
    if (mutedEvents.contains(eventType)) return true;
    final haystack = '${title ?? ''} ${body ?? ''}'.toLowerCase();
    return haystack.contains('punch in') ||
        haystack.contains('punch out') ||
        haystack.contains('location off') ||
        haystack.contains('location disabled') ||
        haystack.contains('gps off');
  }

  Future<String?> refreshToken() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      return _fcmToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> initializeLocalNotifications() async {
    if (kIsWeb || _initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windows = WindowsInitializationSettings(
      appName: 'Skylink',
      appUserModelId: 'Skylink.Chat.Desktop.1',
      guid: '78d1fb56-bc6e-4bc6-90b2-d46f50a45c62',
    );
    const linux = LinuxInitializationSettings(
      defaultActionName: 'Open Skylink',
    );
    const settings = InitializationSettings(
      android: android,
      windows: windows,
      linux: linux,
    );
    await _plugin.initialize(settings: settings);

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _chatNotificationChannelId,
          'Skylink messages',
          description: 'Notifications for new Skylink chat messages',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _infoNotificationChannelId,
          'Skylink muted updates',
          description: 'Muted operational info updates like punch and location alerts',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
    }
    _initialized = true;
  }

  Future<void> initialize() async {
    if (kIsWeb) return;
    await initializeLocalNotifications();
    if (!Platform.isAndroid) return;

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    _fcmToken = await messaging.getToken();
    messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _tokenController.add(token);
    });
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final sender =
          notification?.title ??
          message.data['sender_name']?.toString() ??
          'Skylink';
      final body =
          notification?.body ??
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          'New message';
      showMessage(
        sender: sender,
        message: body,
        jid: message.data['jid']?.toString() ?? message.messageId ?? 'skylink',
        silent: isMutedOperationalInfo(
          data: message.data,
          title: sender,
          body: body,
        ),
      );
    });
  }

  Future<void> showMessage({
    required String sender,
    required String message,
    required String jid,
    bool silent = false,
  }) async {
    if (kIsWeb) return;
    await initializeLocalNotifications();
    await _plugin.show(
      id: jid.hashCode & 0x7fffffff,
      title: sender,
      body: message.isEmpty ? 'New message' : message,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          silent ? _infoNotificationChannelId : _chatNotificationChannelId,
          silent ? 'Skylink muted updates' : 'Skylink messages',
          channelDescription: silent
              ? 'Muted operational info updates like punch and location alerts'
              : 'Notifications for new Skylink chat messages',
          importance: silent ? Importance.low : Importance.high,
          priority: silent ? Priority.low : Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
          playSound: !silent,
          enableVibration: !silent,
        ),
        windows: const WindowsNotificationDetails(),
        linux: const LinuxNotificationDetails(),
      ),
      payload: jid,
    );
  }
}