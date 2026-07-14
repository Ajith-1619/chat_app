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

class AttachmentContent extends StatelessWidget {
  const AttachmentContent({required this.attachment});

  final ChatAttachment attachment;

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentPreviewScreen(attachment: attachment),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    try {
      await requestAttachmentStoragePermission(context);
      final path = await chatApi.downloadAttachment(attachment);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded to $path')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPendingUpload = attachment.url.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachment.isLocation)
          _LocationAttachmentPreview(attachment: attachment)
        else if (attachment.isImage)
          InkWell(
            onTap: isPendingUpload ? null : () => _open(context),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.network(
                    attachment.url,
                    width: 260,
                    height: 190,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            width: 260,
                            height: 190,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (_, _, _) => _FileTile(
                      attachment: attachment,
                      onTap: isPendingUpload ? null : () => _open(context),
                      onDownload: isPendingUpload ? null : () => _download(context),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.46),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Download',
                        onPressed: isPendingUpload ? null : () => _download(context),
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _FileTile(
            attachment: attachment,
            onTap: isPendingUpload ? null : () => _open(context),
            onDownload: () => _download(context),
          ),
        if (attachment.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
            child: Text(
              attachment.caption,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.attachment,
    required this.onTap,
    this.onDownload,
  });

  final ChatAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Icon(Icons.insert_drive_file_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatFileSize(attachment.size),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDownload,
              icon: const Icon(
                Icons.download_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AttachmentPreviewKind {
  image,
  audio,
  location,
  pdf,
  text,
  office,
  binary,
}

class AttachmentPreviewScreen extends StatefulWidget {
  const AttachmentPreviewScreen({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  State<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState extends State<AttachmentPreviewScreen> {
  late Future<_AttachmentPreviewData> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  String get _title =>
      widget.attachment.name.isEmpty ? 'File preview' : widget.attachment.name;

  Future<_AttachmentPreviewData> _loadPreview() async {
    final attachment = widget.attachment;
    final mime = attachment.mimeType.toLowerCase();
    final name = attachment.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    final bytes = await chatApi.readAttachmentBytes(attachment);

    if (mime.startsWith('image/')) {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.image,
        bytes: bytes,
      );
    }

    if (attachment.isAudio) {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.audio,
        bytes: bytes,
      );
    }

    if (attachment.isLocation) {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.location,
        text: attachment.locationAddress,
      );
    }

    if (mime.contains('pdf') || ext == 'pdf') {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.pdf,
        bytes: bytes,
      );
    }

    if (_isTextPreviewType(mime, ext)) {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.text,
        text: _bytesToText(bytes),
      );
    }

    if (ext == 'docx') {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.office,
        text: _extractDocxText(bytes),
      );
    }

    if (ext == 'xlsx') {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.office,
        text: _extractXlsxText(bytes),
      );
    }

    return _AttachmentPreviewData(
      kind: _AttachmentPreviewKind.binary,
      text:
          'This file opens inside the app, but a rich preview engine is not available for this type yet.',
    );
  }

  Future<void> _download() async {
    try {
      await requestAttachmentStoragePermission(context);
      final path = await chatApi.downloadAttachment(widget.attachment);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded to $path')));
      }
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
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: _download,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_AttachmentPreviewData>(
        future: _previewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AttachmentPreviewError(
              title: _title,
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _previewFuture = _loadPreview()),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Unable to load preview.'));
          }
          return _AttachmentPreviewBody(
            attachment: widget.attachment,
            data: data,
          );
        },
      ),
    );
  }
}

class _AttachmentPreviewBody extends StatelessWidget {
  const _AttachmentPreviewBody({required this.attachment, required this.data});

  final ChatAttachment attachment;
  final _AttachmentPreviewData data;

