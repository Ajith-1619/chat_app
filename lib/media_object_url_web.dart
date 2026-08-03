import 'dart:html' as html;
import 'dart:typed_data';

String createMediaObjectUrl(Uint8List bytes, {String mimeType = 'application/octet-stream'}) {
  return html.Url.createObjectUrlFromBlob(
    html.Blob(<dynamic>[bytes], mimeType),
  );
}

void revokeMediaObjectUrl(String url) {
  if (url.isNotEmpty && !url.startsWith('data:')) {
    html.Url.revokeObjectUrl(url);
  }
}
