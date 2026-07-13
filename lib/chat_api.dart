import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'device_service.dart';
import 'employee_directory.dart';
import 'session_store.dart';
import 'app_cache.dart';
import 'xmpp_bridge.dart';
import 'web_file_actions.dart';

const xmppDomain = 'chat.skylinkonline.net';
const systemNotificationJid = 'notification@chat.skylinkonline.net';
const requiredProxyVersion = '2026.06.23.2';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

Map<String, dynamic>? _compressChatImage(Map<String, dynamic> input) {
  final bytes = input['bytes'] as Uint8List;
  final name = '${input['name'] ?? 'image'}';
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = decoded.width > 1280 || decoded.height > 1280
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1280 : null,
          height: decoded.height > decoded.width ? 1280 : null,
        )
      : decoded;
  return {
    'bytes': Uint8List.fromList(img.encodeJpg(resized, quality: 74)),
    'name': '${name.replaceFirst(RegExp(r'\.[^.]+$'), '')}.jpg',
  };
}

class CurrentUser {
  const CurrentUser({
    required this.empId,
    required this.name,
    required this.designation,
    required this.jid,
    this.avatarUrl = '',
    this.isPinned = false,
    this.isStarred = false,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      empId: '${json['emp_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      designation: '${json['designation'] ?? ''}',
      jid: '${json['jid'] ?? ''}',
      avatarUrl: '${json['avatar_url'] ?? ''}',
      isPinned: _jsonBool(json['pinned']),
      isStarred: _jsonBool(json['starred']),
    );
  }

  final String empId;
  final String name;
  final String designation;
  final String jid;
  final String avatarUrl;
  final bool isPinned;
  final bool isStarred;
}

class ChatContact {
  const ChatContact({
    required this.empId,
    required this.name,
    required this.designation,
    required this.jid,
    this.type = 'chat',
    this.lastMessage = '',
    this.time = '',
    this.isOnline = false,
    this.unread = 0,
    this.wasMentioned = false,
    this.avatarUrl = '',
    this.isPinned = false,
    this.isStarred = false,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    final empId = '${json['emp_id'] ?? json['id'] ?? ''}'.trim();
    final jid = '${json['jid'] ?? ''}'.trim();
    final unreadValue =
        json['unread_count'] ??
        json['unread'] ??
        json['unreadCount'] ??
        json['count'];
    final normalizedJid = (jid.isNotEmpty ? jid : '$empId@$xmppDomain')
        .toLowerCase();
    final isNotification = normalizedJid == systemNotificationJid;
    return ChatContact(
      empId: isNotification
          ? 'notification'
          : (empId.isNotEmpty ? empId : jid.split('@').first),
      name: isNotification
          ? 'System Notifications'
          : '${json['name'] ?? empId}'.trim(),
      designation: isNotification
          ? 'Receive-only system messages'
          : '${json['designation'] ?? ''}'.trim(),
      jid: normalizedJid,
      type: isNotification ? 'notification' : '${json['type'] ?? 'chat'}',
      lastMessage: '${json['last'] ?? ''}',
      time: '${json['time'] ?? ''}',
      isOnline: _jsonBool(json['online'] ?? json['is_online']),
      unread: _jsonInt(unreadValue),
      wasMentioned: _jsonBool(json['mentioned'] ?? json['was_mentioned']),
      avatarUrl: '${json['avatar_url'] ?? ''}',
      isPinned: _jsonBool(json['pinned']),
      isStarred: _jsonBool(json['starred']),
    );
  }

  final String empId;
  final String name;
  final String designation;
  final String jid;
  final String type;
  final String lastMessage;
  final String time;
  final bool isOnline;
  final int unread;
  final bool wasMentioned;
  final String avatarUrl;
  final bool isPinned;
  final bool isStarred;

  bool get hasValidJid {
    return jid.toLowerCase() == systemNotificationJid ||
        RegExp(r'^[^@\s]+@chat\.skylinkonline\.net$').hasMatch(jid) ||
        RegExp(
          r'^[a-z0-9][a-z0-9-]*@conference\.chat\.skylinkonline\.net$',
          caseSensitive: false,
        ).hasMatch(jid);
  }
}

bool _jsonBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch ('${value ?? ''}'.trim().toLowerCase()) {
    '1' || 'true' || 'yes' || 'online' => true,
    _ => false,
  };
}

int _jsonInt(dynamic value) {
  if (value is int) return value < 0 ? 0 : value;
  if (value is num) return value < 0 ? 0 : value.toInt();
  final parsed = int.tryParse('${value ?? ''}'.trim()) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

double? _jsonDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = '$value'.trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return double.tryParse(text);
}

class PresenceInfo {
  const PresenceInfo({
    required this.isOnline,
    required this.lastSeen,
    this.mobileActive = false,
    this.launchpadActive = false,
    this.messengerConnected = false,
    this.locationAvailable = false,
  });

  final bool isOnline;
  final DateTime? lastSeen;
  final bool mobileActive;
  final bool launchpadActive;
  final bool messengerConnected;
  final bool locationAvailable;
}

class AppVersionStatus {
  const AppVersionStatus({
    required this.latest,
    required this.minimum,
    required this.url,
    required this.updateAvailable,
    required this.updateRequired,
    this.forceUpdate = false,
    this.releaseStatus = '',
  });

  final String latest;
  final String minimum;
  final String url;
  final bool updateAvailable;
  final bool updateRequired;
  final bool forceUpdate;
  final String releaseStatus;
}

class ReleaseBuild {
  const ReleaseBuild({
    required this.id,
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.stage,
    required this.status,
    required this.url,
    required this.notes,
    required this.rolloutPercent,
    required this.forceUpdate,
    required this.createdAt,
  });

  factory ReleaseBuild.fromJson(Map<String, dynamic> json) => ReleaseBuild(
    id: _jsonInt(json['id']),
    platform: '${json['platform'] ?? ''}',
    version: '${json['version'] ?? ''}',
    buildNumber: _jsonInt(json['build_number']),
    stage: '${json['stage'] ?? ''}',
    status: '${json['status'] ?? ''}',
    url: '${json['apk_url'] ?? ''}',
    notes: '${json['notes'] ?? ''}',
    rolloutPercent: _jsonInt(json['rollout_percent']),
    forceUpdate: _jsonBool(json['force_update']),
    createdAt: '${json['created_at'] ?? ''}',
  );

  final int id;
  final String platform;
  final String version;
  final int buildNumber;
  final String stage;
  final String status;
  final String url;
  final String notes;
  final int rolloutPercent;
  final bool forceUpdate;
  final String createdAt;
}

class ReleaseGovernance {
  const ReleaseGovernance({
    required this.canApproveProduction,
    required this.builds,
    required this.history,
  });

  final bool canApproveProduction;
  final List<ReleaseBuild> builds;
  final List<Map<String, dynamic>> history;
}

class ReleaseNote {
  const ReleaseNote({
    required this.id,
    required this.platform,
    required this.version,
    required this.releaseDate,
    required this.newFeatures,
    required this.improvements,
    required this.bugFixes,
    required this.securityUpdates,
    required this.implementationDetails,
    required this.viewed,
  });

  factory ReleaseNote.fromJson(Map<String, dynamic> json) => ReleaseNote(
    id: _jsonInt(json['id']),
    platform: '${json['platform'] ?? ''}',
    version: '${json['version'] ?? ''}',
    releaseDate: '${json['release_date'] ?? ''}',
    newFeatures: '${json['new_features'] ?? ''}',
    improvements: '${json['improvements'] ?? ''}',
    bugFixes: '${json['bug_fixes'] ?? ''}',
    securityUpdates: '${json['security_updates'] ?? ''}',
    implementationDetails: '${json['implementation_details'] ?? ''}',
    viewed: _jsonBool(json['viewed']),
  );

  final int id;
  final String platform;
  final String version;
  final String releaseDate;
  final String newFeatures;
  final String improvements;
  final String bugFixes;
  final String securityUpdates;
  final String implementationDetails;
  final bool viewed;

  bool get isEmpty =>
      newFeatures.trim().isEmpty &&
      improvements.trim().isEmpty &&
      bugFixes.trim().isEmpty &&
      securityUpdates.trim().isEmpty &&
      implementationDetails.trim().isEmpty;
}

class ChannelProfile {
  const ChannelProfile({required this.data});
  final Map<String, dynamic> data;

