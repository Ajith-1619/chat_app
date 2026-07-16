import 'dart:typed_data';

class PastedMediaFile {
  const PastedMediaFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

typedef ClipboardMediaHandler = Future<void> Function(List<PastedMediaFile> files);

void registerClipboardMediaHandler(ClipboardMediaHandler handler) {}

void unregisterClipboardMediaHandler([ClipboardMediaHandler? handler]) {}