  @override
  Widget build(BuildContext context) {
    switch (data.kind) {
      case _AttachmentPreviewKind.image:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.memory(
                data.bytes ?? Uint8List(0),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, size: 72),
              ),
            ),
          ),
        );
      case _AttachmentPreviewKind.audio:
        return _AudioAttachmentPreview(attachment: attachment);
      case _AttachmentPreviewKind.location:
        return _LocationAttachmentPreview(attachment: attachment);
      case _AttachmentPreviewKind.pdf:
        return kIsWeb
            ? SizedBox.expand(
                child: buildEmbeddedFilePreview(
                  attachment.url,
                  attachment.name,
                ),
              )
            : const _AttachmentPreviewText(
                text:
                    'PDF preview is available in the web build. Use download if you want to open it with a local app on this device.',
              );
      case _AttachmentPreviewKind.office:
      case _AttachmentPreviewKind.text:
        return _AttachmentPreviewText(text: data.text ?? '');
      case _AttachmentPreviewKind.binary:
        return _AttachmentPreviewText(text: data.text ?? '');
    }
  }
}

class _AudioAttachmentPreview extends StatefulWidget {
  const _AudioAttachmentPreview({required this.attachment});

  final ChatAttachment attachment;

  @override
  State<_AudioAttachmentPreview> createState() =>
      _AudioAttachmentPreviewState();
}

