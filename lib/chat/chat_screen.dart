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
import '../web_text_selection_state.dart';
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

class ChatMessage {
  const ChatMessage({
    this.id = 0,
    required this.text,
    required this.time,
    required this.isMe,
    this.sender,
    this.isRead = true,
    this.readAt = '',
    this.attachment,
    this.replyToId = 0,
    this.threadRootId = 0,
    this.mentions = const [],
    this.isEdited = false,
    this.sourceDevice = 'unknown',
    this.sourceName = '',
    this.locationAddress = '',
    this.createdAt,
    this.isSending = false,
    this.isFailed = false,
    this.reaction = '',
    this.isStarred = false,
    this.originalSenderJid = '',
    this.originalSenderName = '',
    this.originalSourceName = '',
    this.visibilityMode = 'all',
    this.isSystem = false,
  });

  final int id;
  final String text;
  final String time;
  final bool isMe;
  final String? sender;
  final bool isRead;
  final String readAt;
  final ChatAttachment? attachment;
  final int replyToId;
  final int threadRootId;
  final List<String> mentions;
  final bool isEdited;
  final String sourceDevice;
  final String sourceName;
  final String locationAddress;
  final DateTime? createdAt;
  final bool isSending;
  final bool isFailed;
  final String reaction;
  final bool isStarred;
  final String originalSenderJid;
  final String originalSenderName;
  final String originalSourceName;
  final String visibilityMode;
  final bool isSystem;

  ChatMessage copyWith({
    int? id,
    String? text,
    bool? isRead,
    String? readAt,
    ChatAttachment? attachment,
    bool? isSending,
    bool? isFailed,
    String? reaction,
    bool? isStarred,
    bool? isEdited,
    String? originalSenderJid,
    String? originalSenderName,
    String? originalSourceName,
    String? locationAddress,
    String? visibilityMode,
    bool? isSystem,
  }) => ChatMessage(
    id: id ?? this.id,
    text: text ?? this.text,
    time: time,
    isMe: isMe,
    sender: sender,
    isRead: isRead ?? this.isRead,
    readAt: readAt ?? this.readAt,
    attachment: attachment ?? this.attachment,
    replyToId: replyToId,
    threadRootId: threadRootId,
    mentions: mentions,
    isEdited: isEdited ?? this.isEdited,
    sourceDevice: sourceDevice,
    sourceName: sourceName,
    locationAddress: locationAddress ?? this.locationAddress,
    createdAt: createdAt,
    isSending: isSending ?? this.isSending,
    isFailed: isFailed ?? this.isFailed,
    reaction: reaction ?? this.reaction,
    isStarred: isStarred ?? this.isStarred,
    originalSenderJid: originalSenderJid ?? this.originalSenderJid,
    originalSenderName: originalSenderName ?? this.originalSenderName,
    originalSourceName: originalSourceName ?? this.originalSourceName,
    visibilityMode: visibilityMode ?? this.visibilityMode,
    isSystem: isSystem ?? this.isSystem,
  );

  String get previewText {
    final item = attachment;
    if (item == null) {
      final contact = decodeContactCard(text);
      if (contact != null) {
        final name = '${contact['name'] ?? ''}'.trim();
        return name.isEmpty ? 'Contact' : 'Contact: $name';
      }
      return text.replaceAll('\n', ' ').trim();
    }
    if (item.isLocation) {
      if (item.locationAddress.isNotEmpty) return item.locationAddress;
      return item.isLiveLocation ? 'Live location' : 'Current location';
    }
    return 'Attachment: ${item.name}';
  }
}

class _AttachmentDraft {
  const _AttachmentDraft({
    required this.files,
    required this.caption,
    required this.restricted,
  });

  final List<PlatformFile> files;
  final String caption;
  final bool restricted;
}

class _MessageLocationMetadata {
  const _MessageLocationMetadata({
    this.latitude,
    this.longitude,
    this.address = '',
  });

  final double? latitude;
  final double? longitude;
  final String address;

  bool get hasLocation => latitude != null && longitude != null;
}

class _PendingChatMessage {
  const _PendingChatMessage({required this.message, required this.createdAt});

