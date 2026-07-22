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

class ChatPreview {
  const ChatPreview({
    this.empId = '',
    this.jid = '',
    required this.name,
    this.designation = '',
    required this.message,
    required this.time,
    required this.avatarColor,
    this.unread = 0,
    this.isOnline = false,
    this.isGroup = false,
    this.isPinned = false,
    this.isMuted = false,
    this.sentByMe = false,
    this.wasMentioned = false,
    this.avatarUrl = '',
    this.isStarred = false,
    this.originalSenderJid = '',
    this.originalSenderName = '',
    this.originalSourceName = '',
    this.isChannel = false,
  });

  factory ChatPreview.fromContact(ChatContact contact) {
    const colors = [
      Color(0xFF9C5DE8),
      Color(0xFF2B80D9),
      Color(0xFFEF7B45),
      Color(0xFF35A876),
      Color(0xFFE2557A),
      Color(0xFF6A63D8),
      Color(0xFF18A2AE),
    ];
    final attachment = ChatAttachment.tryParse(contact.lastMessage);
    return ChatPreview(
      empId: contact.empId,
      jid: contact.jid,
      name: contact.name.isEmpty ? contact.empId : contact.name,
      designation: contact.designation,
      message: attachment == null
          ? _plainMessagePreview(contact.lastMessage)
          : 'Attachment: ${attachment.name}',
      time: _displayChatTime(contact.time),
      avatarColor: colors[contact.empId.hashCode.abs() % colors.length],
      unread: contact.unread,
      isOnline: contact.isOnline,
      isGroup: contact.type != 'chat',
      isChannel: contact.type == 'channel',
      isPinned: contact.isPinned,
      isStarred: contact.isStarred,
      wasMentioned: contact.wasMentioned,
      avatarUrl: contact.avatarUrl,
    );
  }

  final String empId;
  final String jid;
  final String name;
  final String designation;
  final String message;
  final String time;
  final Color avatarColor;
  final int unread;
  final bool isOnline;
  final bool isGroup;
  final bool isPinned;
  final bool isMuted;
  final bool sentByMe;
  final bool wasMentioned;
  final String avatarUrl;
  final bool isStarred;
  final String originalSenderJid;
  final String originalSenderName;
  final String originalSourceName;
  final bool isChannel;
}

class _InlineSearchResult {
  const _InlineSearchResult({
    required this.chat,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.messageId = 0,
    this.isMessage = false,
  });

  final ChatPreview chat;
  final String title;
  final String subtitle;
  final IconData icon;
  final int messageId;
  final bool isMessage;
}

ChatPreview _chatPreviewFromSearchItem(Map<String, dynamic> item) {
  final jid = '${item['conversation_jid'] ?? item['jid'] ?? ''}'.trim();
  final type = '${item['conversation_type'] ?? item['type'] ?? 'chat'}'.trim();
  final name =
      '${item['conversation_name'] ?? item['name'] ?? jid.split('@').first}'
          .trim();
  final empId = type == 'chat'
      ? '${item['emp_id'] ?? item['id'] ?? jid.split('@').first}'.trim()
      : '${item['id'] ?? ''}'.trim();
  return ChatPreview.fromContact(
    ChatContact(
      empId: empId.isEmpty ? jid.split('@').first : empId,
      name: name.isEmpty ? jid : name,
      designation: '${item['designation'] ?? ''}',
      jid: jid.toLowerCase(),
      type: type.isEmpty ? 'chat' : type,
      lastMessage:
          '${item['body'] ?? item['caption'] ?? item['file_name'] ?? ''}',
      time: '${item['created_at'] ?? item['time'] ?? ''}',
      avatarUrl: '${item['avatar_url'] ?? ''}',
    ),
  );
}

String _displayChatTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) {
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
  return '${local.day}/${local.month}/${local.year}';
}

String _plainMessagePreview(String value) {
  return value
      .replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6}\]'), '')
      .replaceAll('[/color]', '')
      .replaceAll('**', '')
      .replaceAll('~~', '')
      .replaceAll('_', '')
      .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
      .trim();
}

String formatFileBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

