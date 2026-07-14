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

final chatApi = sharedChatApi;
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
final appMessageScale = ValueNotifier<double>(1.0);
final appChatDensity = ValueNotifier<double>(1.0);

Future<void> requestAttachmentStoragePermission(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return;
  final status = await ph.Permission.storage.status;
  if (status.isGranted) return;
  final result = await ph.Permission.storage.request();
  if (!result.isGranted && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Storage permission denied. Files will be saved in app storage.',
        ),
      ),
    );
  }
}

Future<String> voiceRecordingFilePath() async {
  final baseDir = await getApplicationDocumentsDirectory();
  final dir = Directory(
    '${baseDir.path}${Platform.pathSeparator}voice_recordings',
  );
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return '${dir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

final appShowAvatars = ValueNotifier<bool>(true);
final appCollapseLongMessages = ValueNotifier<bool>(true);
final appWorkspaceMode = ValueNotifier<String>('three_pane');
const _androidPlatform = MethodChannel('skylink/android_settings');
const androidPlatform = _androidPlatform;

Future<void> logout(BuildContext context) async {
  chatApi.logout();
  try {
    await SessionStore.instance.clear();
  } finally {
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }
}


class AppColors {
  static const primary = Color(0xFF2864DC);
  static const primaryDark = Color(0xFF1748B5);
  static const sky = Color(0xFF5BA8FF);
  static const background = Color(0xFFF4F7FC);
  static const text = Color(0xFF17223B);
  static const muted = Color(0xFF74809A);
  static const divider = Color(0xFFE8EDF5);
  static const online = Color(0xFF29B87A);
  static const outgoing = Color(0xFFDDEBFF);
}

class SkylinkApp extends StatelessWidget {
  const SkylinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (_, themeMode, _) => MaterialApp(
        title: 'Skylink',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            surface: Colors.white,
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
            titleLarge: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
            bodyLarge: TextStyle(color: AppColors.text),
            bodyMedium: TextStyle(color: AppColors.text),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF6F8FC),
            hintStyle: const TextStyle(color: AppColors.muted),
            prefixIconColor: AppColors.muted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.6,
              ),
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF10151D),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1A2230),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: const VersionGate(child: LocationGate(child: _SessionGate())),
      ),
    );
  }
}

class VersionGate extends StatefulWidget {
  const VersionGate({super.key, required this.child});

  final Widget child;

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  AppVersionStatus? _status;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final status = await chatApi.getVersionStatus().timeout(
        const Duration(seconds: 7),
      );
      if (mounted) setState(() => _status = status);
    } catch (error) {
      // A temporary version endpoint failure must not lock out the app.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final status = _status;
    if (status?.updateRequired != true) return widget.child;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.system_update_rounded,
                size: 76,
                color: AppColors.primary,
              ),
              const SizedBox(height: 18),
              const Text(
                'Update required',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Skylink ${status!.latest} is required to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(status.url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Update now'),
              ),
              TextButton(onPressed: _check, child: const Text('Check again')),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationGate extends StatefulWidget {
  const LocationGate({super.key, required this.child});

  final Widget child;

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  bool _alwaysAllowed = false;

  bool get _required => !kIsWeb && Platform.isAndroid;
  bool get _allowed =>
      !_required ||
      (_serviceEnabled &&
          _permission != LocationPermission.denied &&
          _permission != LocationPermission.deniedForever &&
          _alwaysAllowed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!_required) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    final alwaysAllowed = await ph.Permission.locationAlways.isGranted;
    if (!mounted) return;
    setState(() {
      _serviceEnabled = enabled;
      _permission = permission;
      _alwaysAllowed = alwaysAllowed;
      _checking = false;
    });
  }

  Future<void> _requestPermission() async {
    var permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await ph.Permission.locationAlways.request();
      permission = await Geolocator.checkPermission();
    }
    if (!mounted) return;
    setState(() => _permission = permission);
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_allowed) return widget.child;
    final permanentlyDenied = _permission == LocationPermission.deniedForever;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Location is required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  !_serviceEnabled
                      ? 'Turn on GPS to use Skylink.'
                      : !_alwaysAllowed &&
                            _permission != LocationPermission.denied
                      ? "Set Location permission to 'Allow all the time' for attendance background tracking."
                      : 'Allow location permission to use Skylink and attendance tracking.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: !_serviceEnabled
                      ? Geolocator.openLocationSettings
                      : !_alwaysAllowed &&
                            _permission != LocationPermission.denied
                      ? ph.openAppSettings
                      : permanentlyDenied
                      ? Geolocator.openAppSettings
                      : _requestPermission,
                  icon: Icon(
                    !_serviceEnabled
                        ? Icons.gps_fixed_rounded
                        : Icons.settings_rounded,
                  ),
                  label: Text(
                    !_serviceEnabled
                        ? 'Turn on GPS'
                        : !_alwaysAllowed &&
                              _permission != LocationPermission.denied
                        ? 'Allow all the time'
                        : permanentlyDenied
                        ? 'Open app settings'
                        : 'Allow location',
                  ),
                ),
                TextButton(onPressed: _check, child: const Text('Check again')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  String? _employeeId;
  String? _error;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    SavedLogin? saved;
    try {
      saved = await SessionStore.instance.read();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Saved session could not be read. Please sign in again.';
          _checking = false;
        });
      }
      return;
    }
    if (saved == null) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    try {
      CurrentUser? user;
      Object? lastError;
      if (saved.sessionCookie.isNotEmpty) {
        try {
          user = await chatApi.restoreSession(saved);
        } catch (error) {
          lastError = error;
        }
      }
      for (var attempt = 0; attempt < 2 && user == null; attempt++) {
        try {
          user = await chatApi
              .login(employeeId: saved.employeeId, password: saved.password)
              .timeout(const Duration(seconds: 15));
        } catch (error) {
          lastError = error;
          if (error is ApiException && error.isUnauthorized) rethrow;
          if (attempt < 1) {
            await Future<void>.delayed(Duration(seconds: attempt + 1));
          }
        }
      }
      if (user == null) {
        throw lastError ?? const ApiException('Connection failed');
      }
      if (chatApi.sessionCookie.isNotEmpty &&
          chatApi.sessionCookie != saved.sessionCookie) {
        unawaited(
          SessionStore.instance.save(
            employeeId: saved.employeeId,
            password: saved.password,
            sessionCookie: chatApi.sessionCookie,
          ),
        );
      }
      final pushToken = NotificationService.instance.fcmToken;
      if (pushToken != null) {
        unawaited(chatApi.registerPushToken(pushToken).catchError((_) {}));
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => HomeScreen(currentUser: user!)),
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        _employeeId = saved.employeeId;
        _error = 'Saved password is no longer valid. Please sign in again.';
      } else {
        _employeeId = saved.employeeId;
        _error = 'Saved session could not connect. Please sign in again.';
      }
    } on TimeoutException {
      _employeeId = saved.employeeId;
      _error = 'Saved session timed out. Please sign in again.';
    } catch (error) {
      _employeeId = saved.employeeId;
      _error = 'Saved session could not connect. Please sign in again.';
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Restoring your session...',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }
    return LoginScreen(initialEmployeeId: _employeeId, initialError: _error);
  }




}