  String get kind => '${data['channel_kind'] ?? ''}';
  String get statusText => '${data['status_text'] ?? ''}';
  String get priority => '${data['priority'] ?? ''}';
  String get ageLabel => '${data['age_label'] ?? ''}';
  Map<String, dynamic> get sla => data['sla'] is Map
      ? Map<String, dynamic>.from(data['sla'] as Map)
      : <String, dynamic>{};
  List<Map<String, dynamic>> get timeline => data['timeline'] is List
      ? (data['timeline'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];
}

class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.url,
    required this.mimeType,
    required this.size,
    this.caption = '',
    this.transcription = '',
    this.waveform = const [],
    this.durationMs = 0,
    this.latitude,
    this.longitude,
    this.locationAddress = '',
    this.isLiveLocation = false,
    this.liveMinutes = 0,
    this.shareId = '',
    this.messageId = 0,
  });

  static const _filePrefix = 'SKYLINK_FILE:';
  static const _locationPrefix = 'SKYLINK_LOCATION:';

  factory ChatAttachment.fromMessage(String body) {
    final data = jsonDecode(body.substring(_filePrefix.length));
    final json = Map<String, dynamic>.from(data as Map);
    return ChatAttachment(
      name: '${json['name'] ?? 'File'}',
      url: '${json['url'] ?? ''}',
      mimeType: '${json['type'] ?? 'application/octet-stream'}',
      size: _jsonInt(json['size']),
      caption: '${json['caption'] ?? ''}'.trim(),
      transcription: '${json['transcription'] ?? ''}'.trim(),
      waveform: (json['waveform'] is List)
          ? (json['waveform'] as List).map((value) => _jsonInt(value)).toList()
          : const [],
      durationMs: _jsonInt(json['duration_ms']),
    );
  }

  factory ChatAttachment.fromLocationMessage(String body) {
    final data = jsonDecode(body.substring(_locationPrefix.length));
    final json = Map<String, dynamic>.from(data as Map);
    final latitude = _jsonDouble(json['latitude']);
    final longitude = _jsonDouble(json['longitude']);
    final isLive = _jsonBool(json['is_live']);
    final liveMinutes = _jsonInt(json['live_minutes']);
    final address = '${json['location_address'] ?? ''}'.trim();
    final label = isLive ? 'Live location' : 'Current location';
    return ChatAttachment(
      name: label,
      url: _mapsUrl(latitude, longitude),
      mimeType: isLive
          ? 'application/vnd.skylink.live-location'
          : 'application/vnd.skylink.location',
      size: 0,
      latitude: latitude,
      longitude: longitude,
      locationAddress: address,
      isLiveLocation: isLive,
      liveMinutes: liveMinutes,
      shareId: '${json['share_id'] ?? ''}',
    );
  }

  static ChatAttachment location({
    required double latitude,
    required double longitude,
    required String locationAddress,
    bool isLiveLocation = false,
    int liveMinutes = 0,
    String shareId = '',
  }) {
    return ChatAttachment(
      name: isLiveLocation ? 'Live location' : 'Current location',
      url: _mapsUrl(latitude, longitude),
      mimeType: isLiveLocation
          ? 'application/vnd.skylink.live-location'
          : 'application/vnd.skylink.location',
      size: 0,
      latitude: latitude,
      longitude: longitude,
      locationAddress: locationAddress.trim(),
      isLiveLocation: isLiveLocation,
      liveMinutes: liveMinutes,
      shareId: shareId,
    );
  }

  final String name;
  final String url;
  final String mimeType;
  final int size;
  final String caption;
  final String transcription;
  final List<int> waveform;
  final int durationMs;
  final double? latitude;
  final double? longitude;
  final String locationAddress;
  final bool isLiveLocation;
  final int liveMinutes;
  final String shareId;
  final int messageId;

  bool get isAudio {
    if (mimeType.toLowerCase().startsWith('audio/')) return true;
    return RegExp(
      r'\.(mp3|m4a|aac|wav|ogg|oga|opus|flac|amr)$',
      caseSensitive: false,
    ).hasMatch(name);
  }

  bool get isImage {
    if (mimeType.toLowerCase().startsWith('image/')) return true;
    return RegExp(
      r'\.(jpe?g|png|gif|webp|bmp|svg|tiff?|heic|heif)$',
      caseSensitive: false,
    ).hasMatch(name);
  }

  bool get isLocation =>
      mimeType == 'application/vnd.skylink.location' ||
      mimeType == 'application/vnd.skylink.live-location';

  String encode() {
    if (isLocation) {
      return '$_locationPrefix${jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'location_address': locationAddress,
        'is_live': isLiveLocation,
        if (liveMinutes > 0) 'live_minutes': liveMinutes,
        if (shareId.isNotEmpty) 'share_id': shareId,
      })}';
    }
    return '$_filePrefix${jsonEncode({'name': name, 'url': url, 'type': mimeType, 'size': size, if (caption.isNotEmpty) 'caption': caption, if (transcription.isNotEmpty) 'transcription': transcription, if (waveform.isNotEmpty) 'waveform': waveform, if (durationMs > 0) 'duration_ms': durationMs})}';
  }

  static ChatAttachment? tryParse(String body) {
    if (body.startsWith(_filePrefix)) {
      try {
        final attachment = ChatAttachment.fromMessage(body);
        return attachment.url.isEmpty ? null : attachment;
      } catch (_) {
        return null;
      }
    }
    if (body.startsWith(_locationPrefix)) {
      try {
        return ChatAttachment.fromLocationMessage(body);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

String _mapsUrl(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return '';
  return 'https://www.google.com/maps/search/?api=1&query=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}

class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.body,
    required this.side,
    required this.status,
    required this.createdAt,
    required this.time,
    this.senderName = '',
    this.replyToId = '',
    this.threadRootId = '',
    this.mentions = const [],
    this.fileUrl = '',
    this.fileName = '',
    this.fileType = '',
    this.fileSize = 0,
    this.latitude,
    this.longitude,
    this.locationAddress = '',
    this.editedAt = '',
    this.sourceDevice = 'unknown',
    this.sourceName = '',
    this.readAt = '',
    this.originalSenderJid = '',
    this.originalSenderName = '',
    this.originalSourceName = '',
    this.forwardedFromMessageId = '',
    this.messageType = 'chat',
  });

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    return ApiMessage(
      id: '${json['id'] ?? ''}',
      from: '${json['from'] ?? ''}',
      to: '${json['to'] ?? ''}',
      body: '${json['body'] ?? ''}',
      side: '${json['side'] ?? ''}',
      status: '${json['status'] ?? ''}',
      createdAt: '${json['created_at'] ?? ''}',
      time: '${json['time'] ?? ''}',
      senderName:
          ('${json['from'] ?? ''}'.toLowerCase() == systemNotificationJid)
          ? 'System Notifications'
          : '${json['sender_name'] ?? ''}',
      replyToId: '${json['reply_to_id'] ?? ''}',
      threadRootId: '${json['thread_root_id'] ?? ''}',
      mentions: (json['mentions'] is List)
          ? (json['mentions'] as List).map((value) => '$value').toList()
          : const [],
      fileUrl: '${json['file_url'] ?? ''}',
      fileName: '${json['file_name'] ?? ''}',
      fileType: '${json['file_type'] ?? ''}',
      fileSize: _jsonInt(json['file_size']),
      latitude: _jsonDouble(json['latitude']),
      longitude: _jsonDouble(json['longitude']),
      locationAddress: '${json['location_address'] ?? ''}',
      editedAt: '${json['edited_at'] ?? ''}',
      sourceDevice: '${json['source_device'] ?? 'unknown'}',
      sourceName: '${json['source_name'] ?? ''}',
      readAt: '${json['read_at'] ?? ''}',
      originalSenderJid: '${json['original_sender_jid'] ?? ''}',
      originalSenderName: '${json['original_sender_name'] ?? ''}',
      originalSourceName: '${json['original_source_name'] ?? ''}',
      forwardedFromMessageId: '${json['forwarded_from_message_id'] ?? ''}',
      messageType: '${json['message_type'] ?? 'chat'}',
    );
  }

  final String id;
  final String from;
  final String to;
  final String body;
  final String side;
  final String status;
  final String createdAt;
  final String time;
  final String senderName;
  final String replyToId;
  final String threadRootId;
  final List<String> mentions;
  final String fileUrl;
  final String fileName;
  final String fileType;
  final int fileSize;
  final double? latitude;
  final double? longitude;
  final String locationAddress;
  final String editedAt;
  final String sourceDevice;
  final String sourceName;
  final String readAt;
  final String originalSenderJid;
  final String originalSenderName;
  final String originalSourceName;
  final String forwardedFromMessageId;
  final String messageType;

  bool get isMine => side.toLowerCase() == 'me';
  bool get isEdited => editedAt.trim().isNotEmpty;
  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'body': body,
    'side': side,
    'status': status,
    'created_at': createdAt,
    'time': time,
    'sender_name': senderName,
    'reply_to_id': replyToId,
    'thread_root_id': threadRootId,
    'mentions': mentions,
    'file_url': fileUrl,
    'file_name': fileName,
    'file_type': fileType,
    'file_size': fileSize,
    'latitude': latitude,
    'longitude': longitude,
    'location_address': locationAddress,
    'edited_at': editedAt,
    'source_device': sourceDevice,
    'source_name': sourceName,
    'read_at': readAt,
    'original_sender_jid': originalSenderJid,
    'original_sender_name': originalSenderName,
    'original_source_name': originalSourceName,
    'forwarded_from_message_id': forwardedFromMessageId,
    'message_type': messageType,
  };
  ChatAttachment? get attachment {
    final encoded = ChatAttachment.tryParse(body);
    if (encoded != null) return encoded;
    final explicitLocationType = {
      'location',
      'current_location',
      'live_location',
    }.contains(messageType.toLowerCase());
    if (explicitLocationType && latitude != null && longitude != null) {
      final isLive = messageType.toLowerCase() == 'live_location';
      return ChatAttachment.location(
        latitude: latitude!,
        longitude: longitude!,
        locationAddress: locationAddress,
        isLiveLocation: isLive,
      );
    }
    if (fileUrl.trim().isEmpty) return null;
    return ChatAttachment(
      name: fileName.trim().isEmpty ? 'File' : fileName,
      url: fileUrl,
      mimeType: fileType.trim().isEmpty ? 'application/octet-stream' : fileType,
      size: fileSize,
      caption: body,
    );
  }
}

class AppSession {
  const AppSession({
    required this.sessionId,
    required this.deviceName,
    required this.platform,
    required this.source,
    required this.lastSeen,
    required this.ipAddress,
  });

  factory AppSession.fromJson(Map<String, dynamic> json) => AppSession(
    sessionId: '${json['session_id'] ?? ''}',
    deviceName: '${json['device_name'] ?? 'Unknown device'}',
    platform: '${json['platform'] ?? 'unknown'}',
    source: '${json['app_source'] ?? ''}',
    lastSeen: '${json['last_seen_at'] ?? ''}',
    ipAddress: '${json['ip_address'] ?? ''}',
  );

  final String sessionId;
  final String deviceName;
  final String platform;
  final String source;
  final String lastSeen;
  final String ipAddress;
}

class SavedMessage {
  const SavedMessage({
    required this.id,
    required this.body,
    required this.createdAt,
  });

  factory SavedMessage.fromJson(Map<String, dynamic> json) => SavedMessage(
    id: _jsonInt(json['id']),
    body: '${json['body'] ?? ''}',
    createdAt: '${json['created_at'] ?? ''}',
  );

  final int id;
  final String body;
  final String createdAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'created_at': createdAt,
  };
}

class UserProfile {
  const UserProfile({
    required this.empId,
    required this.name,
    required this.designation,
    required this.jid,
    required this.avatarUrl,
    required this.email,
    required this.mobile,
    required this.employeeType,
    required this.workLocation,
    this.deviceModel = '',
    this.appVersion = '',
    this.lastActivityAt = '',
    this.latestLatitude,
    this.latestLongitude,
    this.latestLocationAddress = '',
    this.latestLocationAt = '',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    empId: '${json['emp_id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    designation: '${json['designation'] ?? ''}',
    jid: '${json['jid'] ?? ''}',
    avatarUrl: '${json['avatar_url'] ?? ''}',
    email: '${json['email'] ?? ''}',
    mobile: '${json['mobile'] ?? ''}',
    employeeType: '${json['employee_type'] ?? ''}',
    workLocation: '${json['work_location'] ?? ''}',
    deviceModel: '${json['device_model'] ?? ''}',
    appVersion: '${json['app_version'] ?? ''}',
    lastActivityAt: '${json['last_activity_at'] ?? ''}',
    latestLatitude: _jsonDouble(json['latest_latitude']),
    latestLongitude: _jsonDouble(json['latest_longitude']),
    latestLocationAddress: '',
    latestLocationAt: '',
  );

  final String empId;
  final String name;
  final String designation;
  final String jid;
  final String avatarUrl;
  final String email;
  final String mobile;
  final String employeeType;
  final String workLocation;
  final String deviceModel;
  final String appVersion;
  final String lastActivityAt;
  final double? latestLatitude;
  final double? latestLongitude;
  final String latestLocationAddress;
  final String latestLocationAt;
  Map<String, dynamic> toJson() => {
    'emp_id': empId,
    'name': name,
    'designation': designation,
    'jid': jid,
    'avatar_url': avatarUrl,
    'email': email,
    'mobile': mobile,
    'employee_type': employeeType,
    'work_location': workLocation,
    'device_model': deviceModel,
    'app_version': appVersion,
    'last_activity_at': lastActivityAt,
    'latest_latitude': latestLatitude,
    'latest_longitude': latestLongitude,
    'latest_location_address': latestLocationAddress,
    'latest_location_at': latestLocationAt,
  };
}

class AttendanceStatus {
  const AttendanceStatus({
    required this.hasPunchedIn,
    required this.hasPunchedOut,
    required this.punchIn,
    required this.punchOut,
    required this.shiftId,
    this.lastSevenDays = const [],
    this.monthDays = const [],
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) =>
      AttendanceStatus(
        hasPunchedIn: _jsonBool(json['has_punched_in']),
        hasPunchedOut: _jsonBool(json['has_punched_out']),
        punchIn: '${json['punch_in'] ?? ''}',
        punchOut: '${json['punch_out'] ?? ''}',
        shiftId: '${json['shift_id'] ?? ''}',
        lastSevenDays:
            (json['last_7_days'] is List
                    ? json['last_7_days'] as List
                    : const [])
                .whereType<Map>()
                .map(
                  (item) =>
                      AttendanceDay.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(),
        monthDays:
            (json['month_days'] is List ? json['month_days'] as List : const [])
                .whereType<Map>()
                .map(
                  (item) =>
                      AttendanceDay.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(),
      );

  final bool hasPunchedIn;
  final bool hasPunchedOut;
  final String punchIn;
  final String punchOut;
  final String shiftId;
  final List<AttendanceDay> lastSevenDays;
  final List<AttendanceDay> monthDays;
}

class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.dayName,
    required this.punchIn,
    required this.punchOut,
    required this.workingHours,
    required this.shiftTime,
    required this.status,
    this.isWeekoff = false,
    this.isHoliday = false,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
    date: '${json['date'] ?? ''}',
    dayName: '${json['day_name'] ?? ''}',
    punchIn: '${json['punch_in'] ?? ''}',
    punchOut: '${json['punch_out'] ?? ''}',
    workingHours: '${json['working_hours'] ?? '--'}',
    shiftTime: '${json['shift_time'] ?? json['shift_id'] ?? ''}',
    status: '${json['status'] ?? ''}',
    isWeekoff: _jsonBool(json['is_weekoff']),
    isHoliday: _jsonBool(json['is_holiday']),
  );

  final String date;
  final String dayName;
  final String punchIn;
  final String punchOut;
  final String workingHours;
  final String shiftTime;
  final String status;
  final bool isWeekoff;
  final bool isHoliday;
}

class WorkShift {
  const WorkShift({
    required this.id,
    required this.name,
    required this.time,
    required this.hours,
  });

