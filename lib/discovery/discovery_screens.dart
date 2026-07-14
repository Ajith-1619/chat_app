import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

import '../chat_api.dart';
import '../location_tracking_service.dart';
import '../notification_service.dart';
import '../session_store.dart';
import '../myhub_leave_screens.dart';
import '../myhub_tasks_screen.dart';
import '../flow_registry.dart';
import '../mojibake_tools.dart';
import '../clipboard_media_bridge.dart';
import '../clipboard_text_bridge.dart';
import '../file_preview_embed.dart';
import '../web_attachment_bridge.dart';
import '../web_file_actions.dart';
import '../xmpp_bridge.dart';

import '../app/skylink_app.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../discovery/discovery_screens.dart';
import '../reminders/reminders_screens.dart';
import '../settings/settings_screens.dart';
import '../release/release_screens.dart';
import '../tickets/ticket_dashboard_screen.dart';
import '../profile/profile_screens.dart';
import '../chat/chat_screen.dart';
import '../attachments/attachment_widgets.dart';

class DiscoveryListScreen extends StatefulWidget {
  const DiscoveryListScreen({
    super.key,
    required this.title,
    required this.view,
    this.jid = '',
  });

  final String title;
  final String view;
  final String jid;

  @override
  State<DiscoveryListScreen> createState() => _DiscoveryListScreenState();
}

