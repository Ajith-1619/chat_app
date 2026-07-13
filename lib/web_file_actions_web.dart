import 'dart:js_interop';

@JS('skylinkDownloadFile')
external JSPromise<JSBoolean> _downloadFile(JSString url, JSString fileName);

@JS('skylinkOpenFileInApp')
external JSBoolean _openFileInApp(
  JSString url,
  JSString fileName,
  JSString mimeType,
);

String webAttachmentUrl(String url, String fileName) {
  final source = Uri.tryParse(url);
  if (source == null) return url;
  if (source.path.endsWith('/chat/media.php')) return url;
  const marker = '/uploads/';
  final markerIndex = source.path.indexOf(marker);
  if (markerIndex < 0) return url;
  final relative = source.path.substring(markerIndex + marker.length);
  if (!relative.startsWith('chat/') || relative.contains('..')) return url;
  final basePath = source.path.substring(0, markerIndex);
  return source
      .replace(
        path: '$basePath/chat/media.php',
        queryParameters: {'path': relative, 'name': fileName},
      )
      .toString();
}

Future<bool> saveWebFile(String url, String fileName) async {
  try {
    final result = await _downloadFile(
      webAttachmentUrl(url, fileName).toJS,
      fileName.toJS,
    ).toDart;
    return result.toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> openWebFileInApp(
  String url,
  String fileName,
  String mimeType,
) async {
  try {
    return _openFileInApp(
      webAttachmentUrl(url, fileName).toJS,
      fileName.toJS,
      mimeType.toJS,
    ).toDart;
  } catch (_) {
    return false;
  }
}
