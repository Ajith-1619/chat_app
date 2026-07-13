import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

const ejabberdApi = 'https://chat.skylinkonline.net:5443/api/';
const ejabberdBosh = 'https://chat.skylinkonline.net:5443/bosh';
const proxyVersion = '2026.06.23.2';

class ProxySession {
  const ProxySession({
    required this.cookie,
    required this.employeeId,
    required this.password,
  });

  final String cookie;
  final String employeeId;
  final String password;
}

final sessions = <String, ProxySession>{};
final client = http.Client();
List<Map<String, dynamic>>? directoryCache;
DateTime? directoryCacheAt;
List<Map<String, dynamic>> employeeDirectory = [];

Future<void> main() async {
  if (_adminJid.isEmpty || _adminPassword.isEmpty) {
    stderr.writeln(
      'Set SKYLINK_EJABBERD_ADMIN_JID and '
      'SKYLINK_EJABBERD_ADMIN_PASSWORD before starting the proxy.',
    );
    exitCode = 64;
    return;
  }
  final port =
      int.tryParse(Platform.environment['SKYLINK_PROXY_PORT'] ?? '') ?? 8787;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Skylink dev API proxy: http://127.0.0.1:$port');
  await for (final request in server) {
    unawaited(_handle(request));
  }
}

Future<void> _handle(HttpRequest request) async {
  _cors(request.response);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  try {
    if (request.uri.path == '/health') {
      await _json(request.response, {'status': true, 'version': proxyVersion});
      return;
    }
    if (request.uri.path == '/bosh' && request.method == 'POST') {
      await _bosh(request);
      return;
    }
    if (request.uri.path == '/session/login' && request.method == 'POST') {
      await _login(request);
      return;
    }
    if (request.uri.path == '/users' && request.method == 'GET') {
      await _allUsers(request);
      return;
    }
    if (request.uri.path == '/recent' && request.method == 'GET') {
      await _recent(request);
      return;
    }
    if (request.uri.path == '/history' && request.method == 'GET') {
      final jid = request.uri.queryParameters['jid'] ?? '';
      if (!_validJid(jid)) {
        request.response.statusCode = HttpStatus.badRequest;
        await _json(request.response, {
          'status': false,
          'error': 'Invalid Skylink JID',
        });
        return;
      }
      await _history(request, jid);
      return;
    }
    if (request.uri.path == '/message' && request.method == 'POST') {
      await _sendMessage(request);
      return;
    }
    if (request.uri.path == '/group/create' && request.method == 'POST') {
      await _createGroup(request);
      return;
    }
    if (request.uri.path == '/group/members' && request.method == 'GET') {
      await _groupMembers(request);
      return;
    }
    if (request.uri.path == '/group/member' && request.method == 'POST') {
      await _proxyJsonAction(request, 'manage_group');
      return;
    }
    if (request.uri.path == '/message/delete' && request.method == 'POST') {
      await _proxyJsonAction(request, 'delete_message');
      return;
    }
    if (request.uri.path == '/message/edit' && request.method == 'POST') {
      await _proxyJsonAction(request, 'edit_message');
      return;
    }
    if (request.uri.path == '/presence' && request.method == 'GET') {
      final jid = request.uri.queryParameters['jid'] ?? '';
      if (!_validJid(jid)) {
        request.response.statusCode = HttpStatus.badRequest;
        await _json(request.response, {
          'status': false,
          'error': 'Invalid Skylink JID',
        });
        return;
      }
      await _presence(request, jid);
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await _json(request.response, {
      'status': false,
      'error': 'Endpoint not found',
    });
  } catch (_) {
    try {
      request.response.statusCode = HttpStatus.internalServerError;
      await _json(request.response, {
        'status': false,
        'error': 'Local proxy request failed',
      });
    } catch (_) {
      await request.response.close();
    }
  }
}

Future<void> _bosh(HttpRequest request) async {
  final body = await request.fold<List<int>>(
    <int>[],
    (bytes, chunk) => bytes..addAll(chunk),
  );
  final upstreamRequest = http.Request('POST', Uri.parse(ejabberdBosh))
    ..headers[HttpHeaders.acceptHeader] = 'text/xml, application/xml'
    ..headers[HttpHeaders.contentTypeHeader] =
        request.headers.contentType?.toString() ?? 'text/xml; charset=utf-8'
    ..bodyBytes = body;
  final upstreamResponse = await client.send(upstreamRequest);

  request.response.statusCode = upstreamResponse.statusCode;
  request.response.headers.contentType = ContentType(
    'text',
    'xml',
    charset: 'utf-8',
  );
  await request.response.addStream(upstreamResponse.stream);
  await request.response.close();
}

String get _adminJid =>
    Platform.environment['SKYLINK_EJABBERD_ADMIN_JID']?.trim() ?? '';

String get _adminPassword =>
    Platform.environment['SKYLINK_EJABBERD_ADMIN_PASSWORD'] ?? '';

Future<void> _login(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  final body = jsonDecode(raw) as Map<String, dynamic>;
  final employeeId = '${body['employee_id'] ?? ''}'.trim().replaceFirst(
    RegExp(r'^sky-', caseSensitive: false),
    '',
  );
  final password = '${body['password'] ?? ''}';
  if (employeeId.isEmpty || password.isEmpty) {
    request.response.statusCode = HttpStatus.unprocessableEntity;
    await _json(request.response, {
      'status': false,
      'error': 'Employee ID and password are required',
    });
    return;
  }

  // The browser has already authenticated this JID through Ejabberd BOSH
  // before opening a helper session. Do not authenticate against Launchpad:
  // Ejabberd is the source of truth for Skylink Messenger credentials.
  final token = _token();
  sessions[token] = ProxySession(
    cookie: '',
    employeeId: employeeId,
    password: password,
  );
  await _json(request.response, {
    'status': true,
    'token': token,
    'version': proxyVersion,
  });
}

Future<void> _history(HttpRequest request, String jid) async {
  final session = _sessionFor(request);
  if (session == null) {
    request.response.statusCode = HttpStatus.unauthorized;
    await _json(request.response, {
      'status': false,
      'error': 'Local session expired. Sign in again.',
    });
    return;
  }
  final result = await _launchpadChatAction(session, {
    'action': 'history',
    'jid': jid,
  });
  request.response.statusCode = result.statusCode;
  await _json(request.response, result.body);
}

Future<void> _recent(HttpRequest request) async {
  final session = _sessionFor(request);
  if (session == null) {
    request.response.statusCode = HttpStatus.unauthorized;
    await _json(request.response, {
      'status': false,
      'error': 'Local session expired. Sign in again.',
    });
    return;
  }
  final result = await _launchpadChatAction(session, {'action': 'recent'});
  request.response.statusCode = result.statusCode;
  await _json(request.response, result.body);
}

Future<void> _presence(HttpRequest request, String jid) async {
  final session = _sessionFor(request);
  if (session == null) {
    request.response.statusCode = HttpStatus.unauthorized;
    await _json(request.response, {
      'status': false,
      'error': 'Local session expired. Sign in again.',
    });
    return;
  }
  final authorization = base64Encode(utf8.encode('$_adminJid:$_adminPassword'));
  final response = await client.post(
    Uri.parse('${ejabberdApi}get_last'),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Basic $authorization',
      'X-Admin': 'true',
    },
    body: jsonEncode({
      'user': jid.split('@').first,
      'host': 'chat.skylinkonline.net',
    }),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    request.response.statusCode = HttpStatus.badGateway;
    await _json(request.response, {
      'status': false,
      'error': 'Unable to load presence',
    });
    return;
  }
  final value = jsonDecode(utf8.decode(response.bodyBytes));
  final body = value is Map<String, dynamic>
      ? value
      : Map<String, dynamic>.from(value as Map);
  await _json(request.response, {
    'status': true,
    'online': '${body['status'] ?? ''}'.toUpperCase() == 'ONLINE',
    'last_seen': '${body['timestamp'] ?? ''}',
  });
}

