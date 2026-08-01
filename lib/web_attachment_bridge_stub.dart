import 'package:file_picker/file_picker.dart';

class WebAttachmentBridge {
  WebAttachmentBridge({
    required void Function(bool dragging) onDragStateChanged,
    required Future<void> Function(List<PlatformFile> files) onFiles,
  });

  void dispose() {}
}

Future<List<PlatformFile>> pickBrowserFiles({
  bool allowMultiple = false,
  List<String>? acceptedMimeTypes,
}) async {
  final result = await FilePicker.pickFiles(
    allowMultiple: allowMultiple,
    type: FileType.any,
    withData: true,
  );
  return result?.files ?? const <PlatformFile>[];
}