import 'dart:typed_data';

import 'package:flutter/material.dart';

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
  return Container(
    color: Colors.black,
    alignment: Alignment.center,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 72),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inline video playback is currently optimized for Flow Web. Use download or open-with on this device if needed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}
