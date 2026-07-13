import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _previewCounter = 0;

Widget buildEmbeddedFilePreview(String url, String title) {
  final viewType = 'skylink-file-preview-${_previewCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return html.IFrameElement()
      ..src = url
      ..title = title
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('sandbox', 'allow-same-origin allow-scripts allow-forms')
      ..setAttribute('referrerpolicy', 'no-referrer');
  });
  return HtmlElementView(viewType: viewType);
}