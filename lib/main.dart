import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/skylink_app.dart';
import 'location_tracking_service.dart';
import 'notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrint('${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error');
    debugPrint('$stack');
    return true;
  };
  final preferences = await SharedPreferences.getInstance();
  appThemeMode.value = preferences.getBool('dark_mode') == true
      ? ThemeMode.dark
      : ThemeMode.light;
  appMessageScale.value = preferences.getDouble('message_scale') ?? 1.0;
  appChatDensity.value = preferences.getDouble('chat_density') ?? 1.0;
  appShowAvatars.value = preferences.getBool('show_avatars') ?? true;
  appCollapseLongMessages.value =
      preferences.getBool('collapse_long_messages') ?? true;
  appWorkspaceMode.value = preferences.getString('workspace_mode') ?? 'three_pane';
  try {
    await LocationTrackingService.instance.initialize();
  } catch (error) {
    debugPrint('Location service initialization failed: $error');
  }
  try {
    await NotificationService.instance.initialize();
  } catch (error) {
    debugPrint('Notification service initialization failed: $error');
  }
  runApp(const SkylinkApp());
}