  factory WorkShift.fromJson(Map<String, dynamic> json) => WorkShift(
    id: '${json['shift_id'] ?? ''}',
    name: '${json['name'] ?? 'Shift'}',
    time: '${json['time'] ?? ''}',
    hours: '${json['hours'] ?? ''}',
  );

  final String id;
  final String name;
  final String time;
  final String hours;
}

class PunchResult {
  const PunchResult({required this.attendance, this.trackingToken = ''});

  final AttendanceStatus attendance;
  final String trackingToken;
}

class GroupMember {
  const GroupMember({
    required this.empId,
    required this.name,
    required this.designation,
    required this.jid,
    required this.role,
    this.isOnline = false,
    this.lastSeen,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      empId: '${json['emp_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      designation: '${json['designation'] ?? ''}',
      jid: '${json['jid'] ?? ''}',
      role: '${json['role'] ?? 'member'}',
      isOnline: _jsonBool(json['online']),
      lastSeen: _parseStaticDateTime(json['last_seen']),
    );
  }

  final String empId;
  final String name;
  final String designation;
  final String jid;
  final String role;
  final bool isOnline;
  final DateTime? lastSeen;
}

DateTime? _parseStaticDateTime(dynamic value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == '0') return null;
  final seconds = int.tryParse(text);
  if (seconds != null) {
    return DateTime.fromMillisecondsSinceEpoch(
      text.length > 10 ? seconds : seconds * 1000,
      isUtc: true,
    ).toLocal();
  }
  return DateTime.tryParse(text)?.toLocal();
}

class GroupMembersResult {
  const GroupMembersResult({required this.currentRole, required this.members});

  final String currentRole;
  final List<GroupMember> members;
}

final sharedChatApi = ChatApi();

class ChatApi {
  ChatApi({http.Client? client})
    : _client = client ?? http.Client(),
      _xmpp = const XmppBridge();

  static final Uri _baseUri = Uri.parse(
    'https://dns.watchtower247.in/router_login/',
  );

  final http.Client _client;
  final XmppBridge _xmpp;
  String? _sessionCookie;
  String? _directorySession;
  CurrentUser? _xmppUser;
  bool _notificationXmppConnected = false;
  String? _webEmployeeId;
  String? _webPassword;
  String? _loginEmployeeId;
  String? _loginPassword;
  final Map<String, List<ApiMessage>> _historyCache = {};
  final Map<String, String> _reverseGeocodeCache = {};
  final Map<String, ({DateTime at, List<ChatContact> users})> _userSearchCache =
      {};
  final Map<String, ({DateTime at, List<Map<String, dynamic>> users})>
  _myHubDirectoryCache = {};
  ({DateTime at, Map<String, dynamic> data})? _myHubTasksCache;
  final ValueNotifier<String> connectionStatus = ValueNotifier('reconnecting');
  final List<Map<String, dynamic>> _diagnosticQueue = [];
  Timer? _diagnosticFlushTimer;
  // Hosted web builds must not depend on browser BOSH/CORS or the local
  // 127.0.0.1 development helper. Keep direct XMPP available in the bridge
  // code for local experiments, but route production web through the same
  // PHP API as Android/Windows/Linux.
  bool get _useDirectWebXmpp => false;

  static const diagnosticEmployeeIds = {'116', '302'};

  bool get diagnosticsAllowed => diagnosticEmployeeIds.contains(
    (_loginEmployeeId ?? _xmppUser?.empId)?.trim(),
  );

  String get currentJid =>
      _loginEmployeeId == null ? '' : employeeJid(_loginEmployeeId!);
  String get sessionCookie => _sessionCookie ?? '';
  String? _sourceName;

  Future<String> _deviceSourceName() async {
    if (_sourceName != null) return _sourceName!;
    try {
      final device = await DeviceService.instance.info;
      final package = await PackageInfo.fromPlatform();
      return _sourceName = '${device.name} - v${package.version}';
    } catch (_) {
      return _sourceName = kIsWeb ? 'web browser' : 'Unknown device';
    }
  }

  String employeeJid(String employeeId) {
    final localPart = employeeId
        .trim()
        .split('@')
        .first
        .replaceFirst(RegExp(r'^sky-', caseSensitive: false), '');
    return '$localPart@$xmppDomain';
  }

  String launchpadUsername(String employeeId) {
    final localPart = employeeId
        .trim()
        .split('@')
        .first
        .replaceFirst(RegExp(r'^sky-', caseSensitive: false), '');
    return 'sky-$localPart';
  }

  Future<void> _connectNotificationXmpp(String jid, String password) async {
    if (!kIsWeb || !_xmpp.isSupported || password.isEmpty) return;
    try {
      await _xmpp.connect(jid, password).timeout(const Duration(seconds: 25));
      _notificationXmppConnected = true;
    } catch (_) {
      _notificationXmppConnected = false;
    }
  }

  Future<CurrentUser> login({
    required String employeeId,
    required String password,
  }) async {
    final employeeNumber = employeeId
        .trim()
        .split('@')
        .first
        .replaceFirst(RegExp(r'^sky-', caseSensitive: false), '');
    _loginEmployeeId = employeeNumber;
    _loginPassword = password;
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(employeeNumber)) {
      throw const ApiException('Enter a valid employee ID.');
    }

    if (_useDirectWebXmpp) {
      final jid = employeeJid(employeeNumber);
      try {
        final result = await _xmpp
            .connect(jid, password)
            .timeout(const Duration(seconds: 25));
        _xmppUser = CurrentUser(
          empId: '${result['emp_id'] ?? employeeNumber}',
          name: 'Employee $employeeNumber',
          designation: '',
          jid: '${result['jid'] ?? jid}',
        );
        _webEmployeeId = employeeNumber;
        _webPassword = password;
        await _loginWebDirectory(employeeNumber, password);
        connectionStatus.value = 'connected';
        return _xmppUser!;
      } on ApiException {
        _clearWebSession();
        rethrow;
      } catch (error) {
        _clearWebSession();
        throw ApiException(_xmppError(error));
      }
    }

    final traceId = _newTraceId('auth');
    final stopwatch = Stopwatch()..start();
    final response = await _client
        .post(
          _uri('chat/login.php'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Skylink-Trace-Id': traceId,
          },
          body: jsonEncode({'username': employeeNumber, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));

    _captureCookie(response);
    final body = _decode(response);
    final successful =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (body['ok'] == true || body['status'] == true);
    if (!successful) {
      _sessionCookie = null;
      throw ApiException(
        _errorMessage(body, fallback: 'Login failed. Check your credentials.'),
        statusCode: response.statusCode,
      );
    }
    final webSessionId = '${body['session_id'] ?? ''}'.trim();
    if (kIsWeb && webSessionId.isNotEmpty) {
      _sessionCookie = webSessionId;
    }

    final userPayload = body['user'];
    final user = userPayload is Map
        ? CurrentUser.fromJson(Map<String, dynamic>.from(userPayload))
        : await getCurrentUser();
    final expectedJid = employeeJid(employeeNumber);
    if (user.jid.toLowerCase() != expectedJid.toLowerCase()) {
      _sessionCookie = null;
      throw const ApiException(
        'The authenticated employee does not match this login.',
      );
    }
    if (kIsWeb) {
      unawaited(_connectNotificationXmpp(expectedJid, password));
    }
    unawaited(registerCurrentSession().catchError((_) {}));
    connectionStatus.value = 'connected';
    unawaited(
      _recordDiagnostic(
        traceId: traceId,
        category: 'android',
        operation: 'authentication_end_to_end',
        durationMs: stopwatch.elapsedMicroseconds / 1000,
        eventStatus: 'success',
        metadata: {'http_status': response.statusCode},
      ),
    );
    return user;
  }

  Future<CurrentUser> restoreSession(SavedLogin saved) async {
    if (saved.sessionCookie.isEmpty) {
      throw const ApiException('Saved server session is unavailable.');
    }
    _sessionCookie = saved.sessionCookie;
    _loginEmployeeId = saved.employeeId;
    _loginPassword = saved.password;
    try {
      final user = await getCurrentUser().timeout(const Duration(seconds: 8));
      if (kIsWeb) {
        unawaited(_connectNotificationXmpp(user.jid, saved.password));
      }
      connectionStatus.value = 'connected';
      return user;
    } catch (_) {
      _sessionCookie = null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDiagnostics({
    int hours = 24,
    int limit = 200,
  }) async {
    if (!diagnosticsAllowed) {
      throw const ApiException('Diagnostics access denied.', statusCode: 403);
    }
    return _getJson(
      'chat/diagnostics.php',
      query: {'hours': '$hours', 'limit': '$limit'},
      recordDiagnostic: false,
    );
  }

  Future<CurrentUser> getCurrentUser() async {
    if (kIsWeb && _xmppUser != null) return _xmppUser!;
    final body = await _getJson('chat/current_user.php');
    return CurrentUser.fromJson(body);
  }

  Future<Map<String, dynamic>> getUserProfile(String employeeId) async {
    final body = await _getJson(
      'chat/user_profile.php',
      query: {'emp_id': employeeId},
    );
    final user = body['user'];
    return user is Map ? Map<String, dynamic>.from(user) : body;
  }

  Future<AppVersionStatus> getVersionStatus() async {
    final body = await _getJson('chat/version.php');
    final package = await PackageInfo.fromPlatform();
    final platformKey = !kIsWeb && Platform.isWindows
        ? 'windows'
        : !kIsWeb && Platform.isLinux
        ? 'linux'
        : 'android';
    final config = body[platformKey] is Map
        ? Map<String, dynamic>.from(body[platformKey] as Map)
        : <String, dynamic>{};
    final latest = '${config['latest'] ?? package.version}';
    final minimum = '${config['minimum'] ?? package.version}';
    return AppVersionStatus(
      latest: latest,
      minimum: minimum,
      url: '${config['url'] ?? ''}',
      updateAvailable: _compareVersions(package.version, latest) < 0,
      updateRequired: _compareVersions(package.version, minimum) < 0,
      forceUpdate: _jsonBool(config['force_update']),
      releaseStatus: '${config['release_status'] ?? ''}',
    );
  }

  int _compareVersions(String first, String second) {
    final a = first.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final b = second.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = a.length > b.length ? a.length : b.length;
    for (var index = 0; index < length; index++) {
      final left = index < a.length ? a[index] : 0;
      final right = index < b.length ? b[index] : 0;
      if (left != right) return left.compareTo(right);
    }
    return 0;
  }

  Future<void> registerPushToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty || kIsWeb) return;
    await _postJson('chat/register_push_token.php', {
      'token': trimmed,
      'platform': defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
    });
  }