  final ChatMessage message;
  final DateTime createdAt;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    this.initialMessageId = 0,
    this.onProfileTap,
  });

  final ChatPreview chat;
  final int initialMessageId;
  final VoidCallback? onProfileTap;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  final List<ChatMessage> _messages = [];
  final List<_PendingChatMessage> _pendingOutgoing = [];
  Timer? _pollTimer;
  Timer? _draftTimer;
  bool _hasText = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  bool _showEmojiPicker = false;
  double _uploadProgress = 0;
  String? _loadError;
  PresenceInfo? _presence;
  ChatMessage? _replyingTo;
  String _replyQuote = '';
  int _threadRootId = 0;
  bool _isMuted = false;
  bool _historyRequestActive = false;
  bool _presenceRequestActive = false;
  bool _showJumpToLatest = false;
  int _savedReadMessageId = 0;
  int _returnReadMessageId = 0;
  int _newMessageCount = 0;
  bool _didJumpToInitialMessage = false;
  List<GroupMember> _groupMembers = [];
  String _groupRole = '';
  bool _canViewMessageLocations = false;
  String _mentionQuery = '';
  final Set<String> _selectedMentions = {};
  final Map<int, GlobalKey> _messageKeys = {};
  final Set<int> _selectedMessageIds = <int>{};
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final SpeechToText _speechToText = SpeechToText();
  bool _isRecordingVoice = false;
  String _voiceTranscript = '';
  String? _voiceRecordingPath;
  bool _isDragOver = false;
  Timer? _liveLocationTimer;
  bool _liveLocationSharing = false;
  DateTime? _liveLocationEndsAt;
  Position? _lastMessagePosition;
  DateTime? _lastMessagePositionAt;
  Future<Position?>? _messagePositionFuture;
  DateTime? _textSelectionActiveUntil;
  int? _selectionAnchorIndex;
  double _selectionAnchorAlignment = 0;
  String _lastClipboardPasteKey = '';
  DateTime? _lastClipboardPasteAt;
  String _lastMessageAddress = '';
  double? _lastMessageAddressLatitude;
  double? _lastMessageAddressLongitude;
  DateTime? _lastMessageAddressAt;
  bool get _isSystemNotification =>
      widget.chat.jid.toLowerCase() == systemNotificationJid;

  @override
  void initState() {
    super.initState();
    _loadInitialHistory();
    _loadConversationState();
    _itemPositionsListener.itemPositions.addListener(_trackScrollPosition);
    _loadPresence();
    if (widget.chat.isGroup) _loadGroupMembers();
    _loadMessageLocationVisibility();
    _warmMessageLocationMetadata();
    registerClipboardMediaHandler(_handleClipboardMediaPaste);
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      _loadHistory(silent: true);
      if (timer.tick % 5 == 0) _loadPresence();
    });
    /*
    _messages = [
      const ChatMessage(
        text: 'Hey! How are you doing?',
        time: '10:30 AM',
        isMe: false,
        sender: 'Priya',
      ),
      const ChatMessage(
        text: 'I am doing great! Just finishing up the Skylink designs.',
        time: '10:32 AM',
        isMe: true,
      ),
      const ChatMessage(
        text: 'That sounds exciting. Can you share a preview?',
        time: '10:34 AM',
        isMe: false,
        sender: 'Priya',
      ),
      const ChatMessage(
        text: 'Of course! The new chat experience is clean and super smooth.',
        time: '10:37 AM',
        isMe: true,
      ),
      ChatMessage(
        text: widget.chat.message,
        time: widget.chat.time.contains('AM') ? widget.chat.time : '10:42 AM',
        isMe: false,
        sender: widget.chat.isGroup
            ? 'Arun'
            : widget.chat.name.split(' ').first,
      ),
    ];
    */
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      final mention = RegExp(
        r'@([A-Za-z0-9_]*)$',
      ).firstMatch(_messageController.text);
      final mentionQuery = mention?.group(1)?.toLowerCase() ?? '';
      if (hasText != _hasText || mentionQuery != _mentionQuery) {
        setState(() {
          _hasText = hasText;
          _mentionQuery = mention == null ? '' : mentionQuery;
        });
      }
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 700), () {
        chatApi
            .saveDraft(
              jid: widget.chat.jid,
              body: _messageController.text,
              replyToId: _replyingTo?.id ?? 0,
            )
            .catchError((_) {});
      });
    });
  }

  Future<void> _loadConversationState() async {
    try {
      final state = await chatApi.getConversationState(widget.chat.jid);
      final draft = state['draft'];
      final position = state['read_position'];
      if (!mounted) return;
      if (draft is Map && _messageController.text.isEmpty) {
        _messageController.text = '${draft['body'] ?? ''}';
      }
      if (position is Map) {
        _savedReadMessageId =
            int.tryParse('${position['message_id'] ?? 0}') ?? 0;
        _returnReadMessageId = _savedReadMessageId;
        if (mounted) setState(() {});
      }
    } catch (error) {
      // Conversation state can synchronize on the next refresh.
    }
  }

  Future<void> _loadInitialHistory() async {
    var cached = chatApi.cachedHistory(widget.chat.jid);
    cached ??= await chatApi.persistedHistory(widget.chat.jid);
    if (cached.isNotEmpty) _applyHistory(cached);
    await _loadHistory(silent: cached.isNotEmpty);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _draftTimer?.cancel();
    _liveLocationTimer?.cancel();
    _saveVisibleReadPosition();
    _itemPositionsListener.itemPositions.removeListener(_trackScrollPosition);
    _voiceRecorder.dispose();
    _speechToText.stop();
    unregisterClipboardMediaHandler(_handleClipboardMediaPaste);
    _messageController.dispose();
    super.dispose();
  }

  void _trackScrollPosition() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || _messages.isEmpty) return;
    final lastVisible = positions
        .where((position) => position.itemTrailingEdge > 0)
        .map((position) => position.index)
        .fold<int>(0, (max, index) => index > max ? index : max);
    final shouldShow = lastVisible < _messages.length - 2;
    if (shouldShow != _showJumpToLatest && mounted) {
      setState(() {
        _showJumpToLatest = shouldShow;
        if (!shouldShow) _newMessageCount = 0;
      });
    }
    final firstVisible = positions
        .where((position) => position.itemTrailingEdge > 0)
        .map((position) => position.index)
        .fold<int>(_messages.length - 1, min);
    if (firstVisible >= 0 && firstVisible < _messages.length) {
      final id = _messages[firstVisible].id;
      if (id > 0) _savedReadMessageId = id;
    }
  }

  void _saveVisibleReadPosition() {
    if (_savedReadMessageId > 0) {
      chatApi
          .saveReadPosition(
            jid: widget.chat.jid,
            messageId: _savedReadMessageId,
          )
          .catchError((_) {});
    }
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (_historyRequestActive) return;
    _historyRequestActive = true;
    try {
      final readLocation = await _messageLocationMetadata(
        positionTimeout: const Duration(milliseconds: 450),
        addressTimeout: const Duration(milliseconds: 250),
      );
      final history = await chatApi.getHistory(
        widget.chat.jid,
        readLatitude: readLocation.latitude,
        readLongitude: readLocation.longitude,
        readLocationAddress: readLocation.address,
        targetMessageId: !_didJumpToInitialMessage
            ? widget.initialMessageId
            : 0,
      );
      if (!mounted) return;
      _applyHistory(history);
    } on ApiException catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _loadError = error.message;
        });
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _loadError = 'Unable to load messages.';
        });
      }
    } finally {
      _historyRequestActive = false;
    }
  }

  void _applyHistory(List<ApiMessage> history) {
    if (!mounted) return;
    final historyMessages = history.map((message) {
      final attachment = message.attachment;
      return ChatMessage(
        id: int.tryParse(message.id) ?? 0,
        text: attachment == null ? message.body : '',
        time: message.time,
        isMe: message.isMine,
        sender: message.isMine
            ? null
            : message.senderName.isEmpty
            ? widget.chat.name
            : message.senderName,
        isRead: message.status.toLowerCase() == 'read',
        readAt: message.readAt,
        attachment: attachment,
        replyToId: int.tryParse(message.replyToId) ?? 0,
        threadRootId: int.tryParse(message.threadRootId) ?? 0,
        mentions: message.mentions,
        isEdited: message.isEdited,
        sourceDevice: message.sourceDevice,
        sourceName: message.sourceName,
        locationAddress: message.locationAddress,
        createdAt: DateTime.tryParse(message.createdAt)?.toLocal(),
        originalSenderJid: message.originalSenderJid,
        originalSenderName: message.originalSenderName,
        originalSourceName: message.originalSourceName,
        visibilityMode: message.visibilityMode,
        isSystem: message.messageType == 'system',
      );
    }).toList();
    final now = DateTime.now();
    _pendingOutgoing.removeWhere(
      (pending) =>
          now.difference(pending.createdAt) > const Duration(minutes: 5) ||
          historyMessages.any(
            (message) => _sameOutgoingMessage(message, pending.message),
          ),
    );
    final refreshedMessages = [
      ...historyMessages,
      ..._pendingOutgoing.map((pending) => pending.message),
    ];
    final previousIds = _messages
        .where((message) => message.id > 0)
        .map((message) => message.id)
        .toSet();
    final addedCount = refreshedMessages
        .where((message) => message.id > 0 && !previousIds.contains(message.id))
        .length;
    final wasEmpty = _messages.isEmpty;
    final viewingOlderMessages = _showJumpToLatest;
    setState(() {
      _messages
        ..clear()
        ..addAll(refreshedMessages);
      _isLoading = false;
      _loadError = null;
      if (viewingOlderMessages && addedCount > 0) {
        _newMessageCount += addedCount;
      }
    });
    if (!_didJumpToInitialMessage && widget.initialMessageId > 0) {
      _didJumpToInitialMessage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToMessage(widget.initialMessageId);
      });
    } else if (wasEmpty) {
      // The message list is initially built at the latest item via initialScrollIndex.
    } else if (!viewingOlderMessages && addedCount > 0) {
      _scrollToBottom();
    }
  }

  Future<void> _loadPresence() async {
    if (widget.chat.isGroup || _presenceRequestActive) return;
    _presenceRequestActive = true;
    try {
      final presence = await chatApi.getPresence(widget.chat.jid);
      if (mounted) setState(() => _presence = presence);
    } catch (error) {
      // Keep the most recently known presence.
    } finally {
      _presenceRequestActive = false;
    }
  }

  Future<void> _loadGroupMembers() async {
    if (!widget.chat.isGroup) return;
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    try {
      final result = await chatApi.getGroupMembers(groupId);
      if (mounted) {
        setState(() {
          _groupMembers = result.members;
          _groupRole = result.currentRole;
        });
      }
    } catch (error) {
      // Group messages remain available if member details cannot refresh.
    }
  }
  Map<int, String> _participantNamesForMessage(ChatMessage message) {
    final names = <int, String>{};
    final myId = int.tryParse(chatApi.currentJid.split('@').first);
    if (myId != null && myId > 0) names[myId] = 'You';
    final directId = int.tryParse(widget.chat.empId);
    if (!widget.chat.isGroup && directId != null && directId > 0) {
      names[directId] = widget.chat.name;
    }
    for (final member in _groupMembers) {
      final id = int.tryParse(member.empId);
      if (id != null && id > 0) {
        names[id] = member.name.trim().isEmpty ? member.empId : member.name;
      }
    }
    return names;
  }

  Future<void> _loadMessageLocationVisibility() async {
    try {
      final visibility = await chatApi.getMyLocationVisibility();
      final enabled =
          visibility['enabled'] == true ||
          '${visibility['enabled'] ?? ''}' == '1';
      if (mounted) setState(() => _canViewMessageLocations = enabled);
    } catch (error) {
      // Message info must stay usable even if permission lookup fails.
    }
  }

  String get _presenceLabel {
    if (widget.chat.isChannel) {
      final label = widget.chat.designation.trim();
      return label.isEmpty ? 'Channel' : label;
    }
    if (widget.chat.isGroup) return 'Group conversation';
    final presence = _presence;
    if (presence?.isOnline ?? widget.chat.isOnline) return 'online';
    final lastSeen = presence?.lastSeen;
    if (lastSeen == null) return 'last seen recently';
    final now = DateTime.now();
    final sameDay =
        lastSeen.year == now.year &&
        lastSeen.month == now.month &&
        lastSeen.day == now.day;
    final hour = lastSeen.hour == 0
        ? 12
        : lastSeen.hour > 12
        ? lastSeen.hour - 12
        : lastSeen.hour;
    final minute = lastSeen.minute.toString().padLeft(2, '0');
    final clock = '$hour:$minute ${lastSeen.hour >= 12 ? 'PM' : 'AM'}';
    if (sameDay) return 'last seen today at $clock';
    return 'last seen ${lastSeen.day}/${lastSeen.month} at $clock';
  }

  Future<bool> _scheduleMessageBody(String body) async {
    if (_isSystemNotification || body.trim().isEmpty) return false;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return false;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return false;
    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time.')),
      );
      return false;
    }
    try {
      await chatApi.scheduleMessage(
        message: body.trim(),
        scheduledAt: scheduledAt.toIso8601String(),
        targets: [widget.chat.jid],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message scheduled for ${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year} ${TimeOfDay.fromDateTime(scheduledAt).format(context)}.',
            ),
          ),
        );
      }
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  Future<void> _scheduleDraftMessage() async {
    final body = _messageController.text.trim();
    if (await _scheduleMessageBody(body) && mounted) {
      _messageController.clear();
      setState(() => _hasText = false);
    }
  }

  Future<void> _showSendTargetOptions() async {
    if (!widget.chat.isGroup || _messageController.text.trim().isEmpty) {
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: const Text('Send to all'),
              subtitle: const Text('Visible to every member'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_person_rounded),
              title: const Text('Send selected users'),
              subtitle: const Text('Visible only to selected members'),
              onTap: () => Navigator.pop(context, 'selected'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'all') {
      await _sendMessage();
    } else if (action == 'selected') {
      await _sendMessageToSelectedUsers();
    }
  }

  Future<void> _sendMessageToSelectedUsers() async {
    if (!widget.chat.isGroup) return;
    if (_groupMembers.isEmpty) {
      await _loadGroupMembers();
    }
    if (!mounted) return;
    final selected = <String>{};
    var memberQuery = '';
    final recipients = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final canSend = selected.isNotEmpty;
          final needle = memberQuery.trim().toLowerCase();
          final visibleMembers = _groupMembers.where((member) {
            if (needle.isEmpty) return true;
            return member.name.toLowerCase().contains(needle) ||
                member.empId.toLowerCase().contains(needle) ||
                member.designation.toLowerCase().contains(needle) ||
                member.role.toLowerCase().contains(needle);
          }).toList();
          return SafeArea(
            child: SizedBox(
              height: min(MediaQuery.sizeOf(context).height * 0.78, 620),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Send selected users',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: canSend
                              ? () => Navigator.pop(
                                  context,
                                  selected.toList(growable: false),
                                )
                              : null,
                          child: Text('Send (${selected.length})'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search members',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) =>
                          setSheetState(() => memberQuery = value),
                    ),
                  ),
                  Expanded(
                    child: visibleMembers.isEmpty
                        ? const Center(child: Text('No members found.'))
                        : ListView.builder(
                            itemCount: visibleMembers.length,
                            itemBuilder: (context, index) {
                              final member = visibleMembers[index];
                              final checked = selected.contains(member.empId);
                              return CheckboxListTile(
                                value: checked,
                                onChanged: (_) {
                                  setSheetState(() {
                                    if (checked) {
                                      selected.remove(member.empId);
                                    } else {
                                      selected.add(member.empId);
                                    }
                                  });
                                },
                                secondary: CircleAvatar(
                                  child: Text(
                                    (member.name.isEmpty
                                            ? member.empId
                                            : member.name)
                                        .trim()
                                        .substring(0, 1),
                                  ),
                                ),
                                title: Text(
                                  member.name.isEmpty
                                      ? member.empId
                                      : member.name,
                                ),
                                subtitle: Text(
                                  member.role == 'owner'
                                      ? 'Owner'
                                      : member.role == 'admin'
                                      ? 'Admin'
                                      : member.designation,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (recipients == null || recipients.isEmpty || !mounted) return;
    await _sendMessage(recipientEmpIds: recipients);
  }

  Future<void> _sendMessage({List<String> recipientEmpIds = const []}) async {
    if (_isSystemNotification) return;
    var text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    if (_replyQuote.isNotEmpty) {
      text =
          '${_replyQuote.split('\n').map((line) => '> $line').join('\n')}\n\n$text';
    }
    final chunks = _splitMessage(text);
    final detectedMentions = _mentionsFromText(text);
    final reply = _replyingTo;
    final temporary = <ChatMessage>[];
    for (var index = 0; index < chunks.length; index++) {
      temporary.add(
        ChatMessage(
          id: -(DateTime.now().microsecondsSinceEpoch + index),
          text: chunks[index],
          time: TimeOfDay.now().format(context),
          isMe: true,
          isRead: false,
          replyToId: index == 0 ? reply?.id ?? 0 : 0,
          threadRootId: _threadRootId,
          mentions: index == 0 ? detectedMentions : const [],
          sourceDevice: 'this device',
          createdAt: DateTime.now(),
          isSending: true,
          visibilityMode: recipientEmpIds.isEmpty ? 'all' : 'selected',
        ),
      );
    }
    setState(() {
      _messages.addAll(temporary);
      _replyingTo = null;
      _replyQuote = '';
      _threadRootId = 0;
      _selectedMentions.clear();
      _showEmojiPicker = false;
    });
    _messageController.clear();
    _scrollToBottom();
    try {
      final batchId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
      final sendLocation = await _messageLocationMetadata();
      for (var index = 0; index < chunks.length; index++) {
        final messageId = await chatApi.sendMessage(
          to: widget.chat.jid,
          message: chunks[index],
          replyToId: index == 0 && (reply?.id ?? 0) > 0 ? '${reply!.id}' : '',
          mentions: index == 0 ? temporary[index].mentions : const [],
          threadRootId: temporary[index].threadRootId > 0
              ? '${temporary[index].threadRootId}'
              : '',
          latitude: sendLocation.latitude,
          longitude: sendLocation.longitude,
          locationAddress: sendLocation.address,
          clientMessageId: '$batchId-$index',
          recipientEmpIds: recipientEmpIds,
        );
        if (!mounted) return;
        setState(() {
          final messageIndex = _messages.indexWhere(
            (item) => item.id == temporary[index].id,
          );
          if (messageIndex >= 0) {
            final sent = temporary[index].copyWith(
              id: messageId,
              isSending: false,
            );
            _messages[messageIndex] = sent;
            _pendingOutgoing.add(
              _PendingChatMessage(message: sent, createdAt: DateTime.now()),
            );
          }
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        for (final pending in temporary) {
          final index = _messages.indexWhere((item) => item.id == pending.id);
          if (index >= 0) {
            _messages[index] = pending.copyWith(
              isSending: false,
              isFailed: true,
            );
          }
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        for (final pending in temporary) {
          final index = _messages.indexWhere((item) => item.id == pending.id);
          if (index >= 0) {
            _messages[index] = pending.copyWith(
              isSending: false,
              isFailed: true,
            );
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send the message: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _coordinateAddress(Position position) {
    return '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }

  bool _isFreshMessagePosition(Position? position) {
    final capturedAt = _lastMessagePositionAt;
    return position != null &&
        capturedAt != null &&
        DateTime.now().difference(capturedAt) < const Duration(minutes: 5);
  }

  bool _isFreshMessageAddress(Position position) {
    final capturedAt = _lastMessageAddressAt;
    final addressLat = _lastMessageAddressLatitude;
    final addressLng = _lastMessageAddressLongitude;
    if (_lastMessageAddress.isEmpty ||
        capturedAt == null ||
        addressLat == null ||
        addressLng == null) {
      return false;
    }
    if (DateTime.now().difference(capturedAt) > const Duration(minutes: 15)) {
      return false;
    }
    return (addressLat - position.latitude).abs() < 0.0005 &&
        (addressLng - position.longitude).abs() < 0.0005;
  }

  Future<Position?> _currentMessagePosition() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );
      _lastMessagePosition = position;
      _lastMessagePositionAt = DateTime.now();
      return position;
    } catch (error) {
      return _isFreshMessagePosition(_lastMessagePosition)
          ? _lastMessagePosition
          : null;
    }
  }

  Future<Position?> _fastMessagePosition({
    Duration timeout = const Duration(milliseconds: 1800),
  }) async {
    if (_isFreshMessagePosition(_lastMessagePosition)) {
      return _lastMessagePosition;
    }
    _messagePositionFuture ??= _currentMessagePosition().whenComplete(() {
      _messagePositionFuture = null;
    });
    try {
      return await _messagePositionFuture!.timeout(
        timeout,
        onTimeout: () => _isFreshMessagePosition(_lastMessagePosition)
            ? _lastMessagePosition
            : null,
      );
    } catch (_) {
      return _isFreshMessagePosition(_lastMessagePosition)
          ? _lastMessagePosition
          : null;
    }
  }

  Future<String> _resolveLocationAddress(Position position) async {
    try {
      final address = await chatApi.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      return address.trim().isNotEmpty
          ? address.trim()
          : _coordinateAddress(position);
    } catch (_) {
      return _coordinateAddress(position);
    }
  }

  Future<String> _fastLocationAddress(
    Position? position, {
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    if (position == null) return '';
    if (_isFreshMessageAddress(position)) return _lastMessageAddress;
    final fallback = _coordinateAddress(position);
    try {
      final address = await _resolveLocationAddress(
        position,
      ).timeout(timeout, onTimeout: () => fallback);
      final normalized = address.trim().isNotEmpty ? address.trim() : fallback;
      _lastMessageAddress = normalized;
      _lastMessageAddressLatitude = position.latitude;
      _lastMessageAddressLongitude = position.longitude;
      _lastMessageAddressAt = DateTime.now();
      return normalized;
    } catch (_) {
      return fallback;
    }
  }

  Future<_MessageLocationMetadata> _messageLocationMetadata({
    Duration positionTimeout = const Duration(milliseconds: 1800),
    Duration addressTimeout = const Duration(milliseconds: 900),
  }) async {
    final position = await _fastMessagePosition(timeout: positionTimeout);
    final address = await _fastLocationAddress(
      position,
      timeout: addressTimeout,
    );
    return _MessageLocationMetadata(
      latitude: position?.latitude,
      longitude: position?.longitude,
      address: address,
    );
  }

  Future<void> _warmMessageLocationMetadata() async {
    unawaited(
      _messageLocationMetadata(
        positionTimeout: const Duration(seconds: 3),
        addressTimeout: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _sendLocationAttachment({
    required Position position,
    required String locationAddress,
    bool isLive = false,
    int liveMinutes = 0,
    String shareId = '',
    bool showSuccess = true,
  }) async {
    final reply = _replyingTo;
    final threadRootId = _threadRootId;
    final mentions = _selectedMentions.toList();
    final messageId = await chatApi.sendLocationMessage(
      to: widget.chat.jid,
      latitude: position.latitude,
      longitude: position.longitude,
      locationAddress: locationAddress,
      isLiveLocation: isLive,
      liveMinutes: liveMinutes,
      shareId: shareId,
      replyToId: reply?.id == 0 ? '' : '${reply?.id ?? ''}',
      mentions: mentions,
      threadRootId: threadRootId > 0 ? '$threadRootId' : '',
      clientMessageId:
          '${isLive ? 'live' : 'loc'}-$shareId-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!mounted) return;
    final attachment = ChatAttachment.location(
      latitude: position.latitude,
      longitude: position.longitude,
      locationAddress: locationAddress,
      isLiveLocation: isLive,
      liveMinutes: liveMinutes,
      shareId: shareId,
    );
    setState(() {
      _messages.add(
        ChatMessage(
          id: messageId,
          text: attachment.encode(),
          time: TimeOfDay.now().format(context),
          isMe: true,
          isRead: false,
          attachment: attachment,
          replyToId: reply?.id ?? 0,
          threadRootId: threadRootId,
          mentions: mentions,
        ),
      );
      _replyingTo = null;
      _selectedMentions.clear();
      _showEmojiPicker = false;
      _threadRootId = 0;
    });
    _scrollToBottom();
    if (showSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLive ? 'Live location shared.' : 'Location shared.'),
        ),
      );
    }
  }

  Future<void> _sendCurrentLocationAttachment() async {
    if (_isUploading) return;
    final position = await _currentMessagePosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable location to send your position.'),
          ),
        );
      }
      return;
    }
    final address = await _resolveLocationAddress(position);
    await _sendLocationAttachment(position: position, locationAddress: address);
  }

  Future<int?> _pickLiveLocationMinutes() async {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Live location duration'),
              subtitle: const Text(
                'Choose how long to share your location. Updates every 1 minute.',
              ),
            ),
            for (final entry in const [
              (15, '15 minutes'),
              (60, '1 hour'),
              (180, '3 hours'),
              (480, '8 hours'),
            ])
              ListTile(
                leading: const Icon(Icons.timelapse_rounded),
                title: Text(entry.$2),
                onTap: () => Navigator.pop(sheetContext, entry.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendLiveLocationAttachment() async {
    if (_isUploading || _liveLocationSharing) return;
    final liveMinutes = await _pickLiveLocationMinutes();
    if (!mounted || liveMinutes == null) return;
    final position = await _currentMessagePosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable location to share live updates.'),
          ),
        );
      }
      return;
    }
    final shareId = 'live-${DateTime.now().microsecondsSinceEpoch}';
    final endsAt = DateTime.now().add(Duration(minutes: liveMinutes));
    _liveLocationSharing = true;
    _liveLocationEndsAt = endsAt;
    final address = await _resolveLocationAddress(position);
    await _sendLocationAttachment(
      position: position,
      locationAddress: address,
      isLive: true,
      liveMinutes: liveMinutes,
      shareId: shareId,
    );
    _liveLocationTimer?.cancel();
    _liveLocationTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      if (!mounted || !_liveLocationSharing || _liveLocationEndsAt == null) {
        timer.cancel();
        return;
      }
      if (DateTime.now().isAfter(_liveLocationEndsAt!)) {
        timer.cancel();
        if (mounted) {
          setState(() => _liveLocationSharing = false);
        }
        return;
      }
      final nextPosition = await _currentMessagePosition();
      if (nextPosition == null) return;
      final nextAddress = await _resolveLocationAddress(nextPosition);
      await _sendLocationAttachment(
        position: nextPosition,
        locationAddress: nextAddress,
        isLive: true,
        liveMinutes: liveMinutes,
        shareId: shareId,
        showSuccess: false,
      );
    });
  }

  void _stopLiveLocationSharing() {
    _liveLocationTimer?.cancel();
    setState(() {
      _liveLocationSharing = false;
      _liveLocationEndsAt = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live location sharing stopped.')),
    );
  }

  List<String> _splitMessage(String text) {
    const limit = 3500;
    if (text.length <= limit) return [text];
    final chunks = <String>[];
    var remaining = text;
    while (remaining.length > limit) {
      var split = remaining.lastIndexOf('\n', limit);
      if (split < limit ~/ 2) split = remaining.lastIndexOf(' ', limit);
      if (split < limit ~/ 2) split = limit;
      chunks.add(remaining.substring(0, split).trim());
      remaining = remaining.substring(split).trimLeft();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isSystemNotification || _isUploading) return;
    if (_isRecordingVoice) {
      await _stopAndSendVoiceRecording();
      return;
    }
    try {
      if (!await _voiceRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required to record a voice message.',
              ),
            ),
          );
        }
        return;
      }
      final path = kIsWeb
          ? 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : await voiceRecordingFilePath();
      _voiceTranscript = '';
      final speechReady = await _speechToText.initialize();
      if (speechReady) {
        await _speechToText.listen(
          onResult: (result) => _voiceTranscript = result.recognizedWords,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
          ),
        );
      }
      await _voiceRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (mounted) {
        setState(() {
          _isRecordingVoice = true;
          _voiceRecordingPath = path;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start recording: $error')),
        );
      }
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    try {
      final stoppedPath = await _voiceRecorder.stop();
      await _speechToText.stop();
      if (mounted) setState(() => _isRecordingVoice = false);
      final path = stoppedPath ?? _voiceRecordingPath;
      if (path == null || path.isEmpty) return;
      Uint8List bytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw const ApiException('Unable to read the recorded audio.');
        }
        bytes = response.bodyBytes;
      } else {
        bytes = await File(path).readAsBytes();
      }
      if (!mounted) return;
      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });
      final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final sendLocation = await _messageLocationMetadata();
      final attachment = await chatApi.sendAttachment(
        to: widget.chat.jid,
        name: name,
        mimeType: 'audio/mp4',
        bytes: bytes,
        caption: _voiceTranscript.trim(),
        replyToId: _replyingTo?.id == 0 ? '' : '${_replyingTo?.id ?? ''}',
        threadRootId: _threadRootId > 0 ? '$_threadRootId' : '',
        latitude: sendLocation.latitude,
        longitude: sendLocation.longitude,
        locationAddress: sendLocation.address,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            id: attachment.messageId,
            text: '',
            time: TimeOfDay.now().format(context),
            isMe: true,
            isRead: false,
            attachment: attachment,
            replyToId: _replyingTo?.id ?? 0,
            threadRootId: _threadRootId,
          ),
        );
        _replyingTo = null;
        _threadRootId = 0;
      });
      _scrollToBottom();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send voice message: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _createPollFromComposer() async {
    final questionController = TextEditingController(
      text: _messageController.text.trim().isEmpty
          ? 'Poll'
          : _messageController.text.trim(),
    );
    final optionsController = TextEditingController();
    var allowMultiple = false;
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create poll'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: const InputDecoration(labelText: 'Question'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: optionsController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Options',
                    helperText: 'Enter one option per line.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: allowMultiple,
                  title: const Text('Allow multiple answers'),
                  onChanged: (value) =>
                      setDialogState(() => allowMultiple = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.poll_outlined),
              label: const Text('Send poll'),
            ),
          ],
        ),
      ),
    );
    final question = questionController.text.trim();
    final options = optionsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    questionController.dispose();
    optionsController.dispose();
    if (create != true || question.isEmpty || options.length < 2) return;
    final body =
        'SKYLINK_POLL:${jsonEncode(<String, dynamic>{
          'question': question,
          'allow_multiple': allowMultiple,
          'options': options.map((text) => {'text': text, 'votes': <int>[]}).toList(),
          'created_at': DateTime.now().toIso8601String(),
        })}';
    await chatApi.sendMessage(
      to: widget.chat.jid,
      message: body,
      clientMessageId: 'poll-${DateTime.now().microsecondsSinceEpoch}',
    );
    _messageController.clear();
    await _loadHistory(silent: true);
  }

  Future<void> _createChecklistFromComposer() async {
    final seed = _messageController.text.trim();
    await _createChecklistFromMessage(
      ChatMessage(
        text: seed,
        time: TimeOfDay.now().format(context),
        isMe: true,
      ),
    );
  }

  Future<void> _pickAndSendContact() async {
    if (kIsWeb || !Platform.isAndroid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact picker is available on Android.'),
        ),
      );
      return;
    }
    final permission = await ph.Permission.contacts.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacts permission is required to send a contact.'),
        ),
      );
      return;
    }
    try {
      final picked = await androidPlatform.invokeMapMethod<String, dynamic>(
        'pickContact',
      );
      if (!mounted || picked == null) return;
      final phones = (picked['phones'] is List)
          ? (picked['phones'] as List)
                .map((value) => '$value')
                .where((value) => value.trim().isNotEmpty)
                .toList()
          : <String>[];
      final emails = (picked['emails'] is List)
          ? (picked['emails'] as List)
                .map((value) => '$value')
                .where((value) => value.trim().isNotEmpty)
                .toList()
          : <String>[];
      final contact = <String, dynamic>{
        'name': '${picked['name'] ?? ''}'.trim(),
        'phones': phones,
        'emails': emails,
      };
      if ('${contact['name']}'.trim().isEmpty &&
          phones.isEmpty &&
          emails.isEmpty) {
        return;
      }
      final body = encodeContactCard(contact);
      final sendLocation = await _messageLocationMetadata();
      await chatApi.sendMessage(
        to: widget.chat.jid,
        message: body,
        replyToId: _replyingTo?.id == 0 ? '' : '${_replyingTo?.id ?? ''}',
        mentions: _selectedMentions.toList(),
        threadRootId: _threadRootId > 0 ? '$_threadRootId' : '',
        latitude: sendLocation.latitude,
        longitude: sendLocation.longitude,
        locationAddress: sendLocation.address,
        clientMessageId: 'contact-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: body,
            time: TimeOfDay.now().format(context),
            isMe: true,
            isRead: false,
            replyToId: _replyingTo?.id ?? 0,
            threadRootId: _threadRootId,
            mentions: _selectedMentions.toList(),
          ),
        );
        _replyingTo = null;
        _threadRootId = 0;
        _selectedMentions.clear();
      });
      _scrollToBottom();
    } on PlatformException catch (error) {
      if (!mounted || error.code == 'cancelled') return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to pick contact.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to send contact: $error')));
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (_isUploading) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo or image'),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Document or file'),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Create checklist'),
              onTap: () => Navigator.pop(sheetContext, 'checklist'),
            ),
            ListTile(
              leading: const Icon(Icons.poll_outlined),
              title: const Text('Create poll'),
              onTap: () => Navigator.pop(sheetContext, 'poll'),
            ),
            ListTile(
              leading: const Icon(Icons.contacts_rounded),
              title: const Text('Contact'),
              onTap: () => Navigator.pop(sheetContext, 'contact'),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Current location'),
              onTap: () => Navigator.pop(sheetContext, 'location'),
            ),
            ListTile(
              leading: const Icon(Icons.location_searching_rounded),
              title: const Text('Live location'),
              subtitle: const Text('Share updates every 1 minute.'),
              onTap: () => Navigator.pop(sheetContext, 'live_location'),
            ),
            if (_liveLocationSharing)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Stop live location'),
                subtitle: _liveLocationEndsAt == null
                    ? null
                    : Text(
                        'Active until ${TimeOfDay.fromDateTime(_liveLocationEndsAt!).format(context)}',
                      ),
                onTap: () => Navigator.pop(sheetContext, 'stop_live_location'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'image':
        final images = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.image,
          withData: kIsWeb,
        );
        if (!mounted || images == null || images.files.isEmpty) return;
        await _sendPickedFiles(images.files);
        return;
      case 'file':
        final result = await FilePicker.pickFiles(
          allowMultiple: true,
          withData: kIsWeb,
        );
        if (!mounted || result == null || result.files.isEmpty) return;
        await _sendPickedFiles(result.files);
        return;
      case 'checklist':
        await _createChecklistFromComposer();
        return;
      case 'poll':
        await _createPollFromComposer();
        return;
      case 'contact':
        await _pickAndSendContact();
        return;
      case 'location':
        await _sendCurrentLocationAttachment();
        return;
      case 'live_location':
        await _sendLiveLocationAttachment();
        return;
      case 'stop_live_location':
        _stopLiveLocationSharing();
        return;
      default:
        return;
    }
  }

  Future<void> _handleDroppedFiles(List<dynamic> files) async {
    if (_isUploading) return;
    if (_isDragOver && mounted) setState(() => _isDragOver = false);
    final converted = await _platformFilesFromDroppedFiles(files);
    if (!mounted || converted.isEmpty) return;
    await _sendPickedFiles(converted);
  }

  Future<void> _handleClipboardMediaPaste(List<PastedMediaFile> files) async {
    if (!mounted || _isUploading || files.isEmpty) return;
    final pasteKey = files.map((file) {
      final bytes = file.bytes;
      var hash = 0;
      for (var index = 0; index < bytes.length; index += max(1, bytes.length ~/ 64)) {
        hash = 0x1fffffff & (hash + bytes[index] + ((hash << 10) & 0x1fffffff));
        hash ^= hash >> 6;
      }
      return '${file.name}|${file.mimeType}|${bytes.length}|$hash';
    }).join('::');
    final now = DateTime.now();
    final previousAt = _lastClipboardPasteAt;
    if (pasteKey == _lastClipboardPasteKey &&
        previousAt != null &&
        now.difference(previousAt) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastClipboardPasteKey = pasteKey;
    _lastClipboardPasteAt = now;
    final converted = _platformFilesFromClipboard(files);
    if (converted.isEmpty) return;
    await _sendPickedFiles(converted);
  }

  Future<void> _sendPickedFiles(List<PlatformFile> files) async {
    if (_isUploading || files.isEmpty) return;
    final draft = await _previewAttachments(files);
    if (!mounted || draft == null || draft.files.isEmpty) return;
    files = draft.files;
    final caption = draft.caption;
    final restricted = draft.restricted;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    try {
      final reply = _replyingTo;
      final sendLocation = await _messageLocationMetadata();
      if (!mounted) return;
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        var bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        if (bytes == null) {
          throw ApiException('Unable to read ${file.name}.');
        }
        final mimeType = mimeTypeForFile(file.name);
        final tempId = -(DateTime.now().microsecondsSinceEpoch + index);
        final tempAttachment = ChatAttachment(
          name: file.name,
          url: '',
          mimeType: mimeType,
          size: bytes.length,
          caption: index == 0 ? caption : '',
          isRestricted: restricted,
        );
        final tempMessage = ChatMessage(
          id: tempId,
          text: '',
          time: TimeOfDay.now().format(context),
          isMe: true,
          isRead: false,
          attachment: tempAttachment,
          replyToId: reply?.id ?? 0,
          threadRootId: _threadRootId,
          mentions: _selectedMentions.toList(),
          isSending: true,
        );
        setState(() => _messages.add(tempMessage));
        _scrollToBottom();
        try {
          final attachment = await chatApi.sendAttachment(
            to: widget.chat.jid,
            name: file.name,
            mimeType: mimeType,
            bytes: bytes,
            caption: index == 0 ? caption : '',
            restricted: restricted,
            replyToId: reply?.id == 0 ? '' : '${reply?.id ?? ''}',
            mentions: _selectedMentions.toList(),
            threadRootId: _threadRootId > 0 ? '$_threadRootId' : '',
            latitude: sendLocation.latitude,
            longitude: sendLocation.longitude,
            locationAddress: sendLocation.address,
            clientMessageId:
                'file-${DateTime.now().microsecondsSinceEpoch}-$index',
            onProgress: (progress) {
              if (mounted) {
                setState(
                  () => _uploadProgress = (index + progress) / files.length,
                );
              }
            },
          );
          if (!mounted) return;
          final message = tempMessage.copyWith(
            id: attachment.messageId,
            attachment: attachment,
            isSending: false,
          );
          setState(() {
            final messageIndex = _messages.indexWhere(
              (item) => item.id == tempId,
            );
            if (messageIndex >= 0) {
              _messages[messageIndex] = message;
            } else {
              _messages.add(message);
            }
            _pendingOutgoing.add(
              _PendingChatMessage(message: message, createdAt: DateTime.now()),
            );
          });
        } catch (_) {
          if (mounted) {
            setState(() {
              final messageIndex = _messages.indexWhere(
                (item) => item.id == tempId,
              );
              if (messageIndex >= 0) {
                _messages[messageIndex] = tempMessage.copyWith(
                  isSending: false,
                  isFailed: true,
                );
              }
            });
          }
          rethrow;
        }
      }
      setState(() {
        _replyingTo = null;
        _selectedMentions.clear();
      });
      _scrollToBottom();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to upload the file.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDragOver = false;
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<List<PlatformFile>> _platformFilesFromDroppedFiles(
    List<dynamic> files,
  ) async {
    final converted = <PlatformFile>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      converted.add(
        PlatformFile(
          name: file.name,
          size: bytes.length,
          bytes: bytes,
          path: file.path,
        ),
      );
    }
    return converted;
  }

  List<PlatformFile> _platformFilesFromClipboard(List<PastedMediaFile> files) {
    return files
        .map(
          (file) => PlatformFile(
            name: file.name,
            size: file.bytes.length,
            bytes: file.bytes,
          ),
        )
        .toList();
  }

  Future<Uint8List> _editImageBeforeSend({
    required String fileName,
    required String? path,
    required Uint8List bytes,
  }) async {
    return bytes;
  }

  Future<_AttachmentDraft?> _previewAttachments(
    List<PlatformFile> initialFiles,
  ) async {
    final captionController = TextEditingController();
    var files = List<PlatformFile>.from(initialFiles);
    var restricted = false;
    try {
      return await showDialog<_AttachmentDraft>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            void send() {
              if (files.isEmpty) return;
              Navigator.pop(
                dialogContext,
                _AttachmentDraft(
                  files: List<PlatformFile>.from(files),
                  caption: captionController.text.trim(),
                  restricted: restricted,
                ),
              );
            }

            final first = files.isEmpty ? null : files.first;
            final title = files.length == 1
                ? (mimeTypeForFile(first!.name).startsWith('image/')
                      ? 'Send an image'
                      : 'Send as a file')
                : 'Send ${files.length} files';
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 330),
                      child: files.isEmpty
                          ? const Center(child: Text('No files selected.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: files.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 18),
                              itemBuilder: (_, index) {
                                final file = files[index];
                                final mimeType = mimeTypeForFile(file.name);
                                final isImage = mimeType.startsWith('image/');
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox.square(
                                      dimension: 72,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.09,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: isImage && file.bytes != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  file.bytes!,
                                                  fit: BoxFit.cover,
                                                  gaplessPlayback: true,
                                                ),
                                              )
                                            : Icon(
                                                _iconForMimeType(mimeType),
                                                color: AppColors.primary,
                                                size: 34,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            file.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(formatFileBytes(file.size)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove',
                                      onPressed: () {
                                        setDialogState(
                                          () => files.removeAt(index),
                                        );
                                        if (files.isEmpty)
                                          Navigator.pop(dialogContext);
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: restricted,
                      title: const Text('Restricted'),
                      subtitle: const Text('Open only inside Flow. Download and Open with are disabled.'),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) => setDialogState(
                        () => restricted = value ?? false,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Focus(
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent)
                          return KeyEventResult.ignored;
                        final isEnter =
                            event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.numpadEnter;
                        if (!isEnter) return KeyEventResult.ignored;
                        final insertNewLine =
                            HardwareKeyboard.instance.isShiftPressed ||
                            HardwareKeyboard.instance.isControlPressed ||
                            HardwareKeyboard.instance.isMetaPressed;
                        if (insertNewLine) return KeyEventResult.ignored;
                        send();
                        return KeyEventResult.handled;
                      },
                      child: TextField(
                        controller: captionController,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Caption',
                          hintText: 'Add a caption (optional)',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
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
                FilledButton.icon(
                  onPressed: files.isEmpty ? null : send,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      captionController.dispose();
    }
  }

  IconData _iconForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.movie_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mimeType.contains('location')) return Icons.location_on_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('zip') || mimeType.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  bool _sameOutgoingMessage(ChatMessage first, ChatMessage second) {
    if (!first.isMe || !second.isMe) return false;
    final firstAttachment = first.attachment;
    final secondAttachment = second.attachment;
    if (firstAttachment != null || secondAttachment != null) {
      return firstAttachment?.url == secondAttachment?.url;
    }
    return first.text == second.text;
  }

  ChatMessage? _messageById(int id) {
    if (id <= 0) return null;
    for (final message in _messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  List<GroupMember> get _mentionSuggestions {
    if (!widget.chat.isGroup ||
        !RegExp(r'@[A-Za-z0-9_]*$').hasMatch(_messageController.text)) {
      return const [];
    }
    final special =
        [
          const GroupMember(
            empId: '@channel',
            name: 'channel',
            designation: 'Notify everyone in this channel',
            jid: '',
            role: 'special',
          ),
          const GroupMember(
            empId: '@online',
            name: 'online',
            designation: 'Notify online members',
            jid: '',
            role: 'special',
          ),
          const GroupMember(
            empId: '@admins',
            name: 'admins',
            designation: 'Notify owners and admins',
            jid: '',
            role: 'special',
          ),
        ].where((member) {
          return _mentionQuery.isEmpty || member.name.contains(_mentionQuery);
        });
    return [
      ...special,
      ..._groupMembers
          .where((member) {
            final searchable =
                '${member.name.replaceAll(' ', '_')} ${member.empId}'
                    .toLowerCase();
            return _mentionQuery.isEmpty || searchable.contains(_mentionQuery);
          })
          .take(5),
    ].take(8).toList();
  }

  void _selectMention(GroupMember member) {
    final text = _messageController.text;
    final match = RegExp(r'@[A-Za-z0-9_]*$').firstMatch(text);
    if (match == null) return;
    final mention = '@${member.name.trim().replaceAll(RegExp(r'\s+'), '_')}';
    _messageController.value = TextEditingValue(
      text: text.replaceRange(match.start, match.end, '$mention '),
      selection: TextSelection.collapsed(
        offset: match.start + mention.length + 1,
      ),
    );
    setState(() {
      _selectedMentions.add(
        member.role == 'special' ? member.empId : member.empId,
      );
      _mentionQuery = '';
    });
  }

  Future<void> _openMentionProfile(String token) async {
    final normalized = token.trim().replaceFirst('@', '').toLowerCase();
    if (normalized.isEmpty) return;
    final specialMentions = {'channel', 'online', 'admins'};
    if (specialMentions.contains(normalized)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mention target: @$normalized')));
      return;
    }
    GroupMember? member;
    for (final item in _groupMembers) {
      final byName = item.name
          .trim()
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      if (byName == normalized || item.empId.toLowerCase() == normalized) {
        member = item;
        break;
      }
    }
    if (member == null) return;
    await _showUserProfile(empId: member.empId, fallbackName: member.name);
  }

  List<String> _mentionsFromText(String text) {
    final result = <String>{..._selectedMentions};
    final tokens = RegExp(
      r'@[A-Za-z0-9_]+',
    ).allMatches(text).map((match) => match.group(0)!.toLowerCase());
    for (final token in tokens) {
      if (const {'@channel', '@online', '@admins'}.contains(token)) {
        result.add(token);
        continue;
      }
      final normalized = token.substring(1).replaceAll('_', ' ');
      for (final member in _groupMembers) {
        if (member.name.toLowerCase() == normalized ||
            member.empId.toLowerCase() == normalized) {
          result.add(member.empId);
          break;
        }
      }
    }
    return result.toList();
  }

  void _toggleMessageSelection(ChatMessage message) {
    setState(() {
      if (!_selectedMessageIds.add(message.id)) {
        _selectedMessageIds.remove(message.id);
      }
    });
  }

  List<ChatMessage> get _selectedMessages => _messages
      .where((message) => _selectedMessageIds.contains(message.id))
      .toList();

  Future<void> _copyMessageToClipboard(ChatMessage message) async {
    final content = message.text.trim().isNotEmpty
        ? cleanMojibakeText(message.text.trim())
        : cleanMojibakeText(message.attachment?.name ?? message.previewText);
    if (content.isEmpty) return;
    try {
      final copied = await copyTextToClipboard(content);
      if (!copied) throw StateError('Clipboard copy failed');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message copied.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to copy message.')));
    }
  }

  Future<void> _copySelectedMessages() async {
    final selected = _selectedMessages;
    if (selected.isEmpty) return;
    final multiple = selected.length > 1;
    final text = selected
        .map((message) {
          final content = message.text.trim().isNotEmpty
              ? cleanMojibakeText(message.text.trim())
              : cleanMojibakeText(
                  message.attachment?.name ?? message.previewText,
                );
          if (!multiple) return content;
          final sender = message.isMe
              ? 'You'
              : (message.sender ?? widget.chat.name);
          return '$sender (${message.time}): $content';
        })
        .where((value) => value.isNotEmpty)
        .join(String.fromCharCode(10));
    if (text.isEmpty) return;
    final copied = await copyTextToClipboard(text);
    if (!copied) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to copy message.')));
      return;
    }
    if (!mounted) return;
    setState(_selectedMessageIds.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.length} message(s) copied.')),
    );
  }

  Future<ChatContact?> _pickForwardTarget() async {
    final values = await Future.wait([
      chatApi.getRecentChats(),
      chatApi.searchUsers(),
    ]);
    final byJid = <String, ChatContact>{};
    byJid[_savedMessagesForwardTarget.jid.toLowerCase()] = _savedMessagesForwardTarget;
    for (final chat in [...values[0], ...values[1]]) {
      byJid[chat.jid.toLowerCase()] = chat;
    }
    if (!mounted) return null;
    return showModalBottomSheet<ChatContact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForwardTargetSheet(chats: byJid.values.toList()),
    );
  }

  Future<void> _forwardSelectedMessages() async {
    final selected = _selectedMessages;
    final target = await _pickForwardTarget();
    if (target == null) return;
    for (final message in selected) {
      await _forwardMessageToTarget(
        message,
        target,
        clientMessagePrefix: 'multi-forward',
      );
    }
    if (mounted) {
      setState(_selectedMessageIds.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} message(s) forwarded to ${target.name}.',
          ),
        ),
      );
    }
  }

  static const String _savedMessagesForwardJid = 'saved@chat.skylinkonline.net';

  static const ChatContact _savedMessagesForwardTarget = ChatContact(
    empId: 'saved',
    name: 'Saved Messages',
    designation: 'Private notes',
    jid: _savedMessagesForwardJid,
    type: 'saved',
    isPinned: true,
  );

  bool _isSavedMessagesTarget(ChatContact target) =>
      target.jid.toLowerCase() == _savedMessagesForwardJid;

  Future<void> _forwardMessageToTarget(
    ChatMessage message,
    ChatContact target, {
    required String clientMessagePrefix,
  }) async {
    final body = message.attachment?.encode() ?? message.text;
    if (_isSavedMessagesTarget(target)) {
      final attachment = message.attachment;
      await chatApi.saveMessage(
        attachment?.caption.trim().isNotEmpty == true
            ? attachment!.caption
            : message.text,
        fileUrl: attachment?.url ?? '',
        fileName: attachment?.name ?? '',
        fileType: attachment?.mimeType ?? '',
      );
      return;
    }
    await chatApi.sendMessage(
      to: target.jid,
      message: body,
      clientMessageId:
          '$clientMessagePrefix-${message.id}-${DateTime.now().microsecondsSinceEpoch}',
      forwardedFromMessageId: message.id,
      originalSenderJid: message.originalSenderJid.isNotEmpty
          ? message.originalSenderJid
          : (message.isMe ? chatApi.currentJid : widget.chat.jid),
      originalSenderName: message.originalSenderName.isNotEmpty
          ? message.originalSenderName
          : (message.isMe ? 'You' : (message.sender ?? widget.chat.name)),
      originalSourceName: message.originalSourceName.isNotEmpty
          ? message.originalSourceName
          : message.sourceName,
    );
  }

  bool get _canDeleteSelectedMessages {
    final selected = _selectedMessages;
    return selected.isNotEmpty &&
        selected.every((message) => message.isMe && message.id > 0);
  }

  Future<void> _deleteSelectedMessages() async {
    final deletable = _selectedMessages;
    if (!_canDeleteSelectedMessages) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${deletable.length} message(s)?'),
        content: const Text('The selected sent messages will be unsent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final message in deletable) {
      await chatApi.unsendMessage(message.id);
    }
    if (!mounted) return;
    setState(() {
      final ids = deletable.map((message) => message.id).toSet();
      _messages.removeWhere((message) => ids.contains(message.id));
      _selectedMessageIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${deletable.length} message(s) deleted.')),
    );
  }

  ChatMessage? get _selectedPrimaryMessage =>
      _selectedMessages.isEmpty ? null : _selectedMessages.first;

  void _clearMessageSelection() {
    if (!mounted) return;
    setState(_selectedMessageIds.clear);
  }

  Future<void> _replyToSelectedMessage() async {
    final message = _selectedPrimaryMessage;
    if (message == null || message.isSystem) return;
    if (!mounted) return;
    setState(() {
      _replyingTo = message;
      _replyQuote = '';
      _selectedMessageIds.clear();
    });
  }

  Future<void> _quoteSelectedMessage() async {
    final message = _selectedPrimaryMessage;
    if (message == null) return;
    await _quoteMessage(message);
    _clearMessageSelection();
  }

  Future<void> _bookmarkSelectedMessages() async {
    final selected = _selectedMessages
        .where((message) => message.id > 0)
        .toList();
    if (selected.isEmpty) return;
    final shouldStar = !selected.every((message) => message.isStarred);
    try {
      for (final message in selected) {
        await chatApi.starMessage(message.id, shouldStar);
      }
      if (!mounted) return;
      setState(() {
        final ids = selected.map((message) => message.id).toSet();
        for (var i = 0; i < _messages.length; i++) {
          if (ids.contains(_messages[i].id)) {
            _messages[i] = _messages[i].copyWith(isStarred: shouldStar);
          }
        }
        _selectedMessageIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldStar ? 'Message bookmarked.' : 'Bookmark removed.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _pinSelectedMessages() async {
    final selected = _selectedMessages
        .where((message) => message.id > 0)
        .toList();
    if (selected.isEmpty) return;
    try {
      for (final message in selected) {
        await chatApi.pinMessage(message.id, true);
      }
      if (!mounted) return;
      _clearMessageSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} message(s) pinned.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _createTaskFromSelectedMessage() async {
    final message = _selectedPrimaryMessage;
    if (message == null) return;
    await _createTaskFromMessage(message);
    _clearMessageSelection();
  }

  String _selectedMessagesSummary() {
    final selected = _selectedMessages;
    if (selected.isEmpty) return '';
    final parts = <String>[];
    for (final message in selected.take(6)) {
      final prefix = message.isMe
          ? 'You'
          : (message.sender ?? widget.chat.name);
      final text = message.previewText.trim();
      if (text.isEmpty) continue;
      parts.add('$prefix: $text');
    }
    if (selected.length > 6) {
      parts.add('... and ${selected.length - 6} more message(s)');
    }
    return parts.join('\n');
  }

  Future<void> _showAiSummaryForSelection() async {
    final summary = _selectedMessagesSummary();
    if (summary.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI Summary'),
        content: SizedBox(
          width: 520,
          child: SelectionArea(
            child: Text(
              'Selected ${_selectedMessages.length} message(s).\n\n$summary',
              style: const TextStyle(height: 1.45),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _translateSelection() async {
    final summary = _selectedMessagesSummary();
    if (summary.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Translate'),
        content: SizedBox(
          width: 520,
          child: SelectionArea(
            child: Text(
              'Translation workflow is ready to wire into a language service.\n\n$summary',
              style: const TextStyle(height: 1.45),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSelectionMessageInfo() async {
    final message = _selectedPrimaryMessage;
    if (message == null) return;
    await _showMessageInfo(message);
    _clearMessageSelection();
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final selectedCount = _selectedMessages.length;
    final primary = _selectedPrimaryMessage;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearMessageSelection,
      ),
      title: Text('$selectedCount selected'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(104),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SelectionToolbarAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onPressed: _copySelectedMessages,
                ),
                _SelectionToolbarAction(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onPressed: primary == null || primary.isSystem
                      ? null
                      : _replyToSelectedMessage,
                ),
                _SelectionToolbarAction(
                  icon: Icons.forward_rounded,
                  label: 'Forward',
                  onPressed: selectedCount == 0
                      ? null
                      : _forwardSelectedMessages,
                ),
                _SelectionToolbarAction(
                  icon: Icons.bookmark_add_outlined,
                  label: 'Bookmark',
                  onPressed: selectedCount == 0
                      ? null
                      : _bookmarkSelectedMessages,
                ),
                _SelectionToolbarAction(
                  icon: Icons.task_alt_rounded,
                  label: 'Create Task',
                  onPressed: primary == null
                      ? null
                      : _createTaskFromSelectedMessage,
                ),
                _SelectionToolbarAction(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Summary',
                  onPressed: selectedCount == 0
                      ? null
                      : _showAiSummaryForSelection,
                ),
                _SelectionToolbarAction(
                  icon: Icons.format_quote_rounded,
                  label: 'Quote',
                  onPressed: primary == null ? null : _quoteSelectedMessage,
                ),
                _SelectionToolbarAction(
                  icon: Icons.translate_rounded,
                  label: 'Translate',
                  onPressed: selectedCount == 0 ? null : _translateSelection,
                ),
                _SelectionToolbarAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  destructive: true,
                  onPressed: _canDeleteSelectedMessages
                      ? _deleteSelectedMessages
                      : null,
                ),
                _SelectionToolbarAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onPressed:
                      primary != null &&
                          primary.isMe &&
                          primary.id > 0 &&
                          primary.attachment == null &&
                          selectedCount == 1
                      ? () async {
                          await _editMessage(primary);
                          _clearMessageSelection();
                        }
                      : null,
                ),
                _SelectionToolbarAction(
                  icon: Icons.push_pin_outlined,
                  label: 'Pin',
                  onPressed: selectedCount == 0 ? null : _pinSelectedMessages,
                ),
                _SelectionToolbarAction(
                  icon: Icons.info_outline_rounded,
                  label: 'Message Info',
                  onPressed: primary == null || primary.id <= 0
                      ? null
                      : _showSelectionMessageInfo,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFloatingMessageMenu(
    ChatMessage message,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      color: Theme.of(context).colorScheme.surface,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (!_isSystemNotification)
          const PopupMenuItem(
            value: 'reply',
            child: _MessageMenuItem(icon: Icons.reply_rounded, label: 'Reply'),
          ),
        if (message.isMe &&
            message.id > 0 &&
            decodeLiveChecklist(message.text) != null)
          const PopupMenuItem(
            value: 'edit_checklist',
            child: _MessageMenuItem(
              icon: Icons.checklist_rtl_rounded,
              label: 'Edit',
            ),
          )
        else if (message.isMe && message.id > 0 && message.attachment == null)
          const PopupMenuItem(
            value: 'edit',
            child: _MessageMenuItem(icon: Icons.edit_outlined, label: 'Edit'),
          ),
        if (message.id > 0)
          const PopupMenuItem(
            value: 'pin',
            child: _MessageMenuItem(
              icon: Icons.push_pin_outlined,
              label: 'Pin',
            ),
          ),
        if (message.previewText.isNotEmpty)
          const PopupMenuItem(
            value: 'copy',
            child: _MessageMenuItem(
              icon: Icons.copy_rounded,
              label: 'Copy Text',
            ),
          ),
        const PopupMenuItem(
          value: 'forward',
          child: _MessageMenuItem(
            icon: Icons.forward_rounded,
            label: 'Forward',
          ),
        ),
        const PopupMenuItem(
          value: 'create',
          child: _MessageMenuItem(
            icon: Icons.add_circle_outline_rounded,
            label: 'Create',
          ),
        ),
        if (message.isMe && message.id > 0)
          const PopupMenuItem(
            value: 'unsend',
            child: _MessageMenuItem(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              destructive: true,
            ),
          ),
        PopupMenuItem(
          value: 'select',
          child: _MessageMenuItem(
            icon: _selectedMessageIds.contains(message.id)
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline_rounded,
            label: 'Select',
          ),
        ),
        if (message.id > 0)
          const PopupMenuItem(
            value: 'info',
            child: _MessageMenuItem(
              icon: Icons.info_outline_rounded,
              label: 'Message Info',
            ),
          ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'select') {
      _toggleMessageSelection(message);
      return;
    }
    await _handleMessageAction(message, action);
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, controller) => Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.only(
              top: 8,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children:
                      [
                            '\u{1F44D}',
                            '\u{2764}\u{FE0F}',
                            '\u{1F44F}',
                            '\u{1F525}',
                            '\u{1F389}',
                            '\u{1F602}',
                            '\u{1F60E}',
                          ]
                          .map(
                            (reaction) => InkWell(
                              onTap: () => Navigator.pop(
                                sheetContext,
                                'react:$reaction',
                              ),
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  reaction,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              if (!_isSystemNotification)
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () => Navigator.pop(sheetContext, 'reply'),
                ),
              if (message.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy'),
                  onTap: () async {
                    await _copyMessageToClipboard(message);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              if (message.previewText.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.format_quote_rounded),
                  title: const Text('Quote selected lines'),
                  onTap: () => Navigator.pop(sheetContext, 'quote'),
                ),
              ListTile(
                leading: const Icon(Icons.forward_rounded),
                title: const Text('Forward'),
                onTap: () => Navigator.pop(sheetContext, 'forward'),
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Pin message'),
                onTap: () => Navigator.pop(sheetContext, 'pin'),
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Create'),
                subtitle: const Text(
                  'Task, reminder, thread, incident and more',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, 'create'),
              ),
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Send options'),
                subtitle: const Text('Send now or forward'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, 'send_options'),
              ),
              const Divider(),
              if (message.id > 0)
                ListTile(
                  leading: Icon(
                    message.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                  title: Text(message.isStarred ? 'Unstar' : 'Star message'),
                  onTap: () => Navigator.pop(sheetContext, 'star'),
                ),
              if (message.id > 0)
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Info'),
                  onTap: () => Navigator.pop(sheetContext, 'info'),
                ),
              if (message.id > 0)
                ListTile(
                  leading: const Icon(Icons.forum_outlined),
                  title: const Text('Reply in thread'),
                  onTap: () => Navigator.pop(sheetContext, 'thread'),
                ),
              if (message.text.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.bookmark_add_outlined),
                  title: const Text('Save message'),
                  onTap: () => Navigator.pop(sheetContext, 'save'),
                ),
              if (message.isMe &&
                  message.id > 0 &&
                  decodeLiveChecklist(message.text) != null)
                ListTile(
                  leading: const Icon(Icons.checklist_rtl_rounded),
                  title: const Text('Edit checklist'),
                  onTap: () => Navigator.pop(sheetContext, 'edit_checklist'),
                ),
              if (message.isMe &&
                  message.id > 0 &&
                  message.attachment == null &&
                  decodeLiveChecklist(message.text) == null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit message'),
                  onTap: () => Navigator.pop(sheetContext, 'edit'),
                ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share to another app'),
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
              if (message.isMe && message.id > 0)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Unsend message'),
                  textColor: const Color(0xFFB3261E),
                  iconColor: const Color(0xFFB3261E),
                  onTap: () => Navigator.pop(sheetContext, 'unsend'),
                ),
            ],
          ),
        ),
      ),
    );
    await _handleMessageAction(message, action);
  }

  Future<void> _handleMessageAction(ChatMessage message, String? action) async {
    if (!mounted || action == null) return;
    if (action.startsWith('react:') == true) {
      final reaction = action.substring(6);
      await chatApi.reactToMessage(message.id, reaction);
      if (mounted) {
        setState(() {
          final index = _messages.indexOf(message);
          if (index >= 0) {
            _messages[index] = message.copyWith(reaction: reaction);
          }
        });
      }
    } else if (action == 'copy') {
      await _copyMessageToClipboard(message);
    } else if (action == 'forward') {
      await _forwardMessage(message);
    } else if (action == 'share') {
      await _shareMessage(message);
    } else if (action == 'create') {
      await _showCreateOptions(message);
    } else if (action == 'send_options') {
      await _showSendOptions(message);
    } else if (action == 'star') {
      await chatApi.starMessage(message.id, !message.isStarred);
      if (mounted) {
        setState(() {
          final index = _messages.indexOf(message);
          if (index >= 0) {
            _messages[index] = message.copyWith(isStarred: !message.isStarred);
          }
        });
      }
    } else if (action == 'pin') {
      await chatApi.pinMessage(message.id, true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message pinned.')));
      }
    } else if (action == 'info') {
      await Future<void>.delayed(Duration.zero);
      await _showMessageInfo(message);
    } else if (action == 'reply') {
      setState(() {
        _replyingTo = message;
        _replyQuote = '';
      });
    } else if (action == 'quote') {
      await _quoteMessage(message);
    } else if (action == 'thread') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _ThreadViewScreen(
            chat: widget.chat,
            root: message,
            messages: _messages,
          ),
        ),
      );
      await _loadHistory(silent: true);
    } else if (action == 'save') {
      try {
        await chatApi.saveMessage(message.previewText);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message saved.')));
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    } else if (action == 'edit_checklist') {
      await _editChecklistMessage(message);
    } else if (action == 'edit') {
      await _editMessage(message);
    } else if (action == 'unsend') {
      try {
        await chatApi.unsendMessage(message.id);
        if (mounted) {
          setState(() {
            _messages.removeWhere((item) => item.id == message.id);
            _pendingOutgoing.removeWhere(
              (pending) => pending.message.id == message.id,
            );
          });
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }
  }

  Future<void> _showCreateOptions(ChatMessage message) async {
    final options = [
      ('Create task', Icons.task_alt_rounded),
      ('Update task', Icons.assignment_turned_in_outlined),
      ('Create checklist', Icons.checklist_rounded),
      ('Create reminder', Icons.notifications_active_outlined),
      ('Create meeting request', Icons.groups_2_outlined),
      ('Create thread', Icons.forum_outlined),
      ('Create follow up', Icons.update_rounded),
      ('Create calendar invite', Icons.calendar_month_outlined),
      ('Save to saved messages', Icons.bookmark_add_outlined),
      ('Create incident', Icons.warning_amber_rounded),
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const ListTile(
                leading: BackButton(),
                title: Text(
                  'Create',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  leading: Icon(option.$2, color: AppColors.primary),
                  title: Text(option.$1),
                  onTap: () => Navigator.pop(sheetContext, option.$1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'Create task') {
      await _createTaskFromMessage(message);
    } else if (selected == 'Update task') {
      await _updateTaskFromMessage(message);
    } else if (selected == 'Create checklist') {
      await _createChecklistFromMessage(message);
    } else if (selected == 'Create reminder' ||
        selected == 'Create follow up') {
      await _createReminderFromMessage(
        message,
        kind: selected == 'Create follow up' ? 'followup' : 'reminder',
      );
    } else if (selected == 'Save to saved messages') {
      try {
        await chatApi.saveMessage(message.previewText);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to saved messages.')),
          );
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save this message.')),
          );
        }
      }
    } else if (selected == 'Create thread') {
      setState(() {
        _replyingTo = message;
        _threadRootId = message.threadRootId > 0
            ? message.threadRootId
            : message.id;
      });
    } else {
      showComingSoon(context, '$selected from this message');
    }
  }

  String _taskTitleFromMessage(ChatMessage message) {
    final raw = message.previewText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return 'Task from ${widget.chat.name}';
    return raw.length <= 90 ? raw : '${raw.substring(0, 87)}...';
  }

  int? _taskAssigneeFromConversation() {
    if (!widget.chat.isGroup) return int.tryParse(widget.chat.empId);
    return int.tryParse(chatApi.currentJid.split('@').first);
  }

  String _taskDescriptionFromMessage(ChatMessage message) {
    final lines = <String>[
      'Conversation: ${widget.chat.name}',
      if (message.id > 0) 'Message ID: ${message.id}',
      'Message:',
      message.previewText.trim().isEmpty
          ? '(attachment or empty message)'
          : message.previewText.trim(),
    ];
    return lines.join('\n');
  }

  String _reminderTitleFromMessage(ChatMessage message, String kind) {
    final raw = message.previewText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isNotEmpty) {
      return raw.length <= 90 ? raw : '${raw.substring(0, 87)}...';
    }
    return kind == 'followup'
        ? 'Follow-up from ${widget.chat.name}'
        : 'Reminder from ${widget.chat.name}';
  }

  String _reminderNotesFromMessage(ChatMessage message) {
    final lines = <String>[
      'Conversation: ${widget.chat.name}',
      if (message.id > 0) 'Message ID: ${message.id}',
      'Message:',
      message.previewText.trim().isEmpty
          ? '(attachment or empty message)'
          : message.previewText.trim(),
    ];
    return lines.join('\n');
  }

  Future<void> _createReminderFromMessage(
    ChatMessage message, {
    required String kind,
  }) async {
    final titleController = TextEditingController(
      text: _reminderTitleFromMessage(message, kind),
    );
    final notesController = TextEditingController(
      text: _reminderNotesFromMessage(message),
    );
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          kind == 'followup' ? 'Create follow up' : 'Create reminder',
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 5,
                maxLines: 9,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Continue'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    titleController.dispose();
    notesController.dispose();
    if (created != true || title.isEmpty) return;
    if (!mounted) return;
    final currentUser = await chatApi.getCurrentUser();
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReminderCreateScreen(
          currentUser: currentUser,
          initialKind: kind,
          initialTitle: title,
          initialNotes: notes,
          sourceConversationJid: widget.chat.jid,
          sourceConversationName: widget.chat.name,
          sourceMessageId: message.id,
          sourceMessageText: message.previewText,
        ),
      ),
    );
  }

  Future<void> _createTaskFromMessage(ChatMessage message) async {
    final titleController = TextEditingController(
      text: _taskTitleFromMessage(message),
    );
    final descriptionController = TextEditingController(
      text: _taskDescriptionFromMessage(message),
    );
    final directory = await chatApi.getMyHubDirectory();
    final verticals = await chatApi.getMyHubVerticals();
    final defaultAssignee = _taskAssigneeFromConversation();
    final assignees = <int>{if (defaultAssignee != null) defaultAssignee};
    final followers = <int>{
      int.tryParse(chatApi.currentJid.split('@').first) ?? 0,
    }..remove(0);
    var priority = 'medium';
    var vertical = verticals.isNotEmpty
        ? '${verticals.first['name'] ?? ''}'
        : '';
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create task'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => priority = value ?? 'medium'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: vertical.isEmpty ? null : vertical,
                    decoration: const InputDecoration(labelText: 'Vertical'),
                    items: verticals
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: '${item['name'] ?? ''}',
                            child: Text('${item['name'] ?? ''}'),
                          ),
                        )
                        .where(
                          (item) =>
                              item.value != null && item.value!.isNotEmpty,
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => vertical = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  _TaskPeoplePicker(
                    title: 'Assignees',
                    directory: directory,
                    selected: assignees,
                    onChanged: (values) => setDialogState(() {
                      assignees
                        ..clear()
                        ..addAll(values);
                    }),
                  ),
                  const SizedBox(height: 8),
                  _TaskPeoplePicker(
                    title: 'Followers',
                    directory: directory,
                    selected: followers,
                    onChanged: (values) => setDialogState(() {
                      followers
                        ..clear()
                        ..addAll(values);
                    }),
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
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();
    if (create != true || title.isEmpty) return;
    final groupId = widget.chat.isGroup
        ? int.tryParse(widget.chat.empId) ?? 0
        : 0;
    try {
      await chatApi.createMyHubTask(
        title: title.length <= 120 ? title : title.substring(0, 120),
        description: description,
        assignees: assignees.toList(),
        followers: followers.toList(),
        priority: priority,
        vertical: vertical,
        groupId: groupId,
      );
      await chatApi.invalidateMyHubTasksCache();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task created.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create task: $error')));
    }
  }

  bool _isOpenMyHubTask(Map<String, dynamic> task) {
    final statusText =
        '${task['status_text'] ?? task['status_label'] ?? task['status'] ?? ''}'
            .trim()
            .toLowerCase();
    final numericStatus = int.tryParse('${task['status'] ?? ''}');
    if (numericStatus != null) {
      return numericStatus != 1 &&
          numericStatus != 3 &&
          numericStatus != 4 &&
          numericStatus != 5;
    }
    return !const {
      'closed',
      'done',
      'completed',
      'complete',
      'cancelled',
      'canceled',
    }.contains(statusText);
  }

  String _taskSearchText(Map<String, dynamic> task) => [
    task['id'],
    task['task_id'],
    task['title'],
    task['deadline'],
    task['due_date'],
  ].map((value) => '${value ?? ''}'.toLowerCase()).join(' ');

  List<Map<String, dynamic>> _extractOpenMyHubTasks(Map<String, dynamic> data) {
    final raw = data['tasks'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(_isOpenMyHubTask)
        .toList();
  }

  Future<Map<String, dynamic>?> _pickOpenMyHubTask(
    List<Map<String, dynamic>> tasks,
  ) async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No open tasks available.')));
      return null;
    }
    final searchController = TextEditingController();
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? tasks
              : tasks
                    .where((task) => _taskSearchText(task).contains(query))
                    .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                children: [
                  ListTile(
                    leading: const BackButton(),
                    title: const Text(
                      'Update task',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text('Select an open task'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search by ID, title or deadline',
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No matching open tasks found'),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final task = filtered[index];
                              final id =
                                  '${task['id'] ?? task['task_id'] ?? ''}'
                                      .trim();
                              final deadline =
                                  '${task['deadline'] ?? task['due_date'] ?? ''}'
                                      .trim();
                              return ListTile(
                                leading: const Icon(Icons.task_alt_rounded),
                                title: Text('${task['title'] ?? 'Task'}'),
                                subtitle: Text(
                                  [
                                    if (id.isNotEmpty) '#$id',
                                    if (deadline.isNotEmpty) 'Due $deadline',
                                  ].join(' | '),
                                ),
                                onTap: () => Navigator.pop(sheetContext, task),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
    return selected;
  }

  Future<String?> _askTaskUpdateComment(ChatMessage message) async {
    final controller = TextEditingController(
      text: 'Update from ${widget.chat.name}:\n${message.previewText}',
    );
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Task update'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Comments'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (submit != true || text.isEmpty) return null;
    return text;
  }

  Future<void> _updateTaskFromMessage(ChatMessage message) async {
    try {
      final data = await chatApi.getMyHubTasks(forceRefresh: true);
      if (!mounted) return;
      final task = await _pickOpenMyHubTask(_extractOpenMyHubTasks(data));
      if (!mounted || task == null) return;
      final taskId = int.tryParse('${task['id'] ?? task['task_id'] ?? 0}') ?? 0;
      if (taskId <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected task has no valid ID.')),
        );
        return;
      }
      final comments = await _askTaskUpdateComment(message);
      if (!mounted || comments == null) return;
      await chatApi.updateMyHubTask(taskId: taskId, comments: comments);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task updated.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update task: $error')));
    }
  }

  Future<void> _createChecklistFromMessage(ChatMessage message) async {
    final titleController = TextEditingController(text: 'Checklist');
    final itemsController = TextEditingController(text: message.previewText);
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create live checklist'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Items',
                  helperText: 'Enter one checklist item per line.',
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
    );
    if (create != true) {
      titleController.dispose();
      itemsController.dispose();
      return;
    }
    final items = itemsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((item) => <String, dynamic>{'text': item, 'done': false})
        .toList();
    final title = titleController.text.trim().isEmpty
        ? 'Checklist'
        : titleController.text.trim();
    titleController.dispose();
    itemsController.dispose();
    if (items.isEmpty) return;
    final body =
        'SKYLINK_CHECKLIST:${jsonEncode(<String, dynamic>{'title': title, 'items': items, 'created_at': DateTime.now().toIso8601String()})}';
    final sendLocation = await _messageLocationMetadata();
    await chatApi.sendMessage(
      to: widget.chat.jid,
      message: body,
      latitude: sendLocation.latitude,
      longitude: sendLocation.longitude,
      locationAddress: sendLocation.address,
      clientMessageId: 'checklist-${DateTime.now().microsecondsSinceEpoch}',
    );
    await _loadHistory(silent: true);
  }

  Future<void> _editChecklistMessage(ChatMessage message) async {
    final checklist = decodeLiveChecklist(message.text);
    if (checklist == null || message.id <= 0) return;
    final rawItems = checklist['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final titleController = TextEditingController(
      text: '${checklist['title'] ?? 'Checklist'}',
    );
    final itemControllers = items.isEmpty
        ? <TextEditingController>[TextEditingController()]
        : items
              .map(
                (item) => TextEditingController(
                  text: '${item['text'] ?? ''}'.trim(),
                ),
              )
              .toList();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit checklist'),
          content: SizedBox(
            width: 500,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: itemControllers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: itemControllers[index],
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Item ${index + 1}',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove item',
                            onPressed: itemControllers.length == 1
                                ? null
                                : () => setDialogState(() {
                                    itemControllers.removeAt(index).dispose();
                                  }),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(
                        () => itemControllers.add(TextEditingController()),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add item'),
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
    final title = titleController.text.trim().isEmpty
        ? 'Checklist'
        : titleController.text.trim();
    final nextItems = itemControllers
        .map((controller) => controller.text.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    titleController.dispose();
    for (final controller in itemControllers) {
      controller.dispose();
    }
    if (save != true || nextItems.isEmpty) return;
    final previousByText = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final text = '${item['text'] ?? ''}'.trim().toLowerCase();
      if (text.isNotEmpty) previousByText[text] = item;
    }
    final encodedItems = <Map<String, dynamic>>[];
    for (var i = 0; i < nextItems.length; i++) {
      final previous = previousByText[nextItems[i].toLowerCase()] ??
          (i < items.length ? items[i] : <String, dynamic>{});
      encodedItems.add(<String, dynamic>{
        'text': nextItems[i],
        'done': previous['done'] == true,
        if (previous['checked_by'] is List) 'checked_by': previous['checked_by'],
        if (previous['updated_by'] != null) 'updated_by': previous['updated_by'],
        if (previous['updated_at'] != null) 'updated_at': previous['updated_at'],
      });
    }
    final editedBody =
        'SKYLINK_CHECKLIST:${jsonEncode(<String, dynamic>{'title': title, 'items': encodedItems, 'created_at': checklist['created_at'] ?? DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()})}';
    try {
      await chatApi.editMessage(message.id, editedBody);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexOf(message);
        if (index >= 0) {
          _messages[index] = message.copyWith(text: editedBody, isEdited: true);
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not edit checklist: $error')),
      );
    }
  }
  Future<void> _editPollMessage(ChatMessage message) async {
    final poll = decodeLivePoll(message.text);
    if (poll == null || message.id <= 0) return;
    final rawOptions = poll['options'];
    final options = rawOptions is List
        ? rawOptions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final questionController = TextEditingController(
      text: '${poll['question'] ?? 'Poll'}',
    );
    final optionControllers = options.length < 2
        ? <TextEditingController>[TextEditingController(), TextEditingController()]
        : options
              .map(
                (item) => TextEditingController(
                  text: '${item['text'] ?? ''}'.trim(),
                ),
              )
              .toList();
    var allowMultiple =
        poll['allow_multiple'] == true ||
        '${poll['allow_multiple']}'.toLowerCase() == 'true' ||
        '${poll['allow_multiple']}' == '1';
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit poll'),
          content: SizedBox(
            width: 500,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: questionController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Question'),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: optionControllers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: optionControllers[index],
                              minLines: 1,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Option ${index + 1}',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove option',
                            onPressed: optionControllers.length <= 2
                                ? null
                                : () => setDialogState(() {
                                    optionControllers.removeAt(index).dispose();
                                  }),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => setDialogState(
                          () => optionControllers.add(TextEditingController()),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add option'),
                      ),
                      const Spacer(),
                      Flexible(
                        child: CheckboxListTile(
                          value: allowMultiple,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Multiple'),
                          onChanged: (value) => setDialogState(
                            () => allowMultiple = value ?? false,
                          ),
                        ),
                      ),
                    ],
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
    final question = questionController.text.trim().isEmpty
        ? 'Poll'
        : questionController.text.trim();
    final nextOptions = optionControllers
        .map((controller) => controller.text.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    questionController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
    if (save != true || nextOptions.length < 2) return;

    final votesByText = <String, List<int>>{};
    for (final option in options) {
      final text = '${option['text'] ?? ''}'.trim().toLowerCase();
      final votes = option['votes'];
      if (text.isNotEmpty && votes is List) {
        votesByText[text] = votes
            .map((value) => int.tryParse('$value') ?? 0)
            .where((value) => value > 0)
            .toList();
      }
    }
    final encodedOptions = nextOptions
        .map(
          (text) => <String, dynamic>{
            'text': text,
            'votes': votesByText[text.toLowerCase()] ?? <int>[],
          },
        )
        .toList();
    final editedBody =
        'SKYLINK_POLL:${jsonEncode(<String, dynamic>{'question': question, 'allow_multiple': allowMultiple, 'options': encodedOptions, 'created_at': poll['created_at'] ?? DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()})}';
    try {
      await chatApi.editMessage(message.id, editedBody);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexOf(message);
        if (index >= 0) {
          _messages[index] = message.copyWith(text: editedBody, isEdited: true);
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not edit poll: $error')));
    }
  }
  Future<void> _votePoll(ChatMessage message, int optionIndex) async {
    try {
      await chatApi.votePollOption(message.id, optionIndex);
      await _loadHistory(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _toggleChecklist(ChatMessage message, int itemIndex) async {
    try {
      await chatApi.toggleChecklistItem(message.id, itemIndex);
      await _loadHistory(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showSendOptions(ChatMessage message) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.send_rounded),
              title: const Text('Send now'),
              onTap: () => Navigator.pop(sheetContext, 'send'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_send_rounded),
              title: const Text('Send later'),
              subtitle: const Text('Choose a future date and time'),
              onTap: () => Navigator.pop(sheetContext, 'send_later'),
            ),
            ListTile(
              leading: const Icon(Icons.forward_rounded),
              title: const Text('Forward'),
              onTap: () => Navigator.pop(sheetContext, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share to another app'),
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
          ],
        ),
      ),
    );
    if (selected == 'send_later') {
      await _scheduleMessageBody(message.previewText);
    }
    if (selected == 'forward') await _forwardMessage(message);
    if (selected == 'share') await _shareMessage(message);
  }

  Future<void> _quoteMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.previewText);
    final quote = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quote selected lines'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            helperText: 'Keep only the lines you want to quote.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Quote'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || quote == null || quote.isEmpty) return;
    setState(() {
      _replyingTo = message;
      _replyQuote = quote;
    });
  }

  Future<void> _editMessage(ChatMessage message) async {
    if (decodeLiveChecklist(message.text) != null) {
      await _editChecklistMessage(message);
      return;
    }
    if (decodeLivePoll(message.text) != null) {
      await _editPollMessage(message);
      return;
    }
    final controller = TextEditingController(text: message.text);
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: 4000,
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
    if (edited == null || edited.isEmpty || edited == message.text) return;
    try {
      await chatApi.editMessage(message.id, edited);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexOf(message);
        if (index >= 0) {
          _messages[index] = ChatMessage(
            id: message.id,
            text: edited,
            time: message.time,
            isMe: message.isMe,
            sender: message.sender,
            isRead: message.isRead,
            replyToId: message.replyToId,
            threadRootId: message.threadRootId,
            mentions: message.mentions,
            isEdited: true,
            sourceDevice: message.sourceDevice,
            sourceName: message.sourceName,
            createdAt: message.createdAt,
            attachment: message.attachment,
            reaction: message.reaction,
            isFailed: message.isFailed,
            isSending: message.isSending,
            originalSenderJid: message.originalSenderJid,
            originalSenderName: message.originalSenderName,
            originalSourceName: message.originalSourceName,
            visibilityMode: message.visibilityMode,
            isSystem: message.isSystem,
          );
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message updated.')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _manageGroup() async {
    if (!widget.chat.isGroup) return;
    if (widget.onProfileTap != null) {
      widget.onProfileTap!.call();
      return;
    }
    await _loadGroupMembers();
    await _showConversationProfile();
  }

  Future<void> _toggleMute() async {
    try {
      await chatApi.setMuted(widget.chat.jid, !_isMuted);
      if (!mounted) return;
      setState(() => _isMuted = !_isMuted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isMuted ? 'Notifications muted.' : 'Notifications enabled.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _changeGroupPhoto() async {
    if (!widget.chat.isGroup) return;
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
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
            widget.chat.isChannel
                ? 'Channel photo updated.'
                : 'Group photo updated.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _leaveGroup() async {
    if (!widget.chat.isGroup) return;
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave ${widget.chat.isChannel ? 'channel' : 'group'}?'),
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
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _memberAction(GroupMember member, String action) async {
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    if (!const {'owner', 'admin'}.contains(_groupRole)) return;
    try {
      await chatApi.groupMemberAction(
        groupId: groupId,
        empId: member.empId,
        action: action,
      );
      await _loadGroupMembers();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Member updated.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  bool get _isTextSelectionActive {
    final selectionUntil = _textSelectionActiveUntil;
    return browserHasActiveTextSelection() ||
        (selectionUntil != null && DateTime.now().isBefore(selectionUntil));
  }

  void _scrollToBottom({bool force = false, bool instant = false}) {
    if (!force && _isTextSelectionActive) return;
    if (force) _textSelectionActiveUntil = null;
    _scrollToBottomWhenReady(force: force, instant: instant, attemptsLeft: 10);
  }

  void _scrollToBottomWhenReady({
    required bool force,
    required bool instant,
    required int attemptsLeft,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!force && _isTextSelectionActive) return;
      if (_itemScrollController.isAttached && _messages.isNotEmpty) {
        _itemScrollController.scrollTo(
          index: _messages.length - 1,
          duration: instant ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.9,
        );
        if (_showJumpToLatest || _newMessageCount != 0) {
          setState(() {
            _showJumpToLatest = false;
            _newMessageCount = 0;
          });
        }
        return;
      }
      if (attemptsLeft <= 0) return;
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        _scrollToBottomWhenReady(
          force: force,
          instant: instant,
          attemptsLeft: attemptsLeft - 1,
        );
      });
    });
  }

  void _markTextSelectionActive() {
    _textSelectionActiveUntil = DateTime.now().add(const Duration(seconds: 12));
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final visible = positions
        .where((position) => position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1)
        .toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return;
    final anchor = visible.first;
    _selectionAnchorIndex = anchor.index;
    _selectionAnchorAlignment = anchor.itemLeadingEdge.clamp(0.0, 1.0).toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSelectionAnchor());
  }

  void _restoreSelectionAnchor({int attemptsLeft = 4}) {
    if (!mounted || !_isTextSelectionActive) return;
    final index = _selectionAnchorIndex;
    if (index == null || index < 0 || index >= _messages.length) return;
    _itemScrollController.jumpTo(
      index: index,
      alignment: _selectionAnchorAlignment,
    );
    if (attemptsLeft > 0) {
      Future<void>.delayed(const Duration(milliseconds: 32), () {
        _restoreSelectionAnchor(attemptsLeft: attemptsLeft - 1);
      });
    }
  }

  void _jumpToMessage(int messageId) {
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index < 0 || !_itemScrollController.isAttached) return;
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0.22,
    );
  }

  Future<void> _searchMessages() async {
    final controller = TextEditingController();
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = controller.text.trim().toLowerCase();
          final results = _messages
              .where(
                (message) =>
                    query.isNotEmpty &&
                    message.previewText.toLowerCase().contains(query),
              )
              .toList();
          return AlertDialog(
            title: const Text('Search messages'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search this conversation',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: query.isNotEmpty && results.isEmpty
                        ? const Center(child: Text('No matching messages.'))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, index) {
                              final message = results[index];
                              return ListTile(
                                title: Text(
                                  message.previewText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(message.time),
                                onTap: () =>
                                    Navigator.pop(dialogContext, message.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
    if (selected != null) _jumpToMessage(selected);
  }

  String _infoText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = '${data[key] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  String _infoDisplay(Map<String, dynamic> data, List<String> keys) {
    final value = _infoText(data, keys);
    return value.isEmpty ? '-' : value;
  }

  String _readDisplay(Map<String, dynamic> data, List<String> keys) {
    final value = _infoText(data, keys);
    return value.isEmpty ? 'Not read yet' : value;
  }

  String _deviceDisplay(
    Map<String, dynamic> data,
    String deviceKey,
    String nameKey,
  ) {
    final device = _infoText(data, [deviceKey]);
    final name = _infoText(data, [nameKey]);
    if (device.isEmpty && name.isEmpty) return '-';
    if (device.isEmpty) return name;
    if (name.isEmpty) return device;
    return '$device - $name';
  }

  Widget _messageInfoRow(IconData icon, String label, String value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
  bool _looksLikeCoordinates(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    return RegExp(r'^-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?$').hasMatch(text);
  }

  double? _infoDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) continue;
      final value = double.tryParse('$raw'.trim());
      if (value != null) return value;
    }
    return null;
  }

  Future<String> _resolvedInfoAddress(
    Map<String, dynamic> data, {
    required List<String> addressKeys,
    required List<String> latitudeKeys,
    required List<String> longitudeKeys,
    String fallbackAddress = '',
    double? fallbackLatitude,
    double? fallbackLongitude,
  }) async {
    final rawAddress = _infoText(data, addressKeys).trim();
    final latitude = _infoDouble(data, latitudeKeys) ?? fallbackLatitude;
    final longitude = _infoDouble(data, longitudeKeys) ?? fallbackLongitude;
    if (rawAddress.isNotEmpty && !_looksLikeCoordinates(rawAddress)) {
      return cleanMojibakeText(rawAddress);
    }
    final fallback = fallbackAddress.trim();
    if (fallback.isNotEmpty && !_looksLikeCoordinates(fallback)) {
      return cleanMojibakeText(fallback);
    }
    if (latitude != null && longitude != null) {
      try {
        final address = await chatApi.reverseGeocode(latitude, longitude);
        if (address.trim().isNotEmpty &&
            address.trim().toLowerCase() != 'location unavailable') {
          return cleanMojibakeText(address.trim());
        }
      } catch (_) {
        // Keep the message info usable if reverse geocoding is temporarily down.
      }
    }
    if (rawAddress.isNotEmpty) return rawAddress;
    return fallback;
  }

  Future<List<Widget>> _messageReaderInfoRows(
    Map<String, dynamic> data,
    bool canViewLocations,
  ) async {
    final rawReaders = data['readers'];
    if (rawReaders is! List || rawReaders.isEmpty) return const [];
    final rows = <Widget>[];
    for (final rawReader in rawReaders) {
      if (rawReader is! Map) continue;
      final reader = Map<String, dynamic>.from(rawReader);
      final name = _infoText(reader, ['name', 'emp_id']);
      final readAt = _infoText(reader, ['read_at']);
      final device = _deviceDisplay(
        reader,
        'read_source_device',
        'read_source_name',
      );
      final address = await _resolvedInfoAddress(
        reader,
        addressKeys: ['read_location_address'],
        latitudeKeys: ['read_latitude'],
        longitudeKeys: ['read_longitude'],
      );
      final readLines = <String>[
        if (name.isNotEmpty) name,
        if (readAt.isNotEmpty) readAt,
        if (device != '-') device,
      ];
      if (readLines.isNotEmpty) {
        rows.add(
          _messageInfoRow(
            Icons.person_outline_rounded,
            'Read by',
            readLines.join('\n'),
          ),
        );
      }
      if (canViewLocations && address.isNotEmpty) {
        rows.add(
          _messageInfoRow(
            Icons.my_location_outlined,
            'Read address',
            name.isEmpty ? address : '$name\n$address',
          ),
        );
      }
    }
    return rows;
  }

  Future<void> _showLocalMessageInfo(ChatMessage message, String reason) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Message info'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              _messageInfoRow(Icons.schedule_rounded, 'Sent', message.time),
              _messageInfoRow(
                Icons.done_all_rounded,
                'Read',
                message.readAt.trim().isNotEmpty
                    ? message.readAt
                    : (message.isRead ? 'Read' : 'Not read yet'),
              ),
              if (message.sourceDevice != 'unknown' &&
                  message.sourceDevice.isNotEmpty)
                _messageInfoRow(
                  Icons.devices_outlined,
                  'Sent from',
                  message.sourceName.isEmpty
                      ? cleanMojibakeText(message.sourceDevice)
                      : '${cleanMojibakeText(message.sourceDevice)} - ${cleanMojibakeText(message.sourceName)}',
                ),
              if (_canViewMessageLocations &&
                  message.locationAddress.trim().isNotEmpty)
                _messageInfoRow(
                  Icons.location_on_outlined,
                  'Send address',
                  cleanMojibakeText(message.locationAddress),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessageInfo(ChatMessage message) async {
    if (message.id <= 0) return;
    try {
      final data = await chatApi.getMessageInfo(message.id);
      if (!mounted) return;
      final info = data['message'] is Map
          ? Map<String, dynamic>.from(data['message'] as Map)
          : <String, dynamic>{};
      final canViewLocations = _canViewMessageLocations;
      final sentLocation = await _resolvedInfoAddress(
        info,
        addressKeys: ['location_address'],
        latitudeKeys: ['latitude'],
        longitudeKeys: ['longitude'],
        fallbackAddress: message.locationAddress,
      );
      final readLocation = await _resolvedInfoAddress(
        info,
        addressKeys: ['read_location_address'],
        latitudeKeys: ['read_latitude'],
        longitudeKeys: ['read_longitude'],
      );
      final readerRows = await _messageReaderInfoRows(data, canViewLocations);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Message info'),
          content: SizedBox(
            width: 460,
            child: ListView(
              shrinkWrap: true,
              children: [
                _messageInfoRow(
                  Icons.schedule_rounded,
                  'Sent',
                  _infoDisplay(info, ['created_at']),
                ),
                _messageInfoRow(
                  Icons.done_all_rounded,
                  'Read',
                  _readDisplay(info, ['read_at']),
                ),
                _messageInfoRow(
                  Icons.devices_outlined,
                  'Sent from',
                  _deviceDisplay(info, 'source_device', 'source_name'),
                ),
                if (_infoText(info, [
                  'read_source_device',
                  'read_source_name',
                ]).isNotEmpty)
                  _messageInfoRow(
                    Icons.phonelink_ring_outlined,
                    'Read from',
                    _deviceDisplay(
                      info,
                      'read_source_device',
                      'read_source_name',
                    ),
                  ),
                if (_infoText(info, ['edited_at']).isNotEmpty)
                  _messageInfoRow(
                    Icons.edit_outlined,
                    'Edited',
                    _infoDisplay(info, ['edited_at']),
                  ),
                if (canViewLocations && sentLocation.isNotEmpty)
                  _messageInfoRow(
                    Icons.location_on_outlined,
                    'Send address',
                    sentLocation,
                  ),
                if (canViewLocations && readLocation.isNotEmpty)
                  _messageInfoRow(
                    Icons.my_location_outlined,
                    'Read address',
                    readLocation,
                  ),
                ...readerRows,
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      await _showLocalMessageInfo(message, error.message);
    } catch (error) {
      await _showLocalMessageInfo(message, '$error');
    }
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final values = await Future.wait([
      chatApi.getRecentChats(),
      chatApi.searchUsers(),
    ]);
    final byJid = <String, ChatContact>{};
    byJid[_savedMessagesForwardTarget.jid.toLowerCase()] = _savedMessagesForwardTarget;
    for (final chat in [...values[0], ...values[1]]) {
      byJid[chat.jid.toLowerCase()] = chat;
    }
    final chats = byJid.values.toList();
    if (!mounted) return;
    final target = await showModalBottomSheet<ChatContact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForwardTargetSheet(chats: chats),
    );
    if (target == null) return;
    await _forwardMessageToTarget(
      message,
      target,
      clientMessagePrefix: 'forward',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Forwarded to ${target.name}.')));
    }
  }

  Future<void> _shareMessage(ChatMessage message) async {
    final attachment = message.attachment;
    if (attachment != null) {
      await requestAttachmentStoragePermission(context);
      final path = await chatApi.downloadAttachment(attachment);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: attachment.mimeType)],
          text: attachment.caption,
        ),
      );
    } else {
      await SharePlus.instance.share(ShareParams(text: message.text));
    }
  }

  Future<void> _renameGroup() async {
    final controller = TextEditingController(text: widget.chat.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.chat.isChannel ? 'Rename channel' : 'Rename group'),
        content: TextField(controller: controller, autofocus: true),
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
    if (name == null || name.isEmpty) return;
    await chatApi.renameGroup(int.tryParse(widget.chat.empId) ?? 0, name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.chat.isChannel
                ? 'Channel name updated.'
                : 'Group name updated.',
          ),
        ),
      );
    }
  }

  Future<void> _closeChannel() async {
    if (!widget.chat.isChannel ||
        !const {'owner', 'admin'}.contains(_groupRole)) {
      return;
    }
    final channelId = int.tryParse(widget.chat.empId) ?? 0;
    if (channelId <= 0) return;
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true) return;
    try {
      await chatApi.closeChannel(channelId);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedMessageIds.isNotEmpty
          ? _buildSelectionAppBar()
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              scrolledUnderElevation: 1,
              titleSpacing: 0,
              title: InkWell(
                onTap: widget.onProfileTap ?? _showConversationProfile,
                child: Row(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(chat: widget.chat, radius: 20),
                        if (_presence?.isOnline == true &&
                            !widget.chat.isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.online,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _presenceLabel,
                            style: TextStyle(
                              color:
                                  (_presence?.isOnline ?? widget.chat.isOnline)
                                  ? AppColors.primary
                                  : AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Return to last read position',
                  onPressed: _returnReadMessageId > 0
                      ? () => _jumpToMessage(_returnReadMessageId)
                      : null,
                  icon: const Icon(Icons.bookmark_outline_rounded),
                ),
                IconButton(
                  tooltip: 'Search messages',
                  onPressed: _searchMessages,
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: 'Call',
                  onPressed: () => showComingSoon(context, 'Voice call'),
                  icon: const Icon(Icons.call_outlined),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'Manage group') {
                      _manageGroup();
                    } else if (value == 'View profile') {
                      _showUserProfile();
                    } else if (value == 'Close channel') {
                      _closeChannel();
                    } else if (value == 'Pinned messages') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DiscoveryListScreen(
                            title: 'Pinned messages',
                            view: 'pins',
                            jid: widget.chat.jid,
                          ),
                        ),
                      );
                    } else if (value == 'Media browser') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatMediaBrowser(chat: widget.chat),
                        ),
                      );
                    } else if (value == 'Mute notifications' ||
                        value == 'Unmute notifications') {
                      _toggleMute();
                    } else {
                      showComingSoon(context, value);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: widget.chat.isGroup
                          ? 'Manage group'
                          : 'View profile',
                      child: Text(
                        widget.chat.isChannel
                            ? 'Manage channel'
                            : widget.chat.isGroup
                            ? 'Manage group'
                            : 'View profile',
                      ),
                    ),
                    if (widget.chat.isChannel && _groupRole == 'owner')
                      const PopupMenuItem(
                        value: 'Close channel',
                        child: Text('Close and archive channel'),
                      ),
                    const PopupMenuItem(
                      value: 'Pinned messages',
                      child: Text('Pinned messages'),
                    ),
                    const PopupMenuItem(
                      value: 'Media browser',
                      child: Text('Media browser'),
                    ),
                    PopupMenuItem(
                      value: _isMuted
                          ? 'Unmute notifications'
                          : 'Mute notifications',
                      child: Text(
                        _isMuted
                            ? 'Unmute notifications'
                            : 'Mute notifications',
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          Expanded(
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
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ChatBackgroundPainter(
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _loadError != null
                          ? LoadError(
                              message: _loadError!,
                              onRetry: _loadHistory,
                            )
                          : _messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet. Say hello!',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          : ScrollablePositionedList.builder(
                              key: ValueKey('chat-list-' + widget.chat.jid),
                              initialScrollIndex: _messages.isEmpty
                                  ? 0
                                  : _messages.length - 1,
                              initialAlignment: 1.0,
                              itemScrollController: _itemScrollController,
                              itemPositionsListener: _itemPositionsListener,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                18,
                                14,
                                18,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (_, index) {
                                final message = _messages[index];
                                final previous = index > 0
                                    ? _messages[index - 1]
                                    : null;
                                final showDate =
                                    previous == null ||
                                    !_sameMessageDay(
                                      previous.createdAt,
                                      message.createdAt,
                                    );
                                return _MessageBubble(
                                  key: _messageKeys.putIfAbsent(
                                    message.id,
                                    () => GlobalKey(),
                                  ),
                                  message: message,
                                  showSender: widget.chat.isGroup,
                                  showLocationAddress: _canViewMessageLocations,
                                  participantNames: _participantNamesForMessage(message),
                                  showChecklistPollDetails: message.isMe,
                                  replyMessage: _messageById(message.replyToId),
                                  dateLabel: showDate
                                      ? _messageDateLabel(message.createdAt)
                                      : null,
                                  onReplyTap: message.replyToId > 0
                                      ? () => _jumpToMessage(message.replyToId)
                                      : null,
                                  selected: _selectedMessageIds.contains(
                                    message.id,
                                  ),
                                  onTap: () {
                                    if (_selectedMessageIds.isNotEmpty) {
                                      _toggleMessageSelection(message);
                                    }
                                  },
                                  onLongPressStart: (details) =>
                                      _showFloatingMessageMenu(
                                        message,
                                        details.globalPosition,
                                      ),
                                  onSecondaryTapDown: (details) =>
                                      _showFloatingMessageMenu(
                                        message,
                                        details.globalPosition,
                                      ),
                                  onSwipeReply: _isSystemNotification
                                      ? null
                                      : () => setState(() {
                                          _selectedMessageIds.clear();
                                          _replyingTo = message;
                                          _replyQuote = '';
                                        }),
                                  onSwipeBack:
                                      _showEmojiPicker ||
                                          MediaQuery.sizeOf(context).width >=
                                              900
                                      ? null
                                      : () {
                                          if (_selectedMessageIds.isNotEmpty) {
                                            setState(_selectedMessageIds.clear);
                                          }
                                          Navigator.maybePop(context);
                                        },
                                  onTextSelectionChanged:
                                      _markTextSelectionActive,
                                  onMentionTap: _openMentionProfile,
                                  onChecklistToggle: (itemIndex) =>
                                      _toggleChecklist(message, itemIndex),
                                  onPollVote: (optionIndex) =>
                                      _votePoll(message, optionIndex),
                                );
                              },
                            ),
                    ),
                  ),
                  if (_isDragOver)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                child: Text('Drop files to send'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_mentionSuggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              color: Colors.white,
              child: ListView(
                shrinkWrap: true,
                children: _mentionSuggestions
                    .map(
                      (member) => ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          child: Icon(Icons.alternate_email_rounded),
                        ),
                        title: Text(member.name),
                        subtitle: Text(member.designation),
                        onTap: () => _selectMention(member),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_replyingTo != null && !_isSystemNotification)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingTo!.sender ??
                              (_replyingTo!.isMe ? 'You' : widget.chat.name),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _replyQuote.isNotEmpty
                              ? _replyQuote
                              : _replyingTo!.previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _replyingTo = null;
                      _replyQuote = '';
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          if (_isSystemNotification)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.paddingOf(context).bottom + 14,
              ),
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Replies are disabled for this conversation.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            )
          else
            _MessageComposer(
              controller: _messageController,
              onSend: () => _sendMessage(),
              onSendLongPress: widget.chat.isGroup
                  ? _showSendTargetOptions
                  : null,
              onSendLater: _scheduleDraftMessage,
              onVoiceRecord: _toggleVoiceRecording,
              isRecordingVoice: _isRecordingVoice,
              onAttach: _pickAndSendAttachment,
              isUploading: _isUploading,
              uploadProgress: _uploadProgress,
              showEmojiPicker: _showEmojiPicker,
              onEmojiToggle: () =>
                  setState(() => _showEmojiPicker = !_showEmojiPicker),
              onEmojiSelected: (emoji) {
                final value = _messageController.value;
                final selection = value.selection.isValid
                    ? value.selection
                    : TextSelection.collapsed(offset: value.text.length);
                final text = value.text.replaceRange(
                  selection.start,
                  selection.end,
                  emoji,
                );
                _messageController.value = TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(
                    offset: selection.start + emoji.length,
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: !_showJumpToLatest
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 76),
              child: FloatingActionButton.small(
                tooltip: _newMessageCount > 0
                    ? '$_newMessageCount new messages'
                    : 'Jump to latest',
                onPressed: () {
                  setState(() => _newMessageCount = 0);
                  _scrollToBottom(force: true);
                },
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ),
    );
  }

  Future<void> _showUserProfile({String? empId, String? fallbackName}) async {
    try {
      final targetEmpId = empId ?? widget.chat.empId;
      final user = await chatApi.getUserProfile(targetEmpId);
      if (!mounted) return;
      final title = '${user['name'] ?? fallbackName ?? widget.chat.name}';
      final designation = '${user['designation'] ?? 'Employee'}';
      final online =
          user['messenger_connected'] == true ||
          '${user['messenger_connected']}' == '1';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text('#${user['employee_id'] ?? targetEmpId}'),
                  subtitle: const Text('Employee ID'),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.work_outline_rounded),
                  title: Text(designation),
                  subtitle: const Text('Designation'),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    online
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                  ),
                  title: Text(online ? 'Online' : 'Offline'),
                  subtitle: Text(
                    'Launchpad ${user['launchpad_active'] == true ? 'active' : 'inactive'}',
                  ),
                ),
                if ('${user['device_model'] ?? ''}'.isNotEmpty ||
                    '${user['platform'] ?? ''}'.isNotEmpty ||
                    '${user['app_version'] ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices_outlined),
                    title: Text('${user['device_model'] ?? '-'}'),
                    subtitle: Text(
                      '${user['platform'] ?? '-'} - ${user['app_version'] ?? '-'}',
                    ),
                  ),
                if ('${user['last_activity'] ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text('${user['last_activity']}'),
                    subtitle: const Text('Last activity'),
                  ),
                if ('${user['latest_location_address'] ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text('${user['latest_location_address']}'),
                    subtitle: const Text('Last known location'),
                  ),
                if ('${user['mobile'] ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_outlined),
                    title: Text('${user['mobile']}'),
                    subtitle: const Text('Mobile'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showWakeupConfig() async {
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    if (!const {'owner', 'admin'}.contains(_groupRole)) {
      return;
    }
    try {
      final config = await chatApi.getWakeupConfig(
        groupId: groupId,
        jid: widget.chat.jid,
      );
      if (!mounted) return;
      var enabled =
          config['enabled'] == true ||
          '${config['enabled']}'.toLowerCase() == '1' ||
          '${config['enabled']}'.toLowerCase() == 'true';
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
                    subtitle: Text(
                      enabled &&
                              '${config['next_wakeup_label'] ?? ''}'.isNotEmpty
                          ? 'Next wake-up: ${config['next_wakeup_label']}'
                          : 'Weekends are skipped.',
                    ),
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: choices.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: interval == entry.key,
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
      if (mounted) {
        setState(() {});
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showConversationProfile() async {
    if (!widget.chat.isGroup) {
      await _showUserProfile();
      return;
    }
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (_groupMembers.isEmpty) {
      await _loadGroupMembers();
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: UserAvatar(chat: widget.chat, radius: 48)),
            const SizedBox(height: 12),
            Text(
              widget.chat.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.chat.isChannel ? 'Channel profile' : 'Group profile',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: const Icon(Icons.people_outline_rounded),
              title: Text('${_groupMembers.length} members'),
              subtitle: Text(
                '${_groupMembers.where((member) => member.isOnline).length} online',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Wake-up notification'),
              subtitle: Text(
                const {'owner', 'admin'}.contains(_groupRole)
                    ? 'Disabled by default - tap to configure'
                    : 'Only owners/admins can change',
              ),
              onTap: const {'owner', 'admin'}.contains(_groupRole)
                  ? _showWakeupConfig
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Media, files and links'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatMediaBrowser(chat: widget.chat),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('Pinned messages'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DiscoveryListScreen(
                    title: 'Pinned messages',
                    view: 'pins',
                    jid: widget.chat.jid,
                  ),
                ),
              ),
            ),
            if (const {'owner', 'admin'}.contains(_groupRole)) ...[
              ListTile(
                leading: const Icon(Icons.person_add_alt_rounded),
                title: const Text('Manage members'),
                onTap: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ManageGroupSheet(
                      groupId: groupId,
                      initialMembers: _groupMembers,
                      isOwner: const {'owner', 'admin'}.contains(_groupRole),
                      currentRole: _groupRole,
                    ),
                  );
                  await _loadGroupMembers();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Change photo'),
                onTap: _changeGroupPhoto,
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(
                  widget.chat.isChannel
                      ? 'Change channel name'
                      : 'Change group name',
                ),
                onTap: _renameGroup,
              ),
            ],
            const Divider(),
            const Text(
              'Members',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            ..._groupMembers.map(
              (member) => ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member.name.isEmpty ? member.empId : member.name[0],
                  ),
                ),
                title: Text(member.name.isEmpty ? member.empId : member.name),
                subtitle: Text(
                  member.role == 'owner'
                      ? 'Owner'
                      : member.role == 'admin'
                      ? 'Admin'
                      : member.isOnline
                      ? 'online'
                      : member.lastSeen == null
                      ? member.designation
                      : 'last active ${_memberLastSeen(member.lastSeen!)}',
                ),
                trailing:
                    (_groupRole == 'owner' ||
                            (_groupRole == 'admin' && member.role == 'member')) &&
                        member.role != 'owner'
                    ? PopupMenuButton<String>(
                        onSelected: (action) => _memberAction(member, action),
                        itemBuilder: (_) => [
                          if (_groupRole == 'owner')
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
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove member'),
                          ),
                        ],
                      )
                    : member.role == 'owner'
                    ? const Chip(label: Text('Owner'))
                    : member.isOnline
                    ? const Icon(Icons.circle, color: Colors.green, size: 12)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _memberLastSeen(DateTime value) {
    final now = DateTime.now();
    final sameDay =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final time = TimeOfDay.fromDateTime(value).format(context);
    return sameDay ? 'today at $time' : '${value.day}/${value.month} at $time';
  }

  String _friendlyChannelType(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return switch (normalized) {
      'ticket' => 'Ticket Channel',
      'action' => 'Action Channel',
      'incident' => 'Incident Channel',
      'project' => 'Project Channel',
      'approval' => 'Approval Channel',
      'announcement' => 'Announcement Channel',
      'personal_workspace' => 'Personal Workspace',
      'installation' => 'Installation Channel',
      'l2_feasibility' => 'L2 Feasibility Channel',
      'protect' => 'Protect Channel',
      _ => 'Operational Channel',
    };
  }

  bool _sameMessageDay(DateTime? first, DateTime? second) {
    if (first == null && second == null) return true;
    if (first == null || second == null) return false;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _messageDateLabel(DateTime? value) {
    if (value == null) return 'Today';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class ChatBackgroundPainter extends CustomPainter {
  const ChatBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = isDark ? const Color(0xFF0F1722) : const Color(0xFFEDF3FA);
    canvas.drawRect(Offset.zero & size, background);

    final pattern = Paint()
      ..color = (isDark ? Colors.white : AppColors.primary).withValues(
        alpha: isDark ? 0.025 : 0.035,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const spacing = 72.0;
    for (double y = 18; y < size.height; y += spacing) {
      for (double x = 22; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 10, pattern);
        canvas.drawLine(
          Offset(x + 15, y + 16),
          Offset(x + 28, y + 29),
          pattern,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ChatBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF8394A9).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskPeoplePicker extends StatelessWidget {
  const _TaskPeoplePicker({
    required this.title,
    required this.directory,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<Map<String, dynamic>> directory;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedPeople = directory.where((item) {
      final id = int.tryParse('${item['emp_id'] ?? item['id'] ?? ''}') ?? 0;
      return selected.contains(id);
    }).toList();
    return InputDecorator(
      decoration: InputDecoration(labelText: title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...selectedPeople.map((person) {
                final id =
                    int.tryParse('${person['emp_id'] ?? person['id'] ?? ''}') ??
                    0;
                return Chip(
                  label: Text('${person['name'] ?? id}'),
                  onDeleted: () => onChanged({...selected}..remove(id)),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: const Text('Add'),
                onPressed: () async {
                  final picked = await showModalBottomSheet<Set<int>>(
                    context: context,
                    showDragHandle: true,
                    builder: (sheetContext) {
                      final draft = {...selected};
                      var query = '';
                      return StatefulBuilder(
                        builder: (context, setSheetState) {
                          final needle = query.trim().toLowerCase();
                          final visiblePeople = directory.where((person) {
                            final idText = '${person['emp_id'] ?? person['id'] ?? ''}';
                            if (needle.isEmpty) return true;
                            return idText.toLowerCase().contains(needle) ||
                                '${person['name'] ?? ''}'.toLowerCase().contains(needle) ||
                                '${person['designation'] ?? ''}'.toLowerCase().contains(needle);
                          }).toList();
                          return SafeArea(
                          child: Column(
                            children: [
                              ListTile(title: Text(title)),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Search people',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                  onChanged: (value) =>
                                      setSheetState(() => query = value),
                                ),
                              ),
                              Expanded(
                                child: visiblePeople.isEmpty
                                    ? const Center(child: Text('No users found.'))
                                    : ListView.builder(
                                  itemCount: visiblePeople.length,
                                  itemBuilder: (context, index) {
                                    final person = visiblePeople[index];
                                    final id =
                                        int.tryParse(
                                          '${person['emp_id'] ?? person['id'] ?? ''}',
                                        ) ??
                                        0;
                                    if (id <= 0) return const SizedBox.shrink();
                                    return CheckboxListTile(
                                      value: draft.contains(id),
                                      title: Text('${person['name'] ?? id}'),
                                      subtitle: Text(
                                        '${person['designation'] ?? ''}',
                                      ),
                                      onChanged: (value) => setSheetState(() {
                                        if (value ?? false) {
                                          draft.add(id);
                                        } else {
                                          draft.remove(id);
                                        }
                                      }),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(sheetContext, draft),
                                  child: const Text('Done'),
                                ),
                              ),
                            ],
                          ),
                        );
                        },
                      );
                    },
                  );
                  if (picked != null) onChanged(picked);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.showSender,
    required this.showLocationAddress,
    required this.onLongPressStart,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTapDown,
    this.replyMessage,
    this.onReplyTap,
    this.dateLabel,
    this.onMentionTap,
    this.onSwipeReply,
    this.onSwipeBack,
    this.onChecklistToggle,
    this.onPollVote,
    this.onTextSelectionChanged,
    this.participantNames = const {},
    this.showChecklistPollDetails = false,
  });

  final ChatMessage message;
  final bool showSender;
  final bool showLocationAddress;
  final ChatMessage? replyMessage;
  final GestureLongPressStartCallback onLongPressStart;
  final bool selected;
  final VoidCallback onTap;
  final GestureTapDownCallback onSecondaryTapDown;
  final VoidCallback? onReplyTap;
  final String? dateLabel;
  final ValueChanged<String>? onMentionTap;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onSwipeBack;
  final ValueChanged<int>? onChecklistToggle;
  final ValueChanged<int>? onPollVote;
  final VoidCallback? onTextSelectionChanged;
  final Map<int, String> participantNames;
  final bool showChecklistPollDetails;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final contactCard = decodeContactCard(message.text);
    final checklist = decodeLiveChecklist(message.text);
    final poll = decodeLivePoll(message.text);
    final isTaggedOrReplied =
        message.replyToId > 0 ||
        message.originalSenderName.isNotEmpty ||
        message.mentions.isNotEmpty;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = min(
      screenWidth * (screenWidth >= 900 ? 0.62 : 0.82),
      screenWidth >= 900 ? 560.0 : screenWidth * 0.82,
    );
    if (message.isSystem) {
      return Column(
        children: [
          if (dateLabel != null) _DateChip(label: dateLabel!),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (dateLabel != null) _DateChip(label: dateLabel!),
        GestureDetector(
          onTap: onTap,
          onLongPressStart: onLongPressStart,
          onSecondaryTapDown: onSecondaryTapDown,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 450) {
              onSwipeReply?.call();
            } else if (velocity < -450 &&
                attachment == null &&
                contactCard == null &&
                checklist == null &&
                poll == null) {
              onSwipeBack?.call();
            }
          },
          child: Align(
            alignment: message.isMe
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              child: IntrinsicWidth(
                child: Container(
              margin: EdgeInsets.only(bottom: 8 * appChatDensity.value),
              padding: EdgeInsets.fromLTRB(
                13,
                9 * appChatDensity.value,
                9,
                7 * appChatDensity.value,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withValues(alpha: dark ? 0.36 : 0.24)
                    : isTaggedOrReplied
                    ? (dark
                          ? colors.secondaryContainer.withValues(alpha: 0.55)
                          : message.isMe
                          ? const Color(0xFFC7E0FF)
                          : const Color(0xFFFFF0C8))
                    : message.isMe
                    ? dark
                          ? colors.primaryContainer.withValues(alpha: 0.55)
                          : AppColors.outgoing
                    : colors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(message.isMe ? 17 : 4),
                  bottomRight: Radius.circular(message.isMe ? 4 : 17),
                ),
                border: isTaggedOrReplied
                    ? Border.all(
                        color: dark ? colors.secondary : const Color(0xFFFFB020),
                        width: 1.2,
                      )
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100C2748),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSender && !message.isMe && message.sender != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        cleanMojibakeText(message.sender!),
                        style: TextStyle(
                          color: dark ? colors.primary : AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (replyMessage != null)
                    InkWell(
                      onTap: onReplyTap,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9),
                          border: const Border(
                            left: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replyMessage!.sender ??
                                  (replyMessage!.isMe ? 'You' : 'Message'),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              cleanMojibakeText(replyMessage!.previewText),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (message.threadRootId > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.forum_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Thread reply',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.originalSenderName.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Forwarded from ${cleanMojibakeText(message.originalSenderName)}'
                        '${message.originalSourceName.isNotEmpty ? ' - ${cleanMojibakeText(message.originalSourceName)}' : ''}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (attachment != null)
                    AttachmentContent(attachment: attachment)
                  else if (contactCard != null)
                    ContactMessageCard(data: contactCard)
                  else if (checklist != null)
                    LiveChecklistCard(
                      data: checklist,
                      onToggle: onChecklistToggle,
                      showDetails: showChecklistPollDetails,
                      participantNames: participantNames,
                    )
                  else if (poll != null)
                    LivePollCard(
                      data: poll,
                      onVote: onPollVote,
                      showDetails: showChecklistPollDetails,
                      participantNames: participantNames,
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CollapsibleMessageText(
                          text: cleanMojibakeText(message.text),
                          onMentionTap: onMentionTap,
                          onSelectionChanged: onTextSelectionChanged,
                        ),
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.time,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                              if (message.isEdited)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text(
                                    'edited',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              if (message.isMe) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  message.isFailed
                                      ? Icons.error_outline_rounded
                                      : message.isSending
                                      ? Icons.schedule_rounded
                                      : message.isRead
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                                  size: 16,
                                  color: message.isFailed
                                      ? Colors.red
                                      : AppColors.primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (attachment != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            message.time,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                          if (message.isMe) ...[
                            const SizedBox(width: 3),
                            Icon(
                              message.isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (message.visibilityMode.toLowerCase() == 'selected')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.lock_person_outlined,
                            size: 11,
                            color: AppColors.muted,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Selected users',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.sourceDevice != 'unknown' &&
                      message.sourceDevice.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        message.sourceName.isEmpty
                            ? 'via ${cleanMojibakeText(message.sourceDevice)}'
                            : 'via ${cleanMojibakeText(message.sourceDevice)} - ${cleanMojibakeText(message.sourceName)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (showLocationAddress &&
                      message.locationAddress.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              cleanMojibakeText(message.locationAddress),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.reaction.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(cleanMojibakeText(message.reaction)),
                    ),
                ],
              ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsibleMessageText extends StatefulWidget {
  const _CollapsibleMessageText({
    required this.text,
    this.onMentionTap,
    this.onSelectionChanged,
  });

  final String text;
  final ValueChanged<String>? onMentionTap;
  final VoidCallback? onSelectionChanged;

  @override
  State<_CollapsibleMessageText> createState() =>
      _CollapsibleMessageTextState();
}

class _CollapsibleMessageTextState extends State<_CollapsibleMessageText> {
  static const _collapsedLines = 8;
  static const _longMessageCharacters = 420;

  bool _expanded = false;

  bool get _isLong {
    if (widget.text.length > _longMessageCharacters) return true;
    return String.fromCharCode(10).allMatches(widget.text).length >=
        _collapsedLines;
  }

  @override
  void didUpdateWidget(covariant _CollapsibleMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appCollapseLongMessages,
      builder: (context, collapseLongMessages, _) {
        final collapsible = collapseLongMessages && _isLong;
        final collapsed = collapsible && !_expanded;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: appMessageScale,
              builder: (context, _, _) => SelectableText.rich(
                _formattedMessageSpan(
                  widget.text,
                  Theme.of(context),
                  onMentionTap: widget.onMentionTap,
                ),
                maxLines: collapsed ? _collapsedLines : null,
                scrollPhysics: const NeverScrollableScrollPhysics(),
                onSelectionChanged: (selection, cause) {
                  if (!selection.isCollapsed) widget.onSelectionChanged?.call();
                },
                contextMenuBuilder: (context, editableTextState) =>
                    AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    ),
              ),
            ),
            if (collapsible)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(top: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? 'Show less' : 'Read more'),
              ),
          ],
        );
      },
    );
  }
}

TextSpan _formattedMessageSpan(
  String text,
  ThemeData theme, {
  ValueChanged<String>? onMentionTap,
}) {
  text = cleanMojibakeText(text);
  final base = TextStyle(
    color: theme.colorScheme.onSurface,
    fontSize: 15 * appMessageScale.value,
    height: 1.35,
  );
  final pattern = RegExp(
    r'(https?:\/\/[^\s<>()]+|www\.[^\s<>()]+|\*\*[\s\S]+?\*\*|~~[\s\S]+?~~|`[^`\n]+?`|__[^_\n]+?__|\*[^*\n]+?\*|_[^_\n]+?_|\[color=#[0-9A-Fa-f]{6}\][\s\S]+?\[/color\]|^> .+$|\n> .+|@[A-Za-z0-9_]+)',
  );
  final spans = <InlineSpan>[];
  var offset = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > offset) {
      spans.add(TextSpan(text: text.substring(offset, match.start)));
    }
    final token = match.group(0)!;
    if (_looksLikeWebUrl(token)) {
      final parts = _splitUrlTrailingPunctuation(token);
      final urlText = parts.$1;
      spans.add(
        TextSpan(
          text: urlText,
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openTextLink(urlText),
        ),
      );
      if (parts.$2.isNotEmpty) spans.add(TextSpan(text: parts.$2));
    } else if (token.startsWith('**')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (token.startsWith('~~')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      );
    } else if (token.startsWith('`')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      );
    } else if (token.startsWith('__')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
      );
    } else if (token.startsWith('> ')) {
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (token.startsWith('\n> ')) {
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (token.startsWith('*') || token.startsWith('_')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else if (token.startsWith('@')) {
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            fontWeight: FontWeight.w700,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onMentionTap?.call(token),
        ),
      );
    } else {
      final colorHex = token.substring(8, 14);
      final content = token.substring(15, token.length - 8);
      spans.add(
        TextSpan(
          text: content,
          style: TextStyle(color: Color(int.parse('FF$colorHex', radix: 16))),
        ),
      );
    }
    offset = match.end;
  }
  if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
  return TextSpan(style: base, children: spans);
}

bool _looksLikeWebUrl(String value) {
  final lower = value.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('www.');
}

(String, String) _splitUrlTrailingPunctuation(String value) {
  var end = value.length;
  while (end > 0 && '.,!?;:'.contains(value[end - 1])) {
    end--;
  }
  return (value.substring(0, end), value.substring(end));
}

Future<void> _openTextLink(String value) async {
  final normalized = value.toLowerCase().startsWith('http')
      ? value
      : 'https://$value';
  final uri = Uri.tryParse(normalized);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ThreadViewScreen extends StatefulWidget {
  const _ThreadViewScreen({
    required this.chat,
    required this.root,
    required this.messages,
  });

  final ChatPreview chat;
  final ChatMessage root;
  final List<ChatMessage> messages;

  @override
  State<_ThreadViewScreen> createState() => _ThreadViewScreenState();
}

class _ThreadViewScreenState extends State<_ThreadViewScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  int get _rootId =>
      widget.root.threadRootId > 0 ? widget.root.threadRootId : widget.root.id;

  List<ChatMessage> get _replies => widget.messages
      .where((message) => message.threadRootId == _rootId)
      .toList();

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await chatApi.sendMessage(
        to: widget.chat.jid,
        message: text,
        replyToId: '${widget.root.id}',
        threadRootId: '$_rootId',
      );
      if (!mounted) return;
      _controller.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thread reply sent.')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _threadMessage(ChatMessage message, {bool root = false}) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              root ? 'Original message' : (message.sender ?? 'You'),
              style: TextStyle(
                color: root ? AppColors.primary : null,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(cleanMojibakeText(message.previewText)),
            const SizedBox(height: 6),
            Text(message.time, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${_replies.length} replies'),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _threadMessage(widget.root, root: true),
                const Divider(height: 24),
                ..._replies.map(_threadMessage),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Reply in thread',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForwardTargetSheet extends StatefulWidget {
  const _ForwardTargetSheet({required this.chats});

  final List<ChatContact> chats;

  @override
  State<_ForwardTargetSheet> createState() => _ForwardTargetSheetState();
}

class _ForwardTargetSheetState extends State<_ForwardTargetSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final chats = widget.chats.where((chat) {
      if (query.isEmpty) return true;
      return '${chat.name} ${chat.designation} ${chat.jid}'
          .toLowerCase()
          .contains(query);
    }).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.76,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Text(
                'Forward to',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search users, groups and channels',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: chats.isEmpty
                  ? const Center(child: Text('No matching conversation found.'))
                  : ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (_, index) {
                        final chat = chats[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              chat.type == 'saved'
                                  ? Icons.bookmark_rounded
                                  : chat.type == 'chat'
                                  ? Icons.person_rounded
                                  : Icons.groups_rounded,
                            ),
                          ),
                          title: Text(chat.name),
                          subtitle: Text(chat.designation),
                          onTap: () => Navigator.pop(context, chat),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


void _applyComposerFormatting(
  TextEditingController controller,
  String prefix,
  String suffix,
) {
  final value = controller.value;
  final selection = value.selection;
  if (!selection.isValid || selection.isCollapsed) return;
  final start = min(selection.start, selection.end);
  final end = max(selection.start, selection.end);
  final selected = value.text.substring(start, end);
  final replacement = '$prefix$selected$suffix';
  controller.value = TextEditingValue(
    text: value.text.replaceRange(start, end, replacement),
    selection: TextSelection(
      baseOffset: start + prefix.length,
      extentOffset: start + prefix.length + selected.length,
    ),
  );
}

Future<void> _applyComposerColor(
  BuildContext context,
  TextEditingController controller,
) async {
  final picked = await showMenu<String>(
    context: context,
    position: const RelativeRect.fromLTRB(80, 520, 16, 80),
    items: const [
      PopupMenuItem(value: '#E11D48', child: Text('Red')),
      PopupMenuItem(value: '#D97706', child: Text('Orange')),
      PopupMenuItem(value: '#07865D', child: Text('Green')),
      PopupMenuItem(value: '#2864DC', child: Text('Blue')),
      PopupMenuItem(value: '#7C3AED', child: Text('Violet')),
      PopupMenuItem(value: '#111827', child: Text('Black')),
    ],
  );
  if (picked == null) return;
  _applyComposerFormatting(controller, '[color=$picked]', '[/color]');
}

Future<void> _showComposerFormattingMenu(
  BuildContext context,
  TextEditingController controller,
) async {
  if (!controller.selection.isValid || controller.selection.isCollapsed) return;
  final action = await showMenu<String>(
    context: context,
    position: const RelativeRect.fromLTRB(80, 520, 16, 80),
    items: const [
      PopupMenuItem(value: 'bold', child: Text('Bold')),
      PopupMenuItem(value: 'italic', child: Text('Italic')),
      PopupMenuItem(value: 'underline', child: Text('Underline')),
      PopupMenuItem(value: 'strike', child: Text('Strikethrough')),
      PopupMenuItem(value: 'mono', child: Text('Monospace')),
      PopupMenuItem(value: 'quote', child: Text('Quote')),
      PopupMenuItem(value: 'color', child: Text('Text color')),
    ],
  );
  if (action == null) return;
  switch (action) {
    case 'bold':
      _applyComposerFormatting(controller, '**', '**');
      break;
    case 'italic':
      _applyComposerFormatting(controller, '*', '*');
      break;
    case 'underline':
      _applyComposerFormatting(controller, '__', '__');
      break;
    case 'strike':
      _applyComposerFormatting(controller, '~~', '~~');
      break;
    case 'mono':
      _applyComposerFormatting(controller, '`', '`');
      break;
    case 'quote':
      _applyComposerFormatting(controller, '> ', '');
      break;
    case 'color':
      await _applyComposerColor(context, controller);
      break;
  }
}

Widget _composerContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
  TextEditingController controller,
) {
  final anchors = editableTextState.contextMenuAnchors;
  final selected = controller.selection.isValid && !controller.selection.isCollapsed;
  final items = <ContextMenuButtonItem>[
    ...editableTextState.contextMenuButtonItems,
    if (selected) ...[
      ContextMenuButtonItem(
        label: 'Bold',
        onPressed: () {
          ContextMenuController.removeAny();
          _applyComposerFormatting(controller, '**', '**');
        },
      ),
      ContextMenuButtonItem(
        label: 'Italic',
        onPressed: () {
          ContextMenuController.removeAny();
          _applyComposerFormatting(controller, '*', '*');
        },
      ),
      ContextMenuButtonItem(
        label: 'Underline',
        onPressed: () {
          ContextMenuController.removeAny();
          _applyComposerFormatting(controller, '__', '__');
        },
      ),
      ContextMenuButtonItem(
        label: 'Strikethrough',
        onPressed: () {
          ContextMenuController.removeAny();
          _applyComposerFormatting(controller, '~~', '~~');
        },
      ),
      ContextMenuButtonItem(
        label: 'Monospace',
        onPressed: () {
          ContextMenuController.removeAny();
          _applyComposerFormatting(controller, '`', '`');
        },
      ),
      ContextMenuButtonItem(
        label: 'Quote',
        onPressed: () {
          ContextMenuController.removeAny();
          _applyComposerFormatting(controller, '> ', '');
        },
      ),
      ContextMenuButtonItem(
        label: 'Text color',
        onPressed: () {
          ContextMenuController.removeAny();
          _applyComposerColor(context, controller);
        },
      ),
    ],
  ];
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: anchors,
    buttonItems: items,
  );
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSend,
    this.onSendLongPress,
    required this.onSendLater,
    required this.onVoiceRecord,
    required this.isRecordingVoice,
    required this.onAttach,
    required this.isUploading,
    required this.uploadProgress,
    required this.showEmojiPicker,
    required this.onEmojiToggle,
    required this.onEmojiSelected,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onSendLongPress;
  final VoidCallback onSendLater;
  final VoidCallback onVoiceRecord;
  final bool isRecordingVoice;
  final VoidCallback onAttach;
  final bool isUploading;
  final double uploadProgress;
  final bool showEmojiPicker;
  final VoidCallback onEmojiToggle;
  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUploading)
              LinearProgressIndicator(
                value: uploadProgress <= 0 ? null : uploadProgress,
                minHeight: 3,
              ),
            Container(
              color: Theme.of(context).colorScheme.surfaceContainer,
              padding: EdgeInsets.fromLTRB(
                10,
                7,
                10,
                MediaQuery.paddingOf(context).bottom + 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x120C2748),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Emoji',
                            onPressed: onEmojiToggle,
                            icon: const Icon(
                              Icons.sentiment_satisfied_alt_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                          Expanded(
                            child: Focus(
                              onKeyEvent: (_, event) {
                                if (event is! KeyDownEvent) {
                                  return KeyEventResult.ignored;
                                }
                                final isEnter =
                                    event.logicalKey ==
                                        LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.numpadEnter;
                                if (!isEnter) {
                                  return KeyEventResult.ignored;
                                }
                                final insertNewLine =
                                    HardwareKeyboard
                                        .instance
                                        .isControlPressed ||
                                    HardwareKeyboard.instance.isMetaPressed ||
                                    HardwareKeyboard.instance.isShiftPressed;
                                if (insertNewLine) {
                                  final value = controller.value;
                                  final selection = value.selection.isValid
                                      ? value.selection
                                      : TextSelection.collapsed(
                                          offset: value.text.length,
                                        );
                                  final text = value.text.replaceRange(
                                    selection.start,
                                    selection.end,
                                    '\n',
                                  );
                                  controller.value = TextEditingValue(
                                    text: text,
                                    selection: TextSelection.collapsed(
                                      offset: selection.start + 1,
                                    ),
                                  );
                                  return KeyEventResult.handled;
                                }
                                if (hasText) {
                                  onSend();
                                }
                                return KeyEventResult.handled;
                              },
                              child: TextField(
                                key: const Key('messageField'),
                                controller: controller,
                                minLines: 1,
                                maxLines: 5,
                                keyboardType: TextInputType.multiline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                contextMenuBuilder:
                                    (context, editableTextState) =>
                                        _composerContextMenu(
                                          context,
                                          editableTextState,
                                          controller,
                                        ),
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Format selected text',
                            onPressed: controller.selection.isValid &&
                                    !controller.selection.isCollapsed
                                ? () => _showComposerFormattingMenu(
                                      context,
                                      controller,
                                    )
                                : null,
                            icon: Icon(
                              Icons.format_bold_rounded,
                              color: controller.selection.isValid &&
                                      !controller.selection.isCollapsed
                                  ? AppColors.muted
                                  : AppColors.muted.withOpacity(0.45),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Schedule message',
                            onPressed: hasText ? onSendLater : null,
                            icon: Icon(
                              Icons.schedule_send_rounded,
                              color: hasText
                                  ? AppColors.muted
                                  : AppColors.muted.withOpacity(0.45),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Attach',
                            onPressed: isUploading ? null : onAttach,
                            icon: isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.attach_file_rounded,
                                    color: AppColors.muted,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: onVoiceRecord,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Icon(
                          isRecordingVoice
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: hasText
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.45),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      key: const Key('sendButton'),
                      onTap: hasText ? onSend : null,
                      onLongPress: hasText ? onSendLongPress : null,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 50,
                        height: 50,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showEmojiPicker)
              MojibakeEmojiPicker(onEmojiSelected: onEmojiSelected),
          ],
        );
      },
    );
  }
}

class _MessageMenuItem extends StatelessWidget {
  const _MessageMenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFB3261E)
        : Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionToolbarAction extends StatelessWidget {
  const _SelectionToolbarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? const Color(0xFFB3261E)
        : AppColors.primary;
    final background = destructive
        ? const Color(0x11B3261E)
        : AppColors.primary.withValues(alpha: 0.08);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: foreground),
        label: Text(label),
        style: FilledButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          disabledForegroundColor: AppColors.muted,
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

String mimeTypeForFile(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'mp4' => 'video/mp4',
    'm4v' => 'video/x-m4v',
    'mov' => 'video/quicktime',
    'avi' => 'video/x-msvideo',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

