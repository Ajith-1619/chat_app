import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

Widget buildEmbeddedVideoPreview({
  required String title,
  required String url,
  Uint8List? bytes,
  bool autoplay = false,
  bool muted = false,
  bool loop = false,
  bool controls = true,
  BoxFit fit = BoxFit.contain,
}) {
  return _EmbeddedVideoPreview(
    title: title,
    url: url,
    bytes: bytes,
    autoplay: autoplay,
    muted: muted,
    loop: loop,
    controls: controls,
    fit: fit,
  );
}

class _EmbeddedVideoPreview extends StatefulWidget {
  const _EmbeddedVideoPreview({
    required this.title,
    required this.url,
    required this.bytes,
    required this.autoplay,
    required this.muted,
    required this.loop,
    required this.controls,
    required this.fit,
  });

  final String title;
  final String url;
  final Uint8List? bytes;
  final bool autoplay;
  final bool muted;
  final bool loop;
  final bool controls;
  final BoxFit fit;

  @override
  State<_EmbeddedVideoPreview> createState() => _EmbeddedVideoPreviewState();
}

class _EmbeddedVideoPreviewState extends State<_EmbeddedVideoPreview> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initializeController();
  }

  @override
  void didUpdateWidget(covariant _EmbeddedVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url || widget.bytes != oldWidget.bytes) {
      _initializeFuture = _initializeController();
    }
  }

  Future<void> _initializeController() async {
    await _disposeController();
    final controller = await _createController();
    await controller.initialize();
    await controller.setLooping(widget.loop);
    await controller.setVolume(widget.muted ? 0 : 1);
    if (widget.autoplay) {
      unawaited(controller.play());
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  Future<VideoPlayerController> _createController() async {
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      final directory = await getTemporaryDirectory();
      final safeName = widget.title.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${directory.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$safeName');
      await file.writeAsBytes(widget.bytes!, flush: true);
      _tempFile = file;
      return VideoPlayerController.file(file);
    }
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      throw StateError('Invalid video URL.');
    }
    return VideoPlayerController.networkUrl(uri);
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
    final tempFile = _tempFile;
    _tempFile = null;
    if (tempFile != null) {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || _controller == null || !_controller!.value.isInitialized) {
          return Container(
            color: Colors.black,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 72),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error?.toString() ?? 'Unable to load this video preview.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }
        final controller = _controller!;
        final content = FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.size.width <= 0 ? 16 : controller.value.size.width,
            height: controller.value.size.height <= 0 ? 9 : controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
        return ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: content),
              if (widget.controls)
                _EmbeddedVideoControls(controller: controller)
              else
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (controller.value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                      if (mounted) setState(() {});
                    },
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: controller.value.isPlaying ? 0 : 1,
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white70,
                          size: 58,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmbeddedVideoControls extends StatefulWidget {
  const _EmbeddedVideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_EmbeddedVideoControls> createState() => _EmbeddedVideoControlsState();
}

class _EmbeddedVideoControlsState extends State<_EmbeddedVideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant _EmbeddedVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final duration = controller.value.duration;
    final position = controller.value.position > duration ? duration : controller.value.position;
    final progress = duration.inMilliseconds <= 0 ? 0.0 : position.inMilliseconds / duration.inMilliseconds;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          IconButton(
            onPressed: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            },
            iconSize: 52,
            color: Colors.white,
            icon: Icon(controller.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: duration.inMilliseconds <= 0 ? null : (value) {
                    final target = Duration(milliseconds: (duration.inMilliseconds * value).round());
                    controller.seekTo(target);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_format(position), style: const TextStyle(color: Colors.white)),
                    Text(_format(duration), style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
