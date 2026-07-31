import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app/skylink_app.dart';
import 'chat_api.dart';

final ChatApi _suggestionsApi = sharedChatApi;

class MyHubSuggestionsScreen extends StatefulWidget {
  const MyHubSuggestionsScreen({super.key});

  @override
  State<MyHubSuggestionsScreen> createState() => _MyHubSuggestionsScreenState();
}

class _MyHubSuggestionsScreenState extends State<MyHubSuggestionsScreen> {
  static const _types = <String>['Suggestion', 'Complaint'];
  static const _categories = <String>[
    'HR',
    'Admin',
    'IT',
    'Facilities',
    'Policy',
    'General',
  ];
  static const _priorities = <String>['Low', 'Normal', 'High', 'Critical'];

  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _userSearch = TextEditingController();
  String _type = _types.first;
  String _category = _categories.first;
  String _priority = _priorities[1];
  int _assignedToEmpId = 0;
  Map<String, dynamic>? _assignedTo;
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _items = const [];
  List<({String name, List<int> bytes})> _files = const [];
  bool _loading = true;
  bool _saving = false;
  bool _searchingUsers = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadUsers();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    _userSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await _suggestionsApi.getMyHubSuggestions();
      final rows = data['items'] is List
          ? (data['items'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers([String search = '']) async {
    setState(() => _searchingUsers = true);
    try {
      final users = await _suggestionsApi.getMyHubDirectory(search: search);
      if (!mounted) return;
      setState(() => _users = users.take(80).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _users = const []);
    } finally {
      if (mounted) setState(() => _searchingUsers = false);
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
        .take(5)
        .map((file) => (name: file.name, bytes: file.bytes!.toList()))
        .toList(growable: false);
    setState(() => _files = picked);
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (_assignedToEmpId <= 0) {
      _showMessage('Select the user this is for.');
      return;
    }
    if (subject.isEmpty || message.isEmpty) {
      _showMessage('Subject and message are required.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _suggestionsApi.saveMyHubSuggestionComplaint(
        entryType: _type,
        category: _category,
        priority: _priority,
        subject: subject,
        message: message,
        assignedToEmpId: _assignedToEmpId,
        files: _files,
      );
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      _userSearch.clear();
      setState(() {
        _files = const [];
        _assignedToEmpId = 0;
        _assignedTo = null;
      });
      await _load();
      _showMessage('Submitted successfully.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _personName(Map<String, dynamic>? value) {
    if (value == null) return '';
    return '${value['name'] ?? value['employee_name'] ?? value['emp_name'] ?? value['username'] ?? value['emp_id'] ?? ''}'
        .trim();
  }

  int _personId(Map<String, dynamic> value) =>
      int.tryParse(
        '${value['emp_id'] ?? value['employee_id'] ?? value['id'] ?? 0}',
      ) ??
      0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggestions & Complaints'),
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
            _SuggestionForm(
              type: _type,
              category: _category,
              priority: _priority,
              types: _types,
              categories: _categories,
              priorities: _priorities,
              subject: _subject,
              message: _message,
              userSearch: _userSearch,
              selectedUserLabel: _assignedTo == null
                  ? ''
                  : '${_personName(_assignedTo)} ($_assignedToEmpId)',
              users: _users,
              files: _files,
              saving: _saving,
              searchingUsers: _searchingUsers,
              onTypeChanged: (value) => setState(() => _type = value ?? _type),
              onCategoryChanged: (value) =>
                  setState(() => _category = value ?? _category),
              onPriorityChanged: (value) =>
                  setState(() => _priority = value ?? _priority),
              onUserSearchChanged: _loadUsers,
              onUserSelected: (user) {
                final id = _personId(user);
                if (id <= 0) return;
                setState(() {
                  _assignedToEmpId = id;
                  _assignedTo = user;
                  _userSearch.text = _personName(user);
                });
              },
              onPickFiles: _pickFiles,
              onSubmit: _submit,
            ),
            const SizedBox(height: 18),
            Text(
              'Visible to you',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error.isNotEmpty)
              _SuggestionEmpty(message: _error, onRetry: _load)
            else if (_items.isEmpty)
              const _SuggestionEmpty(
                message: 'No suggestions or complaints yet.',
              )
            else
              ..._items.map((item) => _SuggestionTile(item: item)),
          ],
        ),
      ),
    );
  }
}

class _SuggestionForm extends StatelessWidget {
  const _SuggestionForm({
    required this.type,
    required this.category,
    required this.priority,
    required this.types,
    required this.categories,
    required this.priorities,
    required this.subject,
    required this.message,
    required this.userSearch,
    required this.selectedUserLabel,
    required this.users,
    required this.files,
    required this.saving,
    required this.searchingUsers,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onUserSearchChanged,
    required this.onUserSelected,
    required this.onPickFiles,
    required this.onSubmit,
  });

