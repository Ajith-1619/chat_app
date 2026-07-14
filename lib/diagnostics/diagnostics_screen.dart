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

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, dynamic>? _report;
  String? _error;
  bool _loading = true;
  int _hours = 24;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await chatApi.getDiagnostics(hours: _hours);
      if (mounted) setState(() => _report = report);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to load diagnostics.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _supportReport() {
    final report = _report ?? const <String, dynamic>{};
    final summary = (report['summary'] as List? ?? const []);
    final bottlenecks = (report['bottlenecks'] as List? ?? const []);
    final buffer = StringBuffer()
      ..writeln('Skylink Advanced Diagnostics')
      ..writeln('Report: ${report['report_id'] ?? '-'}')
      ..writeln('Generated: ${report['generated_at'] ?? '-'}')
      ..writeln('Window: ${report['window_hours'] ?? _hours} hours')
      ..writeln()
      ..writeln('Bottlenecks:');
    if (bottlenecks.isEmpty) buffer.writeln('- None detected');
    for (final raw in bottlenecks.whereType<Map>()) {
      buffer.writeln(
        '- ${raw['category']}/${raw['operation']}: '
        '${raw['avg_ms']} ms avg, ${raw['max_ms']} ms max, '
        '${raw['errors']} errors [${raw['severity']}]',
      );
    }
    buffer.writeln('\nAll measurements:');
    for (final raw in summary.whereType<Map>()) {
      buffer.writeln(
        '- ${raw['category']}/${raw['operation']}: '
        '${raw['count']} samples, ${raw['avg_ms']} ms avg, '
        '${raw['max_ms']} ms max',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final summary = (report?['summary'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final bottlenecks = (report?['bottlenecks'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final traces = (report?['traces'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Share support report',
            onPressed: report == null
                ? null
                : () => SharePlus.instance.share(
                    ShareParams(
                      text: _supportReport(),
                      subject: 'Skylink support report ${report['report_id']}',
                    ),
                  ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && report == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && report == null
          ? LoadError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${report?['report_id'] ?? 'Support report'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Android - API - Database - XMPP - Notification/File Transfer',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1h')),
                              ButtonSegment(value: 24, label: Text('24h')),
                              ButtonSegment(value: 168, label: Text('7d')),
                            ],
                            selected: {_hours},
                            onSelectionChanged: (value) {
                              _hours = value.first;
                              _load();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Detected bottlenecks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (bottlenecks.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        title: Text('No bottlenecks detected'),
                      ),
                    ),
                  ...bottlenecks.map((item) => _DiagnosticTile(item: item)),
                  const SizedBox(height: 16),
                  Text(
                    'Latency summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...summary.map((item) => _DiagnosticTile(item: item)),
                  const SizedBox(height: 16),
                  Text(
                    'Recent trace events (${traces.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  ...traces
                      .take(100)
                      .map(
                        (trace) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.timeline_rounded),
                          title: Text(' - '),
                          subtitle: Text(' - Trace '),
                          trailing: Text(
                            '${(trace['duration_ms'] as num? ?? 0).toStringAsFixed(0)} ms',
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({required this.item});

  final Map item;

  @override
  Widget build(BuildContext context) {
    final severity = '${item['severity'] ?? 'healthy'}';
    final color = switch (severity) {
      'error' || 'critical' => Colors.red,
      'slow' => Colors.orange,
      _ => Colors.green,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: const Icon(Icons.speed_rounded),
        ),
        title: Text(' - '),
        subtitle: Text(' samples - max  ms -  errors'),
        trailing: Text(
          '${item['avg_ms']} ms',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }



}