const chats = [
  ChatPreview(
    name: 'Priya Sharma',
    message: 'Perfect! See you tomorrow!',
    time: '10:42 AM',
    unread: 2,
    isOnline: true,
    avatarColor: Color(0xFF9C5DE8),
  ),
  ChatPreview(
    name: 'Skylink Design Team',
    message: 'Arun: I have shared the new screens',
    time: '10:18 AM',
    unread: 5,
    isGroup: true,
    isPinned: true,
    avatarColor: Color(0xFF2B80D9),
  ),
  ChatPreview(
    name: 'Rahul Kumar',
    message: 'The project looks great!',
    time: 'Yesterday',
    sentByMe: true,
    avatarColor: Color(0xFFEF7B45),
  ),
  ChatPreview(
    name: 'Family',
    message: 'Mom: Dinner at 8 tonight <3',
    time: 'Yesterday',
    isGroup: true,
    isMuted: true,
    avatarColor: Color(0xFF35A876),
  ),
  ChatPreview(
    name: 'Vikram Singh',
    message: 'Voice message',
    time: 'Mon',
    isOnline: true,
    avatarColor: Color(0xFFE2557A),
  ),
  ChatPreview(
    name: 'Weekend Crew',
    message: 'Meera: Who is joining this weekend?',
    time: 'Sun',
    unread: 1,
    isGroup: true,
    avatarColor: Color(0xFF6A63D8),
  ),
  ChatPreview(
    name: 'Ananya',
    message: 'Thank you so much!',
    time: 'Sat',
    sentByMe: true,
    avatarColor: Color(0xFF18A2AE),
  ),
  ChatPreview(
    name: 'Office Updates',
    message: 'Meeting moved to 3:30 PM',
    time: 'Fri',
    isGroup: true,
    isMuted: true,
    avatarColor: Color(0xFF56657C),
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.currentUser});

  final CurrentUser currentUser;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _androidSettings = MethodChannel('skylink/android_settings');
  final _searchController = TextEditingController();
  final _filterScrollController = ScrollController();
  final List<ChatPreview> _liveChats = [];
  final Map<String, String> _knownChatTimes = {};
  Timer? _pollTimer;
  Timer? _searchDebounce;
  Timer? _pushRetryTimer;
  Timer? _connectivityTimer;
  StreamSubscription<String>? _pushTokenSubscription;
  String _query = '';
  int _filter = 0;
  List<int> _filterOrder = const [0, 1, 6, 2, 3, 4, 5];
  Map<String, List<String>> _chatFolders = const {};
  List<String> _chatFolderOrder = const [];
  String _activeFolderName = '';
  bool _isLoading = true;
  bool _chatRefreshActive = false;
  String? _loadError;
  ChatPreview? _selectedDesktopChat;
  int _selectedDesktopInitialMessageId = 0;
  bool _showDesktopProfile = false;
  bool _attendanceActive = false;
  bool _offlineBannerVisible = false;
  bool _inlineSearchLoading = false;
  Map<String, dynamic> _inlineSearchResults = const {};

  List<ChatPreview> get _filteredChats {
    return _liveChats.where((chat) {
      final matchesQuery =
          chat.name.toLowerCase().contains(_query.toLowerCase()) ||
          chat.message.toLowerCase().contains(_query.toLowerCase());
      final activeFolder = _activeFolderName.trim();
      final matchesFolder =
          activeFolder.isEmpty ||
          (_chatFolders[activeFolder] ?? const <String>[]).contains(chat.jid);
      final matchesFilter = switch (_filter) {
        1 => chat.unread > 0,
        2 => !chat.isGroup,
        3 => chat.isGroup && !chat.isChannel,
        4 => chat.isChannel,
        5 => chat.isStarred,
        6 => chat.isOnline,
        _ => true,
      };
      return matchesQuery && matchesFilter && matchesFolder;
    }).toList();
  }

  int get _unreadCount =>
      _liveChats.fold(0, (total, chat) => total + chat.unread);

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadFilterOrder();
    _loadChatFolders();
    _resumeAttendanceTracking();
    _registerPushNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWhatsNew();
    });
    _pushTokenSubscription = NotificationService.instance.onTokenRefresh.listen(
      (token) => chatApi.registerPushToken(token).catchError((_) {}),
    );
    _pushRetryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _registerPushNotifications(),
    );
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadChats(silent: true),
    );
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkPunchedInConnectivity(),
    );
    _checkPunchedInConnectivity();
  }

  Future<void> _maybeShowWhatsNew() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();
      final localKey =
          'release_notes_prompted_${widget.currentUser.empId}_${package.version}';
      if (prefs.getBool(localKey) == true) return;
      final note = await chatApi.getReleaseNotes().timeout(
        const Duration(seconds: 5),
      );
      if (!mounted || note == null || note.viewed || note.isEmpty) {
        await prefs.setBool(localKey, true);
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('What\'s new in v${note.version}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(child: ReleaseNoteContent(note: note)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                unawaited(chatApi.markReleaseNoteViewed(note.id));
                Navigator.pop(context);
              },
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      await prefs.setBool(localKey, true);
    } catch (error) {
      // Release notes must never block chat startup.
    }
  }

  Future<void> _resumeAttendanceTracking() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final attendance = await chatApi.getAttendance();
      if (!attendance.hasPunchedIn || attendance.hasPunchedOut) {
        _attendanceActive = false;
        await LocationTrackingService.instance.stop();
        return;
      }
      _attendanceActive = true;
      final tracking = await chatApi.startLocationTracking(attendance.shiftId);
      await LocationTrackingService.instance.start(tracking.$2);
    } catch (error) {
      // Attendance tracking retries when the profile is opened or app restarts.
    }
  }

  Future<void> _checkPunchedInConnectivity() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final attendance = await chatApi.getAttendance();
      _attendanceActive = attendance.hasPunchedIn && !attendance.hasPunchedOut;
    } catch (error) {
      // A failed attendance request can itself be caused by no internet.
    }
    if (!_attendanceActive) {
      if (_offlineBannerVisible && mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        _offlineBannerVisible = false;
      }
      return;
    }
    var online = false;
    try {
      final addresses = await InternetAddress.lookup(
        'chat.skylinkonline.net',
      ).timeout(const Duration(seconds: 5));
      online = addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } catch (error) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      if (_offlineBannerVisible) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        _offlineBannerVisible = false;
      }
      return;
    }
    if (_offlineBannerVisible) return;
    _offlineBannerVisible = true;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.wifi_off_rounded, color: Colors.red),
        content: const Text(
          'Attendance is active, but this phone is offline. Enable mobile data '
          'or connect to Wi-Fi so location tracking can continue.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await _androidSettings.invokeMethod<void>(
                  'openWirelessSettings',
                );
              } catch (error) {
                await ph.openAppSettings();
              }
            },
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerPushNotifications() async {
    final token =
        NotificationService.instance.fcmToken ??
        await NotificationService.instance.refreshToken();
    if (token == null || token.isEmpty) return;
    try {
      await chatApi.registerPushToken(token);
    } catch (error) {
      // Retry automatically while the signed-in app remains active.
    }
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (_chatRefreshActive) return;
    _chatRefreshActive = true;
    try {
      final contacts = await chatApi.getRecentChats();
      if (!mounted) return;
      if (_knownChatTimes.isNotEmpty) {
        for (final contact in contacts) {
          final oldTime = _knownChatTimes[contact.jid];
          if (contact.time.isNotEmpty &&
              oldTime != null &&
              oldTime != contact.time) {
            try {
              if (contact.unread > 0 &&
                  NotificationService.instance.fcmToken == null) {
                await NotificationService.instance.showMessage(
                  sender: contact.name,
                  message: contact.lastMessage,
                  jid: contact.jid,
                );
              }
            } catch (error) {
              // A notification failure must never break chat refresh.
            }
          }
        }
      }
      for (final contact in contacts) {
        if (contact.time.isNotEmpty) {
          _knownChatTimes[contact.jid] = contact.time;
        }
      }
      setState(() {
        final previews = contacts.map(ChatPreview.fromContact).toList();
        if (!previews.any((chat) => chat.jid == _savedMessagesJid)) {
          previews.insert(0, _savedMessagesPreview);
        }
        _liveChats
          ..clear()
          ..addAll(previews);
        _isLoading = false;
        _loadError = null;
      });
      unawaited(
        chatApi.prefetchHistories(
          contacts
              .where((contact) => contact.lastMessage.isNotEmpty)
              .map((contact) => contact.jid),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        _handleSessionExpired();
      } else if (!silent) {
        setState(() {
          _isLoading = false;
          _loadError = error.message;
        });
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _loadError = 'Unable to load conversations.';
        });
      }
    } finally {
      _chatRefreshActive = false;
    }
  }

  void _handleSessionExpired() {
    _pollTimer?.cancel();
    chatApi.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchDebounce?.cancel();
    _pushRetryTimer?.cancel();
    _connectivityTimer?.cancel();
    _pushTokenSubscription?.cancel();
    _searchController.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  String get _filterOrderKey => 'chat_filter_order_${widget.currentUser.empId}';

  static const String _chatFoldersStorageKey = 'chat_folders_v1';

  String _filterLabel(int filter) => switch (filter) {
    1 => 'Unread',
    2 => 'Personal',
    3 => 'Groups',
    4 => 'Channels',
    5 => 'Starred',
    6 => 'Online',
    _ => 'All',
  };

  Future<void> _loadFilterOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_filterOrderKey);
    if (saved == null) return;
    final values = saved.map(int.tryParse).whereType<int>().toList();
    const expected = {0, 1, 2, 3, 4, 5, 6};
    if (values.length != expected.length ||
        values.toSet().length != expected.length ||
        !values.toSet().containsAll(expected)) {
      return;
    }
    if (mounted) setState(() => _filterOrder = values);
  }

  Future<void> _saveFilterOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _filterOrderKey,
      _filterOrder.map((value) => value.toString()).toList(),
    );
  }

  Future<void> _loadChatFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatFoldersStorageKey);
    if (raw == null || raw.isEmpty) {
      if (mounted) {
        setState(() {
          _chatFolders = const {};
          _chatFolderOrder = const [];
          _activeFolderName = '';
        });
      }
      return;
    }
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final folders = decoded.map(
        (name, values) =>
            MapEntry(name, (values as List).map((value) => '$value').toList()),
      );
      if (!mounted) return;
      setState(() {
        _chatFolders = folders;
        _chatFolderOrder = folders.keys.toList();
        if (_activeFolderName.isNotEmpty &&
            !_chatFolders.containsKey(_activeFolderName)) {
          _activeFolderName = '';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _chatFolders = const {};
          _chatFolderOrder = const [];
          _activeFolderName = '';
        });
      }
    }
  }

  Widget _buildChatFilter(int filter) {
    final label = _filterLabel(filter);
    return _FilterChip(
      key: ValueKey('chat-filter-$filter'),
      label: label,
      count: filter == 1 ? _unreadCount : null,
      selected: _activeFolderName.isEmpty && _filter == filter,
      onTap: () => setState(() {
        _activeFolderName = '';
        _filter = filter;
      }),
      onLongPress: () => _showFilterActions(label, filter),
    );
  }

  Widget _buildChatFolderFilter(String folderName) {
    final count = _liveChats
        .where(
          (chat) =>
              (_chatFolders[folderName] ?? const <String>[]).contains(chat.jid),
        )
        .length;
    return _FilterChip(
      key: ValueKey('chat-folder-$folderName'),
      label: folderName,
      count: count,
      selected: _activeFolderName == folderName,
      onTap: () => setState(() {
        _activeFolderName = folderName;
        _filter = 0;
      }),
      onLongPress: () => _showFolderActions(folderName),
    );
  }

  Widget _buildFilterStrip({
    EdgeInsets padding = const EdgeInsets.fromLTRB(10, 0, 10, 8),
  }) {
    final chips = [
      ..._filterOrder.map(_buildChatFilter),
      ..._chatFolderOrder
          .where((name) => name.trim().isNotEmpty)
          .map(_buildChatFolderFilter),
    ];
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scrollbar(
        controller: _filterScrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _filterScrollController,
          scrollDirection: Axis.horizontal,
          primary: false,
          padding: padding,
          child: Row(
            children: [
              ...chips,
              Tooltip(
                message: 'Reorder filters',
                child: IconButton.filledTonal(
                  onPressed: _reorderFilters,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reorderFilters() async {
    var order = List<int>.from(_filterOrder);
    final updated = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reorder chat filters'),
          content: SizedBox(
            width: 360,
            height: 420,
            child: ReorderableListView.builder(
              itemCount: order.length,
              onReorder: (oldIndex, newIndex) {
                setDialogState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = order.removeAt(oldIndex);
                  order.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final filter = order[index];
                return ListTile(
                  key: ValueKey(filter),
                  leading: const Icon(Icons.drag_handle_rounded),
                  title: Text(_filterLabel(filter)),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, order),
              child: const Text('Save order'),
            ),
          ],
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _filterOrder = updated);
    await _saveFilterOrder();
  }

  Future<void> _showFolderActions(String folderName) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: Text(folderName),
              subtitle: Text(
                '${(_chatFolders[folderName] ?? const <String>[]).length} conversations',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Manage chat folders'),
              onTap: () => Navigator.pop(sheetContext, 'folders'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action != 'folders') return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatFoldersScreen(chats: _liveChats),
      ),
    );
    await _loadChatFolders();
  }

  Future<void> _showFilterActions(String label, int filter) async {
    final scoped = _liveChats.where((chat) {
      return switch (filter) {
        2 => !chat.isGroup,
        3 => chat.isGroup && !chat.isChannel,
        4 => chat.isChannel,
        _ => true,
      };
    }).toList();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('$label options'),
              subtitle: Text('${scoped.length} conversations'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert_rounded),
              title: const Text('Reorder filters'),
              subtitle: const Text('Saved separately for your account'),
              onTap: () => Navigator.pop(sheetContext, 'reorder'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Chat folders'),
              subtitle: const Text('Create, display and reorder folders'),
              onTap: () => Navigator.pop(sheetContext, 'folders'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text('Mute all $label notifications'),
              onTap: () => Navigator.pop(sheetContext, 'mute'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text('Unmute all $label notifications'),
              onTap: () => Navigator.pop(sheetContext, 'unmute'),
            ),
            if (filter == 3 || filter == 4)
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Edit group/channel settings'),
                subtitle: const Text('Choose a conversation to manage'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reorder') {
      await _reorderFilters();
    } else if (action == 'folders') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatFoldersScreen(chats: _liveChats),
        ),
      );
      await _loadChatFolders();
      return;
    }
    if (action == 'mute' || action == 'unmute') {
      final muted = action == 'mute';
      await Future.wait(
        scoped.map((chat) => chatApi.setMuted(chat.jid, muted)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              muted
                  ? '$label notifications muted.'
                  : '$label notifications enabled.',
            ),
          ),
        );
      }
      return;
    }
    if (action == 'edit' && scoped.isNotEmpty && mounted) {
      final chosen = await showDialog<ChatPreview>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Choose conversation'),
          children: scoped
              .map(
                (chat) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, chat),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(chat: chat, radius: 20),
                    title: Text(chat.name),
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (chosen != null && mounted) _openChat(chosen);
    }
  }

  Future<bool> _handleChatSwipe(
    ChatPreview chat,
    DismissDirection direction,
  ) async {
    try {
      if (direction == DismissDirection.startToEnd) {
        await chatApi.getHistory(chat.jid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All messages marked as read.')),
          );
        }
      } else if (direction == DismissDirection.endToStart) {
        await chatApi.setMuted(chat.jid, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${chat.name} notifications muted.')),
          );
        }
      }
      await _loadChats(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    return false;
  }

  static const String _savedMessagesJid = 'saved@chat.skylinkonline.net';

  ChatPreview get _savedMessagesPreview => const ChatPreview(
    empId: 'saved',
    jid: _savedMessagesJid,
    name: 'Saved Messages',
    designation: 'Private notes',
    message: 'Save messages, notes and files for yourself',
    time: '',
    avatarColor: AppColors.primary,
    isPinned: true,
  );

  void _onHomeSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _inlineSearchResults = const {};
        _inlineSearchLoading = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _inlineSearchLoading = true);
      try {
        final results = await chatApi.globalSearch(query);
        if (!mounted || _query.trim() != query) return;
        setState(() => _inlineSearchResults = results);
      } catch (_) {
        if (!mounted || _query.trim() != query) return;
        setState(() => _inlineSearchResults = const {});
      } finally {
        if (mounted && _query.trim() == query) {
          setState(() => _inlineSearchLoading = false);
        }
      }
    });
  }

  Future<void> _openSavedMessages() async {
    if (MediaQuery.sizeOf(context).width >= 900) {
      setState(() {
        _selectedDesktopChat = _savedMessagesPreview;
        _selectedDesktopInitialMessageId = 0;
        _showDesktopProfile = false;
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SavedMessagesScreen()),
    );
    if (mounted) await _loadChats(silent: true);
  }

  Future<void> _openChat(ChatPreview chat, {int initialMessageId = 0}) async {
    if (chat.jid == _savedMessagesJid) {
      await _openSavedMessages();
      return;
    }
    if (MediaQuery.sizeOf(context).width >= 900) {
      setState(() {
        _selectedDesktopChat = chat;
        _selectedDesktopInitialMessageId = initialMessageId;
        _showDesktopProfile = false;
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatScreen(chat: chat, initialMessageId: initialMessageId),
      ),
    );
    if (mounted) await _loadChats(silent: true);
  }

  List<_InlineSearchResult> get _inlineSearchItems {
    final query = _query.trim();
    if (query.isEmpty) return const [];
    final items = <_InlineSearchResult>[];
    final savedSearch = 'saved messages private notes notes files self';
    if (savedSearch.contains(query.toLowerCase())) {
      items.add(
        _InlineSearchResult(
          chat: _savedMessagesPreview,
          title: 'Saved Messages',
          subtitle: 'Private notes and saved items',
          icon: Icons.bookmark_rounded,
        ),
      );
    }
    final conversations = _inlineSearchResults['conversations'] is List
        ? _inlineSearchResults['conversations'] as List
        : const [];
    final users = _inlineSearchResults['users'] is List
        ? _inlineSearchResults['users'] as List
        : const [];
    final messages = _inlineSearchResults['messages'] is List
        ? _inlineSearchResults['messages'] as List
        : const [];

    for (final raw in conversations.whereType<Map>().take(8)) {
      final data = Map<String, dynamic>.from(raw);
      final chat = _chatPreviewFromSearchItem(data);
      if (chat.jid.isEmpty) continue;
      items.add(
        _InlineSearchResult(
          chat: chat,
          title: chat.name,
          subtitle: chat.isChannel ? 'Channel' : 'Group',
          icon: chat.isChannel ? Icons.tag_rounded : Icons.groups_rounded,
        ),
      );
    }
    for (final raw in users.whereType<Map>().take(8)) {
      final data = Map<String, dynamic>.from(raw);
      final contact = ChatContact.fromJson(data);
      final chat = ChatPreview.fromContact(contact);
      items.add(
        _InlineSearchResult(
          chat: chat,
          title: chat.name,
          subtitle: chat.designation.isEmpty ? chat.jid : chat.designation,
          icon: Icons.person_outline_rounded,
        ),
      );
    }
    for (final raw in messages.whereType<Map>().take(20)) {
      final data = Map<String, dynamic>.from(raw);
      final chat = _chatPreviewFromSearchItem(data);
      if (chat.jid.isEmpty) continue;
      final fileName = '${data['file_name'] ?? ''}'.trim();
      final caption = '${data['caption'] ?? ''}'.trim();
      final body = cleanMojibakeText('${data['body'] ?? ''}'.trim());
      final title = fileName.isNotEmpty
          ? fileName
          : caption.isNotEmpty
          ? caption
          : body;
      final messageId = int.tryParse('${data['id'] ?? 0}') ?? 0;
      items.add(
        _InlineSearchResult(
          chat: chat,
          title: title.isEmpty ? 'Message' : title,
          subtitle:
              '${chat.name}${'${data['created_at'] ?? ''}'.trim().isEmpty ? '' : ' - ${data['created_at']}'}',
          icon: fileName.isNotEmpty
              ? Icons.attach_file_rounded
              : Icons.chat_bubble_outline_rounded,
          messageId: messageId,
          isMessage: true,
        ),
      );
    }
    return items;
  }

  Widget _buildInlineSearchHeader() {
    final query = _query.trim();
    if (query.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.manage_search_rounded),
        title: Text('Search "$query"'),
        subtitle: const Text('Contacts, groups, channels and chat history'),
        trailing: _inlineSearchLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }

  Widget _buildInlineSearchResults({required bool desktop}) {
    final items = _inlineSearchItems;
    if (_query.trim().isEmpty) return const SizedBox.shrink();
    if (_inlineSearchLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) return _EmptySearch(isSearch: true);
    return ListView.separated(
      padding: EdgeInsets.only(top: 6, bottom: desktop ? 16 : 92),
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: desktop ? 76 : 88,
        endIndent: 16,
        color: AppColors.divider,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: item.chat.avatarColor.withValues(alpha: 0.14),
            child: Icon(item.icon, color: AppColors.primary),
          ),
          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _openChat(item.chat, initialMessageId: item.messageId),
        );
      },
    );
  }

  Future<void> _showChatActions(ChatPreview chat) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                chat.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
              ),
              title: Text(chat.isPinned ? 'Unpin chat' : 'Pin chat'),
              onTap: () => Navigator.pop(sheetContext, 'pin'),
            ),
            ListTile(
              leading: Icon(
                chat.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
              ),
              title: Text(
                chat.isStarred ? 'Remove from starred' : 'Add to starred',
              ),
              onTap: () => Navigator.pop(sheetContext, 'star'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    await chatApi.setConversationPreference(
      jid: chat.jid,
      pinned: action == 'pin' ? !chat.isPinned : chat.isPinned,
      starred: action == 'star' ? !chat.isStarred : chat.isStarred,
    );
    await _loadChats(silent: true);
  }

  Future<void> _createGroup() async {
    if (!await _canCreateGroupOrChannel(context)) return;
    if (!mounted) return;
    final group = await showModalBottomSheet<ChatPreview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewGroupSheet(),
    );
    if (group == null || !mounted) return;
    await _loadChats(silent: true);
    if (mounted) await _openChat(group);
  }

  Future<void> _createChannel() async {
    if (!await _canCreateGroupOrChannel(context)) return;
    if (!mounted) return;
    final channel = await showModalBottomSheet<ChatPreview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewGroupSheet(isChannel: true),
    );
    if (channel == null || !mounted) return;
    await _loadChats(silent: true);
    if (mounted) await _openChat(channel);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 900) {
      return ValueListenableBuilder<String>(
        valueListenable: appWorkspaceMode,
        builder: (_, _, _) => _buildDesktop(context),
      );
    }
    return Scaffold(
      drawer: _AppDrawer(
        currentUser: widget.currentUser,
        chats: _liveChats,
        onSavedMessages: _openSavedMessages,
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        titleSpacing: 2,
        title: Image.asset(
          'logo-skylink.png',
          height: 42,
          width: 145,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            tooltip: 'Global search',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GlobalSearchScreen(),
              ),
            ),
            icon: const Icon(Icons.manage_search_rounded),
          ),
          ValueListenableBuilder<String>(
            valueListenable: chatApi.connectionStatus,
            builder: (context, status, _) {
              final color = status == 'connected'
                  ? Colors.green
                  : status == 'reconnecting'
                  ? Colors.amber
                  : Colors.red;
              return TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Messenger connection'),
                    content: Text(
                      'Status: ${status[0].toUpperCase()}${status.substring(1)}\n'
                      'Server: chat.skylinkonline.net\n'
                      'Transport: Ejabberd API / XMPP\n'
                      'Last check: ${DateTime.now()}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                icon: Icon(Icons.circle, size: 11, color: color),
                label: const SizedBox.shrink(),
              );
            },
          ),
          IconButton(
            tooltip: 'New channel',
            onPressed: _createChannel,
            icon: const Icon(Icons.tag_rounded),
          ),
          IconButton(
            tooltip: 'New group',
            onPressed: _createGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'logout') {
                logout(context);
              } else if (value == 'New group') {
                _createGroup();
              } else if (value == 'Settings') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SettingsScreen(currentUser: widget.currentUser),
                  ),
                );
              } else {
                showComingSoon(context, value);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'New group', child: Text('New group')),
              PopupMenuItem(value: 'Settings', child: Text('Settings')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onHomeSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _onHomeSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _buildFilterStrip(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            ),
          ),
          _buildInlineSearchHeader(),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: _query.trim().isNotEmpty
                ? _buildInlineSearchResults(desktop: false)
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? LoadError(message: _loadError!, onRetry: _loadChats)
                : _filteredChats.isEmpty
                ? _EmptySearch(isSearch: false)
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 6, bottom: 92),
                    itemCount: _filteredChats.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 88,
                      endIndent: 16,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (_, index) {
                      final chat = _filteredChats[index];
                      return Dismissible(
                        key: ValueKey('inbox-${chat.jid}'),
                        confirmDismiss: (direction) =>
                            _handleChatSwipe(chat, direction),
                        background: Container(
                          color: Colors.green.shade600,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Row(
                            children: [
                              Icon(Icons.done_all_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Mark read',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          color: Colors.blueGrey.shade700,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Mute',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.notifications_off_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        child: _ChatTile(
                          chat: chat,
                          onTap: () => _openChat(chat),
                          onLongPress: () => _showChatActions(chat),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showNewMessageSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: _AppDrawer(
        currentUser: widget.currentUser,
        chats: _liveChats,
        onSavedMessages: _openSavedMessages,
      ),
      body: Row(
        children: [
          SizedBox(
            width: 430,
            child: Material(
              color: colors.surface,
              child: Column(
                children: [
                  SizedBox(
                    height: 70,
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            tooltip: 'Menu',
                            onPressed: Scaffold.of(context).openDrawer,
                            icon: const Icon(Icons.menu_rounded),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onHomeSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF7C86A0),
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          _onHomeSearchChanged('');
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? colors.surfaceContainerHighest
                                    : const Color(0xFFE9E9EF),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'New message',
                          onPressed: () => showNewMessageSheet(context),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 54, child: _buildFilterStrip()),
                  _buildInlineSearchHeader(),
                  const Divider(height: 1),
                  Expanded(
                    child: _query.trim().isNotEmpty
                        ? _buildInlineSearchResults(desktop: true)
                        : _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _loadError != null
                        ? LoadError(message: _loadError!, onRetry: _loadChats)
                        : _filteredChats.isEmpty
                        ? _EmptySearch(isSearch: false)
                        : ListView.separated(
                            itemCount: _filteredChats.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 76),
                            itemBuilder: (_, index) {
                              final chat = _filteredChats[index];
                              final selected =
                                  _selectedDesktopChat?.jid == chat.jid;
                              return ColoredBox(
                                color: selected
                                    ? colors.primaryContainer.withValues(
                                        alpha: 0.5,
                                      )
                                    : Colors.transparent,
                                child: _ChatTile(
                                  chat: chat,
                                  onTap: () => _openChat(chat),
                                  onLongPress: () => _showChatActions(chat),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
          Expanded(
            child: _selectedDesktopChat == null
                ? _DesktopEmptyChat(currentUser: widget.currentUser)
                : _selectedDesktopChat!.jid == _savedMessagesJid
                ? const SavedMessagesScreen()
                : ChatScreen(
                    key: ValueKey(
                      '${_selectedDesktopChat!.jid}-$_selectedDesktopInitialMessageId',
                    ),
                    chat: _selectedDesktopChat!,
                    initialMessageId: _selectedDesktopInitialMessageId,
                    onProfileTap: () {
                      setState(() => _showDesktopProfile = true);
                    },
                  ),
          ),
          if (_selectedDesktopChat != null &&
              _showDesktopProfile &&
              ((appWorkspaceMode.value == 'three_pane' &&
                      MediaQuery.sizeOf(context).width >= 1180) ||
                  (appWorkspaceMode.value == 'auto' &&
                      MediaQuery.sizeOf(context).width >= 1280))) ...[
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colors.outlineVariant,
            ),
            SizedBox(
              width: 320,
              child: _DesktopConversationProfile(
                key: ValueKey('profile-${_selectedDesktopChat!.jid}'),
                chat: _selectedDesktopChat!,
                onClose: () => setState(() => _showDesktopProfile = false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopConversationProfile extends StatefulWidget {
  const _DesktopConversationProfile({
    super.key,
    required this.chat,
    required this.onClose,
  });

  final ChatPreview chat;
  final VoidCallback onClose;

  @override
  State<_DesktopConversationProfile> createState() =>
      _DesktopConversationProfileState();
}

class _DesktopConversationProfileState
    extends State<_DesktopConversationProfile> {
  late Future<Map<String, dynamic>> _profileFuture;

  ChatPreview get chat => widget.chat;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadPanelData();
  }

  void _reloadPanel() {
    if (!mounted) return;
    setState(() => _profileFuture = _loadPanelData());
  }

  Widget _detailCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadPanelData() async {
    if (!chat.isGroup) return chatApi.getUserProfile(chat.empId);
    final groupId = int.tryParse(chat.empId) ?? 0;
    GroupMembersResult? members;
    ChannelProfile? channelProfile;
    if (groupId > 0) {
      members = await chatApi.getGroupMembers(groupId);
      try {
        channelProfile = await chatApi.getChannelProfile(
          groupId: groupId,
          jid: chat.jid,
        );
      } catch (error) {
        channelProfile = null;
      }
    }
    return <String, dynamic>{
      'current_role': members?.currentRole ?? '',
      'members': members?.members ?? const <GroupMember>[],
      'channel_kind': channelProfile?.kind ?? '',
      'channel_status': channelProfile?.statusText ?? '',
      'channel_priority': channelProfile?.priority ?? '',
      'channel_description': channelProfile?.description ?? '',
      'channel_next_action_text': channelProfile?.nextActionText ?? '',
      'channel_next_action_persons': channelProfile?.nextActionPersons ?? '',
      'channel_next_action_date': channelProfile?.nextActionDate ?? '',
      'channel_next_action_updated_at':
          channelProfile?.nextActionUpdatedAt ?? '',
    };
  }

  Future<void> _changeGroupPhoto() async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    try {
      await chatApi.updateGroupPhoto(
        groupId: groupId,
        name: file.name,
        bytes: file.bytes!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chat.isChannel ? 'Channel photo updated.' : 'Group photo updated.',
          ),
        ),
      );
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editChannelDetails() async {
    final channelId = int.tryParse(chat.empId) ?? 0;
    if (channelId <= 0) return;
    final profile = await _profileFuture;
    final descriptionController = TextEditingController(
      text: '${profile['channel_description'] ?? ''}',
    );
    final nextController = TextEditingController(
      text: '${profile['channel_next_action_date'] ?? ''}',
    );
    var kind = '${profile['channel_kind'] ?? 'operational'}';
    var priority = '${profile['channel_priority'] ?? 'Normal'}';
    var status = '${profile['channel_status'] ?? 'Open'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit channel details'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Purpose, scope and operating notes',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: kind.isEmpty ? 'operational' : kind,
                    decoration: const InputDecoration(
                      labelText: 'Channel type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'incident',
                        child: Text('Incident'),
                      ),
                      DropdownMenuItem(value: 'action', child: Text('Action')),
                      DropdownMenuItem(
                        value: 'operational',
                        child: Text('Operational'),
                      ),
                      DropdownMenuItem(
                        value: 'project',
                        child: Text('Project'),
                      ),
                      DropdownMenuItem(
                        value: 'announcement',
                        child: Text('Announcement'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => kind = value ?? 'operational'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority.isEmpty ? 'Normal' : priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'Normal',
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'High',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'Critical',
                              child: Text('Critical'),
                            ),
                          ],
                          onChanged: (value) => setDialogState(
                            () => priority = value ?? 'Normal',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: status.isEmpty ? 'Open' : status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Open',
                              child: Text('Open'),
                            ),
                            DropdownMenuItem(
                              value: 'In Progress',
                              child: Text('In Progress'),
                            ),
                            DropdownMenuItem(
                              value: 'Blocked',
                              child: Text('Blocked'),
                            ),
                            DropdownMenuItem(
                              value: 'Closed',
                              child: Text('Closed'),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => status = value ?? 'Open'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nextController,
                    readOnly: true,
                    onTap: () => _pickPanelChannelDate(nextController),
                    decoration: const InputDecoration(
                      labelText: 'Next action date',
                      suffixIcon: Icon(Icons.event_available_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final description = descriptionController.text.trim();
    final nextDate = nextController.text.trim();
    descriptionController.dispose();
    nextController.dispose();
    if (saved != true || !mounted) return;
    try {
      await chatApi.updateChannelDetails(
        groupId: channelId,
        description: description,
        channelType: kind,
        priority: priority,
        status: status,
        nextActionDate: nextDate,
      );
      if (!mounted) return;
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pickPanelChannelDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text.trim()) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(now.year - 1)) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    String two(int number) => number.toString().padLeft(2, '0');
    controller.text =
        '${selected.year}-${two(selected.month)}-${two(selected.day)} '
        '${two(selected.hour)}:${two(selected.minute)}:00';
  }

  Future<void> _renameConversation() async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final controller = TextEditingController(text: chat.name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(chat.isChannel ? 'Rename channel' : 'Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null || result.isEmpty) return;
    try {
      await chatApi.renameGroup(groupId, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chat.isChannel ? 'Channel renamed.' : 'Group renamed.'),
        ),
      );
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _leaveConversation() async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave ' + (chat.isChannel ? 'channel' : 'group') + '?'),
        content: const Text(
          'You will stop receiving messages from this conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.groupMemberAction(
        groupId: groupId,
        empId: '0',
        action: 'leave',
      );
      if (!mounted) return;
      widget.onClose();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _closeChannel() async {
    final channelId = int.tryParse(chat.empId) ?? 0;
    if (!chat.isChannel || channelId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close channel?'),
        content: const Text(
          "The channel will move to the archive and disappear from every member's open channel list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close channel'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.closeChannel(channelId);
      if (!mounted) return;
      widget.onClose();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showWakeupConfigDesktop(bool canManage) async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    if (!canManage) {
      return;
    }
    try {
      final config = await chatApi.getWakeupConfig(
        groupId: groupId,
        jid: chat.jid,
      );
      if (!mounted) return;
      var enabled =
          config['enabled'] == true ||
          "${config['enabled']}".toLowerCase() == '1' ||
          "${config['enabled']}".toLowerCase() == 'true';
      var interval =
          int.tryParse(
            '${config['interval_minutes'] ?? config['minutes'] ?? 1440}',
          ) ??
          1440;
      const choices = <int, String>{
        1440: '1 day',
        4320: '3 days',
        10080: '7 days',
        21600: '15 days',
        43200: '1 month',
        86400: '2 months',
        129600: '3 months',
      };
      if (!choices.containsKey(interval)) interval = 1440;
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Wake-up notification'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable wake-up notification'),
                    subtitle: const Text(
                      'Weekends are skipped. Only owner/admin can edit.',
                    ),
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: choices.entries.map((entry) {
                      final selected = interval == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: selected,
                        onSelected: enabled
                            ? (_) => setDialogState(() => interval = entry.key)
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return;
      await chatApi.updateWakeupConfig(
        groupId: groupId,
        enabled: enabled,
        intervalMinutes: interval,
      );
      if (!mounted) return;
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _addMember(List<GroupMember> currentMembers) async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final users = await chatApi.searchUsers();
    if (!mounted) return;
    final existing = currentMembers.map((member) => member.empId).toSet();
    final selected = await _pickMemberToAdd(
      context,
      users: users,
      existing: existing,
    );
    if (selected == null) return;
    try {
      await chatApi.manageGroupMember(
        groupId: groupId,
        empId: selected.user.empId,
        add: true,
        showHistory: selected.showHistory,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member added.')));
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          'Remove ' +
              (member.name.isEmpty ? member.empId : member.name) +
              ' from this ' +
              (chat.isChannel ? 'channel' : 'group') +
              '?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _memberAction(member, 'remove', success: 'Member removed.');
  }

  Future<void> _memberAction(
    GroupMember member,
    String action, {
    String success = 'Member updated.',
  }) async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    try {
      await chatApi.groupMemberAction(
        groupId: groupId,
        empId: member.empId,
        action: action,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data ?? const <String, dynamic>{};
          final groupMembers = chat.isGroup && profile['members'] is List
              ? List<GroupMember>.from(profile['members'] as List)
              : const <GroupMember>[];
          final groupRole = (profile['current_role'] ?? '').toString();
          final canManageGroup = const {'owner', 'admin'}.contains(groupRole);
          final channelKind = (profile['channel_kind'] ?? '').toString();
          final channelStatus = (profile['channel_status'] ?? '').toString();
          final channelPriority = (profile['channel_priority'] ?? '')
              .toString();
          final channelDescription = (profile['channel_description'] ?? '')
              .toString();
          final channelNextAction = (profile['channel_next_action_text'] ?? '')
              .toString();
          final channelNextPersons =
              (profile['channel_next_action_persons'] ?? '').toString();
          final channelNextDate = (profile['channel_next_action_date'] ?? '')
              .toString();
          final isChannelPanel =
              chat.isChannel ||
              channelKind.trim().isNotEmpty ||
              channelStatus.trim().isNotEmpty ||
              channelDescription.trim().isNotEmpty ||
              channelNextAction.trim().isNotEmpty ||
              channelNextPersons.trim().isNotEmpty ||
              channelNextDate.trim().isNotEmpty;
          final designation =
              (profile['designation'] ??
                      (isChannelPanel
                          ? 'Channel'
                          : chat.isGroup
                          ? 'Group'
                          : 'Employee'))
                  .toString();
          final onlineValue = profile['messenger_connected'];
          final online =
              onlineValue == true ||
              onlineValue == 1 ||
              onlineValue.toString() == '1' ||
              chat.isOnline;
          final launchpadValue = profile['launchpad_active'];
          final launchpadActive =
              launchpadValue == true ||
              launchpadValue == 1 ||
              launchpadValue.toString() == '1';

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close details',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Center(child: UserAvatar(chat: chat, radius: 44)),
              const SizedBox(height: 12),
              Text(
                chat.name,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                designation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: online ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GlobalSearchScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Search'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatMediaBrowser(chat: chat),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Media'),
                    ),
                  ),
                ],
              ),
              if (isChannelPanel) ...[
                const SizedBox(height: 12),
                _detailCard(
                  context,
                  icon: Icons.description_outlined,
                  label: 'Description',
                  value: channelDescription.trim().isEmpty
                      ? 'No description added.'
                      : channelDescription,
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.task_alt_rounded,
                  label: 'Next action',
                  value: channelNextAction.trim().isEmpty
                      ? 'No next action detected.'
                      : channelNextAction,
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.people_alt_outlined,
                  label: 'Next action person',
                  value: channelNextPersons.trim().isEmpty
                      ? 'Mention a person to assign clearly.'
                      : channelNextPersons,
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.event_available_outlined,
                  label: 'Next action date',
                  value: channelNextDate.trim().isEmpty ? '-' : channelNextDate,
                ),
              ],
              if (chat.isGroup) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: canManageGroup ? _renameConversation : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        isChannelPanel ? 'Rename channel' : 'Rename group',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: canManageGroup ? _changeGroupPhoto : null,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Photo'),
                    ),
                    if (isChannelPanel) ...[
                      OutlinedButton.icon(
                        onPressed: canManageGroup ? _editChannelDetails : null,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Edit details'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canManageGroup ? _closeChannel : null,
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Archive'),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: groupRole == 'owner'
                          ? null
                          : _leaveConversation,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Leave'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Manage',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Wake-up notification'),
                  subtitle: FutureBuilder<Map<String, dynamic>>(
                    future: chat.isGroup
                        ? chatApi.getWakeupConfig(
                            groupId: int.tryParse(chat.empId) ?? 0,
                            jid: chat.jid,
                          )
                        : null,
                    builder: (context, wakeSnapshot) {
                      final wake =
                          wakeSnapshot.data ?? const <String, dynamic>{};
                      final enabled =
                          wake['enabled'] == true ||
                          '${wake['enabled'] ?? ''}' == '1' ||
                          '${wake['enabled'] ?? ''}'.toLowerCase() == 'true';
                      final next = '${wake['next_wakeup_label'] ?? ''}'.trim();
                      if (enabled && next.isNotEmpty) {
                        return Text('Next wake-up: $next');
                      }
                      return Text(
                        canManageGroup
                            ? 'Configure from this right panel'
                            : 'Only owner/admin can edit',
                      );
                    },
                  ),
                  trailing: canManageGroup
                      ? const Icon(Icons.chevron_right_rounded)
                      : null,
                  onTap: () => _showWakeupConfigDesktop(canManageGroup),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.push_pin_outlined),
                  title: const Text('Pinned messages'),
                  subtitle: const Text('Open pinned messages'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiscoveryListScreen(
                        title: 'Pinned messages',
                        view: 'pins',
                        jid: chat.jid,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text('Member management'),
                  subtitle: Text(
                    canManageGroup
                        ? 'Add and remove members from here'
                        : 'Read-only member list',
                  ),
                  trailing: canManageGroup
                      ? TextButton.icon(
                          onPressed: () => _addMember(groupMembers),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                ...groupMembers.map((member) {
                  final name = member.name.isEmpty ? member.empId : member.name;
                  final subtitle = member.role == 'owner'
                      ? 'Owner'
                      : member.role == 'admin'
                      ? 'Admin'
                      : member.isOnline
                      ? 'online'
                      : member.designation;
                  final selfEmpId = chatApi.currentJid.split('@').first;
                  final canRemove =
                      canManageGroup &&
                      member.role != 'owner' &&
                      member.empId != selfEmpId;
                  final canChangeAdminRole =
                      groupRole == 'owner' &&
                      member.role != 'owner' &&
                      member.empId != selfEmpId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                    ),
                    title: Text(name),
                    subtitle: Text(subtitle),
                    trailing: canRemove || canChangeAdminRole
                        ? PopupMenuButton<String>(
                            tooltip: 'Member actions',
                            onSelected: (action) {
                              if (action == 'remove') {
                                _removeMember(member);
                                return;
                              }
                              _memberAction(
                                member,
                                action,
                                success: action == 'promote'
                                    ? 'Member promoted to admin.'
                                    : 'Admin changed to member.',
                              );
                            },
                            itemBuilder: (_) => [
                              if (canChangeAdminRole)
                                PopupMenuItem(
                                  value: member.role == 'admin'
                                      ? 'demote'
                                      : 'promote',
                                  child: Text(
                                    member.role == 'admin'
                                        ? 'Change to member'
                                        : 'Promote to admin',
                                  ),
                                ),
                              if (canRemove)
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove member'),
                                ),
                            ],
                          )
                        : member.role == 'owner'
                        ? const Chip(label: Text('Owner'))
                        : member.isOnline
                        ? const Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 12,
                          )
                        : null,
                  );
                }),
              ],
              const SizedBox(height: 16),
              _detailCard(
                context,
                icon: Icons.alternate_email_rounded,
                label: 'JID',
                value: chat.jid,
              ),
              if (!chat.isGroup) ...[
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.badge_outlined,
                  label: 'Employee ID',
                  value: (profile['employee_id'] ?? chat.empId).toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.work_outline_rounded,
                  label: 'Designation',
                  value: designation,
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: online
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  label: 'Status',
                  value: online ? 'Online' : 'Offline',
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.rocket_launch_outlined,
                  label: 'Launchpad',
                  value: launchpadActive ? 'Active' : 'Inactive',
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.devices_outlined,
                  label: 'Device model',
                  value: (profile['device_model'] ?? '').toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.computer_outlined,
                  label: 'Platform',
                  value: (profile['platform'] ?? '').toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.info_outline_rounded,
                  label: 'App version',
                  value: (profile['app_version'] ?? '').toString(),
                ),
              ],
              const SizedBox(height: 10),
              _detailCard(
                context,
                icon: Icons.history_rounded,
                label: 'Last activity',
                value: (profile['last_activity'] ?? chat.time).toString(),
              ),
              if (!chat.isGroup) ...[
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.location_on_outlined,
                  label: 'Latest location',
                  value: (profile['latest_location_address'] ?? '').toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'Mobile number',
                  value: (profile['mobile'] ?? '').toString(),
                ),
              ],
              const SizedBox(height: 10),
              _detailCard(
                context,
                icon: Icons.mark_chat_unread_outlined,
                label: 'Unread',
                value: chat.unread.toString(),
              ),
              if (chat.isGroup) ...[
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.people_outline_rounded,
                  label: 'Members',
                  value: groupMembers.length.toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.verified_user_outlined,
                  label: 'Your role',
                  value: groupRole.isEmpty ? '-' : groupRole,
                ),
                if (isChannelPanel) ...[
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.category_outlined,
                    label: 'Channel type',
                    value: channelKind,
                  ),
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.description_outlined,
                    label: 'Description',
                    value: channelDescription.trim().isEmpty
                        ? 'No description added.'
                        : channelDescription,
                  ),
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.task_alt_rounded,
                    label: 'Next action',
                    value: channelNextAction.trim().isEmpty
                        ? 'No next action detected.'
                        : channelNextAction,
                  ),
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.people_alt_outlined,
                    label: 'Next action persons',
                    value: channelNextPersons.trim().isEmpty
                        ? 'Mention a person to assign clearly.'
                        : channelNextPersons,
                  ),
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.event_available_outlined,
                    label: 'Next action date',
                    value: channelNextDate.trim().isEmpty
                        ? '-'
                        : channelNextDate,
                  ),
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.info_outline_rounded,
                    label: 'Channel status',
                    value: channelStatus,
                  ),
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.low_priority_rounded,
                    label: 'Priority',
                    value: channelPriority,
                  ),
                ],
              ],
              const SizedBox(height: 18),
              Text(
                'Latest message',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                chat.message.isEmpty ? 'No messages yet.' : chat.message,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DesktopEmptyChat extends StatelessWidget {
  const _DesktopEmptyChat({required this.currentUser});

  final CurrentUser currentUser;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: ChatBackgroundPainter(isDark: dark),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF102A25), Color(0xFF233A2F)]
                : const [
                    Color(0xFFDCEB82),
                    Color(0xFF66BFA2),
                    Color(0xFFE7E7A1),
                  ],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Select a chat to start messaging',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature will be available soon.')));
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppColors.primary
            : Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : const Color(0xFFE8E8EE),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatPreview chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: chat.unread > 0
          ? AppColors.primary.withValues(alpha: 0.025)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ValueListenableBuilder<double>(
          valueListenable: appChatDensity,
          builder: (context, density, _) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12 * density,
            ),
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: appShowAvatars,
                  builder: (_, show, _) => show
                      ? UserAvatar(chat: chat, radius: 30)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    chat.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 16,
                                      fontWeight: chat.unread > 0
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (!chat.isGroup &&
                                    chat.designation.trim().isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 120,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      chat.designation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            chat.time,
                            style: TextStyle(
                              color: chat.unread > 0
                                  ? AppColors.primary
                                  : colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: chat.unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (chat.sentByMe) ...[
                            const Icon(
                              Icons.done_all_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (chat.message == 'Voice message') ...[
                            const Icon(
                              Icons.mic_rounded,
                              color: AppColors.primary,
                              size: 17,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              chat.message.isEmpty
                                  ? 'No messages yet'
                                  : chat.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: chat.unread > 0
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: chat.unread > 0
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (chat.isPinned)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.push_pin_rounded,
                                color: AppColors.muted,
                                size: 16,
                              ),
                            ),
                          if (chat.isStarred)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF5A623),
                                size: 18,
                              ),
                            ),
                          if (chat.isMuted)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.volume_off_rounded,
                                color: AppColors.muted,
                                size: 17,
                              ),
                            ),
                          if (chat.wasMentioned)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE85270),
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '@',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (chat.unread > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${chat.unread}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.chat, required this.radius});

  final ChatPreview chat;
  final double radius;

  String get _initials {
    final parts = chat.name.trim().split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: chat.avatarColor,
          backgroundImage: chat.avatarUrl.isNotEmpty
              ? NetworkImage(chat.avatarUrl)
              : null,
          child: chat.avatarUrl.isNotEmpty
              ? null
              : chat.isGroup
              ? Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: radius * 0.95,
                )
              : Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.62,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        if (chat.isOnline)
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: radius * 0.48,
              height: radius * 0.48,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.isSearch});

  final bool isSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 56,
            color: AppColors.muted,
          ),
          const SizedBox(height: 14),
          Text(
            isSearch ? 'No conversations found' : 'No recent conversations',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isSearch
                ? 'Try another name or message'
                : 'Start a new chat using the compose button',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class LoadError extends StatelessWidget {
  const LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.currentUser,
    required this.chats,
    this.onSavedMessages,
  });

  final CurrentUser currentUser;
  final List<ChatPreview> chats;
  final Future<void> Function()? onSavedMessages;

  String get _initials {
    final parts = currentUser.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return currentUser.empId;
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              22,
              MediaQuery.paddingOf(context).top + 24,
              22,
              24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  backgroundImage: currentUser.avatarUrl.isNotEmpty
                      ? NetworkImage(currentUser.avatarUrl)
                      : null,
                  child: currentUser.avatarUrl.isNotEmpty
                      ? null
                      : Text(
                          _initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  currentUser.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currentUser.jid,
                  style: const TextStyle(color: Color(0xFFC9DCFF)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                DrawerItem(
                  icon: Icons.group_add_outlined,
                  label: 'New group',
                  onTap: () => _drawerAction(context, 'New group'),
                ),
                DrawerItem(
                  icon: Icons.tag_rounded,
                  label: 'New channel',
                  onTap: () => _drawerAction(context, 'New channel'),
                ),
                DrawerItem(
                  icon: Icons.account_circle_outlined,
                  label: 'My profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.schedule_send_rounded,
                  label: 'Schedule message',
                  onTap: () => _drawerAction(context, 'Schedule message'),
                ),
                DrawerItem(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Saved messages',
                  onTap: () => _drawerAction(context, 'Saved messages'),
                ),
                DrawerItem(
                  icon: Icons.alarm_outlined,
                  label: 'Reminders & Follow-ups',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RemindersScreen(currentUser: currentUser),
                      ),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.alternate_email_rounded,
                  label: 'Mentions',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DiscoveryListScreen(
                          title: 'Mentions',
                          view: 'mentions',
                        ),
                      ),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.folder_outlined,
                  label: 'Chat folders',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatFoldersScreen(chats: chats),
                      ),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.archive_outlined,
                  label: 'Archived channels',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ArchivedChannelsScreen(),
                      ),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Ticket dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TicketDashboardScreen(),
                      ),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.call_outlined,
                  label: 'Calls',
                  onTap: () => _drawerAction(context, 'Calls'),
                ),
                const Divider(height: 24, indent: 20, endIndent: 20),
                DrawerItem(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'My Hub',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MyHubScreen(currentUser: currentUser),
                      ),
                    );
                  },
                ),
                if (ChatApi.diagnosticEmployeeIds.contains(currentUser.empId))
                  DrawerItem(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Advanced diagnostics',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DiagnosticsScreen(),
                        ),
                      );
                    },
                  ),
                if (currentUser.empId == '302')
                  DrawerItem(
                    icon: Icons.verified_user_outlined,
                    label: 'Release management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ReleaseManagementScreen(),
                        ),
                      );
                    },
                  ),
                DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _drawerAction(context, 'Settings'),
                ),
                DrawerItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & feedback',
                  onTap: () => _drawerAction(context, 'Help & feedback'),
                ),
                DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  onTap: () {
                    Navigator.pop(context);
                    logout(context);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) => Text(
                'Skylink v${snapshot.data?.version ?? '1.2.0'}\n'
                'Developed by RK & Co',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _drawerAction(BuildContext context, String action) async {
    Navigator.pop(context);
    if (action == 'Schedule message') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const ScheduleMessageScreen()),
      );
    } else if (action == 'New group' || action == 'New channel') {
      if (!await _canCreateGroupOrChannel(context)) return;
      if (!context.mounted) return;
      final group = await showModalBottomSheet<ChatPreview>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => NewGroupSheet(isChannel: action == 'New channel'),
      );
      if (group != null && context.mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => ChatScreen(chat: group)),
        );
      }
    } else if (action == 'Saved messages') {
      final openSavedMessages = onSavedMessages;
      if (openSavedMessages != null) {
        await openSavedMessages();
      } else {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SavedMessagesScreen()),
        );
      }
    } else if (action == 'Settings') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(currentUser: currentUser),
        ),
      );
    } else {
      showComingSoon(context, action);
    }
  }
}

