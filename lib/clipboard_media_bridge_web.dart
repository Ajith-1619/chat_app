import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

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

StreamSubscription<html.Event>? _pasteSubscription;
ClipboardMediaHandler? _handler;

void registerClipboardMediaHandler(ClipboardMediaHandler handler) {
  _handler = handler;
  _pasteSubscription?.cancel();
  _pasteSubscription = html.document.onPaste.listen((event) async {
    final data = (event as html.ClipboardEvent).clipboardData;
    final items = data?.items;
    if (items == null || items.length == 0 || _handler == null) return;
    final files = <PastedMediaFile>[];
    for (var i = 0; i < (items.length ?? 0); i++) {
      final item = items[i];
      final file = item.getAsFile();
      if (file == null) continue;
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      reader.onLoad.listen((_) {
        final result = reader.result;
        if (result is ByteBuffer) {
          completer.complete(Uint8List.view(result));
        } else if (result is Uint8List) {
          completer.complete(result);
        } else {
          completer.complete(Uint8List(0));
        }
      });
      reader.onError.listen((_) => completer.complete(Uint8List(0)));
      reader.readAsArrayBuffer(file);
      final bytes = await completer.future;
      if (bytes.isEmpty) continue;
      files.add(
        PastedMediaFile(
          name: file.name,
          mimeType: file.type.isEmpty ? 'application/octet-stream' : file.type,
          bytes: bytes,
        ),
      );
    }
    if (files.isEmpty) return;
    event.preventDefault();
    await _handler?.call(files);
  });
}

void unregisterClipboardMediaHandler() {
  _pasteSubscription?.cancel();
  _pasteSubscription = null;
  _handler = null;
}

