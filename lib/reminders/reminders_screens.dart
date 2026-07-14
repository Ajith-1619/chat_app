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

class ScheduleMessageScreen extends StatefulWidget {
  const ScheduleMessageScreen();

  @override
  State<ScheduleMessageScreen> createState() => ScheduleMessageScreenState();
}

class ScheduleMessageScreenState extends State<ScheduleMessageScreen> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selected = <String>{};
  List<ChatContact> _targets = const [];
  bool _loading = true;
  bool _sending = false;
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  @override
  void dispose() {
    unregisterClipboardMediaHandler();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    try {
      final values = await Future.wait([
        chatApi.getRecentChats(),
        chatApi.searchUsers(),
      ]);
      final byJid = <String, ChatContact>{};
      for (final target in [...values[0], ...values[1]]) {
        if (target.jid.toLowerCase() != systemNotificationJid) {
          byJid[target.jid.toLowerCase()] = target;
        }
      }
      if (mounted) {
        setState(() {
          _targets = byJid.values.toList();
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(
      () => _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty ||
        _selected.isEmpty ||
        !_scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a message, select recipients and choose a future time.',
          ),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await chatApi.scheduleMessage(
        message: _messageController.text,
        scheduledAt: _scheduledAt.toIso8601String(),
        targets: _selected.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message scheduled for ${_selected.length} recipient(s).',
            ),
          ),
        );
        Navigator.pop(context);
      }
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

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final targets = _targets
        .where(
          (target) =>
              query.isEmpty ||
              '${target.name} ${target.designation} ${target.jid}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(
                    '${_scheduledAt.day}/${_scheduledAt.month}/${_scheduledAt.year} - ${TimeOfDay.fromDateTime(_scheduledAt).format(context)}',
                  ),
                  subtitle: const Text('Delivery date and time'),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: _pickSchedule,
                ),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search users, groups and channels',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: targets.length,
                    itemBuilder: (_, index) {
                      final target = targets[index];
                      return CheckboxListTile(
                        value: _selected.contains(target.jid),
                        onChanged: (checked) => setState(
                          () => checked == true
                              ? _selected.add(target.jid)
                              : _selected.remove(target.jid),
                        ),
                        secondary: CircleAvatar(
                          child: Icon(
                            target.type == 'chat'
                                ? Icons.person_rounded
                                : Icons.groups_rounded,
                          ),
                        ),
                        title: Text(target.name),
                        subtitle: Text(target.designation),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.schedule_send_rounded),
            label: Text('Schedule for ${_selected.length}'),
          ),
        ),
      ),
    );
  }
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.currentUser});

  final CurrentUser currentUser;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  bool _showActive = true;
  String? _error;

  List<Map<String, dynamic>> get _visibleItems => _items.where((item) {
    final value = item['active'];
    final active = value == true || value == 1 || value == '1';
    return active == _showActive;
  }).toList();

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
      final items = await chatApi.getReminders();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReminderCreateScreen(currentUser: widget.currentUser),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _stop(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop reminder?'),
        content: Text('Stop "${item['title'] ?? 'this reminder'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await chatApi.stopReminder(int.parse('${item['id']}'));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not stop reminder: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders & Follow-ups'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Create'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Active'),
                  icon: Icon(Icons.check_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Stopped'),
                  icon: Icon(Icons.notifications_off_outlined),
                ),
              ],
              selected: {_showActive},
              onSelectionChanged: (value) {
                setState(() => _showActive = value.first);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ReminderMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load reminders',
                    detail: _error!,
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : items.isEmpty
                ? _ReminderMessage(
                    icon: _showActive
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_off_outlined,
                    title: _showActive
                        ? 'No active reminders'
                        : 'No stopped reminders',
                    detail: _showActive
                        ? 'Create a reminder or follow-up to see it here.'
                        : 'Stopped items will appear here.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final kind = '${item['kind'] ?? 'reminder'}';
                        final startsAt = '${item['starts_at'] ?? ''}';
                        final recurrence =
                            '${item['recurrence_type'] ?? 'once'}';
                        final creator =
                            '${item['created_by_name'] ?? item['created_by_emp_id'] ?? ''}';
                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              child: Icon(
                                kind == 'followup'
                                    ? Icons.follow_the_signs_outlined
                                    : Icons.alarm_rounded,
                              ),
                            ),
                            title: Text(
                              '${item['title'] ?? 'Untitled'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                startsAt,
                                recurrenceLabel(recurrence),
                                if (creator.isNotEmpty) 'From $creator',
                              ].join('\n'),
                            ),
                            trailing: _showActive
                                ? TextButton(
                                    onPressed: () => _stop(item),
                                    child: const Text('Stop'),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReminderMessage extends StatelessWidget {
  const _ReminderMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(detail, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ReminderCreateScreen extends StatefulWidget {
  const ReminderCreateScreen({
    super.key,
    required this.currentUser,
    this.initialKind = 'reminder',
    this.initialTitle = '',
    this.initialNotes = '',
    this.sourceConversationJid = '',
    this.sourceConversationName = '',
    this.sourceMessageId = 0,
    this.sourceMessageText = '',
  });

  final CurrentUser currentUser;
  final String initialKind;
  final String initialTitle;
  final String initialNotes;
  final String sourceConversationJid;
  final String sourceConversationName;
  final int sourceMessageId;
  final String sourceMessageText;

  @override
  State<ReminderCreateScreen> createState() => _ReminderCreateScreenState();
}

class _ReminderCreateScreenState extends State<ReminderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late String _kind;
  String _recurrence = 'once';
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 1));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind == 'followup' ? 'followup' : 'reminder';
    _titleController = TextEditingController(text: widget.initialTitle);
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _dateTimeLabel {
    final value = _startsAt;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String get _apiDateTime {
    final value = _startsAt;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:00';
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final employeeId = int.tryParse(widget.currentUser.empId);
    setState(() => _saving = true);
    try {
      await chatApi.createReminder(
        kind: _kind,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        startsAt: _apiDateTime,
        recurrence: _recurrence,
        assigneeIds: employeeId == null ? const [] : [employeeId],
        sourceConversationJid: widget.sourceConversationJid,
        sourceConversationName: widget.sourceConversationName,
        sourceMessageId: widget.sourceMessageId,
        sourceMessageText: widget.sourceMessageText,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create reminder: $error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _kind == 'followup' ? 'Create follow up' : 'Create reminder',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'reminder',
                  label: Text('Reminder'),
                  icon: Icon(Icons.alarm_outlined),
                ),
                ButtonSegment(
                  value: 'followup',
                  label: Text('Follow-up'),
                  icon: Icon(Icons.follow_the_signs_outlined),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (value) {
                setState(() => _kind = value.first);
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a title'
                  : null,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.event_outlined),
              title: const Text('Date and time'),
              subtitle: Text(_dateTimeLabel),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _recurrence,
              decoration: const InputDecoration(
                labelText: 'Repeat',
                prefixIcon: Icon(Icons.repeat_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'once', child: Text('This time only')),
                DropdownMenuItem(value: 'daily', child: Text('Every day')),
                DropdownMenuItem(value: 'weekly', child: Text('Every week')),
                DropdownMenuItem(value: 'monthly', child: Text('Every month')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _recurrence = value);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving reminder...' : 'Save reminder'),
          ),
        ),
      ),
    );
  }
}

String recurrenceLabel(String value) {
  return switch (value) {
    'daily' => 'Every day',
    'weekly' => 'Every week',
    'monthly' => 'Every month',
    _ => 'This time only',
  };
}



