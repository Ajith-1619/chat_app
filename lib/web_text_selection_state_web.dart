import 'dart:html' as html;

bool browserHasActiveTextSelection() {
  final selection = html.window.getSelection();
  return selection != null && selection.toString().trim().isNotEmpty;
}