Future<void> _sendMessage(HttpRequest request) async {
  final session = _sessionFor(request);
  if (session == null) {
    request.response.statusCode = HttpStatus.unauthorized;
    await _json(request.response, {
      'status': false,
      'error': 'Local session expired. Sign in again.',
    });
    return;
  }

  final raw = await utf8.decoder.bind(request).join();
  final body = jsonDecode(raw) as Map<String, dynamic>;
  final to = '${body['to'] ?? ''}'.trim();
  final message = '${body['message'] ?? ''}'.trim();
  if (!_validJid(to) || message.isEmpty) {
    request.response.statusCode = HttpStatus.badRequest;
    await _json(request.response, {
      'status': false,
      'error': 'Valid recipient and message are required',
    });
    return;
  }

  final result = await _launchpadChatAction(session, {
    'action': 'send',
    'to': to,
    'message': message,
    'reply_to_id': '${body['reply_to_id'] ?? ''}',
    'mentions': body['mentions'] is List ? body['mentions'] : const [],
    'thread_root_id': '${body['thread_root_id'] ?? ''}',
    'source_device': 'launchpad',
    'source_name': 'Skylink Web',
  });
  request.response.statusCode = result.statusCode;
  await _json(request.response, result.body);
}

Future<void> _groupMembers(HttpRequest request) async {
  final session = _sessionFor(request);
  if (session == null) {
    request.response.statusCode = HttpStatus.unauthorized;
    await _json(request.response, {
      'status': false,
      'error': 'Local session expired. Sign in again.',
    });
    return;
  }
  final groupId = request.uri.queryParameters['group_id'] ?? '';
  final result = await _launchpadChatAction(session, {
    'action': 'group_members',
    'group_id': groupId,
  });
  request.response.statusCode = result.statusCode;
  await _json(request.response, result.body);
}

