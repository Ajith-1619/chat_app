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

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  ReleaseNote? _note;
  String? _error;
  bool _loading = true;

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
      final note = await chatApi.getReleaseNotes();
      if (!mounted) return;
      setState(() => _note = note);
      if (note != null && !note.viewed) {
        unawaited(chatApi.markReleaseNoteViewed(note.id));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to load release notes.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Scaffold(
      appBar: AppBar(title: const Text('What\'s New')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? LoadError(message: _error!, onRetry: _load)
          : note == null || note.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No release notes are available for this version yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.new_releases_rounded,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Skylink v${note.version}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Release date: ${note.releaseDate.isEmpty ? '-' : note.releaseDate}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ReleaseNoteContent(note: note),
                ],
              ),
            ),
    );
  }
}

class ReleaseNoteContent extends StatelessWidget {
  const ReleaseNoteContent({required this.note});

  final ReleaseNote note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReleaseNoteSection(
          icon: Icons.auto_awesome_outlined,
          title: 'New features',
          body: note.newFeatures,
        ),
        ReleaseNoteSection(
          icon: Icons.trending_up_rounded,
          title: 'Improvements',
          body: note.improvements,
        ),
        ReleaseNoteSection(
          icon: Icons.bug_report_outlined,
          title: 'Bug fixes',
          body: note.bugFixes,
        ),
        ReleaseNoteSection(
          icon: Icons.security_rounded,
          title: 'Security updates',
          body: note.securityUpdates,
        ),
        ReleaseNoteSection(
          icon: Icons.integration_instructions_outlined,
          title: 'Implementation details',
          body: note.implementationDetails,
        ),
      ],
    );
  }
}

class ReleaseNoteSection extends StatelessWidget {
  const ReleaseNoteSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(trimmed),
          ],
        ),
      ),
    );
  }
}

class ReleaseManagementScreen extends StatefulWidget {
  const ReleaseManagementScreen({super.key});

  @override
  State<ReleaseManagementScreen> createState() =>
      _ReleaseManagementScreenState();
}

class _ReleaseManagementScreenState extends State<ReleaseManagementScreen> {
  ReleaseGovernance? _governance;
  bool _loading = true;
  String? _error;

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
      final data = await chatApi.getReleases();
      if (mounted) {
        setState(() {
          _governance = data;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _register() async {
    final version = TextEditingController();
    final build = TextEditingController();
    final url = TextEditingController(
      text:
          'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-latest.apk',
    );
    final notes = TextEditingController();
    var platform = 'android';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Register uploaded build'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: platform,
                  items: const [
                    DropdownMenuItem(
                      value: 'android',
                      child: Text('Android APK'),
                    ),
                    DropdownMenuItem(value: 'windows', child: Text('Windows')),
                    DropdownMenuItem(
                      value: 'linux',
                      child: Text('Ubuntu/Linux'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => platform = value ?? 'android'),
                ),
                TextField(
                  controller: version,
                  decoration: const InputDecoration(labelText: 'Version'),
                ),
                TextField(
                  controller: build,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Build number'),
                ),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'Download URL'),
                ),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Release notes'),
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
              child: const Text('Save as Draft'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.registerReleaseBuild(
        platform: platform,
        version: version.text.trim(),
        buildNumber: int.tryParse(build.text.trim()) ?? 0,
        url: url.text.trim(),
        notes: notes.text.trim(),
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _action(ReleaseBuild build, String action) async {
    var force = false;
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(action.replaceAll('_', ' ')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${build.platform} ${build.version}+${build.buildNumber}'),
              if (action == 'approve_for_production')
                CheckboxListTile(
                  value: force,
                  title: const Text('Enable force update'),
                  subtitle: const Text(
                    'Allowed only after Ajith approves Production.',
                  ),
                  onChanged: (value) =>
                      setDialogState(() => force = value ?? false),
                ),
              TextField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.releaseAction(
        releaseId: build.id,
        action: action,
        notes: notes.text.trim(),
        forceUpdate: force,
      );
      await _load();
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
    final governance = _governance;
    return Scaffold(
      appBar: AppBar(title: const Text('Release management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _register,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('New draft'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? LoadError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(
                        governance?.canApproveProduction == true
                            ? Icons.verified_user_rounded
                            : Icons.lock_outline_rounded,
                      ),
                      title: const Text('Production approval'),
                      subtitle: Text(
                        governance?.canApproveProduction == true
                            ? 'Ajith (302) can approve Production and force update.'
                            : 'Only Ajith (302) may approve Production.',
                      ),
                    ),
                  ),
                  ...?governance?.builds.map(
                    (build) => Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          child: Text(
                            build.platform.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          '${build.platform} ${build.version}+${build.buildNumber}',
                        ),
                        subtitle: Text(
                          '${build.stage} - ${build.status} - rollout ${build.rolloutPercent}%',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        children: [
                          if (build.notes.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(build.notes),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _action(build, 'reject_build'),
                                child: const Text('Reject'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _action(build, 'deploy_to_testers'),
                                child: const Text('Deploy testers'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _action(build, 'deploy_to_pilot_users'),
                                child: const Text('Pilot'),
                              ),
                              FilledButton(
                                onPressed:
                                    governance.canApproveProduction == true
                                    ? () => _action(
                                        build,
                                        'approve_for_production',
                                      )
                                    : null,
                                child: const Text('Approve production'),
                              ),
                              OutlinedButton(
                                onPressed:
                                    governance.canApproveProduction == true
                                    ? () => _action(build, 'rollback_release')
                                    : null,
                                child: const Text('Rollback'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }




}


