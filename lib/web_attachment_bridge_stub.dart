import 'package:file_picker/file_picker.dart';

class WebAttachmentBridge {
  WebAttachmentBridge({
    required void Function(bool dragging) onDragStateChanged,
    required Future<void> Function(List<PlatformFile> files) onFiles,
  });

  void dispose() {}
}