Future<void> _proxyJsonAction(HttpRequest request, String action) async {
  final session = _sessionFor(request);
  if (session == null) {
    request.response.statusCode = HttpStatus.unauthorized;
    await _json(request.response, {
      'status': false,
      'error': 'Local session expired. Sign in again.',
    });
    return;
  }
  final raw = await utf8.decoder.bind(request).join();
  final body = jsonDecode(raw) as Map<String, dynamic>;
  final result = await _launchpadChatAction(session, {
    'proxy_action': action,
    ...body,
  });
  request.response.statusCode = result.statusCode;
  await _json(request.response, result.body);
}

Future<void> _createGroup(HttpRequest request) async {
  final session = _sessionFor(request);
  if (session == null) {
    request.response.statusCode = HttpStatus.unauthorized;
    await _json(request.response, {
      'status': false,
      'error': 'Local session expired. Sign in again.',
    });
    return;
  }
  final raw = await utf8.decoder.bind(request).join();
  final body = jsonDecode(raw) as Map<String, dynamic>;
  final groupName = '${body['group_name'] ?? ''}'.trim();
  final members = body['members'];
  if (groupName.isEmpty || members is! List || members.isEmpty) {
    request.response.statusCode = HttpStatus.unprocessableEntity;
    await _json(request.response, {
      'status': false,
      'error': 'Group name and members are required',
    });
    return;
  }
  final result = await _launchpadChatAction(session, {
    'action': 'create_group',
    'group_name': groupName,
    'members': members,
  });
  request.response.statusCode = result.statusCode;
  await _json(request.response, result.body);
}

Future<({int statusCode, Map<String, dynamic> body})> _launchpadChatAction(
  ProxySession session,
  Map<String, dynamic> action,
) async {
  if (!Platform.isWindows) {
    return (
      statusCode: HttpStatus.notImplemented,
      body: <String, dynamic>{
        'status': false,
        'error': 'Launchpad chat helper requires Windows PowerShell',
      },
    );
  }
  final process = await Process.start(
    'powershell.exe',
    [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      'tool/launchpad_chat.ps1',
    ],
    workingDirectory: Directory.current.path,
    runInShell: false,
  );
  process.stdin.write(
    jsonEncode({
      'employee_id': session.employeeId,
      'password': session.password,
      ...action,
    }),
  );
  await process.stdin.close();
  final output = await utf8.decoder.bind(process.stdout).join();
  final errorOutput = await utf8.decoder.bind(process.stderr).join();
  final exitCode = await process.exitCode;
  if (exitCode != 0 || output.trim().isEmpty) {
    return (
      statusCode: HttpStatus.badGateway,
      body: <String, dynamic>{
        'status': false,
        'error': errorOutput.trim().isEmpty
            ? 'Launchpad chat helper failed'
            : errorOutput.trim(),
      },
    );
  }
  final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
  return (
    statusCode: decoded['status_code'] as int? ?? 500,
    body: Map<String, dynamic>.from(decoded['body'] as Map? ?? const {}),
  );
}

