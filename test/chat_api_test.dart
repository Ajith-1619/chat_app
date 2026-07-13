import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skylink_chat/chat_api.dart';

void main() {
  test('employee ID maps to Launchpad username and XMPP JID', () {
    final api = ChatApi();
    addTearDown(api.close);

    expect(api.launchpadUsername('302'), 'sky-302');
    expect(api.launchpadUsername('302@chat.skylinkonline.net'), 'sky-302');
    expect(api.employeeJid('sky-302'), '302@chat.skylinkonline.net');
  });

  test('chat contact parses server presence and unread variants', () {
    final contact = ChatContact.fromJson({
      'emp_id': '302',
      'jid': '302@chat.skylinkonline.net',
      'name': 'Test User',
      'online': '1',
      'unread_count': '4',
    });

    expect(contact.isOnline, isTrue);
    expect(contact.unread, 4);
  });

  test('advanced diagnostics are restricted to 116 and 302', () {
    expect(ChatApi.diagnosticEmployeeIds, containsAll(['116', '302']));
    expect(ChatApi.diagnosticEmployeeIds, isNot(contains('218')));
  });

  test('attachment metadata survives an XMPP message round trip', () {
    const attachment = ChatAttachment(
      name: 'invoice.pdf',
      url: 'https://chat.skylinkonline.net:5443/upload/token/invoice.pdf',
      mimeType: 'application/pdf',
      size: 2048,
      caption: 'June invoice',
    );

    final parsed = ChatAttachment.tryParse(attachment.encode());

    expect(parsed?.name, 'invoice.pdf');
    expect(parsed?.url, attachment.url);
    expect(parsed?.size, 2048);
    expect(parsed?.caption, 'June invoice');
    expect(parsed?.isImage, isFalse);
  });

  test('image extension enables preview when legacy MIME type is generic', () {
    const attachment = ChatAttachment(
      name: 'photo1719399266-min.jpg',
      url: 'https://chat.skylinkonline.net/upload/photo.jpg',
      mimeType: 'application/octet-stream',
      size: 89800,
    );

    expect(attachment.isImage, isTrue);
  });

  test('release note parses all required sections', () {
    final note = ReleaseNote.fromJson({
      'id': '7',
      'platform': 'android',
      'version': '1.3.8',
      'release_date': '2026-06-24',
      'new_features': 'What’s New',
      'improvements': 'Faster user search',
      'bug_fixes': 'Fixed loading states',
      'security_updates': 'Viewed state is per user',
      'implementation_details': 'Backed by release_notes table',
      'viewed': '0',
    });

    expect(note.id, 7);
    expect(note.version, '1.3.8');
    expect(note.viewed, isFalse);
    expect(note.isEmpty, isFalse);
  });

  test('release note API fetches current installed version', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Skylink',
      packageName: 'com.skylink.chat',
      version: '1.3.8',
      buildNumber: '17',
      buildSignature: '',
    );
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/chat/release_notes.php'));
      expect(request.url.queryParameters['version'], '1.3.8');
      return http.Response(
        '{"status":true,"note":{"id":1,"platform":"android","version":"1.3.8","release_date":"2026-06-24","new_features":"A","improvements":"B","bug_fixes":"C","security_updates":"D","implementation_details":"E","viewed":0}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ChatApi(client: client);
    addTearDown(api.close);

    final note = await api.getReleaseNotes();

    expect(note?.version, '1.3.8');
    expect(note?.securityUpdates, 'D');
  });
  test(
    'sendMessage preserves client id and source metadata for integrity',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'Skylink',
        packageName: 'com.skylink.chat',
        version: '1.4.1',
        buildNumber: '41',
        buildSignature: '',
      );
      Map<String, dynamic> payload = {};
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/chat/send_message.php'));
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '{"status":true,"message_id":123}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ChatApi(client: client);
      addTearDown(api.close);

      final id = await api.sendMessage(
        to: '116@chat.skylinkonline.net',
        message: 'Integrity check',
        clientMessageId: 'client-1',
        latitude: 13.0,
        longitude: 80.0,
      );

      expect(id, 123);
      expect(payload['to'], '116@chat.skylinkonline.net');
      expect(payload['message'], 'Integrity check');
      expect(payload['client_message_id'], 'client-1');
      expect(payload['latitude'], 13.0);
      expect(payload['longitude'], 80.0);
      expect(payload['source_device'], isNotEmpty);
      expect(payload['source_name'], isNotEmpty);
    },
  );

  test(
    'sendMessage treats duplicate client id as delivered message id',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'Skylink',
        packageName: 'com.skylink.chat',
        version: '1.4.1',
        buildNumber: '41',
        buildSignature: '',
      );
      final client = MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['client_message_id'], 'duplicate-safe-id');
        return http.Response(
          '{"status":true,"message_id":777,"duplicate":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ChatApi(client: client);
      addTearDown(api.close);

      final id = await api.sendMessage(
        to: '116@chat.skylinkonline.net',
        message: 'Duplicate guard',
        clientMessageId: 'duplicate-safe-id',
      );

      expect(id, 777);
    },
  );

  test('system notification JID is receive-only', () async {
    final contact = ChatContact.fromJson({
      'jid': systemNotificationJid,
      'name': 'notification',
    });
    expect(contact.type, 'notification');
    expect(contact.jid, systemNotificationJid);

    var networkCalled = false;
    final api = ChatApi(
      client: MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 500);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.sendMessage(to: systemNotificationJid, message: 'reply'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    expect(networkCalled, isFalse);
  });
}