  final String type;
  final String category;
  final String priority;
  final List<String> types;
  final List<String> categories;
  final List<String> priorities;
  final TextEditingController subject;
  final TextEditingController message;
  final TextEditingController userSearch;
  final String selectedUserLabel;
  final List<Map<String, dynamic>> users;
  final List<({String name, List<int> bytes})> files;
  final bool saving;
  final bool searchingUsers;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String> onUserSearchChanged;
  final ValueChanged<Map<String, dynamic>> onUserSelected;
  final VoidCallback onPickFiles;
  final VoidCallback onSubmit;

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
              'Suggestions & Complaints Portal',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Share ideas, feedback, or workplace concerns',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final threeCols = constraints.maxWidth > 760;
                final fields = [
                  _LabeledField(
                    label: 'Type',
                    child: _dropdown(type, types, saving, onTypeChanged),
                  ),
                  _LabeledField(
                    label: 'Category',
                    child: _dropdown(
                      category,
                      categories,
                      saving,
                      onCategoryChanged,
                    ),
                  ),
                  _LabeledField(
                    label: 'Priority',
                    child: _dropdown(
                      priority,
                      priorities,
                      saving,
                      onPriorityChanged,
                    ),
                  ),
                ];
                if (!threeCols)
                  return Column(
                    children: fields
                        .map(
                          (child) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: child,
                          ),
                        )
                        .toList(),
                  );
                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'For user',
              child: Column(
                children: [
                  TextField(
                    controller: userSearch,
                    enabled: !saving,
                    onChanged: onUserSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search and select employee',
                      prefixIcon: const Icon(Icons.person_search_rounded),
                      suffixIcon: searchingUsers
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (selectedUserLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(label: Text(selectedUserLabel)),
                    ),
                  ],
                  if (users.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: users.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final user = users[index];
                            final name =
                                '${user['name'] ?? user['employee_name'] ?? user['emp_name'] ?? user['username'] ?? user['emp_id'] ?? ''}'
                                    .trim();
                            final id =
                                '${user['emp_id'] ?? user['employee_id'] ?? user['id'] ?? ''}'
                                    .trim();
                            final designation = '${user['designation'] ?? ''}'
                                .trim();
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                child: Text(
                                  name.isEmpty
                                      ? '?'
                                      : name.characters.first.toUpperCase(),
                                ),
                              ),
                              title: Text(
                                name.isEmpty ? 'Employee $id' : name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                designation.isEmpty
                                    ? 'Employee $id'
                                    : designation,
                              ),
                              onTap: saving ? null : () => onUserSelected(user),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subject,
              enabled: !saving,
              decoration: const InputDecoration(hintText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: message,
              enabled: !saving,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText: 'Write your suggestion or complaint...',
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.45),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: saving ? null : onPickFiles,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          files.isEmpty
                              ? 'Choose files (up to 5, 10MB each)'
                              : '${files.length} file(s) selected',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: files
                    .map((file) => Chip(label: Text(file.name)))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: saving ? null : onSubmit,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  DropdownButtonFormField<String> _dropdown(
    String value,
    List<String> values,
    bool disabled,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: const InputDecoration(isDense: true),
    items: values
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: disabled ? null : onChanged,
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final createdBy = item['created_by'] is Map
        ? Map<String, dynamic>.from(item['created_by'] as Map)
        : <String, dynamic>{};
    final assignedTo = item['assigned_to'] is Map
        ? Map<String, dynamic>.from(item['assigned_to'] as Map)
        : <String, dynamic>{};
    final attachment = '${item['attachment_paths'] ?? ''}'.trim();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFDCE6FF),
          child: Icon(
            _iconFor('${item['entry_type'] ?? ''}'),
            color: AppColors.primary,
          ),
        ),
        title: Text(
          '${item['subject'] ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['message'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text('From: ${createdBy['name'] ?? item['username'] ?? '-'}'),
              Text(
                'For: ${assignedTo['name'] ?? item['assigned_to_emp_id'] ?? '-'}',
              ),
              Text(
                '${item['category'] ?? '-'} • ${item['priority'] ?? '-'} • ${item['status'] ?? '-'}',
              ),
              if (attachment.isNotEmpty) Text('Files: $attachment'),
            ],
          ),
        ),
        trailing: Text('${item['created_at'] ?? ''}'.split(' ').first),
      ),
    );
  }

  IconData _iconFor(String type) => type.toLowerCase() == 'complaint'
      ? Icons.report_problem_outlined
      : Icons.lightbulb_outline_rounded;
}

class _SuggestionEmpty extends StatelessWidget {
  const _SuggestionEmpty({required this.message, this.onRetry});
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
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
