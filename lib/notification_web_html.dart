import 'dart:html' as html;

Future<void> initializeWebNotifications() async {
  if (html.Notification.permission == 'default') {
    try {
      await html.Notification.requestPermission();
    } catch (_) {}
  }
}

Future<void> showWebNotification({
  required String sender,
  required String message,
  required String tag,
  required bool silent,
}) async {
  if (html.Notification.permission != 'granted') return;
  try {
    html.Notification(
      sender,
      body: message.isEmpty ? 'New message' : message,
      tag: tag,
    );
  } catch (_) {}
}