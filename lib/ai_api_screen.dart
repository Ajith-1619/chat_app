import 'package:flutter/material.dart';

import 'chat_api.dart';

const Color _aiPrimary = Color(0xFF2864E6);

class AiApiScreen extends StatefulWidget {
  const AiApiScreen({super.key});

  @override
  State<AiApiScreen> createState() => _AiApiScreenState();
}

class _AiApiScreenState extends State<AiApiScreen> {
  late Future<Map<String, dynamic>> _future;
  final Set<int> _saving = {};

  @override
  void initState() {
    super.initState();
    _future = sharedChatApi.getAiAccess();
  }

  void _reload() {
    setState(() => _future = sharedChatApi.getAiAccess());
  }

  Future<void> _toggle(int groupId, bool enabled) async {
    setState(() => _saving.add(groupId));
    try {
      await sharedChatApi.setAiRoomAccess(groupId: groupId, enabled: enabled);
      _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving.remove(groupId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI API'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AiEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load AI access',
              subtitle: '${snapshot.error}',
              action: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final hasAccess = data['has_access'] == true;
          if (!hasAccess) {
            return const _AiEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'AI API access not enabled',
              subtitle:
                  'Ask employee 302 to assign AI API access for your account.',
            );
          }
          final provider = data['default_provider'] is Map
              ? Map<String, dynamic>.from(data['default_provider'] as Map)
              : const <String, dynamic>{};
          final rooms = data['rooms'] is List
              ? (data['rooms'] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : <Map<String, dynamic>>[];
          final channels = rooms
              .where((room) => room['type'] == 'channel')
              .toList();
          final groups = rooms
              .where((room) => room['type'] != 'channel')
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: _aiPrimary,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.auto_awesome_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${provider['provider_name'] ?? 'Open Router API'}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Toggle AI for your groups and channels. Use @ai in enabled rooms.',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (channels.isNotEmpty) ...[
                _sectionTitle(context, 'Channels'),
                ...channels.map(_roomTile),
                const SizedBox(height: 12),
              ],
              if (groups.isNotEmpty) ...[
                _sectionTitle(context, 'Groups'),
                ...groups.map(_roomTile),
              ],
              if (rooms.isEmpty)
                const _AiEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No groups or channels',
                  subtitle: 'You are not involved in any group or channel yet.',
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: _aiPrimary,
        ),
      ),
    );
  }

  Widget _roomTile(Map<String, dynamic> room) {
    final groupId = int.tryParse('${room['group_id'] ?? 0}') ?? 0;
    final enabled = room['ai_enabled'] == true;
    final saving = _saving.contains(groupId);
    final isChannel = room['type'] == 'channel';
    final subtitle = isChannel
        ? '${room['channel_kind'] ?? 'channel'} channel'
        : 'Group conversation';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        secondary: CircleAvatar(
          backgroundColor: isChannel ? _aiPrimary : const Color(0xFF35A876),
          foregroundColor: Colors.white,
          child: Icon(isChannel ? Icons.tag_rounded : Icons.groups_rounded),
        ),
        title: Text(
          '${room['name'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(enabled ? '$subtitle - @ai enabled' : subtitle),
        value: enabled,
        onChanged: saving || groupId <= 0
            ? null
            : (value) => _toggle(groupId, value),
      ),
    );
  }
}

class _AiEmptyState extends StatelessWidget {
  const _AiEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}
