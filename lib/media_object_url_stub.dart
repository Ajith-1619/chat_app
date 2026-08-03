import 'dart:convert';
import 'dart:typed_data';

String createMediaObjectUrl(Uint8List bytes, {String mimeType = 'application/octet-stream'}) {
  final encoded = base64Encode(bytes);
  return 'data:$mimeType;base64,$encoded';
}

void revokeMediaObjectUrl(String url) {}
