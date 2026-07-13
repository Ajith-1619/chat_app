import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class WebAttachmentBridge {
  WebAttachmentBridge({
    required this.onDragStateChanged,
    required this.onFiles,
  }) {
    _install();
  }

  final void Function(bool dragging) onDragStateChanged;
  final Future<void> Function(List<PlatformFile> files) onFiles;

  int _dragDepth = 0;
  bool _disposed = false;
  late final html.EventListener _dragEnterListener;
  late final html.EventListener _dragOverListener;
  late final html.EventListener _dragLeaveListener;
  late final html.EventListener _dropListener;
  late final html.EventListener _pasteListener;

  void _install() {
    _dragEnterListener = (event) {
      if (_disposed || !_hasFiles(event)) return;
      event.preventDefault();
      _dragDepth += 1;
      onDragStateChanged(true);
    };
    _dragOverListener = (event) {
      if (_disposed || !_hasFiles(event)) return;
      event.preventDefault();
      final dragEvent = event as html.MouseEvent;
      dragEvent.dataTransfer.dropEffect = 'copy';
      onDragStateChanged(true);
    };
    _dragLeaveListener = (event) {
      if (_disposed) return;
      event.preventDefault();
      _dragDepth = (_dragDepth - 1).clamp(0, 999999);
      if (_dragDepth == 0) onDragStateChanged(false);
    };
    _dropListener = (event) async {
      if (_disposed || !_hasFiles(event)) return;
      event.preventDefault();
      _dragDepth = 0;
      onDragStateChanged(false);
      final files = await _extractFiles(event);
      if (files.isNotEmpty) {
        await onFiles(files);
      }
    };
    _pasteListener = (event) async {
      if (_disposed || event is! html.ClipboardEvent) return;
      final clipboard = event.clipboardData;
      if (clipboard == null) return;
      final files = <html.File>[];
      final clipboardFiles = clipboard.files;
      if (clipboardFiles != null && clipboardFiles.isNotEmpty) {
        files.addAll(clipboardFiles);
      }
      final items = clipboard.items;
      final itemCount = items?.length ?? 0;
      for (var index = 0; index < itemCount; index++) {
        final item = items![index];
        if (item.kind == 'file') {
          final file = item.getAsFile();
          if (file != null) files.add(file);
        }
      }
      if (files.isEmpty) return;
      event.preventDefault();
      final platformFiles = await _extractClipboardFiles(files);
      if (platformFiles.isNotEmpty) {
        await onFiles(platformFiles);
      }
    };

    html.window.addEventListener('dragenter', _dragEnterListener);
    html.window.addEventListener('dragover', _dragOverListener);
    html.window.addEventListener('dragleave', _dragLeaveListener);
    html.window.addEventListener('drop', _dropListener);
    html.document.addEventListener('paste', _pasteListener, true);
  }

  bool _hasFiles(html.Event event) {
    if (event is! html.MouseEvent) return false;
    final transfer = event.dataTransfer;
    final items = transfer.items;
    final itemCount = items?.length ?? 0;
    for (var index = 0; index < itemCount; index++) {
      if (items![index].kind == 'file') return true;
    }
    return transfer.files?.isNotEmpty == true;
  }

  Future<List<PlatformFile>> _extractFiles(html.Event event) async {
    if (event is! html.MouseEvent) return <PlatformFile>[];
    final files = event.dataTransfer.files;
    if (files == null || files.isEmpty) return <PlatformFile>[];
    final result = <PlatformFile>[];
    for (final file in files) {
      result.add(await _toPlatformFile(file));
    }
    return result;
  }

  Future<List<PlatformFile>> _extractClipboardFiles(
    Iterable<html.File> files,
  ) async {
    final result = <PlatformFile>[];
    for (final file in files) {
      result.add(await _toPlatformFile(file));
    }
    return result;
  }

  Future<PlatformFile> _toPlatformFile(html.File file) async {
    final bytes = await _readBytes(file);
    final inferredName = file.name.trim().isEmpty
        ? _generatedName(file.type)
        : file.name;
    return PlatformFile(name: inferredName, size: file.size, bytes: bytes);
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
        : 'bin';
    return 'pasted_file_$stamp.$extension';
  }

  Future<Uint8List> _readBytes(html.File file) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
        return;
      }
      if (result is Uint8List) {
        completer.complete(result);
        return;
      }
      if (result is List<int>) {
        completer.complete(Uint8List.fromList(result));
        return;
      }
      completer.completeError(
        StateError('Unsupported clipboard file payload.'),
      );
    });
    reader.onError.listen((_) {
      completer.completeError(StateError('Unable to read browser file data.'));
    });
    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  void dispose() {
    _disposed = true;
    html.window.removeEventListener('dragenter', _dragEnterListener);
    html.window.removeEventListener('dragover', _dragOverListener);
    html.window.removeEventListener('dragleave', _dragLeaveListener);
    html.window.removeEventListener('drop', _dropListener);
    html.document.removeEventListener('paste', _pasteListener, true);
    onDragStateChanged(false);
  }
}