  Future<ChatContact> getNotificationContact() async {
    return const ChatContact(
      empId: 'notification',
      name: 'System Notifications',
      designation: 'Receive-only system messages',
      jid: systemNotificationJid,
      type: 'notification',
      lastMessage: 'OTP and system alerts',
      isPinned: true,
    );
  }

  Future<List<ChatContact>> getRecentChats() async {
    final fallbackNotification = await getNotificationContact();
    if (_useDirectWebXmpp) {
      final directory = await _webDirectoryUsers();
      try {
        final recent = (await _xmpp.getRoster())
            .map(ChatContact.fromJson)
            .where((chat) => chat.hasValidJid && chat.empId != _xmppUser?.empId)
            .toList();
        final system = recent
            .where((chat) => chat.jid.toLowerCase() == systemNotificationJid)
            .firstOrNull;
        final recentIds = recent.map((chat) => chat.empId).toSet();
        connectionStatus.value = 'connected';
        return [
          system ?? fallbackNotification,
          ...recent.where(
            (chat) => chat.jid.toLowerCase() != systemNotificationJid,
          ),
          ...directory.where((user) => !recentIds.contains(user.empId)),
        ];
      } catch (_) {
        connectionStatus.value = 'disconnected';
        return [fallbackNotification, ...directory];
      }
    }
    final body = await _getJson('chat/recent_chats.php');
    final chats = body['chats'];
    if (chats is! List) return [fallbackNotification];
    final parsed = chats
        .whereType<Map>()
        .map((item) => ChatContact.fromJson(Map<String, dynamic>.from(item)))
        .where((chat) => chat.hasValidJid)
        .toList();
    final system = parsed
        .where((chat) => chat.jid.toLowerCase() == systemNotificationJid)
        .firstOrNull;
    return [
      system ?? fallbackNotification,
      ...parsed.where(
        (chat) => chat.jid.toLowerCase() != systemNotificationJid,
      ),
    ];
  }

  Future<List<ChatContact>> searchUsers([String search = '']) async {
    final normalized = search.trim();
    final cacheKey = normalized.toLowerCase();
    final cached = _userSearchCache[cacheKey];
    final cacheTtl = normalized.isEmpty
        ? const Duration(seconds: 30)
        : const Duration(seconds: 45);
    if (cached != null && DateTime.now().difference(cached.at) < cacheTtl) {
      return cached.users;
    }
    if (_useDirectWebXmpp) {
      final users = await _webDirectoryUsers(normalized);
      _userSearchCache[cacheKey] = (at: DateTime.now(), users: users);
      return users;
    }
    final body = await _getJson(
      'chat/search_users.php',
      query: {'search': normalized},
    );
    final rawUsers = body['users'];
    if (rawUsers is! List) return const [];
    final users = rawUsers
        .whereType<Map>()
        .map((item) => ChatContact.fromJson(Map<String, dynamic>.from(item)))
        .where((user) => user.hasValidJid)
        .toList();
    _userSearchCache[cacheKey] = (at: DateTime.now(), users: users);
    return users;
  }

