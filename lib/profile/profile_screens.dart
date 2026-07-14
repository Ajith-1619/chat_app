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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showAttendance = false});

  final bool showAttendance;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  AttendanceStatus? _attendance;
  List<WorkShift> _shifts = const [];
  String? _selectedShiftId;
  String? _error;
  bool _loading = true;
  bool _updatingPhoto = false;
  bool _punching = false;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  Future<void> _loadCached() async {
    if (!widget.showAttendance) {
      final cached = await chatApi.cachedProfile();
      if (mounted && cached != null) {
        setState(() {
          _profile = cached;
          _loading = false;
        });
      }
    }
    await _load();
  }

  Future<void> _load() async {
    Object? firstError;
    final profileFuture = widget.showAttendance
        ? Future<void>.value()
        : chatApi
              .getProfile()
              .then<void>((profile) {
                if (mounted) setState(() => _profile = profile);
              })
              .catchError((Object error) {
                firstError ??= error;
              });
    final attendanceFuture = chatApi
        .getAttendance()
        .then<void>((attendance) {
          if (!mounted) return;
          setState(() {
            _attendance = attendance;
            final activeShift = attendance.shiftId;
            if (activeShift.isNotEmpty) {
              _selectedShiftId = activeShift;
            }
          });
        })
        .catchError((Object error) {
          firstError ??= error;
        });
    final shiftsFuture = chatApi
        .getShifts()
        .then<void>((shifts) {
          if (!mounted) return;
          setState(() {
            _shifts = shifts;
            if (_selectedShiftId == null && shifts.isNotEmpty) {
              _selectedShiftId = shifts.first.id;
            }
          });
        })
        .catchError((Object error) {
          firstError ??= error;
        });
    await Future.wait([profileFuture, attendanceFuture, shiftsFuture]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = !widget.showAttendance && _profile == null && firstError != null
          ? '$firstError'
          : null;
    });
  }

  Future<void> _changePhoto() async {
    if (_updatingPhoto) return;
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() => _updatingPhoto = true);
    try {
      await chatApi.updateProfilePhoto(name: file.name, bytes: file.bytes!);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  Future<void> _punch(String action) async {
    if (_punching) return;
    final isIn = action == 'in';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isIn ? 'Punch In' : 'Punch Out'),
        content: Text(
          isIn
              ? 'Confirm your attendance punch in now?'
              : 'Confirm your attendance punch out now?',
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
    );
    if (confirmed != true || !mounted) return;
    setState(() => _punching = true);
    try {
      final shiftId = _selectedShiftId ?? '';
      if (shiftId.isEmpty) {
        throw const ApiException('Select a shift first.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ApiException('Turn on GPS before punching attendance.');
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiException('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 40),
        ),
      );
      final result = isIn
          ? await chatApi.punchIn(
              shiftId: shiftId,
              latitude: position.latitude,
              longitude: position.longitude,
            )
          : await chatApi.punchOut(
              shiftId: shiftId,
              latitude: position.latitude,
              longitude: position.longitude,
            );
      if (!mounted) return;
      if (isIn) {
        await LocationTrackingService.instance.start(result.trackingToken);
      } else {
        await LocationTrackingService.instance.stop();
      }
      if (!mounted) return;
      setState(() => _attendance = result.attendance);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isIn ? 'Punched in.' : 'Punched out.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _punching = false);
    }
  }

  String _attendanceTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? '--:--' : value;
    return TimeOfDay.fromDateTime(parsed.toLocal()).format(context);
  }

  bool _hasCarryOverPunch(AttendanceStatus? attendance) {
    if (attendance == null) return false;
    if (!attendance.hasPunchedIn || attendance.hasPunchedOut) return false;
    final parsed = DateTime.tryParse(attendance.punchIn);
    if (parsed == null) return false;
    final punchDay = parsed.toLocal();
    final today = DateTime.now();
    return punchDay.year != today.year ||
        punchDay.month != today.month ||
        punchDay.day != today.day;
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final attendance = _attendance;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showAttendance ? 'Punch In / Out' : 'My profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && profile == null
          ? LoadError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  if (!widget.showAttendance) ...[
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.primary,
                            backgroundImage:
                                profile?.avatarUrl.isNotEmpty == true
                                ? NetworkImage(profile!.avatarUrl)
                                : null,
                            child: profile?.avatarUrl.isNotEmpty == true
                                ? null
                                : const Icon(
                                    Icons.person_rounded,
                                    size: 58,
                                    color: Colors.white,
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton.filled(
                              onPressed: _updatingPhoto ? null : _changePhoto,
                              icon: _updatingPhoto
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile?.name ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      profile?.designation ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 22),
                    Card(
                      child: Column(
                        children: [
                          _ProfileRow(
                            icon: Icons.badge_outlined,
                            label: 'Employee ID',
                            value: profile?.empId ?? '',
                          ),
                          _ProfileRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: profile?.email ?? '',
                          ),
                          _ProfileRow(
                            icon: Icons.phone_outlined,
                            label: 'Mobile',
                            value: profile?.mobile ?? '',
                          ),
                          _ProfileRow(
                            icon: Icons.location_on_outlined,
                            label: 'Work location',
                            value: profile?.workLocation ?? '',
                          ),
                          _ProfileRow(
                            icon: Icons.alternate_email_rounded,
                            label: 'Chat ID',
                            value: profile?.jid ?? '',
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.showAttendance) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attendance?.hasPunchedIn == true &&
                                      attendance?.hasPunchedOut != true
                                  ? 'Today attendance ? active'
                                  : 'Today attendance',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  _shifts.any(
                                    (shift) => shift.id == _selectedShiftId,
                                  )
                                  ? _selectedShiftId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Select shift',
                                prefixIcon: Icon(Icons.schedule_rounded),
                              ),
                              items: _shifts
                                  .map(
                                    (shift) => DropdownMenuItem<String>(
                                      value: shift.id,
                                      child: Text(
                                        '${shift.name} - ${shift.time}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: attendance?.hasPunchedIn == true
                                  ? null
                                  : (value) => setState(
                                      () => _selectedShiftId = value,
                                    ),
                            ),
                            const SizedBox(height: 16),
                            if (attendance?.hasPunchedIn == true &&
                                attendance?.hasPunchedOut != true)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AttendanceTime(
                                  label: 'Login timer',
                                  value: _activePunchDuration(
                                    attendance?.punchIn ?? '',
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: _AttendanceTime(
                                    label: 'Punch In',
                                    value: _attendanceTime(
                                      attendance?.punchIn ?? '',
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _AttendanceTime(
                                    label: 'Punch Out',
                                    value: _attendanceTime(
                                      attendance?.punchOut ?? '',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_hasCarryOverPunch(attendance))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Previous working day punch-out is pending. Please punch out first, then punch in for today.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: Builder(
                                    builder: (_) {
                                      final hasActivePunch =
                                          attendance?.hasPunchedIn ?? false;
                                      final hasClosedPunch =
                                          attendance?.hasPunchedOut ?? false;
                                      final hasCarryOverPunch =
                                          _hasCarryOverPunch(attendance);
                                      return FilledButton.icon(
                                        onPressed:
                                            _punching ||
                                                hasActivePunch ||
                                                hasCarryOverPunch ||
                                                hasClosedPunch
                                            ? null
                                            : () => _punch('in'),
                                        icon: const Icon(Icons.login_rounded),
                                        label: const Text('Punch In'),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Builder(
                                    builder: (_) {
                                      return OutlinedButton.icon(
                                        onPressed: _punching
                                            ? null
                                            : () => _punch('out'),
                                        icon: const Icon(Icons.logout_rounded),
                                        label: const Text('Punch Out'),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last 7 days punch report',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if ((attendance?.lastSevenDays ?? const []).isEmpty)
                              const Text(
                                'No punch records found for the last 7 days.',
                                style: TextStyle(color: AppColors.muted),
                              )
                            else
                              ...attendance!.lastSevenDays.map(
                                (day) => _AttendanceReportTile(
                                  day: day,
                                  timeFormatter: _attendanceTime,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _activePunchDuration(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '--:--';
    final diff = DateTime.now().difference(parsed.toLocal());
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label),
          subtitle: Text(value.isEmpty ? '-' : value),
        ),
        if (showDivider) const Divider(height: 1, indent: 56),
      ],
    );
  }
}

class _AttendanceTime extends StatelessWidget {
  const _AttendanceTime({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

class _AttendanceReportTile extends StatelessWidget {
  const _AttendanceReportTile({required this.day, required this.timeFormatter});

  final AttendanceDay day;
  final String Function(String value) timeFormatter;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_available_outlined),
      title: Text(day.date),
      subtitle: Text(
        'In ${timeFormatter(day.punchIn)} - Out ${timeFormatter(day.punchOut)}\n'
        'Work ${day.workingHours} - Shift ${day.shiftTime.isEmpty ? '-' : day.shiftTime}',
      ),
      trailing: Text(
        day.status,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  AttendanceStatus? _attendance;
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
      final attendance = await chatApi.getAttendance();
      if (!mounted) return;
      setState(() => _attendance = attendance);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _time(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? '--:--' : value;
    return TimeOfDay.fromDateTime(parsed.toLocal()).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _attendance?.monthDays ?? const <AttendanceDay>[];
    final byDate = {for (final row in rows) row.date: row};
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final offset = first.weekday % 7;
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? LoadError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${_monthName(now.month)} ${now.year}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                    itemCount: offset + daysInMonth,
                    itemBuilder: (_, index) {
                      if (index < offset) return const SizedBox.shrink();
                      final dayNumber = index - offset + 1;
                      final date =
                          '${now.year}-${now.month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
                      final row = byDate[date];
                      return Card(
                        color: row == null
                            ? null
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNumber',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(
                                row == null
                                    ? Icons.remove_rounded
                                    : Icons.check_circle_rounded,
                                size: 16,
                                color: row == null
                                    ? AppColors.muted
                                    : Colors.green,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Monthly punch details',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No attendance records found this month.'),
                      ),
                    )
                  else
                    ...rows.map(
                      (day) => Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _AttendanceReportTile(
                            day: day,
                            timeFormatter: _time,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  List<AppSession> _sessions = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await chatApi.getSessions();
      if (mounted) setState(() => _sessions = sessions);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active sessions')),
      body: _error != null
          ? LoadError(message: _error!, onRetry: _load)
          : _sessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _sessions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final session = _sessions[index];
                return ListTile(
                  leading: Icon(
                    session.platform == 'android' || session.platform == 'ios'
                        ? Icons.smartphone_rounded
                        : Icons.computer_rounded,
                  ),
                  title: Text(session.deviceName),
                  subtitle: Text(
                    '${session.platform} - ${session.source}\n'
                    'Last active: ${session.lastSeen}'
                    '${session.ipAddress.isEmpty ? '' : ' - ${session.ipAddress}'}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
    );
  }
}



