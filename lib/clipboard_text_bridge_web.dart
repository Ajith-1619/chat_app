import 'dart:html' as html;

Future<bool> copyTextToClipboard(String text) async {
  final navigator = html.window.navigator;
  final clipboard = navigator.clipboard;
  if (clipboard != null) {
    try {
      await clipboard.writeText(text);
      return true;
    } catch (_) {
      // Fall back to execCommand below for browsers that require a focused element.
    }
  }

  final document = html.document;
  final body = document.body;
  if (body == null) return false;

  final area = html.TextAreaElement()
    ..value = text
    ..style.position = 'fixed'
    ..style.left = '-10000px'
    ..style.top = '0'
    ..style.opacity = '0';
  body.append(area);
  area.focus();
  area.select();
  try {
    return document.execCommand('copy');
  } catch (_) {
    return false;
  } finally {
    area.remove();
  }
}
