import 'dart:async';
import 'dart:html' as html;
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

typedef ClipboardMediaHandler =
    Future<void> Function(List<PastedMediaFile> files);

html.EventListener? _pasteListener;
ClipboardMediaHandler? _handler;

void registerClipboardMediaHandler(ClipboardMediaHandler handler) {
  _handler = handler;
  if (_pasteListener == null) {
    _pasteListener = (event) async {
      if (event is! html.ClipboardEvent || _handler == null) return;
      final data = event.clipboardData;
      if (data == null) return;

      final browserFiles = <html.File>[];
      final seen = <String>{};
      void addFile(html.File file) {
        final key = '${file.name}|${file.size}|${file.type}|${file.lastModified}';
        if (seen.add(key)) browserFiles.add(file);
      }

      final files = data.files;
      if (files != null && files.isNotEmpty) {
        for (final file in files) {
          addFile(file);
        }
      }

      final items = data.items;
      final itemCount = items?.length ?? 0;
      for (var index = 0; index < itemCount; index++) {
        final item = items![index];
        if (item.kind != 'file') continue;
        final file = item.getAsFile();
        if (file != null) addFile(file);
      }

      if (browserFiles.isEmpty) return;
      event.preventDefault();
      event.stopPropagation();

      final pasted = <PastedMediaFile>[];
      final payloadSeen = <String>{};
      for (final file in browserFiles) {
        final bytes = await _readFileBytes(file);
        if (bytes.isEmpty) continue;
        final mimeType = file.type.isEmpty
            ? 'application/octet-stream'
            : file.type;
        final payloadKey = _payloadKey(mimeType, bytes);
        if (!payloadSeen.add(payloadKey)) continue;
        pasted.add(
          PastedMediaFile(
            name: file.name.trim().isEmpty
                ? _generatedName(mimeType)
                : file.name,
            mimeType: mimeType,
            bytes: bytes,
          ),
        );
      }
      if (pasted.isEmpty) return;
      await _handler?.call(pasted);
    };
    html.document.addEventListener('paste', _pasteListener!, true);
  }
}

Future<Uint8List> _readFileBytes(html.File file) async {
  final reader = html.FileReader();
  final completer = Completer<Uint8List>();
  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(result.asUint8List());
    } else if (result is Uint8List) {
      completer.complete(result);
    } else if (result is List<int>) {
      completer.complete(Uint8List.fromList(result));
    } else {
      completer.complete(Uint8List(0));
    }
  });
  reader.onError.listen((_) => completer.complete(Uint8List(0)));
  reader.readAsArrayBuffer(file);
  return completer.future;
}


String _payloadKey(String mimeType, Uint8List bytes) {
  var hash = 0;
  final step = bytes.length < 64 ? 1 : (bytes.length ~/ 64);
  for (var index = 0; index < bytes.length; index += step) {
    hash = 0x1fffffff & (hash + bytes[index] + ((hash << 10) & 0x1fffffff));
    hash ^= hash >> 6;
  }
  return '$mimeType|${bytes.length}|$hash';
}

String _generatedName(String mimeType) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final type = mimeType.toLowerCase();
  final extension = type.startsWith('image/')
      ? (type.contains('png')
            ? 'png'
            : type.contains('gif')
            ? 'gif'
            : type.contains('webp')
            ? 'webp'
            : 'jpg')
      : type.startsWith('video/')
      ? 'mp4'
      : type.contains('pdf')
      ? 'pdf'
      : type.contains('csv')
      ? 'csv'
      : type.startsWith('text/')
      ? 'txt'
      : 'bin';
  return 'pasted_file_$stamp.$extension';
}

void unregisterClipboardMediaHandler([ClipboardMediaHandler? handler]) {
  if (handler != null && !identical(_handler, handler)) return;
  if (_pasteListener != null) {
    html.document.removeEventListener('paste', _pasteListener!, true);
    _pasteListener = null;
  }
  _handler = null;
}
