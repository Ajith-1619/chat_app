import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.notification == null) {
    await NotificationService.instance.initializeLocalNotifications();
    await NotificationService.instance.showMessage(
      sender: message.data['sender_name']?.toString() ?? 'Skylink',
      message:
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          'New message',
      jid: message.data['jid']?.toString() ?? message.messageId ?? 'skylink',
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
          'skylink_messages',
          'Skylink messages',
          description: 'Notifications for new Skylink chat messages',
          importance: Importance.high,
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
      showMessage(
        sender:
            notification?.title ??
            message.data['sender_name']?.toString() ??
            'Skylink',
        message:
            notification?.body ??
            message.data['body']?.toString() ??
            message.data['message']?.toString() ??
            'New message',
        jid: message.data['jid']?.toString() ?? message.messageId ?? 'skylink',
      );
    });
  }

  Future<void> showMessage({
    required String sender,
    required String message,
    required String jid,
  }) async {
    if (kIsWeb) return;
    await initializeLocalNotifications();
    await _plugin.show(
      id: jid.hashCode & 0x7fffffff,
      title: sender,
      body: message.isEmpty ? 'New message' : message,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'skylink_messages',
          'Skylink messages',
          channelDescription: 'Notifications for new Skylink chat messages',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
          playSound: true,
          enableVibration: true,
        ),
        windows: WindowsNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
      payload: jid,
    );
  }
}