class MyHubScreen extends StatelessWidget {
  const MyHubScreen({super.key, required this.currentUser});

  final CurrentUser currentUser;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Punch In / Out', Icons.fingerprint_rounded),
      ('Attendance', Icons.calendar_month_outlined),
      ('Leave Management', Icons.beach_access_outlined),
      ('Leave Application', Icons.edit_calendar_outlined),
      ('Achievements', Icons.emoji_events_outlined),
      ('Employee Directory', Icons.people_outline_rounded),
      ('Company Announcements', Icons.campaign_outlined),
      ('Tasks & Tickets', Icons.task_alt_outlined),
      ('Reminders & Follow-ups', Icons.notifications_active_outlined),
      ('Projects', Icons.workspaces_outline),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('My Hub')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 330,
          mainAxisExtent: 112,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (index == 0) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileScreen(showAttendance: true),
                    ),
                  );
                } else if (index == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AttendanceCalendarScreen(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyHubLeaveScreen(),
                    ),
                  );
                } else if (index == 3) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyHubLeaveApplyScreen(),
                    ),
                  );
                } else if (item.$1 == 'Reminders & Follow-ups') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RemindersScreen(currentUser: currentUser),
                    ),
                  );
                } else if (item.$1 == 'Tasks & Tickets') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyHubTasksScreen(),
                    ),
                  );
                } else {
                  showComingSoon(context, item.$1);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFDCE6FF),
                      child: Icon(item.$2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ArchivedChannelsScreen extends StatelessWidget {
  const ArchivedChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived channels')),
      body: FutureBuilder<List<ChatContact>>(
        future: chatApi.getArchivedChannels(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load archived channels.'),
            );
          }
          final channels = snapshot.data ?? const [];
          if (channels.isEmpty) {
            return const Center(child: Text('No archived channels.'));
          }
          return ListView.separated(
            itemCount: channels.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final channel = ChatPreview.fromContact(channels[index]);
              return ListTile(
                leading: UserAvatar(chat: channel, radius: 24),
                title: Text(channel.name),
                subtitle: const Text('Closed - Read-only archive'),
                trailing: const Icon(Icons.lock_outline_rounded),
              );
            },
          );
        },
      ),
    );
  }
}

