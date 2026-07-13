import 'package:flutter/material.dart';

import 'chat_api.dart';

final ChatApi _myHubLeaveApi = sharedChatApi;

class MyHubLeaveScreen extends StatefulWidget {
  const MyHubLeaveScreen({super.key});

  @override
  State<MyHubLeaveScreen> createState() => _MyHubLeaveScreenState();
}

class _MyHubLeaveScreenState extends State<MyHubLeaveScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _myHubLeaveApi.getMyHubLeaves();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _myHubLeaveApi.getMyHubLeaves();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        actions: [
          IconButton(
            tooltip: 'Apply leave',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MyHubLeaveApplyScreen(),
                ),
              );
              if (!mounted) return;
              await _reload();
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load leave requests',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final leaves = snapshot.data ?? const <Map<String, dynamic>>[];
          if (leaves.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_busy_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No leave requests yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: leaves.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = leaves[index];
                final from = '${item['from_date'] ?? '-'}';
                final to = '${item['to_date'] ?? '-'}';
                final reason = '${item['reason'] ?? ''}'.trim();
                final statusCode =
                    int.tryParse('${item['approval_status'] ?? 0}') ?? 0;
                final statusLabel = switch (statusCode) {
                  1 => 'Approved',
                  2 => 'Rejected',
                  _ => 'Pending',
                };
                final statusColor = switch (statusCode) {
                  1 => Colors.green,
                  2 => Colors.red,
                  _ => Colors.orange,
                };
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.12),
                      foregroundColor: statusColor,
                      child: const Icon(Icons.beach_access_outlined),
                    ),
                    title: Text('$from to $to'),
                    subtitle: Text(
                      reason.isEmpty ? 'Leave request' : reason,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Chip(label: Text(statusLabel)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class MyHubLeaveApplyScreen extends StatefulWidget {
  const MyHubLeaveApplyScreen({super.key});

  @override
  State<MyHubLeaveApplyScreen> createState() => _MyHubLeaveApplyScreenState();
}

class _MyHubLeaveApplyScreenState extends State<MyHubLeaveApplyScreen> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _fromDate;
  DateTime? _toDate;
  int _leaveTypeId = 2;
  bool _submitting = false;
  double _noOfDays = 0;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _recalculateDays() {
    if (_fromDate == null || _toDate == null) {
      setState(() => _noOfDays = 0);
      return;
    }
    final from = DateUtils.dateOnly(_fromDate!);
    final to = DateUtils.dateOnly(_toDate!);
    if (to.isBefore(from)) {
      setState(() => _noOfDays = 0);
      return;
    }
    setState(() => _noOfDays = to.difference(from).inDays + 1);
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = picked;
        }
      } else {
        _toDate = picked;
      }
    });
    _recalculateDays();
  }

  String _dateText(DateTime? value) {
    if (value == null) return 'Select date';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose from and to dates.')),
      );
      return;
    }
    if (_toDate!.isBefore(_fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To date must be after from date.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final fromDate = _dateText(_fromDate);
      final toDate = _dateText(_toDate);
      final reason = _reasonController.text.trim();
      final otpRequest = await _myHubLeaveApi.requestMyHubLeaveOtp(
        fromDate: fromDate,
        toDate: toDate,
        leaveTypeId: _leaveTypeId,
        reason: reason,
      );
      if (!mounted) return;
      final otp = await _askOtpDialog(
        context,
        days: '${otpRequest['no_of_days'] ?? _noOfDays}',
      );
      if (otp == null || otp.isEmpty) return;
      final result = await _myHubLeaveApi.applyMyHubLeave(
        fromDate: fromDate,
        toDate: toDate,
        leaveTypeId: _leaveTypeId,
        reason: reason,
        otp: otp,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['message'] ?? 'Leave request submitted.'} Days: ${result['no_of_days'] ?? _noOfDays}',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _askOtpDialog(
    BuildContext context, {
    required String days,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter leave OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No. of days: $days'),
            const SizedBox(height: 8),
            const Text(
              'OTP was sent to employee 232 through system notifications.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Application')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _leaveTypeId,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Casual Leave')),
                DropdownMenuItem(value: 2, child: Text('Sick Leave')),
                DropdownMenuItem(value: 3, child: Text('Permission')),
                DropdownMenuItem(value: 4, child: Text('Other Leave')),
              ],
              onChanged: (value) => setState(() => _leaveTypeId = value ?? 2),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: Text(_dateText(_fromDate)),
              subtitle: const Text('From date'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _submitting ? null : () => _pickDate(from: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(_dateText(_toDate)),
              subtitle: const Text('To date'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _submitting ? null : () => _pickDate(from: false),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: const Text('No. of days'),
                subtitle: Text(
                  _noOfDays <= 0
                      ? '--'
                      : _noOfDays.toStringAsFixed(
                          _noOfDays.truncateToDouble() == _noOfDays ? 0 : 1,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please enter a reason'
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('Request OTP and submit leave'),
            ),
          ],
        ),
      ),
    );
  }
}
