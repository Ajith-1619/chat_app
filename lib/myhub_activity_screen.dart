import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app/skylink_app.dart';
import 'chat_api.dart';

final ChatApi _myHubActivityApi = sharedChatApi;

class MyHubActivityScreen extends StatefulWidget {
  const MyHubActivityScreen({super.key});

  @override
  State<MyHubActivityScreen> createState() => _MyHubActivityScreenState();
}

class _MyHubActivityScreenState extends State<MyHubActivityScreen> {
  static const _types = <String>[
    'Task Update',
    'Client Call',
    'Meeting',
    'Support',
    'Follow-up',
    'Incident',
    'General',
  ];

  final _description = TextEditingController();
  String _logType = _types.first;
  TimeOfDay? _from;
  TimeOfDay? _to;
  bool _loading = true;
  bool _saving = false;
  String _error = '';
  List<Map<String, dynamic>> _logs = const [];
  List<({String name, List<int> bytes})> _files = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await _myHubActivityApi.getMyHubActivities();
      final rows = data['logs'] is List
          ? (data['logs'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => _logs = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final picked = result.files
        .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
        .map((file) => (name: file.name, bytes: file.bytes!.toList()))
        .toList(growable: false);
    setState(() => _files = picked);
  }

  Future<void> _pickTime(bool from) async {
    final initial = from ? _from : _to;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _save() async {
    final description = _description.text.trim();
    if (description.isEmpty || _from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description, from time and to time are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _myHubActivityApi.saveMyHubActivity(
        logType: _logType,
        description: description,
        fromTime: _timeValue(_from!),
        toTime: _timeValue(_to!),
        files: _files,
      );
      if (!mounted) return;
      _description.clear();
      setState(() {
        _files = const [];
        _from = null;
        _to = null;
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _timeValue(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _timeLabel(TimeOfDay? value) => value == null ? '--:-- --' : value.format(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ActivityForm(
              logType: _logType,
              types: _types,
              description: _description,
              fromLabel: _timeLabel(_from),
              toLabel: _timeLabel(_to),
              files: _files,
              saving: _saving,
              onTypeChanged: (value) => setState(() => _logType = value ?? _logType),
              onPickFiles: _pickFiles,
              onPickFrom: () => _pickTime(true),
              onPickTo: () => _pickTime(false),
              onSave: _save,
            ),
            const SizedBox(height: 18),
            Text(
              'This month activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error.isNotEmpty)
              _ActivityEmpty(message: _error, onRetry: _load)
            else if (_logs.isEmpty)
              const _ActivityEmpty(message: 'No activity logs for this month.')
            else
              ..._logs.map((log) => _ActivityLogTile(log: log)),
          ],
        ),
      ),
    );
  }
}

class _ActivityForm extends StatelessWidget {
  const _ActivityForm({
    required this.logType,
    required this.types,
    required this.description,
    required this.fromLabel,
    required this.toLabel,
    required this.files,
    required this.saving,
    required this.onTypeChanged,
    required this.onPickFiles,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSave,
  });

  final String logType;
  final List<String> types;
  final TextEditingController description;
  final String fromLabel;
  final String toLabel;
  final List<({String name, List<int> bytes})> files;
  final bool saving;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onPickFiles;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Today\'s Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth > 680;
                final children = [
                  _LabeledField(
                    label: 'Log Type',
                    child: DropdownButtonFormField<String>(
                      initialValue: logType,
                      decoration: const InputDecoration(isDense: true),
                      items: types
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: saving ? null : onTypeChanged,
                    ),
                  ),
                  _LabeledField(
                    label: 'Files',
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : onPickFiles,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(files.isEmpty ? 'Choose Files' : '${files.length} file(s) selected'),
                    ),
                  ),
                ];
                if (!twoCols) {
                  return Column(children: children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: child)).toList());
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 20),
                    Expanded(child: children[1]),
                  ],
                );
              },
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: files.map((file) => Chip(label: Text(file.name))).toList(),
              ),
            ],
            const SizedBox(height: 14),
            _LabeledField(
              label: 'Activity Description',
              child: TextField(
                controller: description,
                minLines: 3,
                maxLines: 5,
                enabled: !saving,
                decoration: const InputDecoration(hintText: 'What did you do today?'),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth > 680;
                final children = [
                  _TimeButton(label: 'From', value: fromLabel, onTap: saving ? null : onPickFrom),
                  _TimeButton(label: 'To', value: toLabel, onTap: saving ? null : onPickTo),
                ];
                if (!twoCols) {
                  return Column(children: children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: child)).toList());
                }
                return Row(children: [Expanded(child: children[0]), const SizedBox(width: 20), Expanded(child: children[1])]);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0E214D)),
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _LabeledField(
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: const InputDecoration(isDense: true, suffixIcon: Icon(Icons.access_time_rounded)),
            child: Text(value),
          ),
        ),
      );
}

class _ActivityLogTile extends StatelessWidget {
  const _ActivityLogTile({required this.log});
  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final filePath = '${log['file_path'] ?? ''}'.trim();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFDCE6FF),
          child: Icon(Icons.event_note_rounded, color: AppColors.primary),
        ),
        title: Text('${log['activity_log_type'] ?? 'Activity'}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${log['activity_desc'] ?? ''}'),
              const SizedBox(height: 4),
              Text('${log['activity_date'] ?? ''}  ${log['start_time'] ?? ''} - ${log['end_time'] ?? ''}'),
              if (filePath.isNotEmpty) Text('File: $filePath'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  const _ActivityEmpty({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.info_outline_rounded, size: 36),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}