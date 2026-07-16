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

final appThemeName = ValueNotifier<String>('flow_blue');

class FlowThemeSpec {
  const FlowThemeSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.seed,
    required this.primary,
    required this.secondary,
    required this.lightBackground,
    required this.lightSurface,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkSurfaceHigh,
  });

  final String id;
  final String name;
  final String description;
  final Color seed;
  final Color primary;
  final Color secondary;
  final Color lightBackground;
  final Color lightSurface;
  final Color darkBackground;
  final Color darkSurface;
  final Color darkSurfaceHigh;
}

const flowThemeSpecs = <FlowThemeSpec>[
  FlowThemeSpec(
    id: 'flow_blue',
    name: 'Flow Blue',
    description: 'Default operational blue.',
    seed: Color(0xFF2864DC),
    primary: Color(0xFF2864DC),
    secondary: Color(0xFF22A7C8),
    lightBackground: Color(0xFFF4F7FC),
    lightSurface: Color(0xFFFFFFFF),
    darkBackground: Color(0xFF0D1118),
    darkSurface: Color(0xFF151A23),
    darkSurfaceHigh: Color(0xFF202838),
  ),
  FlowThemeSpec(
    id: 'emerald_ops',
    name: 'Emerald Ops',
    description: 'Green for field operations.',
    seed: Color(0xFF07865D),
    primary: Color(0xFF07865D),
    secondary: Color(0xFF31B67A),
    lightBackground: Color(0xFFF2F8F4),
    lightSurface: Color(0xFFFFFFFF),
    darkBackground: Color(0xFF081411),
    darkSurface: Color(0xFF101E1A),
    darkSurfaceHigh: Color(0xFF1A2C26),
  ),
  FlowThemeSpec(
    id: 'slate_command',
    name: 'Slate Command',
    description: 'Quiet enterprise dark.',
    seed: Color(0xFF475569),
    primary: Color(0xFF64748B),
    secondary: Color(0xFF38BDF8),
    lightBackground: Color(0xFFF6F7F9),
    lightSurface: Color(0xFFFFFFFF),
    darkBackground: Color(0xFF0B0F14),
    darkSurface: Color(0xFF141A22),
    darkSurfaceHigh: Color(0xFF222B36),
  ),
  FlowThemeSpec(
    id: 'sunrise_field',
    name: 'Sunrise Field',
    description: 'Warm but readable.',
    seed: Color(0xFFD97706),
    primary: Color(0xFFD97706),
    secondary: Color(0xFFE11D48),
    lightBackground: Color(0xFFFFF8ED),
    lightSurface: Color(0xFFFFFFFF),
    darkBackground: Color(0xFF17110A),
    darkSurface: Color(0xFF21180F),
    darkSurfaceHigh: Color(0xFF332414),
  ),
  FlowThemeSpec(
    id: 'violet_ai',
    name: 'Violet AI',
    description: 'AI Marshal accent theme.',
    seed: Color(0xFF7C3AED),
    primary: Color(0xFF7C3AED),
    secondary: Color(0xFF06B6D4),
    lightBackground: Color(0xFFF8F5FF),
    lightSurface: Color(0xFFFFFFFF),
    darkBackground: Color(0xFF120D1C),
    darkSurface: Color(0xFF1C1528),
    darkSurfaceHigh: Color(0xFF2A203A),
  ),
  FlowThemeSpec(
    id: 'rose_alert',
    name: 'Rose Alert',
    description: 'Incident and SLA focus.',
    seed: Color(0xFFE11D48),
    primary: Color(0xFFE11D48),
    secondary: Color(0xFFF59E0B),
    lightBackground: Color(0xFFFFF4F6),
    lightSurface: Color(0xFFFFFFFF),
    darkBackground: Color(0xFF180B10),
    darkSurface: Color(0xFF241219),
    darkSurfaceHigh: Color(0xFF351A24),
  ),
];

FlowThemeSpec flowThemeById(String id) => flowThemeSpecs.firstWhere(
  (theme) => theme.id == id,
  orElse: () => flowThemeSpecs.first,
);

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
      builder: (_, themeMode, _) => ValueListenableBuilder<String>(
        valueListenable: appThemeName,
        builder: (_, themeName, _) {
          final theme = flowThemeById(themeName);
          return MaterialApp(
            title: 'Skylink',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: buildFlowTheme(theme, Brightness.light),
            darkTheme: buildFlowTheme(theme, Brightness.dark),
            home: const VersionGate(child: LocationGate(child: _SessionGate())),
          );
        },
      ),
    );
  }
}

ThemeData buildFlowTheme(FlowThemeSpec spec, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? spec.darkBackground : spec.lightBackground;
  final surface = dark ? spec.darkSurface : spec.lightSurface;
  final surfaceHigh = dark ? spec.darkSurfaceHigh : const Color(0xFFF6F8FC);
  final onSurface = dark ? const Color(0xFFEAF0FA) : AppColors.text;
  final onSurfaceVariant = dark ? const Color(0xFFBAC4D6) : AppColors.muted;
  final scheme = ColorScheme.fromSeed(
    seedColor: spec.seed,
    brightness: brightness,
    primary: spec.primary,
    secondary: spec.secondary,
    surface: surface,
    surfaceContainerHighest: surfaceHigh,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: background,
    colorScheme: scheme,
    canvasColor: surface,
    cardColor: surface,
    dividerColor: dark ? const Color(0xFF30394A) : AppColors.divider,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: surface,
      foregroundColor: onSurface,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(color: onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      dragHandleColor: onSurfaceVariant.withValues(alpha: 0.45),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: TextStyle(color: onSurfaceVariant, fontSize: 14),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: onSurface),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: onSurface,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: onSurface),
      bodyMedium: TextStyle(color: onSurface),
      bodySmall: TextStyle(color: onSurfaceVariant),
      labelLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(color: onSurfaceVariant),
    ),
    listTileTheme: ListTileThemeData(
      textColor: onSurface,
      iconColor: onSurfaceVariant,
      subtitleTextStyle: TextStyle(color: onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceHigh,
      selectedColor: spec.primary.withValues(alpha: dark ? 0.32 : 0.14),
      secondarySelectedColor: spec.primary.withValues(alpha: dark ? 0.32 : 0.14),
      labelStyle: TextStyle(color: onSurface),
      secondaryLabelStyle: TextStyle(color: onSurface),
      side: BorderSide(color: dark ? const Color(0xFF30394A) : AppColors.divider),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHigh,
      hintStyle: TextStyle(color: onSurfaceVariant),
      labelStyle: TextStyle(color: onSurfaceVariant),
      prefixIconColor: onSurfaceVariant,
      suffixIconColor: onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: dark ? const Color(0xFF30394A) : AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: spec.primary, width: 1.6),
      ),
    ),
  );
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
