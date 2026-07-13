import 'package:flutter/material.dart';

import 'app_cache.dart';
import 'chat_api.dart';
import 'notification_service.dart';

final ChatApi _myHubTaskApi = sharedChatApi;

const _taskSnapshotCacheKey = 'myhub_task_snapshot_v2';

enum _TaskFilter {
  all('All'),
  open('Open'),
  requestClose('Request close'),
  closed('Closed'),
  createdByMe('Created by me'),
  following('Following'),
  dueToday('Due today'),
  overdue('Overdue'),
  stale('Stale');

  const _TaskFilter(this.label);
  final String label;
}

class MyHubTasksScreen extends StatefulWidget {
  const MyHubTasksScreen({super.key});

  @override
  State<MyHubTasksScreen> createState() => _MyHubTasksScreenState();
}

class _MyHubTasksScreenState extends State<MyHubTasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _updateController = TextEditingController();
  Map<String, dynamic>? _tasksData;
  Map<String, dynamic>? _selectedTaskDetail;
  bool _loadingList = true;
  bool _loadingDetail = false;
  bool _sendingUpdate = false;
  String _listError = '';
  String _detailError = '';
  int? _selectedTaskId;
  _TaskFilter _activeFilter = _TaskFilter.all;
  List<_TaskAlertSummary> _taskAlerts = const [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _updateController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({bool keepSelection = true}) async {
    setState(() {
      _loadingList = true;
      _listError = '';
    });
    try {
      final data = await _myHubTaskApi.getMyHubTasks(forceRefresh: true);
      final tasks = _extractTasks(data);
      final alerts = _buildAlertSummaries(tasks);
      await _handleTaskNotifications(tasks);
      if (!mounted) return;
      setState(() {
        _tasksData = data;
        _taskAlerts = alerts;
        _loadingList = false;
      });
      if (tasks.isEmpty) {
        setState(() {
          _selectedTaskId = null;
          _selectedTaskDetail = null;
        });
        return;
      }
      final preferredId = keepSelection ? _selectedTaskId : null;
      final firstId = int.tryParse('${tasks.first['id'] ?? 0}') ?? 0;
      final targetId =
          tasks.any((t) => int.tryParse('${t['id'] ?? 0}') == preferredId)
          ? preferredId!
          : firstId;
      await _loadTaskDetail(targetId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = error.toString();
      });
    }
  }

  List<Map<String, dynamic>> _extractTasks(Map<String, dynamic>? data) {
    final raw = data?['tasks'];
    return raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> _loadTaskDetail(int taskId) async {
    if (taskId <= 0) return;
    setState(() {
      _selectedTaskId = taskId;
      _loadingDetail = true;
      _detailError = '';
    });
    try {
      final data = await _myHubTaskApi.getMyHubTaskDetail(taskId);
      if (!mounted) return;
      setState(() {
        _selectedTaskDetail = data;
        _loadingDetail = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _detailError = error.toString();
      });
    }
  }

  Future<void> _openMobileDetail(Map<String, dynamic> task) async {
    final taskId = int.tryParse('${task['id'] ?? 0}') ?? 0;
    if (taskId <= 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TaskDetailPage(
          taskId: taskId,
          initialTitle: '${task['title'] ?? 'Task'}',
        ),
      ),
    );
    if (!mounted) return;
    await _loadTasks();
  }

  Future<void> _sendUpdate(int taskId, {String? presetText}) async {
    final text = (presetText ?? _updateController.text).trim();
    if (text.isEmpty) return;
    setState(() => _sendingUpdate = true);
    try {
      await _myHubTaskApi.updateMyHubTask(taskId: taskId, comments: text);
      if (presetText == null) {
        _updateController.clear();
      }
      await _loadTaskDetail(taskId);
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sendingUpdate = false);
    }
  }

  List<_TaskAlertSummary> _buildAlertSummaries(
    List<Map<String, dynamic>> tasks,
  ) {
    final dueToday = tasks.where(_isDueToday).length;
    final overdue = tasks.where(_isOverdue).length;
    final stale = tasks.where(_isStale).length;
    final closed = tasks.where(_isClosedTask).length;
    final open = tasks.where(_isOpenTask).length;
    return [
      _TaskAlertSummary(
        label: 'Open',
        count: open,
        icon: Icons.work_outline_rounded,
        color: Colors.blue,
      ),
      _TaskAlertSummary(
        label: 'Due today',
        count: dueToday,
        icon: Icons.today_rounded,
        color: Colors.amber,
      ),
      _TaskAlertSummary(
        label: 'Overdue',
        count: overdue,
        icon: Icons.warning_amber_rounded,
        color: Colors.deepOrange,
      ),
      _TaskAlertSummary(
        label: 'Stale',
        count: stale,
        icon: Icons.schedule_send_rounded,
        color: Colors.purple,
      ),
      _TaskAlertSummary(
        label: 'Closed',
        count: closed,
        icon: Icons.task_alt_rounded,
        color: Colors.green,
      ),
    ];
  }

  Future<void> _handleTaskNotifications(
    List<Map<String, dynamic>> tasks,
  ) async {
    final cached = await AppCache.instance.readJson(_taskSnapshotCacheKey);
    final previous = <String, Map<String, dynamic>>{};
    if (cached is Map) {
      for (final entry in cached.entries) {
        if (entry.value is Map) {
          previous['${entry.key}'] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      }
    }

    final current = <String, Map<String, dynamic>>{};
    for (final task in tasks) {
      final id = '${task['id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      final status = _taskStatus(task);
      final dueToday = _isDueToday(task);
      final overdue = _isOverdue(task);
      final stale = _isStale(task);
      current[id] = {
        'title': '${task['title'] ?? 'Task'}',
        'status': status,
        'due_today': dueToday,
        'overdue': overdue,
        'stale': stale,
      };

      final before = previous[id];
      if (before == null) continue;
      final title = '${task['title'] ?? 'Task'}';
      if ((before['status'] ?? -1) != status) {
        await NotificationService.instance.showMessage(
          sender: 'Tasks',
          message: '$title is now ${_statusLabel(status)}.',
          jid: 'task-$id-status',
        );
      }
      if ((before['due_today'] ?? false) != true && dueToday) {
        await NotificationService.instance.showMessage(
          sender: 'Tasks',
          message: '$title is due today.',
          jid: 'task-$id-due',
        );
      }
      if ((before['overdue'] ?? false) != true && overdue) {
        await NotificationService.instance.showMessage(
          sender: 'Tasks',
          message: '$title is overdue.',
          jid: 'task-$id-overdue',
        );
      }
      if ((before['stale'] ?? false) != true && stale) {
        await NotificationService.instance.showMessage(
          sender: 'Tasks',
          message: '$title has gone stale and needs follow-up.',
          jid: 'task-$id-stale',
        );
      }
    }

    await AppCache.instance.writeJson(_taskSnapshotCacheKey, current);
  }

  bool _matchesFilter(Map<String, dynamic> task) {
    return switch (_activeFilter) {
      _TaskFilter.all => true,
      _TaskFilter.open => _isOpenTask(task),
      _TaskFilter.requestClose => _taskStatus(task) == 1,
      _TaskFilter.closed => _isClosedTask(task),
      _TaskFilter.createdByMe => _isCreatedByCurrentUser(task),
      _TaskFilter.following => _isFollowedByCurrentUser(task),
      _TaskFilter.dueToday => _isDueToday(task),
      _TaskFilter.overdue => _isOverdue(task),
      _TaskFilter.stale => _isStale(task),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _extractTasks(_tasksData);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = tasks
        .where((task) {
          if (query.isEmpty) return true;
          final id = '${task['id'] ?? ''}'.toLowerCase();
          final title = '${task['title'] ?? ''}'.toLowerCase();
          final desc = '${task['description'] ?? ''}'.toLowerCase();
          return id.contains(query) ||
              title.contains(query) ||
              desc.contains(query);
        })
        .where(_matchesFilter)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tasks & Tickets'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _loadTasks(keepSelection: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: _loadingList
              ? const Center(child: CircularProgressIndicator())
              : _listError.isNotEmpty
              ? _TaskErrorView(message: _listError, onRetry: _loadTasks)
              : wide
              ? Row(
                  children: [
                    SizedBox(
                      width: 390,
                      child: _TaskListPane(
                        tasks: filtered,
                        allTasks: tasks,
                        alerts: _taskAlerts,
                        activeFilter: _activeFilter,
                        searchController: _searchController,
                        selectedTaskId: _selectedTaskId,
                        onSearchChanged: (_) => setState(() {}),
                        onFilterChanged: (filter) =>
                            setState(() => _activeFilter = filter),
                        onTaskTap: (task) {
                          final id = int.tryParse('${task['id'] ?? 0}') ?? 0;
                          _loadTaskDetail(id);
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _TaskDetailPane(
                        detail: _selectedTaskDetail,
                        loading: _loadingDetail,
                        error: _detailError,
                        updateController: _updateController,
                        sendingUpdate: _sendingUpdate,
                        onRetry: _selectedTaskId == null
                            ? null
                            : () => _loadTaskDetail(_selectedTaskId!),
                        onSendUpdate: _selectedTaskId == null
                            ? null
                            : () => _sendUpdate(_selectedTaskId!),
                        onQuickUpdate: _selectedTaskId == null
                            ? null
                            : (text) => _sendUpdate(
                                _selectedTaskId!,
                                presetText: text,
                              ),
                      ),
                    ),
                  ],
                )
              : _TaskListPane(
                  tasks: filtered,
                  allTasks: tasks,
                  alerts: _taskAlerts,
                  activeFilter: _activeFilter,
                  searchController: _searchController,
                  selectedTaskId: _selectedTaskId,
                  onSearchChanged: (_) => setState(() {}),
                  onFilterChanged: (filter) =>
                      setState(() => _activeFilter = filter),
                  onTaskTap: _openMobileDetail,
                ),
        );
      },
    );
  }
}

