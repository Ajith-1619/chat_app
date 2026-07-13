class XmppBridge {
  const XmppBridge();

  bool get isSupported => false;

  Future<Map<String, dynamic>> connect(String jid, String password) {
    throw UnsupportedError('Direct XMPP is only enabled for the web build.');
  }

  Future<List<Map<String, dynamic>>> getRoster() {
    throw UnsupportedError('Direct XMPP is only enabled for the web build.');
  }

  Future<List<Map<String, dynamic>>> getHistory(String jid) {
    throw UnsupportedError('Direct XMPP is only enabled for the web build.');
  }

  Future<void> sendMessage(String jid, String message) {
    throw UnsupportedError('Direct XMPP is only enabled for the web build.');
  }

  Future<XmppUploadSlot> requestUploadSlot({
    required String filename,
    required int size,
    required String contentType,
  }) {
    throw UnsupportedError(
      'XMPP file upload is only enabled for the web build.',
    );
  }

  Future<void> sendAttachment({
    required String jid,
    required String body,
    required String url,
  }) {
    throw UnsupportedError(
      'XMPP file upload is only enabled for the web build.',
    );
  }

  void disconnect() {}
}

class XmppUploadSlot {
  const XmppUploadSlot({
    required this.putUrl,
    required this.getUrl,
    required this.headers,
  });

  final String putUrl;
  final String getUrl;
  final Map<String, String> headers;
}
