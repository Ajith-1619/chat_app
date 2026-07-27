import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_api.dart';

const Color _accessPrimary = Color(0xFF2864E6);

class AiAccessManagementScreen extends StatefulWidget {
  const AiAccessManagementScreen({super.key});

  @override
  State<AiAccessManagementScreen> createState() =>
      _AiAccessManagementScreenState();
}

class _AiAccessManagementScreenState extends State<AiAccessManagementScreen> {
  late Future<Map<String, dynamic>> _future;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _saving = {};
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _future = sharedChatApi.getAiUserAccess();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reload({String? query}) {
    setState(() {
      _future = sharedChatApi.getAiUserAccess(
        query: query ?? _searchController.text,
      );
    });
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reload(query: value);
    });
  }

  Future<void> _setAccess(Map<String, dynamic> user, bool enabled) async {
    final empId = int.tryParse('${user['emp_id'] ?? 0}') ?? 0;
    if (empId <= 0) return;
    setState(() => _saving.add(empId));
    try {
      await sharedChatApi.setAiUserAccess(
        empId: empId,
        enabled: enabled,
        providerIds: enabled ? '${user['provider_ids'] ?? ''}' : '',
        dailyTokenLimit: int.tryParse('${user['daily_token_limit'] ?? 0}') ?? 0,
        dailySearchLimit:
            int.tryParse('${user['daily_search_limit'] ?? 0}') ?? 0,
      );
      _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving.remove(empId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Access'),
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
            return _AccessEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load API access',
              subtitle: '${snapshot.error}',
              action: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final providers = data['providers'] is List
              ? (data['providers'] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : <Map<String, dynamic>>[];
          final users = data['users'] is List
              ? (data['users'] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : <Map<String, dynamic>>[];
          final defaultProviderId = '${data['default_provider_id'] ?? 2}';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: _accessPrimary,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.admin_panel_settings_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI API user access',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Only enabled users will see the AI API menu. Default provider is Open Router API.',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search users',
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _reload(query: '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ProviderSummary(providers: providers),
              const SizedBox(height: 16),
              Text(
                'Users',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (users.isEmpty)
                const _AccessEmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No users found',
                  subtitle: 'Try another employee name or ID.',
                )
              else
                ...users.map(
                  (user) =>
                      _userTile(user, defaultProviderId: defaultProviderId),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _userTile(
    Map<String, dynamic> user, {
    required String defaultProviderId,
  }) {
    final empId = int.tryParse('${user['emp_id'] ?? 0}') ?? 0;
    final enabled = user['has_ai_access'] == true;
    final saving = _saving.contains(empId);
    if (enabled && '${user['provider_ids'] ?? ''}'.trim().isEmpty) {
      user['provider_ids'] = defaultProviderId;
    }
    final initials = _initials('${user['name'] ?? empId}');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        secondary: CircleAvatar(
          backgroundColor: enabled ? _accessPrimary : const Color(0xFFE9EEF7),
          foregroundColor: enabled ? Colors.white : const Color(0xFF52607A),
          child: Text(initials),
        ),
        title: Text(
          '${user['name'] ?? empId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          enabled
              ? 'AI API enabled - provider ${user['provider_ids'] ?? defaultProviderId}'
              : '${user['designation'] ?? ''}'.trim().isEmpty
              ? 'AI API disabled'
              : '${user['designation']} - AI API disabled',
        ),
        value: enabled,
        onChanged: saving || empId <= 0
            ? null
            : (value) {
                if (value && '${user['provider_ids'] ?? ''}'.trim().isEmpty) {
                  user['provider_ids'] = defaultProviderId;
                }
                _setAccess(user, value);
              },
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'AI';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _ProviderSummary extends StatelessWidget {
  const _ProviderSummary({required this.providers});

  final List<Map<String, dynamic>> providers;

  @override
  Widget build(BuildContext context) {
    final active = providers.where((provider) => provider['active'] == true);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available AI providers',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (active.isEmpty)
              const Text('No active provider configured.')
            else
              ...active.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2EA66F),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${provider['id']}. ${provider['title'] ?? 'AI Provider'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

class _AccessEmptyState extends StatelessWidget {
  const _AccessEmptyState({
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
            Icon(icon, size: 52, color: colors.onSurfaceVariant),
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
