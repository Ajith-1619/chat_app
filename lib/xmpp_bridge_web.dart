import 'dart:convert';
import 'dart:js_interop';

@JS('skylinkXmpp.connect')
external JSPromise<JSString> _connect(JSString jid, JSString password);

@JS('skylinkXmpp.getRoster')
external JSPromise<JSString> _getRoster();

@JS('skylinkXmpp.getHistory')
external JSPromise<JSString> _getHistory(JSString jid);

@JS('skylinkXmpp.sendMessage')
external JSPromise<JSString> _sendMessage(JSString jid, JSString message);

@JS('skylinkXmpp.requestUploadSlot')
external JSPromise<JSString> _requestUploadSlot(
  JSString filename,
  JSNumber size,
  JSString contentType,
);

@JS('skylinkXmpp.sendAttachment')
external JSPromise<JSString> _sendAttachment(
  JSString jid,
  JSString body,
  JSString url,
);

@JS('skylinkXmpp.disconnect')
external void _disconnect();

class XmppBridge {
  const XmppBridge();

  bool get isSupported => true;

  Future<Map<String, dynamic>> connect(String jid, String password) async {
    final result = await _connect(jid.toJS, password.toJS).toDart;
    return Map<String, dynamic>.from(jsonDecode(result.toDart) as Map);
  }

  Future<List<Map<String, dynamic>>> getRoster() async {
    final result = await _getRoster().toDart;
    final decoded = jsonDecode(result.toDart) as List;
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getHistory(String jid) async {
    final result = await _getHistory(jid.toJS).toDart;
    final decoded = jsonDecode(result.toDart) as List;
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> sendMessage(String jid, String message) async {
    await _sendMessage(jid.toJS, message.toJS).toDart;
  }

  Future<XmppUploadSlot> requestUploadSlot({
    required String filename,
    required int size,
    required String contentType,
  }) async {
    final result = await _requestUploadSlot(
      filename.toJS,
      size.toJS,
      contentType.toJS,
    ).toDart;
    final decoded = Map<String, dynamic>.from(jsonDecode(result.toDart) as Map);
    return XmppUploadSlot.fromJson(decoded);
  }

  Future<void> sendAttachment({
    required String jid,
    required String body,
    required String url,
  }) async {
    await _sendAttachment(jid.toJS, body.toJS, url.toJS).toDart;
  }

  void disconnect() => _disconnect();
}

class XmppUploadSlot {
  const XmppUploadSlot({
    required this.putUrl,
    required this.getUrl,
    required this.headers,
  });

  factory XmppUploadSlot.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    return XmppUploadSlot(
      putUrl: '${json['put_url'] ?? ''}',
      getUrl: '${json['get_url'] ?? ''}',
      headers: rawHeaders is Map
          ? rawHeaders.map((key, value) => MapEntry('$key', '$value'))
          : const {},
    );
  }

  final String putUrl;
  final String getUrl;
  final Map<String, String> headers;
}
