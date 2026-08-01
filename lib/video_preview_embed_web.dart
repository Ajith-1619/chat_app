import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _videoPreviewCounter = 0;

Widget buildEmbeddedVideoPreview({
  required String title,
  required String url,
  Uint8List? bytes,
  bool autoplay = false,
  bool muted = false,
  bool loop = false,
  bool controls = true,
  BoxFit fit = BoxFit.contain,
}) {
  final sourceUrl = bytes != null && bytes.isNotEmpty
      ? html.Url.createObjectUrlFromBlob(html.Blob(<dynamic>[bytes]))
      : url;
  final viewType = 'skylink-video-preview-${_videoPreviewCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final video = html.VideoElement()
      ..src = sourceUrl
      ..title = title
      ..controls = controls
      ..autoplay = autoplay
      ..muted = muted
      ..loop = loop
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000000'
      ..style.objectFit = _cssObjectFit(fit)
      ..setAttribute('playsinline', 'true')
      ..setAttribute('preload', autoplay ? 'auto' : 'metadata');
    return video;
  });
  return HtmlElementView(viewType: viewType);
}

String _cssObjectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.cover:
      return 'cover';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.contain:
    case BoxFit.fitHeight:
    case BoxFit.fitWidth:
      return 'contain';
  }
}