class _TaskListPane extends StatelessWidget {
  const _TaskListPane({
    required this.tasks,
    required this.allTasks,
    required this.alerts,
    required this.activeFilter,
    required this.searchController,
    required this.selectedTaskId,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onTaskTap,
  });

  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> allTasks;
  final List<_TaskAlertSummary> alerts;
  final _TaskFilter activeFilter;
  final TextEditingController searchController;
  final int? selectedTaskId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_TaskFilter> onFilterChanged;
  final ValueChanged<Map<String, dynamic>> onTaskTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search tasks',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.85,
            ),
            itemCount: alerts.length,
            itemBuilder: (context, index) =>
                _TaskSummaryCard(summary: alerts[index]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final filter in _TaskFilter.values)
                  Builder(
                    builder: (context) {
                      final count = allTasks.where((task) {
                        return switch (filter) {
                          _TaskFilter.all => true,
                          _TaskFilter.open => _isOpenTask(task),
                          _TaskFilter.requestClose => _taskStatus(task) == 1,
                          _TaskFilter.closed => _isClosedTask(task),
                          _TaskFilter.createdByMe => _isCreatedByCurrentUser(task),
                          _TaskFilter.following => _isFollowedByCurrentUser(task),
                          _TaskFilter.dueToday => _isDueToday(task),
                          _TaskFilter.overdue => _isOverdue(task),
                          _TaskFilter.stale => _isStale(task),
                        };
                      }).length;
                      return FilterChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text('${filter.label} $count'),
                        selected: filter == activeFilter,
                        onSelected: (_) => onFilterChanged(filter),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? const Center(child: Text('No tasks found.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final id = int.tryParse('${task['id'] ?? 0}') ?? 0;
                    final selected = id == selectedTaskId;
                    final priority = '${task['priority'] ?? 'm'}'.toUpperCase();
                    final status = _taskStatus(task);
                    final due = '${task['deadline'] ?? ''}'.trim();
                    final overdue = _isOverdue(task);
                    final stale = _isStale(task);
                    final dueToday = _isDueToday(task);
                    return Material(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onTaskTap(task),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${task['title'] ?? 'Task'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _TaskPill(label: 'P$priority'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${task['description'] ?? ''}'.trim().isEmpty
                                    ? 'No description added'
                                    : '${task['description'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _TaskPill(label: _statusLabel(status)),
                                  if (due.isNotEmpty)
                                    _TaskPill(label: 'Due $due'),
                                  if (dueToday)
                                    const _TaskFlag(
                                      label: 'Today',
                                      color: Colors.amber,
                                    ),
                                  if (overdue)
                                    const _TaskFlag(
                                      label: 'Overdue',
                                      color: Colors.deepOrange,
                                    ),
                                  if (stale)
                                    const _TaskFlag(
                                      label: 'Stale',
                                      color: Colors.purple,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TaskDetailPane extends StatelessWidget {
  const _TaskDetailPane({
    required this.detail,
    required this.loading,
    required this.error,
    required this.updateController,
    required this.sendingUpdate,
    required this.onRetry,
    required this.onSendUpdate,
    required this.onQuickUpdate,
  });

  final Map<String, dynamic>? detail;
  final bool loading;
  final String error;
  final TextEditingController updateController;
  final bool sendingUpdate;
  final VoidCallback? onRetry;
  final VoidCallback? onSendUpdate;
  final ValueChanged<String>? onQuickUpdate;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error.isNotEmpty) {
      return _TaskErrorView(message: error, onRetry: onRetry);
    }
    final task = detail?['task'] is Map
        ? Map<String, dynamic>.from(detail!['task'] as Map)
        : null;
    final updates = detail?['updates'] is List
        ? (detail!['updates'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    if (task == null) {
      return const Center(child: Text('Select a task to view details.'));
    }
    final assignees = task['assignees'] is List
        ? (task['assignees'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    final followers = task['followers'] is List
        ? (task['followers'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    final creator = task['creator'] is Map
        ? Map<String, dynamic>.from(task['creator'] as Map)
        : null;
    final status = _taskStatus(task);
    final dueToday = _isDueToday(task);
    final overdue = _isOverdue(task);
    final stale = _isStale(task);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${task['title'] ?? 'Task'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TaskPill(label: _statusLabel(status)),
                  _TaskPill(
                    label:
                        'Priority ${'${task['priority'] ?? 'm'}'.toUpperCase()}',
                  ),
                  if ('${task['deadline'] ?? ''}'.trim().isNotEmpty)
                    _TaskPill(label: 'Due ${task['deadline']}'),
                ],
              ),
              if (dueToday || overdue || stale) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (dueToday)
                      const _TaskAlertBanner(
                        icon: Icons.today_rounded,
                        title: 'Due today',
                        message:
                            'This task needs attention before the day closes.',
                        color: Colors.amber,
                      ),
                    if (overdue)
                      const _TaskAlertBanner(
                        icon: Icons.warning_amber_rounded,
                        title: 'Overdue',
                        message:
                            'Due date has passed. Please update the task state.',
                        color: Colors.deepOrange,
                      ),
                    if (stale)
                      const _TaskAlertBanner(
                        icon: Icons.schedule_send_rounded,
                        title: 'Stale alert',
                        message:
                            'This task has been overdue for more than 48 hours.',
                        color: Colors.purple,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _TaskInfoCard(
                title: 'Description',
                child: Text(
                  '${task['description'] ?? ''}'.trim().isEmpty
                      ? 'No description added'
                      : '${task['description'] ?? ''}',
                ),
              ),
              const SizedBox(height: 14),
              _TaskInfoCard(
                title: 'People',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (creator != null) ...[
                      _TaskPersonRow(label: 'Created by', person: creator),
                      const SizedBox(height: 12),
                    ],
                    _TaskPeopleSection(label: 'Assignees', people: assignees),
                    const SizedBox(height: 12),
                    _TaskPeopleSection(label: 'Followers', people: followers),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Updates',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (updates.isEmpty)
                const _EmptyThreadCard(message: 'No updates yet.')
              else
                ...updates.map((update) => _TaskUpdateBubble(update: update)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onQuickUpdate != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickUpdateChip(
                          label: 'Started',
                          onTap: () => onQuickUpdate!.call('Task started.'),
                        ),
                        _QuickUpdateChip(
                          label: 'Follow up',
                          onTap: () =>
                              onQuickUpdate!.call('Follow-up completed.'),
                        ),
                        _QuickUpdateChip(
                          label: 'Blocked',
                          onTap: () => onQuickUpdate!.call(
                            'Task is blocked. Need support.',
                          ),
                        ),
                        _QuickUpdateChip(
                          label: 'Close req',
                          onTap: () =>
                              onQuickUpdate!.call('Requesting task closure.'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: updateController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Add a task update',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: sendingUpdate ? null : onSendUpdate,
                      icon: sendingUpdate
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Update'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskDetailPage extends StatefulWidget {
  const _TaskDetailPage({required this.taskId, required this.initialTitle});

  final int taskId;
  final String initialTitle;

  @override
  State<_TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<_TaskDetailPage> {
  final TextEditingController _updateController = TextEditingController();
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _sending = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await _myHubTaskApi.getMyHubTaskDetail(widget.taskId);
      if (!mounted) return;
      setState(() {
        _detail = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _send({String? presetText}) async {
    final text = (presetText ?? _updateController.text).trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _myHubTaskApi.updateMyHubTask(
        taskId: widget.taskId,
        comments: text,
      );
      if (presetText == null) {
        _updateController.clear();
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initialTitle)),
      body: _TaskDetailPane(
        detail: _detail,
        loading: _loading,
        error: _error,
        updateController: _updateController,
        sendingUpdate: _sending,
        onRetry: _load,
        onSendUpdate: _send,
        onQuickUpdate: (text) => _send(presetText: text),
      ),
    );
  }
}

class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TaskPeopleSection extends StatelessWidget {
  const _TaskPeopleSection({required this.label, required this.people});

  final String label;
  final List<Map<String, dynamic>> people;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (people.isEmpty)
          Text(
            'No users added',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: people
                .map(
                  (person) => Chip(
                    avatar: CircleAvatar(
                      child: Text(
                        _initials(
                          '${person['name'] ?? person['emp_id'] ?? ''}',
                        ),
                      ),
                    ),
                    label: Text('${person['name'] ?? person['emp_id']}'),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _TaskPersonRow extends StatelessWidget {
  const _TaskPersonRow({required this.label, required this.person});

  final String label;
  final Map<String, dynamic> person;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(
            '${person['name'] ?? person['emp_id']} ${'${person['designation'] ?? ''}'.trim().isEmpty ? '' : '- ${person['designation']}'}',
          ),
        ),
      ],
    );
  }
}

class _TaskUpdateBubble extends StatelessWidget {
  const _TaskUpdateBubble({required this.update});

  final Map<String, dynamic> update;

  @override
  Widget build(BuildContext context) {
    final author =
        '${update['updated_by_name'] ?? update['updated_by'] ?? 'Unknown'}';
    final designation = '${update['updated_by_designation'] ?? ''}'.trim();
    final type = '${update['comment_type'] ?? 'Update'}';
    final createdAt = '${update['created_at'] ?? ''}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  author,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (designation.isNotEmpty) _TaskPill(label: designation),
                _TaskPill(label: type),
              ],
            ),
            const SizedBox(height: 8),
            Text('${update['comments'] ?? ''}'),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                createdAt,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({required this.summary});

  final _TaskAlertSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: summary.color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(summary.icon, size: 20, color: summary.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.count}',
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: summary.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskAlertBanner extends StatelessWidget {
  const _TaskAlertBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickUpdateChip extends StatelessWidget {
  const _QuickUpdateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.bolt_rounded, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _TaskFlag extends StatelessWidget {
  const _TaskFlag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TaskPill extends StatelessWidget {
  const _TaskPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _EmptyThreadCard extends StatelessWidget {
  const _EmptyThreadCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}

class _TaskErrorView extends StatelessWidget {
  const _TaskErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            const Text('Unable to load tasks'),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry == null ? null : () => onRetry!.call(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskAlertSummary {
  const _TaskAlertSummary({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
}

int _taskStatus(Map<String, dynamic> task) =>
    int.tryParse('${task['status'] ?? 0}') ?? 0;

DateTime? _taskDeadline(Map<String, dynamic> task) {
  final raw = '${task['deadline'] ?? ''}'.trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
}

bool _isDueToday(Map<String, dynamic> task) {
  if (_isClosedTask(task)) return false;
  final deadline = _taskDeadline(task);
  if (deadline == null) return false;
  final now = DateTime.now();
  return deadline.year == now.year &&
      deadline.month == now.month &&
      deadline.day == now.day;
}

bool _isOverdue(Map<String, dynamic> task) {
  if (_isClosedTask(task)) return false;
  final deadline = _taskDeadline(task);
  if (deadline == null) return false;
  return deadline.isBefore(DateTime.now());
}

bool _isStale(Map<String, dynamic> task) {
  if (_isClosedTask(task)) return false;
  final deadline = _taskDeadline(task);
  if (deadline == null) return false;
  return DateTime.now().difference(deadline).inHours >= 48;
}

bool _isClosedTask(Map<String, dynamic> task) {
  final status = _taskStatus(task);
  return status == 3 || status == 4 || status == 5;
}

bool _isOpenTask(Map<String, dynamic> task) =>
    _taskStatus(task) != 1 && !_isClosedTask(task);

int _currentTaskEmpId() =>
    int.tryParse(_myHubTaskApi.currentJid.split('@').first.trim()) ?? 0;

List<int> _taskCsvIds(dynamic value) => '${value ?? ''}'
    .split(',')
    .map((part) => int.tryParse(part.trim()))
    .whereType<int>()
    .where((id) => id > 0)
    .toList();

bool _isCreatedByCurrentUser(Map<String, dynamic> task) {
  final empId = _currentTaskEmpId();
  if (empId <= 0) return false;
  return int.tryParse('${task['created_by'] ?? 0}') == empId;
}

bool _isFollowedByCurrentUser(Map<String, dynamic> task) {
  final empId = _currentTaskEmpId();
  if (empId <= 0) return false;
  return _taskCsvIds(task['follower_ids'] ?? task['task_followers']).contains(empId);
}

String _statusLabel(int status) {
  return switch (status) {
    1 => 'Request close',
    3 || 4 || 5 => 'Closed',
    _ => 'Open',
  };
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