class _MemberAddChoice {
  const _MemberAddChoice({required this.user, required this.showHistory});

  final ChatContact user;
  final bool showHistory;
}

Future<_MemberAddChoice?> _pickMemberToAdd(
  BuildContext context, {
  required List<ChatContact> users,
  required Set<String> existing,
}) async {
  var showHistory = false;
  var query = '';
  return showDialog<_MemberAddChoice>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final filtered = users.where((user) {
          if (existing.contains(user.empId)) return false;
          final needle = query.trim().toLowerCase();
          if (needle.isEmpty) return true;
          return user.name.toLowerCase().contains(needle) ||
              user.empId.toLowerCase().contains(needle) ||
              user.designation.toLowerCase().contains(needle) ||
              user.jid.toLowerCase().contains(needle);
        }).toList();
        return AlertDialog(
          title: const Text('Add member'),
          content: SizedBox(
            width: 420,
            height: 520,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search people',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setDialogState(() => query = value),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: showHistory,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show old messages'),
                  subtitle: const Text(
                    'Allow this user to view previous group/channel messages.',
                  ),
                  onChanged: (value) =>
                      setDialogState(() => showHistory = value ?? false),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No users found.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            return ListTile(
                              title: Text(user.name),
                              subtitle: Text(
                                user.designation.isEmpty
                                    ? 'Employee ${user.empId}'
                                    : user.designation,
                              ),
                              onTap: () => Navigator.pop(
                                dialogContext,
                                _MemberAddChoice(
                                  user: user,
                                  showHistory: showHistory,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ),
  );
}

class ChatFoldersScreen extends StatefulWidget {
  const ChatFoldersScreen({super.key, required this.chats});

  final List<ChatPreview> chats;

  @override
  State<ChatFoldersScreen> createState() => _ChatFoldersScreenState();
}

class _ChatFoldersScreenState extends State<ChatFoldersScreen> {
  static const _storageKey = _HomeScreenState._chatFoldersStorageKey;
  Map<String, List<String>> _folders = {};
  List<String> _folderOrder = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (mounted) {
        setState(() {
          _folders = decoded.map(
            (name, values) => MapEntry(
              name,
              (values as List).map((value) => '$value').toList(),
            ),
          );
          _folderOrder = _folders.keys.toList();
        });
      }
    } catch (error) {
      // Ignore damaged local folder preferences.
    }
  }

  Future<void> _save() async {
    final ordered = <String, List<String>>{};
    for (final name in _folderOrder) {
      final chats = _folders[name];
      if (chats != null) ordered[name] = chats;
    }
    _folders = ordered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_folders));
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final selected = <String>{};
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create chat folder'),
          content: SizedBox(
            width: 430,
            height: 480,
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Folder name',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: widget.chats
                        .map(
                          (chat) => CheckboxListTile(
                            value: selected.contains(chat.jid),
                            title: Text(chat.name),
                            subtitle: Text(
                              chat.isChannel
                                  ? 'Channel'
                                  : chat.isGroup
                                  ? 'Group'
                                  : chat.designation,
                            ),
                            onChanged: (value) => setDialogState(() {
                              if (value ?? false) {
                                selected.add(chat.jid);
                              } else {
                                selected.remove(chat.jid);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (created != true || name.isEmpty || selected.isEmpty) return;
    setState(() {
      _folders[name] = selected.toList();
      _folderOrder.add(name);
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat folders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFolder,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New folder'),
      ),
      body: _folders.isEmpty
          ? const Center(
              child: Text(
                'Create folders to organise users, groups and channels.',
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.only(bottom: 90),
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final name = _folderOrder.removeAt(oldIndex);
                  _folderOrder.insert(newIndex, name);
                });
                await _save();
              },
              children: _folderOrder.map((folderName) {
                final folder = MapEntry(
                  folderName,
                  _folders[folderName] ?? const <String>[],
                );
                final chats = widget.chats
                    .where((chat) => folder.value.contains(chat.jid))
                    .toList();
                return ExpansionTile(
                  key: ValueKey(folder.key),
                  leading: const Icon(Icons.folder_rounded),
                  title: Text(
                    folder.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${chats.length} chats'),
                  trailing: IconButton(
                    tooltip: 'Delete folder',
                    onPressed: () async {
                      setState(() {
                        _folders.remove(folder.key);
                        _folderOrder.remove(folder.key);
                      });
                      await _save();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  children: chats
                      .map(
                        (chat) => ListTile(
                          leading: UserAvatar(chat: chat, radius: 22),
                          title: Text(chat.name),
                          subtitle: Text(chat.message),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(chat: chat),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
    );
  }
}

class _SavedPasteIntent extends Intent {
  const _SavedPasteIntent();
}

class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SavedMessage> _messages = const [];
  bool _loading = true;
  bool _saving = false;
  bool _isDragOver = false;
  String _error = '';
  String _lastClipboardPasteKey = '';
  DateTime? _lastClipboardPasteAt;

  @override
  void initState() {
    super.initState();
    registerClipboardMediaHandler(_handleClipboardMediaPaste);
    _loadCached();
  }

  Future<void> _loadCached() async {
    final cached = await chatApi.cachedSavedMessages();
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _messages = cached;
        _loading = false;
      });
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _error = '');
    try {
      final messages = await chatApi.getSavedMessages();
      if (mounted) {
        setState(() {
          _messages = messages;
          _error = '';
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load saved messages.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await chatApi.saveMessage(text);
      _controller.clear();
      _focusNode.requestFocus();
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this note.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSavedAttachmentOptions() async {
    if (_saving) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_rounded),
              title: const Text('Image or video'),
              subtitle: const Text('Save media to Saved Messages'),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_rounded),
              title: const Text('Document'),
              subtitle: const Text(
                'Save PDF, sheet, text, APK, HTML, PHP or any file',
              ),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Checklist'),
              subtitle: const Text('Create a saved checklist note'),
              onTap: () => Navigator.pop(sheetContext, 'checklist'),
            ),
            ListTile(
              leading: const Icon(Icons.poll_rounded),
              title: const Text('Poll'),
              subtitle: const Text('Create a saved poll note'),
              onTap: () => Navigator.pop(sheetContext, 'poll'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'file') {
      await _pickAndSaveAttachment();
      return;
    }
    final body = selected == 'checklist'
        ? 'SKYLINK_CHECKLIST:{"title":"Checklist","items":[{"text":"New item","done":false}],"created_at":"${DateTime.now().toIso8601String()}"}'
        : 'SKYLINK_POLL:{"question":"Poll","allow_multiple":false,"options":[{"text":"Yes","votes":[]},{"text":"No","votes":[]}],"created_at":"${DateTime.now().toIso8601String()}"}';
    setState(() => _saving = true);
    try {
      await chatApi.saveMessage(body);
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this item.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndSaveAttachment() async {
    if (_saving) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    await _savePlatformFiles(result.files);
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (_saving || files.isEmpty) return;
    final platformFiles = <PlatformFile>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      platformFiles.add(
        PlatformFile(name: file.name, size: bytes.length, bytes: bytes),
      );
    }
    await _savePlatformFiles(platformFiles);
  }

  Future<void> _handleClipboardMediaPaste(List<PastedMediaFile> files) async {
    if (_saving || files.isEmpty) return;
    final now = DateTime.now();
    final pasteKey = files
        .map((file) => '${file.name}|${file.mimeType}|${file.bytes.length}')
        .join(';');
    final previousAt = _lastClipboardPasteAt;
    if (pasteKey == _lastClipboardPasteKey &&
        previousAt != null &&
        now.difference(previousAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastClipboardPasteKey = pasteKey;
    _lastClipboardPasteAt = now;
    await _savePlatformFiles(
      files
          .map(
            (file) => PlatformFile(
              name: file.name,
              size: file.bytes.length,
              bytes: file.bytes,
            ),
          )
          .toList(),
    );
  }

  Future<void> _savePlatformFiles(List<PlatformFile> files) async {
    final validFiles = files.where((file) => file.size > 0).toList();
    if (validFiles.isEmpty || _saving) return;
    setState(() => _saving = true);
    final caption = _controller.text.trim();
    try {
      for (final file in validFiles) {
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        if (bytes == null || bytes.isEmpty) continue;
        await chatApi.saveAttachmentMessage(
          name: file.name,
          mimeType: mimeTypeForFile(file.name),
          bytes: bytes,
          message: caption,
        );
      }
      _controller.clear();
      _focusNode.requestFocus();
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this file.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pasteTextFromClipboard() async {
    if (!_focusNode.hasFocus) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    final value = _controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = min(selection.start, selection.end);
    final end = max(selection.start, selection.end);
    final nextText = value.text.replaceRange(start, end, text);
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  Future<void> _copy(SavedMessage item) async {
    await Clipboard.setData(ClipboardData(text: item.body));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied.')));
    }
  }

  Future<void> _share(SavedMessage item) async {
    final text = item.body.trim();
    if (text.isEmpty && item.fileUrl.trim().isEmpty) return;
    await Share.share(
      [text, item.fileUrl.trim()].where((value) => value.isNotEmpty).join('\n'),
    );
  }

  Future<void> _openFile(SavedMessage item) async {
    final url = item.fileUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  ChatAttachment _savedAttachment(SavedMessage item) {
    final name = item.fileName.trim().isEmpty
        ? 'saved-file'
        : item.fileName.trim();
    final type = item.fileType.trim().isEmpty
        ? 'application/octet-stream'
        : item.fileType.trim();
    return ChatAttachment(
      name: name,
      url: item.fileUrl.trim(),
      mimeType: type,
      size: 0,
    );
  }

  Future<void> _downloadFile(SavedMessage item) async {
    if (!item.hasFile) return;
    try {
      final path = await chatApi.downloadAttachment(_savedAttachment(item));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path.isEmpty ? 'Download started.' : 'Saved to $path'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download file: $error')),
      );
    }
  }

  @override
  void dispose() {
    unregisterClipboardMediaHandler(_handleClipboardMediaPaste);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Icon(Icons.bookmark_rounded, size: 20),
            ),
            SizedBox(width: 12),
            Text('Saved Messages'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyV, control: true):
              _SavedPasteIntent(),
          SingleActivator(LogicalKeyboardKey.keyV, meta: true):
              _SavedPasteIntent(),
        },
        child: Actions(
          actions: {
            _SavedPasteIntent: CallbackAction<_SavedPasteIntent>(
              onInvoke: (_) {
                unawaited(_pasteTextFromClipboard());
                return null;
              },
            ),
          },
          child: DropTarget(
            onDragEntered: (_) {
              if (mounted) setState(() => _isDragOver = true);
            },
            onDragExited: (_) {
              if (mounted) setState(() => _isDragOver = false);
            },
            onDragDone: (details) => _handleDroppedFiles(details.files),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: _buildMessageList(theme)),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  minLines: 1,
                                  maxLines: 5,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _save(),
                                  decoration: const InputDecoration(
                                    hintText: 'Message',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'Attach file',
                              onPressed: _saving
                                  ? null
                                  : _showSavedAttachmentOptions,
                              icon: const Icon(Icons.attach_file_rounded),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filled(
                              tooltip: 'Save',
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isDragOver)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          'Drop files to save',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border_rounded,
                size: 54,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Save messages, links, notes and reminders here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        itemCount: _messages.length,
        itemBuilder: (_, index) {
          final item = _messages[index];
          return _SavedMessageBubble(
            item: item,
            onCopy: () => _copy(item),
            onShare: () => _share(item),
            onOpenFile: () => _openFile(item),
            onDownloadFile: item.hasFile ? () => _downloadFile(item) : null,
          );
        },
      ),
    );
  }
}

class _SavedMessageBubble extends StatelessWidget {
  const _SavedMessageBubble({
    required this.item,
    required this.onCopy,
    required this.onShare,
    required this.onOpenFile,
    this.onDownloadFile,
  });

  final SavedMessage item;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onOpenFile;
  final VoidCallback? onDownloadFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = _formatSavedMessageTime(item.createdAt);
    final bubbleColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : AppColors.outgoing;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: bubbleColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onLongPress: onCopy,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.hasFile) ...[
                    _SavedFilePreview(
                      item: item,
                      onOpen: onOpenFile,
                      onDownload: onDownloadFile,
                    ),
                    if (item.body.trim().isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (item.body.trim().isNotEmpty)
                    SelectableText.rich(_savedMessageSpan(item.body, theme)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        createdAt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'Saved message actions',
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'copy',
                            child: Text('Copy'),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Text('Share'),
                          ),
                          if (onDownloadFile != null)
                            const PopupMenuItem(
                              value: 'download',
                              child: Text('Download'),
                            ),
                        ],
                        onSelected: (value) {
                          if (value == 'copy') onCopy();
                          if (value == 'share') onShare();
                          if (value == 'download') onDownloadFile?.call();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedFilePreview extends StatelessWidget {
  const _SavedFilePreview({
    required this.item,
    required this.onOpen,
    required this.onDownload,
  });

  final SavedMessage item;
  final VoidCallback onOpen;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = item.fileName.trim().isEmpty
        ? 'Saved file'
        : item.fileName.trim();
    final mimeType = item.fileType.trim();
    final isImage = mimeType.startsWith('image/');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: isImage
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      item.fileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 36),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        const Icon(Icons.image_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Download',
                          onPressed: onDownload,
                          icon: const Icon(Icons.download_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        _savedFileIcon(mimeType),
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (mimeType.isNotEmpty)
                            Text(
                              mimeType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Download',
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded, size: 20),
                    ),
                    const Icon(Icons.open_in_new_rounded, size: 18),
                  ],
                ),
              ),
      ),
    );
  }
}

IconData _savedFileIcon(String mimeType) {
  if (mimeType.startsWith('image/')) return Icons.image_outlined;
  if (mimeType.startsWith('video/')) return Icons.movie_outlined;
  if (mimeType.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (mimeType.contains('sheet') ||
      mimeType.contains('excel') ||
      mimeType.contains('csv')) {
    return Icons.table_chart_outlined;
  }
  if (mimeType.contains('word') || mimeType.contains('text'))
    return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}

TextSpan _savedMessageSpan(String text, ThemeData theme) {
  text = cleanMojibakeText(text);
  final style = TextStyle(
    color: theme.colorScheme.onSurface,
    fontSize: 15,
    height: 1.35,
  );
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'(https?:\/\/[^\s<>()]+|www\.[^\s<>()]+)');
  var offset = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > offset) {
      spans.add(TextSpan(text: text.substring(offset, match.start)));
    }
    final token = match.group(0)!;
    final parts = _splitSavedUrlTrailingPunctuation(token);
    spans.add(
      TextSpan(
        text: parts.$1,
        style: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _openSavedLink(parts.$1),
      ),
    );
    if (parts.$2.isNotEmpty) spans.add(TextSpan(text: parts.$2));
    offset = match.end;
  }
  if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
  return TextSpan(style: style, children: spans);
}

(String, String) _splitSavedUrlTrailingPunctuation(String value) {
  var end = value.length;
  while (end > 0 && '.,!?;:'.contains(value[end - 1])) {
    end--;
  }
  return (value.substring(0, end), value.substring(end));
}

Future<void> _openSavedLink(String value) async {
  final normalized = value.toLowerCase().startsWith('http')
      ? value
      : 'https://$value';
  final uri = Uri.tryParse(normalized);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _formatSavedMessageTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

class DrawerItem extends StatelessWidget {
  const DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

String _normalizedCreatorEmployeeType(String value) {
  final type = value.trim().toUpperCase();
  if (type == '1') return 'B';
  if (type == '0') return 'C1';
  return type;
}

Future<bool> _canCreateGroupOrChannel(BuildContext context) async {
  try {
    final cached = await chatApi.cachedProfile();
    final profile = cached ?? await chatApi.getProfile();
    final type = _normalizedCreatorEmployeeType(profile.employeeType);
    if (type == 'C1' || type == 'C2') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your user type is not allowed to create groups or channels.',
            ),
          ),
        );
      }
      return false;
    }
  } catch (_) {
    // Backend enforces this rule; allow the attempt if profile loading is unavailable.
  }
  return true;
}

void showNewMessageSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const NewMessageSheet(),
  );
}

class NewGroupSheet extends StatefulWidget {
  const NewGroupSheet({this.isChannel = false});

  final bool isChannel;

  @override
  State<NewGroupSheet> createState() => NewGroupSheetState();
}

class ManageGroupSheet extends StatefulWidget {
  const ManageGroupSheet({
    required this.groupId,
    required this.initialMembers,
    required this.isOwner,
    required this.currentRole,
  });

  final int groupId;
  final List<GroupMember> initialMembers;
  final bool isOwner;
  final String currentRole;

  @override
  State<ManageGroupSheet> createState() => ManageGroupSheetState();
}

class ManageGroupSheetState extends State<ManageGroupSheet> {
  late List<GroupMember> _members;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _members = [...widget.initialMembers];
  }

  Future<void> _remove(GroupMember member) async {
    setState(() => _busy = true);
    try {
      await chatApi.manageGroupMember(
        groupId: widget.groupId,
        empId: member.empId,
        add: false,
      );
      if (mounted) setState(() => _members.remove(member));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _memberAction(GroupMember member, String action) async {
    setState(() => _busy = true);
    try {
      await chatApi.groupMemberAction(
        groupId: widget.groupId,
        empId: member.empId,
        action: action,
      );
      final refreshed = await chatApi.getGroupMembers(widget.groupId);
      if (mounted) setState(() => _members = refreshed.members);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMember() async {
    final users = await chatApi.searchUsers();
    if (!mounted) return;
    final existing = _members.map((member) => member.empId).toSet();
    final selected = await _pickMemberToAdd(
      context,
      users: users,
      existing: existing,
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await chatApi.manageGroupMember(
        groupId: widget.groupId,
        empId: selected.user.empId,
        add: true,
        showHistory: selected.showHistory,
      );
      if (!mounted) return;
      final refreshed = await chatApi.getGroupMembers(widget.groupId);
      if (mounted) setState(() => _members = refreshed.members);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Icon(Icons.groups_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Group members',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (widget.isOwner)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: Icon(Icons.person_add_rounded),
              ),
              title: const Text('Add member'),
              enabled: !_busy,
              onTap: _addMember,
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _members.length,
              itemBuilder: (_, index) {
                final member = _members[index];
                final selfEmpId = chatApi.currentJid.split('@').first;
                final canRemove =
                    widget.isOwner &&
                    member.role != 'owner' &&
                    member.empId != selfEmpId;
                final canChangeAdminRole =
                    widget.currentRole == 'owner' &&
                    member.role != 'owner' &&
                    member.empId != selfEmpId;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      member.name.isEmpty
                          ? member.empId
                          : member.name[0].toUpperCase(),
                    ),
                  ),
                  title: Text(member.name),
                  subtitle: Text(
                    member.role == 'owner'
                        ? 'Owner'
                        : member.role == 'admin'
                        ? 'Admin'
                        : member.designation,
                  ),
                  trailing: canRemove || canChangeAdminRole
                      ? PopupMenuButton<String>(
                          tooltip: 'Member actions',
                          enabled: !_busy,
                          onSelected: (action) {
                            if (action == 'remove') {
                              _remove(member);
                              return;
                            }
                            _memberAction(member, action);
                          },
                          itemBuilder: (_) => [
                            if (canChangeAdminRole)
                              PopupMenuItem(
                                value: member.role == 'admin'
                                    ? 'demote'
                                    : 'promote',
                                child: Text(
                                  member.role == 'admin'
                                      ? 'Change to member'
                                      : 'Promote to admin',
                                ),
                              ),
                            if (canRemove)
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove member'),
                              ),
                          ],
                        )
                      : member.role == 'owner'
                      ? const Chip(label: Text('Owner'))
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NewGroupSheetState extends State<NewGroupSheet> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _slaController = TextEditingController();
  final _staleController = TextEditingController(text: '120');
  final _targetDateController = TextEditingController();
  final _nextActionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedIds = {};
  List<ChatContact> _users = [];
  String _channelType = 'operational';
  String _priority = 'Normal';
  Timer? _debounce;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    _slaController.dispose();
    _staleController.dispose();
    _targetDateController.dispose();
    _nextActionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadUsers(value.trim()),
    );
  }

  Future<void> _loadUsers([String search = '']) async {
    if (mounted) setState(() => _loading = true);
    try {
      final users = await chatApi.searchUsers(search);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _pickChannelDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text.trim()) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(now.year - 1)) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    controller.text = _formatChannelDateTime(selected);
  }

  String _formatChannelDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _creating) {
      setState(
        () =>
            _error = 'Enter a ${widget.isChannel ? 'channel' : 'group'} name.',
      );
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final group = widget.isChannel
          ? await chatApi.createChannel(
              name: name,
              memberEmployeeIds: _selectedIds.toList(),
              channelType: _channelType,
              priority: _priority,
              description: _descriptionController.text.trim(),
              targetDate: _targetDateController.text.trim(),
              nextActionDate: _nextActionController.text.trim(),
              slaMinutes: int.tryParse(_slaController.text.trim()) ?? 0,
              staleAlertMinutes:
                  int.tryParse(_staleController.text.trim()) ?? 0,
            )
          : await chatApi.createGroup(
              name: name,
              memberIds: _selectedIds.toList(),
            );
      if (!mounted) return;
      Navigator.pop(context, ChatPreview.fromContact(group));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to create the ${widget.isChannel ? 'channel' : 'group'}.',
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isChannel ? 'New channel' : 'New group',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: TextField(
              controller: _nameController,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: widget.isChannel ? 'Channel name' : 'Group name',
                prefixIcon: Icon(
                  widget.isChannel ? Icons.tag_rounded : Icons.groups_rounded,
                ),
                counterText: '',
              ),
            ),
          ),
          if (widget.isChannel)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Channel description',
                      hintText: 'Purpose, scope and operating notes',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _channelType,
                    decoration: const InputDecoration(
                      labelText: 'Channel type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'incident',
                        child: Text('Incident'),
                      ),
                      DropdownMenuItem(value: 'action', child: Text('Action')),
                      DropdownMenuItem(
                        value: 'operational',
                        child: Text('Operational'),
                      ),
                      DropdownMenuItem(
                        value: 'project',
                        child: Text('Project'),
                      ),
                      DropdownMenuItem(
                        value: 'announcement',
                        child: Text('Announcement'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _channelType = value ?? 'operational';
                      if (_slaController.text.isEmpty) {
                        _slaController.text = switch (_channelType) {
                          'incident' => '240',
                          'action' => '1440',
                          'project' => '10080',
                          'announcement' => '0',
                          _ => '1440',
                        };
                      }
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'Normal',
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'High',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'Critical',
                              child: Text('Critical'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _priority = value ?? 'Normal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _staleController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stale alert min',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (const {
                    'ticket',
                    'action',
                    'incident',
                    'project',
                    'installation',
                    'l2_feasibility',
                    'protect',
                  }.contains(_channelType)) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _targetDateController,
                            readOnly: true,
                            onTap: () =>
                                _pickChannelDate(_targetDateController),
                            decoration: const InputDecoration(
                              labelText: 'Target date',
                              hintText: 'Select date',
                              suffixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _nextActionController,
                            readOnly: true,
                            onTap: () =>
                                _pickChannelDate(_nextActionController),
                            decoration: const InputDecoration(
                              labelText: 'Next action date',
                              hintText: 'Select date',
                              suffixIcon: Icon(Icons.event_available_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (const {
                    'ticket',
                    'incident',
                    'action',
                  }.contains(_channelType)) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _slaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'SLA minutes',
                        helperText:
                            'Green 0-50%, Yellow 50-80%, Red 80-100%, Black breached',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search members',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB3261E)),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (_, index) {
                      final user = _users[index];
                      final selected = _selectedIds.contains(user.empId);
                      final preview = ChatPreview.fromContact(user);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value ?? false) {
                              _selectedIds.add(user.empId);
                            } else {
                              _selectedIds.remove(user.empId);
                            }
                          });
                        },
                        secondary: UserAvatar(chat: preview, radius: 22),
                        title: Text(
                          preview.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          preview.designation.isEmpty
                              ? 'Employee ${preview.empId}'
                              : preview.designation,
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        widget.isChannel
                            ? Icons.add_circle_outline_rounded
                            : Icons.group_add_rounded,
                      ),
                label: Text(
                  _creating
                      ? 'Creating...'
                      : 'Create ' + (widget.isChannel ? 'channel' : 'group'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NewMessageSheet extends StatefulWidget {
  const NewMessageSheet();

  @override
  State<NewMessageSheet> createState() => NewMessageSheetState();
}

class NewMessageSheetState extends State<NewMessageSheet> {
  Timer? _debounce;
  List<ChatPreview> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search([String value = '']) async {
    if (mounted) setState(() => _loading = true);
    try {
      final users = await chatApi.searchUsers(value.trim());
      if (!mounted) return;
      setState(() {
        _users = users.map(ChatPreview.fromContact).toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load users.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Text(
                  'New message',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search people',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? LoadError(message: _error!, onRetry: _search)
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, _) =>
                        const Divider(indent: 72, color: AppColors.divider),
                    itemBuilder: (_, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: UserAvatar(chat: user, radius: 23),
                        title: Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          user.designation.isEmpty
                              ? user.jid
                              : user.designation,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(chat: user),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
