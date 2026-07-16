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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.currentUser});

  final CurrentUser? currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: const Text('Profile photo'),
            subtitle: const Text('Choose or update your profile picture'),
            trailing: const Icon(Icons.photo_camera_outlined),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.devices_rounded),
            title: const Text('Devices'),
            subtitle: const Text('View active login sessions'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ActiveSessionsScreen(),
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('Notifications and sounds'),
            subtitle: Text('Use chat menu to mute a user or group'),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline_rounded),
            title: Text('Privacy and security'),
            subtitle: Text('Session and last-seen controls'),
          ),
          const ListTile(
            leading: Icon(Icons.data_usage_rounded),
            title: Text('Data and storage'),
            subtitle: Text('Images are compressed; documents stay original'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: const Text('Theme, font size, density and chat bubbles'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AppearanceSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.new_releases_outlined),
            title: const Text('What\'s New'),
            subtitle: const Text('Release notes for this app version'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WhatsNewScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_rounded),
            title: const Text('Check for updates'),
            subtitle: const Text('Download the latest Skylink version'),
            onTap: () async {
              final status = await chatApi.getVersionStatus();
              if (!context.mounted) return;
              if (!status.updateAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Skylink is up to date.')),
                );
                return;
              }
              await launchUrl(
                Uri.parse(status.url),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.chat_bubble_outline_rounded),
            title: Text('Chat settings'),
            subtitle: Text('Telegram-style chat preferences'),
          ),
          if (currentUser != null &&
              canAccessFlowDevelopment(
                employeeId: currentUser!.empId,
                name: currentUser!.name,
                designation: currentUser!.designation,
              ))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Development'),
              subtitle: const Text(
                'Feature registry, release register and audits',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FlowDevelopmentScreen(
                    viewerEmployeeId: currentUser!.empId,
                    viewerName: currentUser!.name,
                    viewerDesignation: currentUser!.designation,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}
class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  late ThemeMode _theme;
  late String _themeName;
  late double _scale;
  late double _density;
  late bool _avatars;
  late bool _collapseLongMessages;
  late String _workspaceMode;
  String _bubble = 'rounded';

  @override
  void initState() {
    super.initState();
    _theme = appThemeMode.value;
    _themeName = appThemeName.value;
    _scale = appMessageScale.value;
    _density = appChatDensity.value;
    _avatars = appShowAvatars.value;
    _collapseLongMessages = appCollapseLongMessages.value;
    _workspaceMode = appWorkspaceMode.value;
  }

  Future<void> _save() async {
    appThemeMode.value = _theme;
    appThemeName.value = _themeName;
    appMessageScale.value = _scale;
    appChatDensity.value = _density;
    appShowAvatars.value = _avatars;
    appCollapseLongMessages.value = _collapseLongMessages;
    appWorkspaceMode.value = _workspaceMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _theme.name);
    await prefs.setString('theme_name', _themeName);
    await prefs.setDouble('message_scale', _scale);
    await prefs.setDouble('chat_density', _density);
    await prefs.setBool('show_avatars', _avatars);
    await prefs.setBool('collapse_long_messages', _collapseLongMessages);
    await prefs.setString('workspace_mode', _workspaceMode);
    await prefs.setString('bubble_style', _bubble);
  }

  @override
  Widget build(BuildContext context) {
    final activeSpec = flowThemeById(_themeName);
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Display mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ],
            selected: {_theme},
            onSelectionChanged: (value) {
              setState(() => _theme = value.first);
              _save();
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Themes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                activeSpec.name,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 840
                  ? 3
                  : constraints.maxWidth > 560
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 2.6 : 1.72,
                ),
                itemCount: flowThemeSpecs.length,
                itemBuilder: (context, index) {
                  final spec = flowThemeSpecs[index];
                  return _ThemePreviewCard(
                    spec: spec,
                    selected: spec.id == _themeName,
                    darkPreview: _theme == ThemeMode.dark ||
                        (_theme == ThemeMode.system &&
                            MediaQuery.platformBrightnessOf(context) ==
                                Brightness.dark),
                    onTap: () {
                      setState(() => _themeName = spec.id);
                      _save();
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Message font size: ${(_scale * 100).round()}%'),
          Slider(
            value: _scale,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            onChanged: (value) => setState(() => _scale = value),
            onChangeEnd: (_) => _save(),
          ),
          Text('Chat density: ${(_density * 100).round()}%'),
          Slider(
            value: _density,
            min: 0.75,
            max: 1.25,
            divisions: 5,
            onChanged: (value) => setState(() => _density = value),
            onChangeEnd: (_) => _save(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show avatars'),
            value: _avatars,
            onChanged: (value) {
              setState(() => _avatars = value);
              _save();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Collapse long messages'),
            subtitle: const Text('Show long messages in a compact preview.'),
            value: _collapseLongMessages,
            onChanged: (value) {
              setState(() => _collapseLongMessages = value);
              _save();
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _workspaceMode,
            decoration: const InputDecoration(labelText: 'Workspace mode'),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: 'two_pane', child: Text('Two panel')),
              DropdownMenuItem(value: 'three_pane', child: Text('Three panel')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _workspaceMode = value);
              _save();
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _bubble,
            decoration: const InputDecoration(labelText: 'Bubble style'),
            items: const [
              DropdownMenuItem(value: 'rounded', child: Text('Rounded')),
              DropdownMenuItem(value: 'compact', child: Text('Compact')),
              DropdownMenuItem(value: 'classic', child: Text('Classic')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _bubble = value);
              _save();
            },
          ),
          const SizedBox(height: 24),
          Text('Live preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _AppearanceLivePreview(
            spec: activeSpec,
            scale: _scale,
            density: _density,
            dark: _theme == ThemeMode.dark ||
                (_theme == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) == Brightness.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.spec,
    required this.selected,
    required this.darkPreview,
    required this.onTap,
  });

  final FlowThemeSpec spec;
  final bool selected;
  final bool darkPreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = darkPreview ? spec.darkBackground : spec.lightBackground;
    final surface = darkPreview ? spec.darkSurface : spec.lightSurface;
    final text = darkPreview ? const Color(0xFFEAF0FA) : AppColors.text;
    final muted = darkPreview ? const Color(0xFFBAC4D6) : AppColors.muted;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? spec.primary : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ThemeDot(color: spec.primary),
                const SizedBox(width: 6),
                _ThemeDot(color: spec.secondary),
                const SizedBox(width: 6),
                _ThemeDot(color: bg),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: spec.primary, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              spec.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: text, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              spec.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const Spacer(),
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 48,
                    height: 20,
                    decoration: BoxDecoration(
                      color: spec.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeDot extends StatelessWidget {
  const _ThemeDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }
}

class _AppearanceLivePreview extends StatelessWidget {
  const _AppearanceLivePreview({
    required this.spec,
    required this.scale,
    required this.density,
    required this.dark,
  });

  final FlowThemeSpec spec;
  final double scale;
  final double density;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? spec.darkBackground : spec.lightBackground;
    final surface = dark ? spec.darkSurface : spec.lightSurface;
    final surfaceHigh = dark ? spec.darkSurfaceHigh : const Color(0xFFF6F8FC);
    final text = dark ? const Color(0xFFEAF0FA) : AppColors.text;
    final muted = dark ? const Color(0xFFBAC4D6) : AppColors.muted;
    return Container(
      padding: EdgeInsets.all(14 * density),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: spec.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.groups_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#watchtower flow', style: TextStyle(color: text, fontWeight: FontWeight.w800)),
                    Text('Operational channel', style: TextStyle(color: muted, fontSize: 12 * scale)),
                  ],
                ),
              ),
              Icon(Icons.search_rounded, color: muted),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: EdgeInsets.all(12 * density),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Incoming message preview with readable contrast in the selected theme.',
                style: TextStyle(color: text, fontSize: 14 * scale),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: EdgeInsets.all(12 * density),
              decoration: BoxDecoration(
                color: spec.primary.withValues(alpha: dark ? 0.35 : 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: spec.primary.withValues(alpha: 0.38)),
              ),
              child: Text(
                'Outgoing message, links, sender metadata and controls stay visible.',
                style: TextStyle(color: text, fontSize: 14 * scale),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_emotions_outlined, color: muted),
                const SizedBox(width: 8),
                Expanded(child: Text('Message', style: TextStyle(color: muted, fontSize: 14 * scale))),
                Icon(Icons.attach_file_rounded, color: muted),
                const SizedBox(width: 8),
                CircleAvatar(radius: 16, backgroundColor: spec.primary, child: const Icon(Icons.send_rounded, size: 16, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