  Future<ChatContact> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || memberIds.isEmpty) {
      throw const ApiException('Enter a group name and select members.');
    }
    final payload = {'group_name': trimmedName, 'members': memberIds};
    final Map<String, dynamic> body;
    if (_useDirectWebXmpp) {
      if (!await _ensureWebHelperSession()) {
        throw const ApiException(
          'Group service is unavailable. Restart with run_web.ps1.',
        );
      }
      body = await _webHelperPost('/group/create', payload);
    } else {
      body = await _postJson('chat/create_group.php', payload);
    }
    return ChatContact(
      empId: '${body['group_id'] ?? ''}',
      name: '${body['room_name'] ?? trimmedName}',
      designation: '${memberIds.length + 1} members',
      jid: '${body['room_jid'] ?? ''}',
      type: 'group',
      lastMessage: 'Group created',
      time: DateTime.now().toIso8601String(),
    );
  }

  Future<ChatContact> createChannel({
    required String name,
    required List<String> memberEmployeeIds,
    String channelType = 'operational',
    String priority = 'Normal',
    String status = 'Open',
    String targetDate = '',
    String nextActionDate = '',
    int slaMinutes = 0,
    int staleAlertMinutes = 0,
  }) async {
    final trimmedName = name.trim().replaceFirst(RegExp(r'^#'), '');
    if (trimmedName.isEmpty || memberEmployeeIds.isEmpty) {
      throw const ApiException('Enter a channel name and select members.');
    }
    final body = await _postJson('chat/create_channel.php', {
      'channel_name': trimmedName,
      'members': memberEmployeeIds,
      'channel_type': channelType,
      'priority': priority,
      'status': status,
      if (targetDate.isNotEmpty) 'target_date': targetDate,
      if (nextActionDate.isNotEmpty) 'next_action_date': nextActionDate,
      if (slaMinutes > 0) 'sla_minutes': slaMinutes,
      if (staleAlertMinutes > 0) 'stale_alert_minutes': staleAlertMinutes,
    });
    return ChatContact(
      empId: '${body['group_id'] ?? ''}',
      name: '${body['room_name'] ?? '#$trimmedName'}',
      designation: '${body['channel_kind'] ?? channelType} channel',
      jid: '${body['room_jid'] ?? ''}',
      type: 'channel',
    );
  }

  Future<ReleaseGovernance> getReleases() async {
    final body = await _getJson('chat/releases.php');
    final builds = body['builds'] is List
        ? (body['builds'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    ReleaseBuild.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ReleaseBuild>[];
    final history = body['history'] is List
        ? (body['history'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    return ReleaseGovernance(
      canApproveProduction: _jsonBool(body['can_approve_production']),
      builds: builds,
      history: history,
    );
  }

  String _currentPlatformKey() {
    if (!kIsWeb && Platform.isWindows) return 'windows';
    if (!kIsWeb && Platform.isLinux) return 'linux';
    return 'android';
  }

  Future<ReleaseNote?> getReleaseNotes({String? version}) async {
    final package = await PackageInfo.fromPlatform();
    final body = await _getJson(
      'chat/release_notes.php',
      query: {
        'platform': _currentPlatformKey(),
        'version': version ?? package.version,
      },
    );
    final note = body['note'];
    if (note is! Map) return null;
    return ReleaseNote.fromJson(Map<String, dynamic>.from(note));
  }

  Future<void> markReleaseNoteViewed(int releaseNoteId) async {
    if (releaseNoteId <= 0) return;
    await _postJson('chat/release_notes.php', {
      'action': 'mark_viewed',
      'release_note_id': releaseNoteId,
    });
  }

  Future<void> registerReleaseBuild({
    required String platform,
    required String version,
    required int buildNumber,
    required String url,
    required String notes,
  }) async {
    await _postJson('chat/releases.php', {
      'action': 'register',
      'platform': platform,
      'version': version,
      'build_number': buildNumber,
      'url': url,
      'notes': notes,
    });
  }

  Future<void> releaseAction({
    required int releaseId,
    required String action,
    String notes = '',
    int rolloutPercent = 10,
    bool forceUpdate = false,
  }) async {
    await _postJson('chat/releases.php', {
      'release_id': releaseId,
      'action': action,
      'notes': notes,
      'rollout_percent': rolloutPercent,
      'force_update': forceUpdate,
    });
  }

  Future<List<Map<String, dynamic>>> getChannelDefinitions() async {
    final body = await _getJson('chat/channel_definitions.php');
    final values = body['definitions'];
    return values is List
        ? values.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getChannelRelationships(int groupId) async {
    final body = await _getJson(
      'chat/channel_relationship.php',
      query: {'group_id': '$groupId'},
    );
    final values = body['relationships'];
    return values is List
        ? values.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : const <Map<String, dynamic>>[];
  }

  Future<void> linkChannels({
    required int sourceGroupId,
    required int targetGroupId,
    String relationshipType = 'related',
    Map<String, dynamic> metadata = const {},
  }) async {
    await _postJson('chat/channel_relationship.php', {
      'source_group_id': sourceGroupId,
      'target_group_id': targetGroupId,
      'relationship_type': relationshipType,
      'metadata': metadata,
    });
  }
  Future<ChannelProfile> getChannelProfile({
    int groupId = 0,
    String jid = '',
  }) async {
    final body = await _getJson(
      'chat/channel_profile.php',
      query: {
        if (groupId > 0) 'group_id': '$groupId',
        if (jid.isNotEmpty) 'jid': jid,
      },
    );
    final channel = body['channel'];
    return ChannelProfile(
      data: channel is Map ? Map<String, dynamic>.from(channel) : body,
    );
  }

  Future<Map<String, dynamic>> getWakeupConfig({
    int groupId = 0,
    String jid = '',
  }) async {
    final body = await _getJson(
      'chat/wakeup_config.php',
      query: {
        if (groupId > 0) 'group_id': '$groupId',
        if (jid.isNotEmpty) 'jid': jid,
      },
    );
    final config = body['config'];
    return config is Map ? Map<String, dynamic>.from(config) : body;
  }

  Future<Map<String, dynamic>> updateWakeupConfig({
    required int groupId,
    required bool enabled,
    required int intervalMinutes,
  }) async {
    final body = await _postJson('chat/wakeup_config.php', {
      'group_id': groupId,
      'enabled': enabled,
      'interval_minutes': intervalMinutes,
    });
    final config = body['config'];
    return config is Map ? Map<String, dynamic>.from(config) : body;
  }

  Future<Map<String, dynamic>> getTicketDashboard() async {
    return _getJson('chat/ticket_dashboard.php');
  }

  Future<void> closeChannel(int channelId) async {
    await _postJson('chat/close_channel.php', {'channel_id': channelId});
  }

  Future<List<ChatContact>> getArchivedChannels() async {
    final body = await _getJson('chat/archived_channels.php');
    final values = body['channels'];
    return values is List
        ? values
              .whereType<Map>()
              .map(
                (item) => ChatContact.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ChatContact>[];
  }

  Future<List<ApiMessage>> getHistory(
    String jid, {
    bool markRead = true,
    double? readLatitude,
    double? readLongitude,
  }) async {
    _validateJid(jid);
    if (jid.toLowerCase() == systemNotificationJid &&
        kIsWeb &&
        _notificationXmppConnected) {
      try {
        final result = (await _xmpp.getHistory(
          systemNotificationJid,
        )).map(ApiMessage.fromJson).toList();
        _historyCache[jid.toLowerCase()] = result;
        return result;
      } catch (_) {
        // Fall back to the server history cache after XMPP/MAM failure.
      }
    }
    if (_useDirectWebXmpp) {
      try {
        final result = (await _xmpp.getHistory(
          jid,
        )).map(ApiMessage.fromJson).toList();
        connectionStatus.value = 'connected';
        _historyCache[jid.toLowerCase()] = result;
        await AppCache.instance.writeJson(
          'history:${jid.toLowerCase()}',
          result.map((message) => message.toJson()).toList(),
        );
        return result;
      } catch (error) {
        connectionStatus.value = 'disconnected';
        throw ApiException(_xmppError(error));
      }
    }
    final body = await _getJson(
      'chat/history.php',
      query: {
        'jid': jid,
        if (!markRead) 'peek': '1',
        if (markRead && readLatitude != null) 'read_latitude': '$readLatitude',
        if (markRead && readLongitude != null)
          'read_longitude': '$readLongitude',
        if (markRead && readLatitude != null && readLongitude != null)
          'read_source_device': (await DeviceService.instance.info).source,
        if (markRead && readLatitude != null && readLongitude != null)
          'read_source_name': await _deviceSourceName(),
      },
    );
    final messages = body['messages'];
    if (messages is! List) return const [];
    final result = messages
        .whereType<Map>()
        .map((item) => ApiMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    _historyCache[jid.toLowerCase()] = result;
    await AppCache.instance.writeJson(
      'history:${jid.toLowerCase()}',
      result.map((message) => message.toJson()).toList(),
    );
    return result;
  }

  List<ApiMessage>? cachedHistory(String jid) =>
      _historyCache[jid.toLowerCase()];

  Future<List<ApiMessage>> persistedHistory(String jid) async {
    final cached = await AppCache.instance.readJson(
      'history:${jid.toLowerCase()}',
    );
    if (cached is! List) return const [];
    final result = cached
        .whereType<Map>()
        .map((item) => ApiMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (result.isNotEmpty) _historyCache[jid.toLowerCase()] = result;
    return result;
  }

  Future<void> prefetchHistories(Iterable<String> jids) async {
    if (kIsWeb) return;
    final pending = jids
        .where((jid) => !_historyCache.containsKey(jid.toLowerCase()))
        .take(12)
        .map(
          (jid) => getHistory(
            jid,
            markRead: false,
          ).catchError((_) => <ApiMessage>[]),
        );
    await Future.wait(pending);
  }

  Future<int> scheduleMessage({
    required String message,
    required String scheduledAt,
    required List<String> targets,
    bool silent = false,
  }) async {
    if (message.trim().isEmpty) {
      throw const ApiException('Message cannot be empty.');
    }
    if (targets.isEmpty) {
      throw const ApiException('Select at least one recipient.');
    }
    for (final target in targets) {
      _validateJid(target);
    }
    final body = await _postJson('chat/schedule_messages.php', {
      'message': message.trim(),
      'scheduled_at': scheduledAt,
      'targets': targets,
      if (silent) 'silent': true,
    });
    return _jsonInt(body['schedule_id']);
  }

  Future<int> sendMessage({
    required String to,
    required String message,
    String replyToId = '',
    List<String> mentions = const [],
    String threadRootId = '',
    bool silent = false,
    double? latitude,
    double? longitude,
    String locationAddress = '',
    String clientMessageId = '',
    int forwardedFromMessageId = 0,
    String originalSenderJid = '',
    String originalSenderName = '',
    String originalSourceName = '',
  }) async {
    _validateJid(to);
    if (to.toLowerCase() == systemNotificationJid) {
      throw const ApiException(
        'Replies are disabled for System Notifications.',
        statusCode: 403,
      );
    }
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw const ApiException('Message cannot be empty.');
    }

    if (_useDirectWebXmpp) {
      try {
        await _xmpp.sendMessage(to, trimmedMessage);
        connectionStatus.value = 'connected';
        return 0;
      } catch (error) {
        connectionStatus.value = 'disconnected';
        throw ApiException(_xmppError(error));
      }
    }

    AppDeviceInfo device;
    try {
      device = await DeviceService.instance.info;
    } catch (_) {
      device = const AppDeviceInfo(
        id: 'web-session',
        name: 'web browser',
        platform: 'web',
        source: 'web',
      );
    }
    String sourceName;
    try {
      sourceName = await _deviceSourceName();
    } catch (_) {
      sourceName = device.name;
    }
    final response = await _client
        .post(
          _uri('chat/send_message.php'),
          headers: _headers(json: true),
          body: jsonEncode({
            'to': to,
            'message': trimmedMessage,
            if (replyToId.isNotEmpty) 'reply_to_id': replyToId,
            if (mentions.isNotEmpty) 'mentions': mentions,
            if (threadRootId.isNotEmpty) 'thread_root_id': threadRootId,
            if (silent) 'silent': true,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (locationAddress.trim().isNotEmpty)
              'location_address': locationAddress.trim(),
            if (clientMessageId.isNotEmpty)
              'client_message_id': clientMessageId,
            if (forwardedFromMessageId > 0)
              'forwarded_from_message_id': forwardedFromMessageId,
            if (originalSenderJid.isNotEmpty)
              'original_sender_jid': originalSenderJid,
            if (originalSenderName.isNotEmpty)
              'original_sender_name': originalSenderName,
            if (originalSourceName.isNotEmpty)
              'original_source_name': originalSourceName,
            'source_device': device.platform,
            'source_name': sourceName,
          }),
        )
        .timeout(const Duration(seconds: 90));
    _captureCookie(response);
    final Map<String, dynamic> body;
    try {
      body = _decode(response);
    } catch (error) {
      final preview = response.body.trim().replaceAll(RegExp(r'\\s+'), ' ');
      throw ApiException(
        preview.isEmpty
            ? 'Chat server returned an unreadable response.'
            : 'Chat server returned: ${preview.length > 180 ? preview.substring(0, 180) : preview}',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['status'] != true) {
      throw ApiException(
        _errorMessage(body, fallback: 'Could not send the message.'),
        statusCode: response.statusCode,
      );
    }
    return _jsonInt(body['message_id']);
  }

  Future<int> sendLocationMessage({
    required String to,
    required double latitude,
    required double longitude,
    required String locationAddress,
    bool isLiveLocation = false,
    int liveMinutes = 0,
    String shareId = '',
    String replyToId = '',
    List<String> mentions = const [],
    String threadRootId = '',
    String clientMessageId = '',
  }) async {
    final attachment = ChatAttachment.location(
      latitude: latitude,
      longitude: longitude,
      locationAddress: locationAddress,
      isLiveLocation: isLiveLocation,
      liveMinutes: liveMinutes,
      shareId: shareId,
    );
    return sendMessage(
      to: to,
      message: attachment.encode(),
      replyToId: replyToId,
      mentions: mentions,
      threadRootId: threadRootId,
      latitude: latitude,
      longitude: longitude,
      locationAddress: locationAddress,
      clientMessageId: clientMessageId,
    );
  }

  Future<void> unsendMessage(int messageId) async {
    if (messageId <= 0) throw const ApiException('Message is not synced yet.');
    if (_useDirectWebXmpp) {
      await _webHelperPost('/message/delete', {'message_id': messageId});
    } else {
      await _postJson('chat/delete_message.php', {'message_id': messageId});
    }
  }

  Future<Map<String, dynamic>> toggleChecklistItem(
    int messageId,
    int itemIndex,
  ) async {
    if (messageId <= 0) {
      throw const ApiException('Checklist is not synced yet.');
    }
    final body = await _postJson('chat/checklist_toggle.php', {
      'message_id': messageId,
      'item_index': itemIndex,
    });
    return body;
  }

  Future<void> editMessage(int messageId, String message) async {
    final text = message.trim();
    if (messageId <= 0) throw const ApiException('Message is not synced yet.');
    if (text.isEmpty) throw const ApiException('Message cannot be empty.');
    if (_useDirectWebXmpp) {
      await _webHelperPost('/message/edit', {
        'message_id': messageId,
        'message': text,
      });
      return;
    }
    await _postJson('chat/edit_message.php', {
      'message_id': messageId,
      'message': text,
    });
  }

  Future<void> setMuted(String jid, bool muted) async {
    _validateJid(jid);
    await _postJson('chat/mute.php', {'jid': jid, 'muted': muted});
  }

  Future<void> setConversationPreference({
    required String jid,
    required bool pinned,
    required bool starred,
  }) async {
    await _postJson('chat/conversation_preference.php', {
      'jid': jid,
      'pinned': pinned,
      'starred': starred,
    });
  }

  Future<Map<String, dynamic>> getConversationState(String jid) async {
    return _getJson('chat/conversation_state.php', query: {'jid': jid});
  }

  Future<void> saveDraft({
    required String jid,
    required String body,
    int replyToId = 0,
  }) async {
    await _postJson('chat/conversation_state.php', {
      'action': 'draft',
      'jid': jid,
      'body': body,
      if (replyToId > 0) 'reply_to_id': replyToId,
    });
  }

  Future<void> saveReadPosition({
    required String jid,
    required int messageId,
  }) async {
    if (messageId <= 0) return;
    await _postJson('chat/conversation_state.php', {
      'action': 'read_position',
      'jid': jid,
      'message_id': messageId,
    });
  }

  Future<void> reactToMessage(int messageId, String reaction) async {
    await _postJson('chat/message_action.php', {
      'message_id': messageId,
      'action': 'reaction',
      'reaction': reaction,
    });
  }

  Future<void> starMessage(int messageId, bool starred) async {
    await _postJson('chat/message_action.php', {
      'message_id': messageId,
      'action': 'star',
      'starred': starred,
    });
  }

  Future<void> pinMessage(int messageId, bool pinned) async {
    await _postJson('chat/message_action.php', {
      'message_id': messageId,
      'action': 'pin',
      'pinned': pinned,
    });
  }

  Future<List<Map<String, dynamic>>> getDiscovery({
    required String view,
    String jid = '',
    String query = '',
  }) async {
    final body = await _getJson(
      'chat/discovery.php',
      query: {
        'view': view,
        if (jid.isNotEmpty) 'jid': jid,
        if (query.isNotEmpty) 'q': query,
        if (view == 'media') 'limit': '200',
      },
    );
    final values = body['results'] ?? body['messages'];
    if (values is! List) return <Map<String, dynamic>>[];
    return values.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final encodedBody = '${item['body'] ?? ''}';
      final attachment = ChatAttachment.tryParse(encodedBody);
      if (attachment != null) {
        if ('${item['file_url'] ?? ''}'.isEmpty) {
          item['file_url'] = attachment.url;
        }
        if ('${item['file_name'] ?? ''}'.isEmpty) {
          item['file_name'] = attachment.name;
        }
        if ('${item['file_type'] ?? ''}'.isEmpty) {
          item['file_type'] = attachment.mimeType;
        }
        if (_jsonInt(item['file_size']) <= 0) {
          item['file_size'] = attachment.size;
        }
        if ('${item['caption'] ?? ''}'.isEmpty) {
          item['caption'] = attachment.caption;
        }
      }
      return item;
    }).toList();
  }

  Future<Map<String, dynamic>> globalSearch(String query) async {
    return _getJson(
      'chat/discovery.php',
      query: {'view': 'search', 'q': query, 'limit': '30'},
    );
  }

  Future<Map<String, dynamic>> getMyLocationVisibility() async {
    return _getJson('chat/location_visibility.php', query: {'mine': '1'});
  }

  Future<List<Map<String, dynamic>>> getLocationVisibilityUsers() async {
    final body = await _getJson('chat/location_visibility.php');
    final users = body['users'];
    return users is List
        ? users
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> setLocationVisibility({
    required String empId,
    required bool enabled,
  }) async {
    await _postJson('chat/location_visibility.php', {
      'emp_id': empId,
      'enabled': enabled,
    });
  }

  Future<String> reverseGeocode(double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    final cached = _reverseGeocodeCache[key];
    if (cached != null) return cached;
    final body = await _getJson(
      'chat/reverse_geocode.php',
      query: {'lat': '$latitude', 'lon': '$longitude'},
    );
    final address = '${body['address'] ?? 'Location unavailable'}'.trim();
    _reverseGeocodeCache[key] = address.isEmpty
        ? 'Location unavailable'
        : address;
    return _reverseGeocodeCache[key]!;
  }

  Future<Map<String, dynamic>> getMessageInfo(int messageId) async {
    return _getJson(
      'chat/message_action.php',
      query: {'message_id': '$messageId'},
    );
  }

  Future<void> renameGroup(int groupId, String name) async {
    await _postJson('chat/rename_group.php', {
      'group_id': groupId,
      'name': name.trim(),
    });
  }

  Uri _attachmentFetchUri(ChatAttachment attachment, {bool download = false}) {
    final raw = Uri.tryParse(attachment.url);
    if (raw == null) return Uri.parse(attachment.url);
    final path = raw.path;
    final uploadsIndex = path.indexOf('/uploads/');
    if (uploadsIndex >= 0) {
      final relative = path.substring(uploadsIndex + '/uploads/'.length);
      final mediaPath = relative;
      final mediaUri = _baseUri.resolve('chat/media.php').replace(
        queryParameters: {
          'path': mediaPath,
          'name': attachment.name,
          if (download) 'download': '1',
        },
      );
      return mediaUri;
    }
    return download
        ? raw.replace(queryParameters: {
            ...raw.queryParameters,
            'download': '1',
            if (attachment.name.isNotEmpty) 'name': attachment.name,
          })
        : raw;
  }

  Future<Uint8List> readAttachmentBytes(ChatAttachment attachment) async {
    final response = await _client
        .get(_attachmentFetchUri(attachment))
        .timeout(const Duration(minutes: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Download failed (' + response.statusCode.toString() + ').');
    }
    return response.bodyBytes;
  }

  Future<String> downloadAttachment(ChatAttachment attachment) async {
    if (attachment.isLocation) {
      throw const ApiException('Location messages cannot be downloaded.');
    }
    final safeName = attachment.name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();
    final fileName = safeName.isEmpty ? 'attachment' : safeName;
    if (kIsWeb) {
      final ok = await saveWebFile(
        _attachmentFetchUri(attachment, download: true).toString(),
        fileName,
      );
      if (!ok) {
        throw const ApiException('Unable to start the download.');
      }
      return fileName;
    }
    final bytes = await readAttachmentBytes(attachment);
    Directory? directory;
    if (!kIsWeb && Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download/Skylink');
      try {
        if (!await publicDownloads.exists()) {
          await publicDownloads.create(recursive: true);
        }
        directory = publicDownloads;
      } catch (_) {
        directory = null;
      }
    }
    directory ??=
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> registerCurrentSession() async {
    if (_useDirectWebXmpp) return;
    final device = await DeviceService.instance.info;
    await _postJson('chat/sessions.php', {
      'device_id': device.id,
      'device_name': device.name,
      'platform': device.platform,
      'app_source': device.source,
    });
  }

  Future<List<AppSession>> getSessions() async {
    final body = await _getJson('chat/sessions.php');
    final sessions = body['sessions'];
    if (sessions is! List) return const [];
    return sessions
        .whereType<Map>()
        .map((item) => AppSession.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<SavedMessage>> getSavedMessages() async {
    final body = await _getJson('chat/saved_messages.php');
    final messages = body['messages'];
    if (messages is! List) return const [];
    final result = messages
        .whereType<Map>()
        .map((item) => SavedMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    await AppCache.instance.writeJson(
      'saved_messages',
      result.map((message) => message.toJson()).toList(),
    );
    return result;
  }

  Future<List<SavedMessage>> cachedSavedMessages() async {
    final cached = await AppCache.instance.readJson('saved_messages');
    if (cached is! List) return const [];
    return cached
        .whereType<Map>()
        .map((item) => SavedMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveMessage(String message) async {
    await _postJson('chat/saved_messages.php', {'message': message.trim()});
  }

  Future<UserProfile> getProfile() async {
    final body = await _getJson('chat/profile.php');
    final profile = body['profile'];
    if (profile is! Map) {
      throw const ApiException('Unable to load profile details.');
    }
    final result = UserProfile.fromJson(Map<String, dynamic>.from(profile));
    await AppCache.instance.writeJson('user_profile', result.toJson());
    return result;
  }

  Future<UserProfile?> cachedProfile() async {
    final cached = await AppCache.instance.readJson('user_profile');
    if (cached is! Map) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(cached));
  }

  Future<AttendanceStatus> getAttendance() async {
    final body = await _getJson('chat/attendance.php');
    final attendance = body['attendance'];
    if (attendance is! Map) {
      throw const ApiException('Unable to load attendance.');
    }
    return AttendanceStatus.fromJson(Map<String, dynamic>.from(attendance));
  }

  Future<List<Map<String, dynamic>>> getMyHubDirectory({
    String search = '',
  }) async {
    final queryText = search.trim();
    final cacheKey = queryText.toLowerCase();
    final cached = _myHubDirectoryCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 5)) {
      return cached.users
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    if (queryText.isEmpty) {
      final persisted = await AppCache.instance.readJson('myhub_directory');
      if (persisted is List) {
        final users = persisted
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (users.isNotEmpty) {
          _myHubDirectoryCache[cacheKey] = (at: DateTime.now(), users: users);
        }
      }
    }
    final body = await _getJson(
      'chat/myhub.php',
      query: {'section': 'directory', if (queryText.isNotEmpty) 'q': queryText},
    );
    final employees = body['employees'];
    final users = employees is List
        ? employees
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    _myHubDirectoryCache[cacheKey] = (at: DateTime.now(), users: users);
    if (queryText.isEmpty && users.isNotEmpty) {
      await AppCache.instance.writeJson('myhub_directory', users);
    }
    return users;
  }

  Future<Map<String, dynamic>> getMyHubTasks({
    bool forceRefresh = false,
  }) async {
    final cached = _myHubTasksCache;
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 2)) {
      return Map<String, dynamic>.from(cached.data);
    }
    if (!forceRefresh) {
      final persisted = await AppCache.instance.readJson('myhub_tasks');
      if (persisted is Map && persisted.isNotEmpty) {
        final data = Map<String, dynamic>.from(persisted);
        _myHubTasksCache = (at: DateTime.now(), data: data);
      }
    }
    final data = await _getJson(
      'chat/myhub.php',
      query: {'section': 'tasks', 'limit': '30'},
    );
    _myHubTasksCache = (at: DateTime.now(), data: data);
    await AppCache.instance.writeJson('myhub_tasks', data);
    return data;
  }

  Future<void> invalidateMyHubTasksCache() async {
    _myHubTasksCache = null;
    await AppCache.instance.remove('myhub_tasks');
  }

  Future<void> createMyHubTask({
    required String title,
    required List<int> assignees,
    String description = '',
    String priority = 'm',
    String deadline = '',
    List<int> followers = const [],
    int groupId = 0,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'priority': priority,
      'deadline': deadline,
      'assignees': assignees,
      'followers': followers,
    };
    if (groupId > 0) {
      payload['group_id'] = groupId;
    }
    await _postJson(
      'chat/myhub.php',
      payload,
      query: {'section': 'task_create'},
    );
  }

  Future<void> updateMyHubTask({
    required int taskId,
    required String comments,
  }) async {
    await _postJson('chat/task_update.php', {
      'task_id': taskId,
      'comments': comments.trim(),
    });
  }

  Future<Map<String, dynamic>> getMyHubTaskDetail(int taskId) async {
    final body = await _getJson(
      'chat/myhub.php',
      query: {'section': 'task_detail', 'task_id': '$taskId'},
    );
    return Map<String, dynamic>.from(body);
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final body = await _getJson('chat/reminders.php');
    final items = body['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> createReminder({
    required String kind,
    required String title,
    required String startsAt,
    required String recurrence,
    required List<int> assigneeIds,
    String notes = '',
    int customInterval = 1,
    String customUnit = 'week',
    List<int> weekdays = const [],
    List<int> monthDays = const [],
    String sourceConversationJid = '',
    String sourceConversationName = '',
    int sourceMessageId = 0,
    String sourceMessageText = '',
  }) async {
    await _postJson('chat/reminders.php', {
      'action': 'create',
      'kind': kind,
      'title': title,
      'notes': notes,
      'starts_at': startsAt,
      'recurrence': recurrence,
      'custom_interval': customInterval,
      'custom_unit': customUnit,
      'weekdays': weekdays,
      'month_days': monthDays,
      'assignee_ids': assigneeIds,
      'source_conversation_jid': sourceConversationJid,
      'source_conversation_name': sourceConversationName,
      'source_message_id': sourceMessageId,
      'source_message_text': sourceMessageText,
    });
  }

  Future<void> stopReminder(int id) async {
    await _postJson('chat/reminders.php', {'action': 'stop', 'id': id});
  }

  Future<List<Map<String, dynamic>>> getMyHubLeaves() async {
    final body = await _getJson('chat/myhub.php', query: {'section': 'leave'});
    final leaves = body['leaves'];
    return leaves is List
        ? leaves
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> requestMyHubLeaveOtp({
    required String fromDate,
    required String toDate,
    required int leaveTypeId,
    required String reason,
  }) async {
    final body = await _postJson(
      'chat/myhub.php',
      {
        'from_date': fromDate,
        'to_date': toDate,
        'leave_type_id': leaveTypeId,
        'reason': reason,
      },
      query: {'section': 'leave_apply'},
    );
    return Map<String, dynamic>.from(body);
  }

  Future<Map<String, dynamic>> applyMyHubLeave({
    required String fromDate,
    required String toDate,
    required int leaveTypeId,
    required String reason,
    required String otp,
  }) async {
    final body = await _postJson(
      'chat/myhub.php',
      {
        'from_date': fromDate,
        'to_date': toDate,
        'leave_type_id': leaveTypeId,
        'reason': reason,
        'otp': otp,
      },
      query: {'section': 'leave_apply'},
    );
    return Map<String, dynamic>.from(body);
  }

  Future<List<WorkShift>> getShifts() async {
    final credentials = await _attendanceCredentials();
    final response = await _client
        .post(
          Uri.parse('https://skylinkonline.net/servicev2/get_shift.php'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'key': credentials},
        )
        .timeout(const Duration(seconds: 30));
    final body = _decode(response);
    final server = body['server'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        server is! List ||
        server.isEmpty) {
      throw const ApiException('Unable to load shifts.');
    }
    final first = server.first;
    final data = first is Map ? first['DATA'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => WorkShift.fromJson(Map<String, dynamic>.from(item)))
        .where((shift) => shift.id.isNotEmpty)
        .toList();
  }

  Future<PunchResult> punchIn({
    required String shiftId,
    required double latitude,
    required double longitude,
  }) async {
    final credentials = await _attendanceCredentials();
    final device = await DeviceService.instance.info;
    await _attendancePost('servicev2/new.php', {
      'key': credentials,
      'shift': shiftId,
      'lat': '$latitude',
      'lon': '$longitude',
      'version': 'Skylink Chat 1.0.2',
      'imei': device.id,
    });
    final tracking = await startLocationTracking(shiftId);
    final body = tracking.$1;
    final attendance = body['attendance'];
    if (attendance is! Map) {
      throw const ApiException('Attendance response is unavailable.');
    }
    return PunchResult(
      attendance: AttendanceStatus.fromJson(
        Map<String, dynamic>.from(attendance),
      ),
      trackingToken: '${body['tracking_token'] ?? ''}',
    );
  }

  Future<(Map<String, dynamic>, String)> startLocationTracking(
    String shiftId,
  ) async {
    final body = await _postJson('chat/attendance.php', {
      'action': 'start_tracking',
      'shift_id': shiftId,
    });
    final token = '${body['tracking_token'] ?? ''}'.trim();
    if (token.isEmpty) {
      throw const ApiException('Location tracking token is unavailable.');
    }
    return (body, token);
  }

  Future<PunchResult> punchOut({
    required String shiftId,
    required double latitude,
    required double longitude,
  }) async {
    final credentials = await _attendanceCredentials();
    await _attendancePost('servicev2/punchout.php', {
      'key': credentials,
      'shift_id': shiftId,
      'lat': '$latitude',
      'lon': '$longitude',
    });
    final body = await _postJson('chat/attendance.php', {
      'action': 'stop_tracking',
    });
    final attendance = body['attendance'];
    if (attendance is! Map) {
      throw const ApiException('Attendance response is unavailable.');
    }
    return PunchResult(
      attendance: AttendanceStatus.fromJson(
        Map<String, dynamic>.from(attendance),
      ),
    );
  }

  Future<String> _attendanceCredentials() async {
    var employeeId = _loginEmployeeId ?? '';
    var password = _loginPassword ?? '';
    if (employeeId.isEmpty || password.isEmpty) {
      final saved = await SessionStore.instance.read();
      employeeId = saved?.employeeId ?? '';
      password = saved?.password ?? '';
    }
    if (employeeId.isEmpty || password.isEmpty) {
      throw const ApiException('Sign in again before using attendance.');
    }
    return base64Encode(utf8.encode('$employeeId $password'));
  }

  Future<Map<String, dynamic>> _attendancePost(
    String path,
    Map<String, String> fields,
  ) async {
    final response = await _client
        .post(
          Uri.parse('https://skylinkonline.net/$path'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: fields,
        )
        .timeout(const Duration(seconds: 40));
    final body = _decode(response);
    final server = body['server'];
    Map<String, dynamic>? first;
    if (server is List && server.isNotEmpty && server.first is Map) {
      first = Map<String, dynamic>.from(server.first as Map);
    }
    final successful =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        ('${body['status'] ?? ''}' == '1' ||
            '${first?['RESPONSESTATUS'] ?? ''}' == '1');
    if (!successful) {
      throw ApiException(
        '${first?['MESSAGE'] ?? body['message'] ?? body['error'] ?? 'Attendance request failed.'}',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<String> updateProfilePhoto({
    required String name,
    required List<int> bytes,
  }) async {
    final url = await _uploadAvatar(name, bytes);
    await _postJson('chat/profile.php', {'avatar_url': url});
    return url;
  }

  Future<String> updateGroupPhoto({
    required int groupId,
    required String name,
    required List<int> bytes,
  }) async {
    final url = await _uploadAvatar(name, bytes);
    await _postJson('chat/group_profile.php', {
      'group_id': groupId,
      'avatar_url': url,
    });
    return url;
  }

  Future<String> _uploadAvatar(String name, List<int> bytes) async {
    if (bytes.isEmpty) throw const ApiException('The selected image is empty.');
    var output = Uint8List.fromList(bytes);
    try {
      final decoded = img.decodeImage(output);
      if (decoded == null) throw const ApiException('Unsupported image file.');
      final resized = img.copyResizeCropSquare(decoded, size: 720);
      output = Uint8List.fromList(img.encodeJpg(resized, quality: 84));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Unsupported image file.');
    }
    final request = http.MultipartRequest('POST', _uri('chat/upload_file.php'));
    request.headers.addAll(_headers());
    request.files.add(
      http.MultipartFile.fromBytes('file', output, filename: 'avatar.jpg'),
    );
    final streamed = await _client
        .send(request)
        .timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamed);
    _captureCookie(response);
    final body = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['status'] != true) {
      throw ApiException(
        _errorMessage(body, fallback: 'Unable to upload profile photo.'),
        statusCode: response.statusCode,
      );
    }
    final url = '${body['url'] ?? ''}'.trim();
    if (url.isEmpty) throw const ApiException('Photo URL was not returned.');
    return url;
  }

  Future<GroupMembersResult> getGroupMembers(int groupId) async {
    final body = _useDirectWebXmpp
        ? await _webHelperGet('/group/members', query: {'group_id': '$groupId'})
        : await _getJson(
            'chat/group_members.php',
            query: {'group_id': '$groupId'},
          );
    final raw = body['members'];
    final members = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) => GroupMember.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <GroupMember>[];
    return GroupMembersResult(
      currentRole: '${body['current_role'] ?? ''}',
      members: members,
    );
  }

  Future<void> manageGroupMember({
    required int groupId,
    required String empId,
    required bool add,
  }) async {
    final payload = {
      'group_id': groupId,
      'emp_id': empId,
      'action': add ? 'add' : 'remove',
    };
    if (_useDirectWebXmpp) {
      await _webHelperPost('/group/member', payload);
    } else {
      await _postJson('chat/manage_group.php', payload);
    }
  }

  Future<void> groupMemberAction({
    required int groupId,
    required String empId,
    required String action,
  }) async {
    await _postJson('chat/manage_group.php', {
      'group_id': groupId,
      'emp_id': empId,
      'action': action,
    });
  }

  Future<ChatAttachment> sendAttachment({
    required String to,
    required String name,
    required String mimeType,
    required List<int> bytes,
    String caption = '',
    String replyToId = '',
    List<String> mentions = const [],
    String threadRootId = '',
    double? latitude,
    double? longitude,
    String locationAddress = '',
    String clientMessageId = '',
    int forwardedFromMessageId = 0,
    String originalSenderJid = '',
    String originalSenderName = '',
    String originalSourceName = '',
    void Function(double progress)? onProgress,
  }) async {
    _validateJid(to);
    if (bytes.isEmpty) throw const ApiException('The selected file is empty.');
    if (!_useDirectWebXmpp) {
      return _sendNativeAttachment(
        to: to,
        name: name,
        mimeType: mimeType,
        bytes: bytes,
        caption: caption,
        replyToId: replyToId,
        mentions: mentions,
        threadRootId: threadRootId,
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
        clientMessageId: clientMessageId,
        forwardedFromMessageId: forwardedFromMessageId,
        originalSenderJid: originalSenderJid,
        originalSenderName: originalSenderName,
        originalSourceName: originalSourceName,
        onProgress: onProgress,
      );
    }
    onProgress?.call(0.05);
    try {
      final slot = await _xmpp.requestUploadSlot(
        filename: name,
        size: bytes.length,
        contentType: mimeType,
      );
      onProgress?.call(0.2);
      final response = await _client
          .put(
            Uri.parse(slot.putUrl),
            headers: {...slot.headers, 'Content-Type': mimeType},
            body: bytes,
          )
          .timeout(const Duration(minutes: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'File upload failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      onProgress?.call(0.9);
      final attachment = ChatAttachment(
        name: name,
        url: slot.getUrl,
        mimeType: mimeType,
        size: bytes.length,
        caption: caption.trim(),
      );
      await _xmpp.sendAttachment(
        jid: to,
        body: attachment.encode(),
        url: attachment.url,
      );
      connectionStatus.value = 'connected';
      onProgress?.call(1);
      return ChatAttachment(
        name: attachment.name,
        url: attachment.url,
        mimeType: attachment.mimeType,
        size: attachment.size,
        caption: attachment.caption,
        messageId: 0,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      connectionStatus.value = 'disconnected';
      throw ApiException(_xmppError(error));
    }
  }

  Future<ChatAttachment> _sendNativeAttachment({
    required String to,
    required String name,
    required String mimeType,
    required List<int> bytes,
    required String caption,
    required String replyToId,
    required List<String> mentions,
    required String threadRootId,
    double? latitude,
    double? longitude,
    String locationAddress = '',
    String clientMessageId = '',
    int forwardedFromMessageId = 0,
    String originalSenderJid = '',
    String originalSenderName = '',
    String originalSourceName = '',
    void Function(double progress)? onProgress,
  }) async {
    var uploadBytes = Uint8List.fromList(bytes);
    var uploadName = name;
    var uploadType = mimeType;
    if (mimeType.toLowerCase().startsWith('image/') &&
        !mimeType.toLowerCase().contains('gif')) {
      try {
        final compressed = await compute(_compressChatImage, {
          'bytes': uploadBytes,
          'name': name,
        });
        if (compressed != null) {
          uploadBytes = compressed['bytes'] as Uint8List;
          uploadName = '${compressed['name']}';
          uploadType = 'image/jpeg';
        }
      } catch (_) {
        // Preserve the original file when an image codec cannot decode it.
      }
    }
    onProgress?.call(0.1);
    final uploadTraceId = _newTraceId('upload');
    final uploadStopwatch = Stopwatch()..start();
    final request = http.MultipartRequest('POST', _uri('chat/upload_file.php'));
    request.headers.addAll(_headers(traceId: uploadTraceId));
    request.files.add(
      http.MultipartFile.fromBytes('file', uploadBytes, filename: uploadName),
    );
    final streamed = await _client
        .send(request)
        .timeout(const Duration(minutes: 30));
    final response = await http.Response.fromStream(streamed);
    _captureCookie(response);
    unawaited(
      _recordDiagnostic(
        traceId: uploadTraceId,
        category: 'android',
        operation: 'file_upload_end_to_end',
        durationMs: uploadStopwatch.elapsedMicroseconds / 1000,
        eventStatus: response.statusCode < 400 ? 'success' : 'error',
        metadata: {
          'http_status': response.statusCode,
          'original_bytes': bytes.length,
          'uploaded_bytes': uploadBytes.length,
          'mime': uploadType,
        },
      ),
    );
    final uploaded = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        uploaded['status'] != true) {
      throw ApiException(
        _errorMessage(uploaded, fallback: 'Unable to upload the file.'),
        statusCode: response.statusCode,
      );
    }
    onProgress?.call(0.8);
    final url = '${uploaded['url'] ?? ''}'.trim();
    if (url.isEmpty) throw const ApiException('Upload URL was not returned.');
    AppDeviceInfo device;
    try {
      device = await DeviceService.instance.info;
    } catch (_) {
      device = const AppDeviceInfo(
        id: 'web-session',
        name: 'web browser',
        platform: 'web',
        source: 'web',
      );
    }
    final sourceName = await _deviceSourceName();
    final sent = await _postJson('chat/send_message.php', {
      'to': to,
      'message': caption.trim(),
      'file_url': url,
      'file_name': uploadName,
      'file_type': uploadType,
      'file_size': uploadBytes.length,
      if (replyToId.isNotEmpty) 'reply_to_id': replyToId,
      if (mentions.isNotEmpty) 'mentions': mentions,
      if (threadRootId.isNotEmpty) 'thread_root_id': threadRootId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAddress.trim().isNotEmpty)
        'location_address': locationAddress.trim(),
      if (clientMessageId.isNotEmpty) 'client_message_id': clientMessageId,
      if (forwardedFromMessageId > 0)
        'forwarded_from_message_id': forwardedFromMessageId,
      if (originalSenderJid.isNotEmpty)
        'original_sender_jid': originalSenderJid,
      if (originalSenderName.isNotEmpty)
        'original_sender_name': originalSenderName,
      if (originalSourceName.isNotEmpty)
        'original_source_name': originalSourceName,
      'source_device': device.platform,
      'source_name': sourceName,
    });
    onProgress?.call(1);
    return ChatAttachment(
      name: uploadName,
      url: url,
      mimeType: uploadType,
      size: uploadBytes.length,
      caption: caption.trim(),
      messageId: _jsonInt(sent['message_id']),
    );
  }

  Future<PresenceInfo> getPresence(String jid) async {
    _validateJid(jid);
    final Map<String, dynamic> body;
    if (_useDirectWebXmpp) {
      if (!await _ensureWebHelperSession()) {
        return const PresenceInfo(isOnline: false, lastSeen: null);
      }
      body = await _webHelperGet('/presence', query: {'jid': jid});
    } else {
      body = await _getJson('chat/presence.php', query: {'jid': jid});
    }
    return PresenceInfo(
      isOnline: _jsonBool(body['online'] ?? body['is_online']),
      lastSeen: _parseServerDateTime(
        body['last_seen'] ?? body['lastSeen'] ?? body['timestamp'],
      ),
      mobileActive: _jsonBool(body['mobile_active']),
      launchpadActive: _jsonBool(body['launchpad_active']),
      messengerConnected: _jsonBool(body['messenger_connected']),
      locationAvailable: _jsonBool(body['location_available']),
    );
  }

  DateTime? _parseServerDateTime(dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == '0') return null;
    final seconds = int.tryParse(text);
    if (seconds != null) {
      final milliseconds = text.length > 10 ? seconds : seconds * 1000;
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
    }
    return DateTime.tryParse(text)?.toLocal();
  }

  void logout() {
    _diagnosticFlushTimer?.cancel();
    _diagnosticFlushTimer = null;
    _diagnosticQueue.clear();
    _userSearchCache.clear();
    _sessionCookie = null;
    _directorySession = null;
    _clearWebSession();
    _loginEmployeeId = null;
    _loginPassword = null;
  }

  void close() {
    if (_xmpp.isSupported) _xmpp.disconnect();
    _client.close();
  }

  void _clearWebSession() {
    _directorySession = null;
    _xmppUser = null;
    _notificationXmppConnected = false;
    _webEmployeeId = null;
    _webPassword = null;
    if (_xmpp.isSupported) _xmpp.disconnect();
  }

  Future<void> _loginWebDirectory(
    String employeeId,
    String password, {
    bool suppressErrors = false,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('http://127.0.0.1:8787/session/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'employee_id': employeeId, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
      final body = _decode(response);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['status'] != true) {
        throw ApiException(
          _errorMessage(body, fallback: 'Employee directory login failed.'),
          statusCode: response.statusCode,
        );
      }
      if ('${body['version'] ?? ''}' != requiredProxyVersion) {
        throw const ApiException(
          'Old Skylink helper is running. Close the app and run run_web.ps1.',
        );
      }
      final token = '${body['token'] ?? ''}'.trim();
      if (token.isEmpty) {
        throw const ApiException(
          'Employee directory login did not return a session.',
        );
      }
      _directorySession = token;
    } catch (error) {
      _directorySession = null;
      if (!suppressErrors) rethrow;
    }
  }

  Future<bool> _ensureWebHelperSession() async {
    if (_directorySession != null && _directorySession!.isNotEmpty) {
      return true;
    }
    final employeeId = _webEmployeeId;
    final password = _webPassword;
    if (employeeId == null || password == null) return false;
    await _loginWebDirectory(employeeId, password, suppressErrors: true);
    return _directorySession != null && _directorySession!.isNotEmpty;
  }

  Future<List<ChatContact>> _webDirectoryUsers([String search = '']) async {
    final token = _directorySession;
    if (token == null || token.isEmpty) {
      return _bundledDirectory(search);
    }
    try {
      final response = await _client
          .get(
            Uri.parse(
              'http://127.0.0.1:8787/users',
            ).replace(queryParameters: {'search': search}),
            headers: {'Accept': 'application/json', 'X-Skylink-Session': token},
          )
          .timeout(const Duration(seconds: 15));
      final body = _decode(response);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['status'] != true) {
        throw ApiException(
          _errorMessage(body, fallback: 'Unable to load employees.'),
          statusCode: response.statusCode,
        );
      }
      final users = body['users'];
      if (users is! List) return const [];
      return users
          .whereType<Map>()
          .map((item) => ChatContact.fromJson(Map<String, dynamic>.from(item)))
          .where(
            (user) =>
                user.hasValidJid &&
                RegExp(r'^\d+$').hasMatch(user.empId) &&
                user.empId != _xmppUser?.empId,
          )
          .toList();
    } catch (error) {
      return _bundledDirectory(search);
    }
  }

  List<ChatContact> _bundledDirectory([String search = '']) {
    final query = search.trim().toLowerCase();
    return employeeDirectory
        .where((employee) => employee.empId != _xmppUser?.empId)
        .where(
          (employee) =>
              query.isEmpty ||
              employee.empId.toLowerCase().contains(query) ||
              employee.name.toLowerCase().contains(query) ||
              employee.designation.toLowerCase().contains(query),
        )
        .map(
          (employee) => ChatContact(
            empId: employee.empId,
            name: employee.name,
            designation: employee.designation,
            jid: '${employee.empId}@$xmppDomain',
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> _webHelperGet(
    String path, {
    Map<String, String>? query,
    bool retry = true,
  }) async {
    final token = _directorySession;
    if (token == null || token.isEmpty) {
      throw const ApiException('Employee directory session is unavailable.');
    }
    final response = await _client
        .get(
          Uri.parse(
            'http://127.0.0.1:8787$path',
          ).replace(queryParameters: query),
          headers: {'Accept': 'application/json', 'X-Skylink-Session': token},
        )
        .timeout(const Duration(seconds: 30));
    final body = _decode(response);
    if (response.statusCode == 401 && retry) {
      _directorySession = null;
      if (await _ensureWebHelperSession()) {
        return _webHelperGet(path, query: query, retry: false);
      }
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['status'] != true) {
      throw ApiException(
        _errorMessage(body, fallback: 'Unable to load chat history.'),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> _webHelperPost(
    String path,
    Map<String, dynamic> payload, {
    bool retry = true,
  }) async {
    final token = _directorySession;
    if (token == null || token.isEmpty) {
      throw const ApiException('Employee directory session is unavailable.');
    }
    final response = await _client
        .post(
          Uri.parse('http://127.0.0.1:8787$path'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Skylink-Session': token,
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));
    final body = _decode(response);
    if (response.statusCode == 401 && retry) {
      _directorySession = null;
      if (await _ensureWebHelperSession()) {
        return _webHelperPost(path, payload, retry: false);
      }
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['status'] != true) {
      throw ApiException(
        _errorMessage(body, fallback: 'Unable to update group chat.'),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  String _xmppError(Object error) {
    final text = error.toString();
    final cleaned = text.replaceFirst('Error: ', '').trim();
    return cleaned.isEmpty ? 'Unable to connect to ejabberd.' : cleaned;
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
    bool recordDiagnostic = true,
  }) async {
    final traceId = _newTraceId('get');
    final stopwatch = Stopwatch()..start();
    late http.Response response;
    try {
      response = await _client
          .get(
            _uri(path, query: query),
            headers: _headers(traceId: traceId),
          )
          .timeout(const Duration(seconds: 20));
      connectionStatus.value = 'connected';
    } catch (error) {
      connectionStatus.value = 'disconnected';
      if (recordDiagnostic) {
        unawaited(
          _recordDiagnostic(
            traceId: traceId,
            category: 'android',
            operation: 'GET $path',
            durationMs: stopwatch.elapsedMicroseconds / 1000,
            eventStatus: 'error',
            metadata: {'error': error.runtimeType.toString()},
          ),
        );
      }
      rethrow;
    }
    _captureCookie(response);
    if (recordDiagnostic) {
      unawaited(
        _recordDiagnostic(
          traceId: traceId,
          category: 'android',
          operation: 'GET $path',
          durationMs: stopwatch.elapsedMicroseconds / 1000,
          eventStatus: response.statusCode < 400 ? 'success' : 'error',
          metadata: {
            'http_status': response.statusCode,
            'response_bytes': response.bodyBytes.length,
          },
        ),
      );
    }
    final body = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['status'] != true) {
      throw ApiException(
        _errorMessage(body, fallback: 'Unable to load chat data.'),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    Map<String, String>? query,
  }) async {
    final traceId = _newTraceId('post');
    final stopwatch = Stopwatch()..start();
    late http.Response response;
    try {
      response = await _client
          .post(
            _uri(path, query: query),
            headers: _headers(json: true, traceId: traceId),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      connectionStatus.value = 'connected';
    } catch (error) {
      connectionStatus.value = 'disconnected';
      unawaited(
        _recordDiagnostic(
          traceId: traceId,
          category: 'android',
          operation: 'POST $path',
          durationMs: stopwatch.elapsedMicroseconds / 1000,
          eventStatus: 'error',
          metadata: {'error': error.runtimeType.toString()},
        ),
      );
      rethrow;
    }
    _captureCookie(response);
    unawaited(
      _recordDiagnostic(
        traceId: traceId,
        category: 'android',
        operation: 'POST $path',
        durationMs: stopwatch.elapsedMicroseconds / 1000,
        eventStatus: response.statusCode < 400 ? 'success' : 'error',
        metadata: {
          'http_status': response.statusCode,
          'request_bytes': utf8.encode(jsonEncode(payload)).length,
          'response_bytes': response.bodyBytes.length,
        },
      ),
    );
    final body = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['status'] != true) {
      throw ApiException(
        _errorMessage(body, fallback: 'Unable to update chat data.'),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    return _baseUri.resolve(path).replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = false, String traceId = ''}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (traceId.isNotEmpty) 'X-Skylink-Trace-Id': traceId,
    };
    final sessionCookie = _sessionCookie;
    if (sessionCookie != null) {
      if (kIsWeb) {
        headers['X-Skylink-Web-Session'] = sessionCookie
            .replaceFirst(RegExp(r'^PHPSESSID='), '')
            .split(';')
            .first
            .trim();
      } else {
        headers['Cookie'] = sessionCookie;
      }
    }
    return headers;
  }

  String _newTraceId(String prefix) =>
      '$prefix-${_loginEmployeeId ?? 'guest'}-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _recordDiagnostic({
    required String traceId,
    required String category,
    required String operation,
    required double durationMs,
    required String eventStatus,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!diagnosticsAllowed || _sessionCookie == null) return;
    try {
      String appVersion = '';
      try {
        appVersion = (await PackageInfo.fromPlatform()).version;
      } catch (_) {
        appVersion = '';
      }
      final device = await DeviceService.instance.info.catchError(
        (_) => const AppDeviceInfo(
          id: 'web-session',
          name: 'web browser',
          platform: 'web',
          source: 'web',
        ),
      );
      _diagnosticQueue.add({
        'trace_id': traceId,
        'category': category,
        'operation': operation,
        'duration_ms': durationMs,
        'event_status': eventStatus,
        'metadata': {
          ...metadata,
          'platform': device.platform,
          'device_model': device.name,
          'app_version': appVersion,
        },
      });
      _diagnosticFlushTimer ??= Timer(
        const Duration(seconds: 5),
        _flushDiagnostics,
      );
    } catch (_) {
      // Diagnostics must never interrupt normal chat operations.
    }
  }

  Future<void> _flushDiagnostics() async {
    _diagnosticFlushTimer = null;
    if (_diagnosticQueue.isEmpty || _sessionCookie == null) return;
    final events = List<Map<String, dynamic>>.from(_diagnosticQueue);
    _diagnosticQueue.clear();
    try {
      await _client
          .post(
            _uri('chat/diagnostics.php'),
            headers: _headers(json: true),
            body: jsonEncode({'events': events}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      if (_diagnosticQueue.length < 200) {
        _diagnosticQueue.insertAll(0, events.take(50));
      }
    }
  }

  void _captureCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return;
    final cookies = <String, String>{};
    final matches = RegExp(
      r'(?:^|,\s*)([A-Za-z0-9_]+)=([^;,\s]*)',
    ).allMatches(setCookie);
    for (final match in matches) {
      final name = match.group(1);
      final value = match.group(2);
      if (name != null && value != null && value.isNotEmpty) {
        cookies[name] = value;
      }
    }
    if (cookies.isNotEmpty) {
      _sessionCookie = cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Converted to a friendly API error below.
    }
    throw ApiException(
      'The server returned an invalid response.',
      statusCode: response.statusCode,
    );
  }

  String _errorMessage(Map<String, dynamic> body, {required String fallback}) {
    final message = body['error'] ?? body['message'];
    return message is String && message.trim().isNotEmpty
        ? message.trim()
        : fallback;
  }

  void _validateJid(String jid) {
    final isUser = RegExp(r'^[^@\s]+@chat\.skylinkonline\.net$').hasMatch(jid);
    final isRoom = RegExp(
      r'^[a-z0-9][a-z0-9-]*@conference\.chat\.skylinkonline\.net$',
      caseSensitive: false,
    ).hasMatch(jid);
    if (!isUser && !isRoom) {
      throw const ApiException('Invalid Skylink chat recipient.');
    }
  }
}