class _AudioAttachmentPreviewState extends State<_AudioAttachmentPreview> {
  final AudioPlayer _player = AudioPlayer();
  late final Future<String> _sourceFuture;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _sourceFuture = _prepareSource();
    _positionSubscription = _player.positionStream.listen((value) {
      if (mounted) setState(() => _position = value);
    });
    _durationSubscription = _player.durationStream.listen((value) {
      if (mounted) setState(() => _duration = value ?? Duration.zero);
    });
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _playing = state.playing);
    });
  }

  Future<String> _prepareSource() async {
    if (kIsWeb) {
      await _player.setUrl(widget.attachment.url);
      return widget.attachment.url;
    }
    final bytes = await chatApi.readAttachmentBytes(widget.attachment);
    final baseDir = await getTemporaryDirectory();
    final safeName = widget.attachment.name.replaceAll(
      RegExp(r'[<>:"/\|?*]'),
      '_',
    );
    final file = File(
      '${baseDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );
    await file.writeAsBytes(bytes, flush: true);
    await _player.setFilePath(file.path);
    return file.path;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _timeLabel(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _sourceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _AttachmentPreviewText(
            text:
                'Unable to load audio preview. Use download to open it locally.\n${snapshot.error}',
          );
        }
        final duration = _duration;
        final position = _position > duration ? duration : _position;
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final valueMs = position.inMilliseconds
            .clamp(0, maxMs.toInt())
            .toDouble();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _toggle,
                            icon: Icon(
                              _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.attachment.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.attachment.caption.isNotEmpty
                                    ? widget.attachment.caption
                                    : 'Voice message',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: valueMs,
                      max: maxMs,
                      onChanged: duration == Duration.zero
                          ? null
                          : (value) => _player.seek(
                              Duration(milliseconds: value.round()),
                            ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_timeLabel(position)),
                        Text(_timeLabel(duration)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocationAttachmentPreview extends StatelessWidget {
  const _LocationAttachmentPreview({required this.attachment});

  final ChatAttachment attachment;

  int _tileX(double longitude, int zoom) {
    return ((longitude + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  int _tileY(double latitude, int zoom) {
    final latRad = latitude * pi / 180.0;
    return ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) /
            2.0 *
            (1 << zoom))
        .floor();
  }

  String _tileUrl(int x, int y, int zoom) {
    return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
  }

  String get _title =>
      attachment.isLiveLocation ? 'Live location' : 'Current location';

  String get _detail {
    if (attachment.locationAddress.isNotEmpty)
      return attachment.locationAddress;
    if (attachment.latitude != null && attachment.longitude != null) {
      return '${attachment.latitude!.toStringAsFixed(5)}, ${attachment.longitude!.toStringAsFixed(5)}';
    }
    return _title;
  }

  Widget _mapTiles({required double height}) {
    final lat = attachment.latitude;
    final lon = attachment.longitude;
    if (lat == null || lon == null) {
      return _mapFallback(height: height);
    }
    const zoom = 15;
    final centerX = _tileX(lon, zoom);
    final centerY = _tileY(lat, zoom);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GridView.count(
            crossAxisCount: 3,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (var y = centerY - 1; y <= centerY + 1; y++)
                for (var x = centerX - 1; x <= centerX + 1; x++)
                  Image.network(
                    _tileUrl(x, y, zoom),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFFE8E2C6)),
                  ),
            ],
          ),
          const Center(
            child: Icon(
              Icons.location_on,
              color: Colors.redAccent,
              size: 54,
              shadows: [Shadow(color: Colors.white, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapFallback({required double height}) {
    return Container(
      height: height,
      color: const Color(0xFFE8E2C6),
      child: const Center(
        child: Icon(Icons.location_on, size: 58, color: Colors.redAccent),
      ),
    );
  }

  Future<void> _openMap(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _mapTiles(height: 320),
              ),
              const SizedBox(height: 12),
              SelectableText(_detail),
              if (attachment.isLiveLocation && attachment.liveMinutes > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Expires after ${attachment.liveMinutes} minutes. Updates every 1 minute.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return InkWell(
      onTap: () => _openMap(context),
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 318,
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _mapTiles(height: 190),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 26, 10, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              if (detail.isNotEmpty)
                                Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (attachment.isLiveLocation &&
                            attachment.liveMinutes > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${attachment.liveMinutes} min',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreviewText extends StatelessWidget {
  const _AttachmentPreviewText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SelectionArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text.isEmpty ? '(No readable content found.)' : text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreviewError extends StatelessWidget {
  const _AttachmentPreviewError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreviewData {
  const _AttachmentPreviewData({required this.kind, this.bytes, this.text});

  final _AttachmentPreviewKind kind;
  final Uint8List? bytes;
  final String? text;
}

bool _isTextPreviewType(String mimeType, String extension) {
  if (mimeType.startsWith('text/')) return true;
  return {
    'txt',
    'log',
    'md',
    'csv',
    'json',
    'xml',
    'html',
    'htm',
    'php',
    'dart',
    'js',
    'ts',
    'yaml',
    'yml',
    'css',
    'scss',
    'less',
    'py',
    'java',
    'c',
    'cpp',
    'h',
    'hpp',
    'sh',
    'bat',
    'ini',
    'conf',
  }.contains(extension);
}

String _bytesToText(Uint8List bytes) {
  return utf8.decode(bytes, allowMalformed: true);
}

String _extractDocxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final file = archive.findFile('word/document.xml');
    if (file == null) return '';
    final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
    final paragraphs = RegExp(r'<w:p[\s\S]*?</w:p>').allMatches(xml);
    final lines = <String>[];
    for (final paragraph in paragraphs) {
      final content = paragraph.group(0) ?? '';
      final runs = RegExp(r'<w:t[^>]*>([\s\S]*?)</w:t>').allMatches(content);
      final text = runs.map((m) => _xmlUnescape(m.group(1) ?? '')).join('');
      if (text.trim().isNotEmpty) lines.add(text);
    }
    return lines.isEmpty ? _stripXmlTags(xml) : lines.join('\n');
  } catch (_) {
    return '';
  }
}

String _extractXlsxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final shared = archive.findFile('xl/sharedStrings.xml');
    final sharedStrings = <String>[];
    if (shared != null) {
      final sharedXml = utf8.decode(
        shared.content as List<int>,
        allowMalformed: true,
      );
      for (final match in RegExp(
        r'<t[^>]*>([\s\S]*?)</t>',
      ).allMatches(sharedXml)) {
        sharedStrings.add(_xmlUnescape(match.group(1) ?? ''));
      }
    }
    final sheets =
        archive.files
            .where(
              (file) =>
                  file.name.startsWith('xl/worksheets/sheet') &&
                  file.name.endsWith('.xml'),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (sheets.isEmpty) return '';
    final xml = utf8.decode(
      sheets.first.content as List<int>,
      allowMalformed: true,
    );
    final rows = <String>[];
    for (final rowMatch in RegExp(
      r'<row[^>]*>([\s\S]*?)</row>',
    ).allMatches(xml)) {
      final rowXml = rowMatch.group(1) ?? '';
      final cells = <String>[];
      for (final cellMatch in RegExp(
        r'<c[^>]*?(?:t="([^"]+)")?[^>]*>([\s\S]*?)</c>',
      ).allMatches(rowXml)) {
        final cellType = cellMatch.group(1) ?? '';
        final cellXml = cellMatch.group(2) ?? '';
        final sharedIndex = RegExp(
          r'<v>(\d+)</v>',
        ).firstMatch(cellXml)?.group(1);
        final inline = RegExp(
          r'<t[^>]*>([\s\S]*?)</t>',
        ).firstMatch(cellXml)?.group(1);
        var value = '';
        if (cellType == 's' && sharedIndex != null) {
          final index = int.tryParse(sharedIndex) ?? -1;
          if (index >= 0 && index < sharedStrings.length)
            value = sharedStrings[index];
        } else if (inline != null) {
          value = _xmlUnescape(inline);
        } else {
          value = _xmlUnescape(
            RegExp(r'<v>([\s\S]*?)</v>').firstMatch(cellXml)?.group(1) ?? '',
          );
        }
        cells.add(value);
      }
      if (cells.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(cells.join('\t'));
      }
    }
    return rows.join('\n');
  } catch (_) {
    return '';
  }
}

String _xmlUnescape(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

String _stripXmlTags(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String encodeContactCard(Map<String, dynamic> contact) {
  return 'SKYLINK_CONTACT:${jsonEncode(contact)}';
}

Map<String, dynamic>? decodeContactCard(String text) {
  const prefix = 'SKYLINK_CONTACT:';
  if (!text.startsWith(prefix)) return null;
  try {
    final value = jsonDecode(text.substring(prefix.length));
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    data['phones'] = data['phones'] is List
        ? (data['phones'] as List).map((item) => '$item').toList()
        : <String>[];
    data['emails'] = data['emails'] is List
        ? (data['emails'] as List).map((item) => '$item').toList()
        : <String>[];
    return data;
  } catch (_) {
    return null;
  }
}

class ContactMessageCard extends StatelessWidget {
  const ContactMessageCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = '${data['name'] ?? 'Contact'}'.trim();
    final phones = data['phones'] is List ? data['phones'] as List : const [];
    final emails = data['emails'] is List ? data['emails'] as List : const [];
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Contact' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...phones.map(
            (phone) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.call_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$phone')),
                ],
              ),
            ),
          ),
          ...emails.map(
            (email) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.mail_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$email')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? decodeLiveChecklist(String text) {
  const prefix = 'SKYLINK_CHECKLIST:';
  if (!text.startsWith(prefix)) return null;
  try {
    final value = jsonDecode(text.substring(prefix.length));
    return value is Map ? Map<String, dynamic>.from(value) : null;
  } catch (_) {
    return null;
  }
}

class LiveChecklistCard extends StatelessWidget {
  const LiveChecklistCard({required this.data, this.onToggle});

  final Map<String, dynamic> data;
  final ValueChanged<int>? onToggle;

  @override
  Widget build(BuildContext context) {
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final completed = items.where((item) => item['done'] == true).length;
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${data['title'] ?? 'Checklist'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$completed/${items.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: items.isEmpty ? 0 : completed / items.length,
          ),
          const SizedBox(height: 6),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final done = item['done'] == true;
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: done,
              onChanged: onToggle == null ? null : (_) => onToggle!(index),
              title: Text(
                '${item['text'] ?? ''}',
                style: TextStyle(
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        ],
      ),
    );
  }



}

String formatFileSize(int bytes) {
  if (bytes < 1024) return ' B';
  final kb = bytes / 1024;
  if (kb < 1024) return ' KB';
  final mb = kb / 1024;
  return ' MB';
}