Future<void> _allUsers(HttpRequest request) async {
  final token = request.headers.value('x-skylink-session') ?? '';
  final session = sessions[token];
  if (session == null) {
    request.response.statusCode = HttpStatus.unauthorized;
    await _json(request.response, {
      'status': false,
      'error': 'Local session expired. Sign in again.',
    });
    return;
  }

  final cachedAt = directoryCacheAt;
  if (directoryCache != null &&
      cachedAt != null &&
      DateTime.now().difference(cachedAt) < const Duration(minutes: 1)) {
    await _respondWithUsers(request, directoryCache!);
    return;
  }

  final authorization = base64Encode(utf8.encode('$_adminJid:$_adminPassword'));
  final registeredResponse = await client.post(
    Uri.parse('${ejabberdApi}registered_users'),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Basic $authorization',
      'X-Admin': 'true',
    },
    body: jsonEncode({'host': 'chat.skylinkonline.net'}),
  );
  if (registeredResponse.statusCode < 200 ||
      registeredResponse.statusCode >= 300) {
    request.response.statusCode = HttpStatus.badGateway;
    await _json(request.response, {
      'status': false,
      'error': 'Ejabberd admin user directory request failed',
    });
    return;
  }

  final registered = jsonDecode(utf8.decode(registeredResponse.bodyBytes));
  if (registered is! List) {
    request.response.statusCode = HttpStatus.badGateway;
    await _json(request.response, {
      'status': false,
      'error': 'Ejabberd returned an invalid user list',
    });
    return;
  }

  final employees = <String, Map<String, dynamic>>{};
  for (final employee in employeeDirectory) {
    employees['${employee['emp_id'] ?? ''}'] = employee;
  }

  final users =
      registered
          .map((value) => '$value'.trim())
          .where((employeeId) => RegExp(r'^\d+$').hasMatch(employeeId))
          .where((employeeId) => employeeId != session.employeeId)
          .map((employeeId) {
            final employee = employees[employeeId];
            return <String, dynamic>{
              'emp_id': employeeId,
              'name': '${employee?['name'] ?? 'Employee $employeeId'}',
              'designation': '${employee?['designation'] ?? ''}',
              'jid': '$employeeId@chat.skylinkonline.net',
            };
          })
          .toList()
        ..sort(
          (a, b) => '${a['name']}'.toLowerCase().compareTo(
            '${b['name']}'.toLowerCase(),
          ),
        );

  directoryCache = users;
  directoryCacheAt = DateTime.now();
  await _respondWithUsers(request, users);
}

ProxySession? _sessionFor(HttpRequest request) {
  final token = request.headers.value('x-skylink-session') ?? '';
  return sessions[token];
}

bool _validJid(String jid) {
  return RegExp(
        r'^\d+@chat\.skylinkonline\.net$',
        caseSensitive: false,
      ).hasMatch(jid) ||
      RegExp(
        r'^[a-z0-9][a-z0-9-]*@conference\.chat\.skylinkonline\.net$',
        caseSensitive: false,
      ).hasMatch(jid);
}

Future<void> _respondWithUsers(
  HttpRequest request,
  List<Map<String, dynamic>> users,
) async {
  final search = (request.uri.queryParameters['search'] ?? '')
      .trim()
      .toLowerCase();
  final filtered = search.isEmpty
      ? users
      : users.where((user) {
          return '${user['emp_id']}'.toLowerCase().contains(search) ||
              '${user['name']}'.toLowerCase().contains(search) ||
              '${user['designation']}'.toLowerCase().contains(search) ||
              '${user['jid']}'.toLowerCase().contains(search);
        }).toList();
  await _json(request.response, {'status': true, 'users': filtered});
}

String _token() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

void _cors(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type, X-Skylink-Session')
    ..set('Cache-Control', 'no-store');
}

Future<void> _json(HttpResponse response, Map<String, dynamic> body) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

void unawaited(Future<void> future) {}