class _DiscoveryListScreenState extends State<DiscoveryListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = chatApi.getDiscovery(view: widget.view, jid: widget.jid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final values = snapshot.data ?? const [];
          if (values.isEmpty) {
            return Center(
              child: Text('No ${widget.title.toLowerCase()} found.'),
            );
          }
          return ListView.separated(
            itemCount: values.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final item = values[index];
              final fileName = '${item['file_name'] ?? ''}';
              return ListTile(
                leading: Icon(
                  fileName.isNotEmpty
                      ? Icons.attach_file_rounded
                      : Icons.chat_bubble_outline_rounded,
                ),
                title: Text(
                  fileName.isNotEmpty ? fileName : '${item['body'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "${item['from'] ?? ''} ? ${item['created_at'] ?? ''}",
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  Timer? _timer;
  bool _loading = false;
  Map<String, dynamic> _results = {};

  Future<void> _search(String value) async {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().isEmpty) {
        if (mounted) setState(() => _results = {});
        return;
      }
      setState(() => _loading = true);
      try {
        final result = await chatApi.globalSearch(value.trim());
        if (mounted) setState(() => _results = result);
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
  }

  ChatPreview _previewFromSearchItem(Map<String, dynamic> item) {
    final jid = '${item['conversation_jid'] ?? item['jid'] ?? ''}'.trim();
    final type = '${item['conversation_type'] ?? item['type'] ?? 'chat'}'.trim();
    final name = '${item['conversation_name'] ?? item['name'] ?? jid.split('@').first}'.trim();
    final empId = type == 'chat'
        ? '${item['emp_id'] ?? item['id'] ?? jid.split('@').first}'.trim()
        : '${item['id'] ?? ''}'.trim();
    final contact = ChatContact(
      empId: empId.isEmpty ? jid.split('@').first : empId,
      name: name.isEmpty ? jid : name,
      designation: '${item['designation'] ?? ''}',
      jid: jid.toLowerCase(),
      type: type.isEmpty ? 'chat' : type,
      lastMessage: '${item['body'] ?? item['caption'] ?? item['file_name'] ?? ''}',
      time: '${item['created_at'] ?? item['time'] ?? ''}',
      avatarUrl: '${item['avatar_url'] ?? ''}',
    );
    return ChatPreview.fromContact(contact);
  }

  Future<void> _openSearchChat(Map<String, dynamic> item, {int messageId = 0}) async {
    final chat = _previewFromSearchItem(item);
    if (chat.jid.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(chat: chat, initialMessageId: messageId),
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) {
      _controller.text = widget.initialQuery.trim();
      _search(_controller.text);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _results['messages'] is List
        ? _results['messages'] as List
        : const [];
    final conversations = _results['conversations'] is List
        ? _results['conversations'] as List
        : const [];
    final users = _results['users'] is List
        ? _results['users'] as List
        : const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Search everything')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText:
                    'Messages, users, channels, groups, tasks, tickets, files',
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                if (conversations.isNotEmpty)
                  const ListTile(
                    title: Text(
                      'Channels and groups',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ...conversations.map(
                  (item) {
                    final data = Map<String, dynamic>.from(item as Map);
                    return ListTile(
                      leading: Icon(
                        '${data['type']}' == 'channel'
                            ? Icons.tag_rounded
                            : Icons.groups_outlined,
                      ),
                      title: Text('${data['name'] ?? ''}'),
                      subtitle: Text('${data['type'] ?? ''}'),
                      onTap: () => _openSearchChat(data),
                    );
                  },
                ),
                if (users.isNotEmpty)
                  const ListTile(
                    title: Text(
                      'Users',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ...users.map(
                  (item) => ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text('${item['name'] ?? ''}'),
                    subtitle: Text(
                      "${item['designation'] ?? ''} - ${item['jid'] ?? ''}",
                    ),
                    onTap: () {
                      final contact = ChatContact.fromJson(
                        Map<String, dynamic>.from(item as Map),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(
                            chat: ChatPreview.fromContact(contact),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (messages.isNotEmpty)
                  const ListTile(
                    title: Text(
                      'Messages, files and attachments',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ...messages.map(
                  (item) {
                    final data = Map<String, dynamic>.from(item as Map);
                    final fileName = '${data['file_name'] ?? ''}';
                    final caption = '${data['caption'] ?? ''}';
                    final body = '${data['body'] ?? ''}';
                    final messageId = int.tryParse('${data['id'] ?? 0}') ?? 0;
                    final conversationName = '${data['conversation_name'] ?? ''}';
                    final createdAt = '${data['created_at'] ?? ''}';
                    return ListTile(
                      leading: Icon(
                        fileName.isNotEmpty
                            ? Icons.attach_file_rounded
                            : Icons.chat_bubble_outline_rounded,
                      ),
                      title: Text(
                        fileName.isNotEmpty
                            ? fileName
                            : (caption.isNotEmpty ? caption : body),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (conversationName.isNotEmpty) conversationName,
                          if (createdAt.isNotEmpty) createdAt,
                        ].join(' - '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _openSearchChat(data, messageId: messageId),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMediaBrowser extends StatelessWidget {
  const ChatMediaBrowser({super.key, required this.chat});

  final ChatPreview chat;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Media',
      'Files',
      'Links',
      'Voice Notes',
      'Tasks',
      'Shared Channels',
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${chat.name} media'),
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs.map((label) => Tab(text: label)).toList(),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: chatApi.getDiscovery(view: 'media', jid: chat.jid),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snapshot.data ?? const [];
            List<Map<String, dynamic>> filter(String tab) {
              return all.where((item) {
                final type = '${item['file_type'] ?? ''}'.toLowerCase();
                final body = '${item['body'] ?? ''}'.toLowerCase();
                final file = '${item['file_name'] ?? ''}';
                return switch (tab) {
                  'Media' =>
                    type.startsWith('image/') || type.startsWith('video/'),
                  'Files' =>
                    file.isNotEmpty &&
                        !type.startsWith('image/') &&
                        !type.startsWith('video/') &&
                        !type.startsWith('audio/'),
                  'Links' => RegExp(r'https?://').hasMatch(body),
                  'Voice Notes' => type.startsWith('audio/'),
                  'Tasks' =>
                    body.contains('task') ||
                        '${item['message_type']}' == 'task',
                  'Shared Channels' =>
                    body.contains('#channel') ||
                        body.contains('conference.chat'),
                  _ => true,
                };
              }).toList();
            }

            return TabBarView(
              children: tabs.map((tab) {
                final values = filter(tab);
                if (values.isEmpty) {
                  return Center(child: Text('No $tab found.'));
                }
                return ListView.builder(
                  itemCount: values.length,
                  itemBuilder: (_, index) {
                    final item = values[index];
                    return ListTile(
                      leading: Icon(
                        tab == 'Links'
                            ? Icons.link_rounded
                            : tab == 'Media'
                            ? Icons.photo_outlined
                            : Icons.insert_drive_file_outlined,
                      ),
                      title: Text(
                        '${item['file_name'] ?? ''}'.isNotEmpty
                            ? '${item['file_name']}'
                            : '${item['body'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${item['created_at'] ?? ''}'),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }


}
