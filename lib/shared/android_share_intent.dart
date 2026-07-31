import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IncomingShareFile {
  const IncomingShareFile({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.uri,
  });

  final String path;
  final String name;
  final String mimeType;
  final int size;
  final String uri;

  factory IncomingShareFile.fromMap(Map<dynamic, dynamic> map) {
    return IncomingShareFile(
      path: '${map['path'] ?? ''}',
      name: '${map['name'] ?? 'shared-file'}',
      mimeType: '${map['mimeType'] ?? 'application/octet-stream'}',
      size: int.tryParse('${map['size'] ?? 0}') ?? 0,
      uri: '${map['uri'] ?? ''}',
    );
  }

  Future<PlatformFile?> toPlatformFile() async {
    if (path.trim().isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final length = size > 0 ? size : await file.length();
    Uint8List? bytes;
    if (length <= 20 * 1024 * 1024) {
      // Android Sharesheet gives Flow a temporary cache path. Small/normal files
      // must carry bytes too because the chat upload path uses byte uploads for
      // non-video attachments and streams only very large/video files.
      bytes = await file.readAsBytes();
    }
    return PlatformFile(name: name, path: path, size: length, bytes: bytes);
  }
}

class IncomingSharePayload {
  const IncomingSharePayload({
    required this.text,
    required this.subject,
    required this.files,
    required this.receivedAt,
  });

  final String text;
  final String subject;
  final List<IncomingShareFile> files;
  final DateTime receivedAt;

  bool get isEmpty => text.trim().isEmpty && files.isEmpty;

  factory IncomingSharePayload.fromMap(Map<dynamic, dynamic> map) {
    final rawFiles = map['files'];
    final files = rawFiles is List
        ? rawFiles
              .whereType<Map>()
              .map(IncomingShareFile.fromMap)
              .where((file) => file.path.trim().isNotEmpty)
              .toList()
        : <IncomingShareFile>[];
    return IncomingSharePayload(
      text: '${map['text'] ?? ''}',
      subject: '${map['subject'] ?? ''}',
      files: files,
      receivedAt:
          DateTime.tryParse('${map['receivedAt'] ?? ''}') ?? DateTime.now(),
    );
  }

  Future<List<PlatformFile>> toPlatformFiles() async {
    final converted = <PlatformFile>[];
    for (final file in files) {
      final platformFile = await file.toPlatformFile();
      if (platformFile != null) converted.add(platformFile);
    }
    return converted;
  }
}

class AndroidShareIntentBridge {
  AndroidShareIntentBridge._();

  static final AndroidShareIntentBridge instance = AndroidShareIntentBridge._();
  static const MethodChannel _channel = MethodChannel('skylink/share_intent');

  final Map<String, IncomingSharePayload> _pendingByJid = {};
  bool _started = false;

  Future<void> start({
    required FutureOr<void> Function(IncomingSharePayload payload) onPayload,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!_started) {
      _started = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'incomingShare') return null;
        final payload = _payloadFrom(call.arguments);
        if (payload != null && !payload.isEmpty) await onPayload(payload);
        return null;
      });
    }
    final initial = await _channel.invokeMethod<dynamic>('getInitialShare');
    final payload = _payloadFrom(initial);
    if (payload != null && !payload.isEmpty) await onPayload(payload);
  }

  void setPendingFor(String jid, IncomingSharePayload payload) {
    final key = jid.trim().toLowerCase();
    if (key.isEmpty || payload.isEmpty) return;
    _pendingByJid[key] = payload;
  }

  IncomingSharePayload? takePendingFor(String jid) {
    return _pendingByJid.remove(jid.trim().toLowerCase());
  }

  IncomingSharePayload? _payloadFrom(dynamic value) {
    if (value is! Map) return null;
    return IncomingSharePayload.fromMap(value);
  }
}
