import 'package:flutter/material.dart';

Widget buildEmbeddedFilePreview(String url, String title) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.preview_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'In-app preview for this file type is available on web. Native preview engine is not bundled yet.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}