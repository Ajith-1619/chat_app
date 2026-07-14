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

import 'chat_api.dart';
import 'location_tracking_service.dart';
import 'notification_service.dart';
import 'session_store.dart';
import 'myhub_leave_screens.dart';
import 'myhub_tasks_screen.dart';
import 'flow_registry.dart';
import 'mojibake_tools.dart';
import 'clipboard_media_bridge.dart';
import 'clipboard_text_bridge.dart';
import 'file_preview_embed.dart';

final chatApi = sharedChatApi;
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
final appMessageScale = ValueNotifier<double>(1.0);
final appChatDensity = ValueNotifier<double>(1.0);

Future<void> _requestAttachmentStoragePermission(BuildContext context) async {
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

Future<String> _voiceRecordingFilePath() async {
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

Future<void> _logout(BuildContext context) async {
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final savedThemeMode = preferences.getString('theme_mode');
  appThemeMode.value = switch (savedThemeMode) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    'light' => ThemeMode.light,
    _ =>
      preferences.getBool('dark_mode') == true
          ? ThemeMode.dark
          : ThemeMode.light,
  };
  if (savedThemeMode == null && preferences.containsKey('dark_mode')) {
    await preferences.setString('theme_mode', appThemeMode.value.name);
  }
  appMessageScale.value = preferences.getDouble('message_scale') ?? 1.0;
  appChatDensity.value = preferences.getDouble('chat_density') ?? 1.0;
  appShowAvatars.value = preferences.getBool('show_avatars') ?? true;
  appCollapseLongMessages.value =
      preferences.getBool('collapse_long_messages') ?? true;
  final savedWorkspaceMode =
      preferences.getString('workspace_mode') ?? 'three_pane';
  appWorkspaceMode.value =
      const {'auto', 'two_pane', 'three_pane'}.contains(savedWorkspaceMode)
      ? savedWorkspaceMode
      : 'three_pane';
  try {
    await LocationTrackingService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Location service initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  try {
    await NotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Notification service initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SkylinkApp());
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialEmployeeId, this.initialError});

  final String? initialEmployeeId;
  final String? initialError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _rememberMe = true;
  bool _isLoggingIn = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.initialEmployeeId ?? '';
    _loginError = widget.initialError;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isLoggingIn) return;
    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });
    try {
      final user = await chatApi.login(
        employeeId: _usernameController.text,
        password: _passwordController.text,
      );
      final pushToken = NotificationService.instance.fcmToken;
      if (pushToken != null) {
        try {
          await chatApi.registerPushToken(pushToken);
        } catch (error) {
          // Login must still succeed if push registration is unavailable.
        }
      }
      if (_rememberMe) {
        await SessionStore.instance.save(
          employeeId: _usernameController.text.split('@').first,
          password: _passwordController.text,
          sessionCookie: chatApi.sessionCookie,
        );
      } else {
        await SessionStore.instance.clear();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            child: HomeScreen(currentUser: user),
          ),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    } on TimeoutException {
      if (mounted) {
        setState(() => _loginError = 'Server timeout. Please try again.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _loginError = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _loginError = 'Unable to connect to Skylink.');
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF5F9FF),
                  Color(0xFFE8F1FF),
                  Color(0xFFF9FBFF),
                ],
              ),
            ),
          ),
          const Positioned(
            top: -120,
            right: -80,
            child: _GlowCircle(size: 300, opacity: 0.10),
          ),
          const Positioned(
            bottom: -130,
            left: -100,
            child: _GlowCircle(size: 340, opacity: 0.08),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A1E4A8A),
                          blurRadius: 40,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset(
                              'logo-skylink.png',
                              width: 230,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineLarge?.copyWith(fontSize: 30),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in to continue your conversations',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 30),
                          TextFormField(
                            key: const Key('usernameField'),
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Employee ID (example: 302)',
                              hintText: 'Enter employee number',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              helperText:
                                  'Enter only the number - @chat.skylinkonline.net is added automatically',
                              helperMaxLines: 2,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your employee ID';
                              }
                              final employeeId = value.trim().split('@').first;
                              if (!RegExp(
                                r'^[A-Za-z0-9._-]+$',
                              ).hasMatch(employeeId)) {
                                return 'Enter a valid employee ID';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('passwordField'),
                            controller: _passwordController,
                            obscureText: _hidePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _hidePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 4) {
                                return 'Password must have at least 4 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  onChanged: (value) => setState(
                                    () => _rememberMe = value ?? false,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'Remember me',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Password recovery will be available soon.',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Forgot password?',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_loginError != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFCCCC),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFCF3E3E),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _loginError!,
                                      style: const TextStyle(
                                        color: Color(0xFFA72D2D),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton(
                            key: const Key('loginButton'),
                            onPressed: _isLoggingIn ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLoggingIn)
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                else ...[
                                  const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: AppColors.muted,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Your conversations stay private',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: opacity),
      ),
    );
  }
}

class ChatPreview {
  const ChatPreview({
    this.empId = '',
    this.jid = '',
    required this.name,
    this.designation = '',
    required this.message,
    required this.time,
    required this.avatarColor,
    this.unread = 0,
    this.isOnline = false,
    this.isGroup = false,
    this.isPinned = false,
    this.isMuted = false,
    this.sentByMe = false,
    this.wasMentioned = false,
    this.avatarUrl = '',
    this.isStarred = false,
    this.originalSenderJid = '',
    this.originalSenderName = '',
    this.originalSourceName = '',
    this.isChannel = false,
  });

  factory ChatPreview.fromContact(ChatContact contact) {
    const colors = [
      Color(0xFF9C5DE8),
      Color(0xFF2B80D9),
      Color(0xFFEF7B45),
      Color(0xFF35A876),
      Color(0xFFE2557A),
      Color(0xFF6A63D8),
      Color(0xFF18A2AE),
    ];
    final attachment = ChatAttachment.tryParse(contact.lastMessage);
    return ChatPreview(
      empId: contact.empId,
      jid: contact.jid,
      name: contact.name.isEmpty ? contact.empId : contact.name,
      designation: contact.designation,
      message: attachment == null
          ? _plainMessagePreview(contact.lastMessage)
          : 'Attachment: ${attachment.name}',
      time: _displayChatTime(contact.time),
      avatarColor: colors[contact.empId.hashCode.abs() % colors.length],
      unread: contact.unread,
      isOnline: contact.isOnline,
      isGroup: contact.type != 'chat',
      isChannel: contact.type == 'channel',
      isPinned: contact.isPinned,
      isStarred: contact.isStarred,
      wasMentioned: contact.wasMentioned,
      avatarUrl: contact.avatarUrl,
    );
  }

  final String empId;
  final String jid;
  final String name;
  final String designation;
  final String message;
  final String time;
  final Color avatarColor;
  final int unread;
  final bool isOnline;
  final bool isGroup;
  final bool isPinned;
  final bool isMuted;
  final bool sentByMe;
  final bool wasMentioned;
  final String avatarUrl;
  final bool isStarred;
  final String originalSenderJid;
  final String originalSenderName;
  final String originalSourceName;
  final bool isChannel;
}

String _displayChatTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) {
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
  return '${local.day}/${local.month}/${local.year}';
}

String _plainMessagePreview(String value) {
  return value
      .replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6}\]'), '')
      .replaceAll('[/color]', '')
      .replaceAll('**', '')
      .replaceAll('~~', '')
      .replaceAll('_', '')
      .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
      .trim();
}

String _formatFileBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

const chats = [
  ChatPreview(
    name: 'Priya Sharma',
    message: 'Perfect! See you tomorrow!',
    time: '10:42 AM',
    unread: 2,
    isOnline: true,
    avatarColor: Color(0xFF9C5DE8),
  ),
  ChatPreview(
    name: 'Skylink Design Team',
    message: 'Arun: I have shared the new screens',
    time: '10:18 AM',
    unread: 5,
    isGroup: true,
    isPinned: true,
    avatarColor: Color(0xFF2B80D9),
  ),
  ChatPreview(
    name: 'Rahul Kumar',
    message: 'The project looks great!',
    time: 'Yesterday',
    sentByMe: true,
    avatarColor: Color(0xFFEF7B45),
  ),
  ChatPreview(
    name: 'Family',
    message: 'Mom: Dinner at 8 tonight <3',
    time: 'Yesterday',
    isGroup: true,
    isMuted: true,
    avatarColor: Color(0xFF35A876),
  ),
  ChatPreview(
    name: 'Vikram Singh',
    message: 'Voice message',
    time: 'Mon',
    isOnline: true,
    avatarColor: Color(0xFFE2557A),
  ),
  ChatPreview(
    name: 'Weekend Crew',
    message: 'Meera: Who is joining this weekend?',
    time: 'Sun',
    unread: 1,
    isGroup: true,
    avatarColor: Color(0xFF6A63D8),
  ),
  ChatPreview(
    name: 'Ananya',
    message: 'Thank you so much!',
    time: 'Sat',
    sentByMe: true,
    avatarColor: Color(0xFF18A2AE),
  ),
  ChatPreview(
    name: 'Office Updates',
    message: 'Meeting moved to 3:30 PM',
    time: 'Fri',
    isGroup: true,
    isMuted: true,
    avatarColor: Color(0xFF56657C),
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.currentUser});

  final CurrentUser currentUser;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _androidSettings = MethodChannel('skylink/android_settings');
  final _searchController = TextEditingController();
  final _filterScrollController = ScrollController();
  final List<ChatPreview> _liveChats = [];
  final Map<String, String> _knownChatTimes = {};
  Timer? _pollTimer;
  Timer? _pushRetryTimer;
  Timer? _connectivityTimer;
  StreamSubscription<String>? _pushTokenSubscription;
  String _query = '';
  int _filter = 0;
  List<int> _filterOrder = const [0, 1, 6, 2, 3, 4, 5];
  bool _isLoading = true;
  bool _chatRefreshActive = false;
  String? _loadError;
  ChatPreview? _selectedDesktopChat;
  bool _showDesktopProfile = true;
  bool _attendanceActive = false;
  bool _offlineBannerVisible = false;

  List<ChatPreview> get _filteredChats {
    return _liveChats.where((chat) {
      final matchesQuery =
          chat.name.toLowerCase().contains(_query.toLowerCase()) ||
          chat.message.toLowerCase().contains(_query.toLowerCase());
      final matchesFilter = switch (_filter) {
        1 => chat.unread > 0,
        2 => !chat.isGroup,
        3 => chat.isGroup && !chat.isChannel,
        4 => chat.isChannel,
        5 => chat.isStarred,
        6 => chat.isOnline,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  int get _unreadCount =>
      _liveChats.fold(0, (total, chat) => total + chat.unread);

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadFilterOrder();
    _resumeAttendanceTracking();
    _registerPushNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWhatsNew();
    });
    _pushTokenSubscription = NotificationService.instance.onTokenRefresh.listen(
      (token) => chatApi.registerPushToken(token).catchError((_) {}),
    );
    _pushRetryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _registerPushNotifications(),
    );
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadChats(silent: true),
    );
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkPunchedInConnectivity(),
    );
    _checkPunchedInConnectivity();
  }

  Future<void> _maybeShowWhatsNew() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();
      final localKey =
          'release_notes_prompted_${widget.currentUser.empId}_${package.version}';
      if (prefs.getBool(localKey) == true) return;
      final note = await chatApi.getReleaseNotes().timeout(
        const Duration(seconds: 5),
      );
      if (!mounted || note == null || note.viewed || note.isEmpty) {
        await prefs.setBool(localKey, true);
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('What\'s new in v${note.version}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: _ReleaseNoteContent(note: note),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                unawaited(chatApi.markReleaseNoteViewed(note.id));
                Navigator.pop(context);
              },
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      await prefs.setBool(localKey, true);
    } catch (error) {
      // Release notes must never block chat startup.
    }
  }

  Future<void> _resumeAttendanceTracking() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final attendance = await chatApi.getAttendance();
      if (!attendance.hasPunchedIn || attendance.hasPunchedOut) {
        _attendanceActive = false;
        await LocationTrackingService.instance.stop();
        return;
      }
      _attendanceActive = true;
      final tracking = await chatApi.startLocationTracking(attendance.shiftId);
      await LocationTrackingService.instance.start(tracking.$2);
    } catch (error) {
      // Attendance tracking retries when the profile is opened or app restarts.
    }
  }

  Future<void> _checkPunchedInConnectivity() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final attendance = await chatApi.getAttendance();
      _attendanceActive = attendance.hasPunchedIn && !attendance.hasPunchedOut;
    } catch (error) {
      // A failed attendance request can itself be caused by no internet.
    }
    if (!_attendanceActive) {
      if (_offlineBannerVisible && mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        _offlineBannerVisible = false;
      }
      return;
    }
    var online = false;
    try {
      final addresses = await InternetAddress.lookup(
        'chat.skylinkonline.net',
      ).timeout(const Duration(seconds: 5));
      online = addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } catch (error) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      if (_offlineBannerVisible) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        _offlineBannerVisible = false;
      }
      return;
    }
    if (_offlineBannerVisible) return;
    _offlineBannerVisible = true;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.wifi_off_rounded, color: Colors.red),
        content: const Text(
          'Attendance is active, but this phone is offline. Enable mobile data '
          'or connect to Wi-Fi so location tracking can continue.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await _androidSettings.invokeMethod<void>(
                  'openWirelessSettings',
                );
              } catch (error) {
                await ph.openAppSettings();
              }
            },
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerPushNotifications() async {
    final token =
        NotificationService.instance.fcmToken ??
        await NotificationService.instance.refreshToken();
    if (token == null || token.isEmpty) return;
    try {
      await chatApi.registerPushToken(token);
    } catch (error) {
      // Retry automatically while the signed-in app remains active.
    }
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (_chatRefreshActive) return;
    _chatRefreshActive = true;
    try {
      final contacts = await chatApi.getRecentChats();
      if (!mounted) return;
      if (_knownChatTimes.isNotEmpty) {
        for (final contact in contacts) {
          final oldTime = _knownChatTimes[contact.jid];
          if (contact.time.isNotEmpty &&
              oldTime != null &&
              oldTime != contact.time) {
            try {
              if (contact.unread > 0 &&
                  NotificationService.instance.fcmToken == null) {
                await NotificationService.instance.showMessage(
                  sender: contact.name,
                  message: contact.lastMessage,
                  jid: contact.jid,
                );
              }
            } catch (error) {
              // A notification failure must never break chat refresh.
            }
          }
        }
      }
      for (final contact in contacts) {
        if (contact.time.isNotEmpty) {
          _knownChatTimes[contact.jid] = contact.time;
        }
      }
      setState(() {
        _liveChats
          ..clear()
          ..addAll(contacts.map(ChatPreview.fromContact));
        _isLoading = false;
        _loadError = null;
      });
      unawaited(
        chatApi.prefetchHistories(
          contacts
              .where((contact) => contact.lastMessage.isNotEmpty)
              .map((contact) => contact.jid),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        _handleSessionExpired();
      } else if (!silent) {
        setState(() {
          _isLoading = false;
          _loadError = error.message;
        });
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _loadError = 'Unable to load conversations.';
        });
      }
    } finally {
      _chatRefreshActive = false;
    }
  }

  void _handleSessionExpired() {
    _pollTimer?.cancel();
    chatApi.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pushRetryTimer?.cancel();
    _connectivityTimer?.cancel();
    _pushTokenSubscription?.cancel();
    _searchController.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  String get _filterOrderKey => 'chat_filter_order_${widget.currentUser.empId}';

  String _filterLabel(int filter) => switch (filter) {
    1 => 'Unread',
    2 => 'Personal',
    3 => 'Groups',
    4 => 'Channels',
    5 => 'Starred',
    6 => 'Online',
    _ => 'All',
  };

  Future<void> _loadFilterOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_filterOrderKey);
    if (saved == null) return;
    final values = saved.map(int.tryParse).whereType<int>().toList();
    const expected = {0, 1, 2, 3, 4, 5, 6};
    if (values.length != expected.length ||
        values.toSet().length != expected.length ||
        !values.toSet().containsAll(expected)) {
      return;
    }
    if (mounted) setState(() => _filterOrder = values);
  }

  Future<void> _saveFilterOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _filterOrderKey,
      _filterOrder.map((value) => value.toString()).toList(),
    );
  }

  Widget _buildChatFilter(int filter) {
    final label = _filterLabel(filter);
    return _FilterChip(
      key: ValueKey('chat-filter-$filter'),
      label: label,
      count: filter == 1 ? _unreadCount : null,
      selected: _filter == filter,
      onTap: () => setState(() => _filter = filter),
      onLongPress: () => _showFilterActions(label, filter),
    );
  }

  Widget _buildFilterStrip({
    EdgeInsets padding = const EdgeInsets.fromLTRB(10, 0, 10, 8),
  }) {
    final chips = _filterOrder.map(_buildChatFilter).toList();
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scrollbar(
        controller: _filterScrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _filterScrollController,
          scrollDirection: Axis.horizontal,
          primary: false,
          padding: padding,
          child: Row(
            children: [
              ...chips,
              Tooltip(
                message: 'Reorder filters',
                child: IconButton.filledTonal(
                  onPressed: _reorderFilters,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reorderFilters() async {
    var order = List<int>.from(_filterOrder);
    final updated = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reorder chat filters'),
          content: SizedBox(
            width: 360,
            height: 420,
            child: ReorderableListView.builder(
              itemCount: order.length,
              onReorder: (oldIndex, newIndex) {
                setDialogState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = order.removeAt(oldIndex);
                  order.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final filter = order[index];
                return ListTile(
                  key: ValueKey(filter),
                  leading: const Icon(Icons.drag_handle_rounded),
                  title: Text(_filterLabel(filter)),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, order),
              child: const Text('Save order'),
            ),
          ],
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _filterOrder = updated);
    await _saveFilterOrder();
  }

  Future<void> _showFilterActions(String label, int filter) async {
    final scoped = _liveChats.where((chat) {
      return switch (filter) {
        2 => !chat.isGroup,
        3 => chat.isGroup && !chat.isChannel,
        4 => chat.isChannel,
        _ => true,
      };
    }).toList();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('$label options'),
              subtitle: Text('${scoped.length} conversations'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert_rounded),
              title: const Text('Reorder filters'),
              subtitle: const Text('Saved separately for your account'),
              onTap: () => Navigator.pop(sheetContext, 'reorder'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Chat folders'),
              subtitle: const Text('Create, display and reorder folders'),
              onTap: () => Navigator.pop(sheetContext, 'folders'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text('Mute all $label notifications'),
              onTap: () => Navigator.pop(sheetContext, 'mute'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text('Unmute all $label notifications'),
              onTap: () => Navigator.pop(sheetContext, 'unmute'),
            ),
            if (filter == 3 || filter == 4)
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Edit group/channel settings'),
                subtitle: const Text('Choose a conversation to manage'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reorder') {
      await _reorderFilters();
    } else if (action == 'folders') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatFoldersScreen(chats: _liveChats),
        ),
      );
      return;
    }
    if (action == 'mute' || action == 'unmute') {
      final muted = action == 'mute';
      await Future.wait(
        scoped.map((chat) => chatApi.setMuted(chat.jid, muted)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              muted
                  ? '$label notifications muted.'
                  : '$label notifications enabled.',
            ),
          ),
        );
      }
      return;
    }
    if (action == 'edit' && scoped.isNotEmpty && mounted) {
      final chosen = await showDialog<ChatPreview>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Choose conversation'),
          children: scoped
              .map(
                (chat) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, chat),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(chat: chat, radius: 20),
                    title: Text(chat.name),
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (chosen != null && mounted) _openChat(chosen);
    }
  }

  Future<bool> _handleChatSwipe(
    ChatPreview chat,
    DismissDirection direction,
  ) async {
    try {
      if (direction == DismissDirection.startToEnd) {
        await chatApi.getHistory(chat.jid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All messages marked as read.')),
          );
        }
      } else if (direction == DismissDirection.endToStart) {
        await chatApi.setMuted(chat.jid, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${chat.name} notifications muted.')),
          );
        }
      }
      await _loadChats(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    return false;
  }

  Future<void> _openChat(ChatPreview chat) async {
    if (MediaQuery.sizeOf(context).width >= 900) {
      setState(() {
        _selectedDesktopChat = chat;
        _showDesktopProfile = true;
      });
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: chat)));
    if (mounted) await _loadChats(silent: true);
  }

  Future<void> _showChatActions(ChatPreview chat) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                chat.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
              ),
              title: Text(chat.isPinned ? 'Unpin chat' : 'Pin chat'),
              onTap: () => Navigator.pop(sheetContext, 'pin'),
            ),
            ListTile(
              leading: Icon(
                chat.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
              ),
              title: Text(
                chat.isStarred ? 'Remove from starred' : 'Add to starred',
              ),
              onTap: () => Navigator.pop(sheetContext, 'star'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    await chatApi.setConversationPreference(
      jid: chat.jid,
      pinned: action == 'pin' ? !chat.isPinned : chat.isPinned,
      starred: action == 'star' ? !chat.isStarred : chat.isStarred,
    );
    await _loadChats(silent: true);
  }

  Future<void> _createGroup() async {
    final group = await showModalBottomSheet<ChatPreview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewGroupSheet(),
    );
    if (group == null || !mounted) return;
    await _loadChats(silent: true);
    if (mounted) await _openChat(group);
  }

  Future<void> _createChannel() async {
    final channel = await showModalBottomSheet<ChatPreview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewGroupSheet(isChannel: true),
    );
    if (channel == null || !mounted) return;
    await _loadChats(silent: true);
    if (mounted) await _openChat(channel);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 900) {
      return ValueListenableBuilder<String>(
        valueListenable: appWorkspaceMode,
        builder: (_, _, _) => _buildDesktop(context),
      );
    }
    return Scaffold(
      drawer: _AppDrawer(currentUser: widget.currentUser, chats: _liveChats),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        titleSpacing: 2,
        title: Image.asset(
          'logo-skylink.png',
          height: 42,
          width: 145,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            tooltip: 'Global search',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GlobalSearchScreen(),
              ),
            ),
            icon: const Icon(Icons.manage_search_rounded),
          ),
          ValueListenableBuilder<String>(
            valueListenable: chatApi.connectionStatus,
            builder: (context, status, _) {
              final color = status == 'connected'
                  ? Colors.green
                  : status == 'reconnecting'
                  ? Colors.amber
                  : Colors.red;
              return TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Messenger connection'),
                    content: Text(
                      'Status: ${status[0].toUpperCase()}${status.substring(1)}\n'
                      'Server: chat.skylinkonline.net\n'
                      'Transport: Ejabberd API / XMPP\n'
                      'Last check: ${DateTime.now()}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                icon: Icon(Icons.circle, size: 11, color: color),
                label: const SizedBox.shrink(),
              );
            },
          ),
          IconButton(
            tooltip: 'New channel',
            onPressed: _createChannel,
            icon: const Icon(Icons.tag_rounded),
          ),
          IconButton(
            tooltip: 'New group',
            onPressed: _createGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'logout') {
                _logout(context);
              } else if (value == 'New group') {
                _createGroup();
              } else if (value == 'Settings') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SettingsScreen(currentUser: widget.currentUser),
                  ),
                );
              } else {
                _showComingSoon(context, value);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'New group', child: Text('New group')),
              PopupMenuItem(value: 'Settings', child: Text('Settings')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _buildFilterStrip(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? _LoadError(message: _loadError!, onRetry: _loadChats)
                : _filteredChats.isEmpty
                ? _EmptySearch(isSearch: _query.isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 6, bottom: 92),
                    itemCount: _filteredChats.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 88,
                      endIndent: 16,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (_, index) {
                      final chat = _filteredChats[index];
                      return Dismissible(
                        key: ValueKey('inbox-${chat.jid}'),
                        confirmDismiss: (direction) =>
                            _handleChatSwipe(chat, direction),
                        background: Container(
                          color: Colors.green.shade600,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Row(
                            children: [
                              Icon(Icons.done_all_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Mark read',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          color: Colors.blueGrey.shade700,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Mute',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.notifications_off_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        child: _ChatTile(
                          chat: chat,
                          onTap: () => _openChat(chat),
                          onLongPress: () => _showChatActions(chat),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewMessageSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: _AppDrawer(currentUser: widget.currentUser, chats: _liveChats),
      body: Row(
        children: [
          SizedBox(
            width: 430,
            child: Material(
              color: colors.surface,
              child: Column(
                children: [
                  SizedBox(
                    height: 70,
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            tooltip: 'Menu',
                            onPressed: Scaffold.of(context).openDrawer,
                            icon: const Icon(Icons.menu_rounded),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF7C86A0),
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? colors.surfaceContainerHighest
                                    : const Color(0xFFE9E9EF),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'New message',
                          onPressed: () => _showNewMessageSheet(context),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 54, child: _buildFilterStrip()),
                  const Divider(height: 1),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _loadError != null
                        ? _LoadError(message: _loadError!, onRetry: _loadChats)
                        : _filteredChats.isEmpty
                        ? _EmptySearch(isSearch: _query.isNotEmpty)
                        : ListView.separated(
                            itemCount: _filteredChats.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 76),
                            itemBuilder: (_, index) {
                              final chat = _filteredChats[index];
                              final selected =
                                  _selectedDesktopChat?.jid == chat.jid;
                              return ColoredBox(
                                color: selected
                                    ? colors.primaryContainer.withValues(
                                        alpha: 0.5,
                                      )
                                    : Colors.transparent,
                                child: _ChatTile(
                                  chat: chat,
                                  onTap: () => _openChat(chat),
                                  onLongPress: () => _showChatActions(chat),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
          Expanded(
            child: _selectedDesktopChat == null
                ? _DesktopEmptyChat(currentUser: widget.currentUser)
                : ChatScreen(
                    key: ValueKey(_selectedDesktopChat!.jid),
                    chat: _selectedDesktopChat!,
                    onProfileTap: () {
                      setState(() => _showDesktopProfile = true);
                    },
                  ),
          ),
          if (_selectedDesktopChat != null &&
              _showDesktopProfile &&
              ((appWorkspaceMode.value == 'three_pane' &&
                      MediaQuery.sizeOf(context).width >= 1180) ||
                  (appWorkspaceMode.value == 'auto' &&
                      MediaQuery.sizeOf(context).width >= 1280))) ...[
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colors.outlineVariant,
            ),
            SizedBox(
              width: 320,
              child: _DesktopConversationProfile(
                key: ValueKey('profile-${_selectedDesktopChat!.jid}'),
                chat: _selectedDesktopChat!,
                onClose: () => setState(() => _showDesktopProfile = false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopConversationProfile extends StatefulWidget {
  const _DesktopConversationProfile({
    super.key,
    required this.chat,
    required this.onClose,
  });

  final ChatPreview chat;
  final VoidCallback onClose;

  @override
  State<_DesktopConversationProfile> createState() =>
      _DesktopConversationProfileState();
}

class _DesktopConversationProfileState
    extends State<_DesktopConversationProfile> {
  late Future<Map<String, dynamic>> _profileFuture;

  ChatPreview get chat => widget.chat;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadPanelData();
  }

  void _reloadPanel() {
    if (!mounted) return;
    setState(() => _profileFuture = _loadPanelData());
  }

  Widget _detailCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadPanelData() async {
    if (!chat.isGroup) return chatApi.getUserProfile(chat.empId);
    final groupId = int.tryParse(chat.empId) ?? 0;
    GroupMembersResult? members;
    ChannelProfile? channelProfile;
    if (groupId > 0) {
      members = await chatApi.getGroupMembers(groupId);
      if (chat.isChannel) {
        try {
          channelProfile = await chatApi.getChannelProfile(
            groupId: groupId,
            jid: chat.jid,
          );
        } catch (error) {
          channelProfile = null;
        }
      }
    }
    return <String, dynamic>{
      'current_role': members?.currentRole ?? '',
      'members': members?.members ?? const <GroupMember>[],
      'channel_kind': channelProfile?.kind ?? '',
      'channel_status': channelProfile?.statusText ?? '',
      'channel_priority': channelProfile?.priority ?? '',
    };
  }

  Future<void> _changeGroupPhoto() async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    try {
      await chatApi.updateGroupPhoto(
        groupId: groupId,
        name: file.name,
        bytes: file.bytes!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chat.isChannel ? 'Channel photo updated.' : 'Group photo updated.',
          ),
        ),
      );
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _renameConversation() async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final controller = TextEditingController(text: chat.name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(chat.isChannel ? 'Rename channel' : 'Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null || result.isEmpty) return;
    try {
      await chatApi.renameGroup(groupId, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chat.isChannel ? 'Channel renamed.' : 'Group renamed.'),
        ),
      );
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _leaveConversation() async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave ' + (chat.isChannel ? 'channel' : 'group') + '?'),
        content: const Text(
          'You will stop receiving messages from this conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.groupMemberAction(
        groupId: groupId,
        empId: '0',
        action: 'leave',
      );
      if (!mounted) return;
      widget.onClose();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _closeChannel() async {
    final channelId = int.tryParse(chat.empId) ?? 0;
    if (!chat.isChannel || channelId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close channel?'),
        content: const Text(
          "The channel will move to the archive and disappear from every member's open channel list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close channel'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.closeChannel(channelId);
      if (!mounted) return;
      widget.onClose();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showWakeupConfigDesktop(bool canManage) async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    if (!canManage) {
      return;
    }
    try {
      final config = await chatApi.getWakeupConfig(
        groupId: groupId,
        jid: chat.jid,
      );
      if (!mounted) return;
      var enabled =
          config['enabled'] == true ||
          "${config['enabled']}".toLowerCase() == '1' ||
          "${config['enabled']}".toLowerCase() == 'true';
      var interval =
          int.tryParse(
            '${config['interval_minutes'] ?? config['minutes'] ?? 1440}',
          ) ??
          1440;
      const choices = <int, String>{
        1440: '1 day',
        4320: '3 days',
        10080: '7 days',
        21600: '15 days',
        43200: '1 month',
        86400: '2 months',
        129600: '3 months',
      };
      if (!choices.containsKey(interval)) interval = 1440;
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Wake-up notification'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable wake-up notification'),
                    subtitle: const Text(
                      'Weekends are skipped. Only owner/admin can edit.',
                    ),
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: choices.entries.map((entry) {
                      final selected = interval == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: selected,
                        onSelected: enabled
                            ? (_) => setDialogState(() => interval = entry.key)
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return;
      await chatApi.updateWakeupConfig(
        groupId: groupId,
        enabled: enabled,
        intervalMinutes: interval,
      );
      if (!mounted) return;
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _addMember(List<GroupMember> currentMembers) async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final users = await chatApi.searchUsers();
    if (!mounted) return;
    final existing = currentMembers.map((member) => member.empId).toSet();
    final selected = await showDialog<ChatContact>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add member'),
        content: SizedBox(
          width: 420,
          height: 420,
          child: ListView(
            children: users
                .where((user) => !existing.contains(user.empId))
                .map(
                  (user) => ListTile(
                    title: Text(user.name),
                    subtitle: Text(user.designation),
                    onTap: () => Navigator.pop(dialogContext, user),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (selected == null) return;
    try {
      await chatApi.manageGroupMember(
        groupId: groupId,
        empId: selected.empId,
        add: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member added.')));
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final groupId = int.tryParse(chat.empId) ?? 0;
    if (groupId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          'Remove ' +
              (member.name.isEmpty ? member.empId : member.name) +
              ' from this ' +
              (chat.isChannel ? 'channel' : 'group') +
              '?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.manageGroupMember(
        groupId: groupId,
        empId: member.empId,
        add: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member removed.')));
      _reloadPanel();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data ?? const <String, dynamic>{};
          final groupMembers = chat.isGroup && profile['members'] is List
              ? List<GroupMember>.from(profile['members'] as List)
              : const <GroupMember>[];
          final groupRole = (profile['current_role'] ?? '').toString();
          final canManageGroup = const {'owner', 'admin'}.contains(groupRole);
          final channelKind = (profile['channel_kind'] ?? '').toString();
          final channelStatus = (profile['channel_status'] ?? '').toString();
          final channelPriority = (profile['channel_priority'] ?? '')
              .toString();
          final designation =
              (profile['designation'] ??
                      (chat.isChannel
                          ? 'Channel'
                          : chat.isGroup
                          ? 'Group'
                          : 'Employee'))
                  .toString();
          final onlineValue = profile['messenger_connected'];
          final online =
              onlineValue == true ||
              onlineValue == 1 ||
              onlineValue.toString() == '1' ||
              chat.isOnline;
          final launchpadValue = profile['launchpad_active'];
          final launchpadActive =
              launchpadValue == true ||
              launchpadValue == 1 ||
              launchpadValue.toString() == '1';

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close details',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Center(child: UserAvatar(chat: chat, radius: 44)),
              const SizedBox(height: 12),
              Text(
                chat.name,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                designation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: online ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GlobalSearchScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Search'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatMediaBrowser(chat: chat),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Media'),
                    ),
                  ),
                ],
              ),
              if (chat.isGroup) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: canManageGroup ? _renameConversation : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        chat.isChannel ? 'Rename channel' : 'Rename group',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: canManageGroup ? _changeGroupPhoto : null,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Photo'),
                    ),
                    if (chat.isChannel)
                      OutlinedButton.icon(
                        onPressed: canManageGroup ? _closeChannel : null,
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Archive'),
                      ),
                    OutlinedButton.icon(
                      onPressed: groupRole == 'owner'
                          ? null
                          : _leaveConversation,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Leave'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Manage',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Wake-up notification'),
                  subtitle: Text(
                    canManageGroup
                        ? 'Configure from this right panel'
                        : 'Only owner/admin can edit',
                  ),
                  trailing: canManageGroup
                      ? const Icon(Icons.chevron_right_rounded)
                      : null,
                  onTap: () => _showWakeupConfigDesktop(canManageGroup),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.push_pin_outlined),
                  title: const Text('Pinned messages'),
                  subtitle: const Text('Open pinned messages'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiscoveryListScreen(
                        title: 'Pinned messages',
                        view: 'pins',
                        jid: chat.jid,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text('Member management'),
                  subtitle: Text(
                    canManageGroup
                        ? 'Add and remove members from here'
                        : 'Read-only member list',
                  ),
                  trailing: canManageGroup
                      ? TextButton.icon(
                          onPressed: () => _addMember(groupMembers),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                ...groupMembers.map((member) {
                  final name = member.name.isEmpty ? member.empId : member.name;
                  final subtitle = member.role == 'owner'
                      ? 'Owner'
                      : member.role == 'admin'
                      ? 'Admin'
                      : member.isOnline
                      ? 'online'
                      : member.designation;
                  final canRemove =
                      canManageGroup &&
                      member.role != 'owner' &&
                      member.empId != chatApi.currentJid.split('@').first;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                    ),
                    title: Text(name),
                    subtitle: Text(subtitle),
                    trailing: canRemove
                        ? IconButton(
                            tooltip: 'Remove member',
                            onPressed: () => _removeMember(member),
                            icon: const Icon(Icons.person_remove_outlined),
                          )
                        : member.role == 'owner'
                        ? const Chip(label: Text('Owner'))
                        : member.isOnline
                        ? const Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 12,
                          )
                        : null,
                  );
                }),
              ],
              const SizedBox(height: 16),
              _detailCard(
                context,
                icon: Icons.alternate_email_rounded,
                label: 'JID',
                value: chat.jid,
              ),
              if (!chat.isGroup) ...[
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.badge_outlined,
                  label: 'Employee ID',
                  value: (profile['employee_id'] ?? chat.empId).toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.work_outline_rounded,
                  label: 'Designation',
                  value: designation,
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: online
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  label: 'Status',
                  value: online ? 'Online' : 'Offline',
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.rocket_launch_outlined,
                  label: 'Launchpad',
                  value: launchpadActive ? 'Active' : 'Inactive',
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.devices_outlined,
                  label: 'Device model',
                  value: (profile['device_model'] ?? '').toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.computer_outlined,
                  label: 'Platform',
                  value: (profile['platform'] ?? '').toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.info_outline_rounded,
                  label: 'App version',
                  value: (profile['app_version'] ?? '').toString(),
                ),
              ],
              const SizedBox(height: 10),
              _detailCard(
                context,
                icon: Icons.history_rounded,
                label: 'Last activity',
                value: (profile['last_activity'] ?? chat.time).toString(),
              ),
              if (!chat.isGroup) ...[
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.location_on_outlined,
                  label: 'Latest location',
                  value: (profile['latest_location_address'] ?? '').toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'Mobile number',
                  value: (profile['mobile'] ?? '').toString(),
                ),
              ],
              const SizedBox(height: 10),
              _detailCard(
                context,
                icon: Icons.mark_chat_unread_outlined,
                label: 'Unread',
                value: chat.unread.toString(),
              ),
              if (chat.isGroup) ...[
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.people_outline_rounded,
                  label: 'Members',
                  value: groupMembers.length.toString(),
                ),
                const SizedBox(height: 10),
                _detailCard(
                  context,
                  icon: Icons.verified_user_outlined,
                  label: 'Your role',
                  value: groupRole.isEmpty ? '-' : groupRole,
                ),
                if (chat.isChannel) ...[
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.category_outlined,
                    label: 'Channel type',
                    value: channelKind,
                  ),
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.info_outline_rounded,
                    label: 'Channel status',
                    value: channelStatus,
                  ),
                  const SizedBox(height: 10),
                  _detailCard(
                    context,
                    icon: Icons.low_priority_rounded,
                    label: 'Priority',
                    value: channelPriority,
                  ),
                ],
              ],
              const SizedBox(height: 18),
              Text(
                'Latest message',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                chat.message.isEmpty ? 'No messages yet.' : chat.message,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DesktopEmptyChat extends StatelessWidget {
  const _DesktopEmptyChat({required this.currentUser});

  final CurrentUser currentUser;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _ChatBackgroundPainter(isDark: dark),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF102A25), Color(0xFF233A2F)]
                : const [
                    Color(0xFFDCEB82),
                    Color(0xFF66BFA2),
                    Color(0xFFE7E7A1),
                  ],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Select a chat to start messaging',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature will be available soon.')));
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppColors.primary
            : Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : const Color(0xFFE8E8EE),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatPreview chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: chat.unread > 0
          ? AppColors.primary.withValues(alpha: 0.025)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ValueListenableBuilder<double>(
          valueListenable: appChatDensity,
          builder: (context, density, _) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12 * density,
            ),
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: appShowAvatars,
                  builder: (_, show, _) => show
                      ? UserAvatar(chat: chat, radius: 30)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    chat.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 16,
                                      fontWeight: chat.unread > 0
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (!chat.isGroup &&
                                    chat.designation.trim().isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 120,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      chat.designation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            chat.time,
                            style: TextStyle(
                              color: chat.unread > 0
                                  ? AppColors.primary
                                  : colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: chat.unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (chat.sentByMe) ...[
                            const Icon(
                              Icons.done_all_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (chat.message == 'Voice message') ...[
                            const Icon(
                              Icons.mic_rounded,
                              color: AppColors.primary,
                              size: 17,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              chat.message.isEmpty
                                  ? 'No messages yet'
                                  : chat.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: chat.unread > 0
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: chat.unread > 0
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (chat.isPinned)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.push_pin_rounded,
                                color: AppColors.muted,
                                size: 16,
                              ),
                            ),
                          if (chat.isStarred)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF5A623),
                                size: 18,
                              ),
                            ),
                          if (chat.isMuted)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.volume_off_rounded,
                                color: AppColors.muted,
                                size: 17,
                              ),
                            ),
                          if (chat.wasMentioned)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE85270),
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '@',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (chat.unread > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${chat.unread}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.chat, required this.radius});

  final ChatPreview chat;
  final double radius;

  String get _initials {
    final parts = chat.name.trim().split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: chat.avatarColor,
          backgroundImage: chat.avatarUrl.isNotEmpty
              ? NetworkImage(chat.avatarUrl)
              : null,
          child: chat.avatarUrl.isNotEmpty
              ? null
              : chat.isGroup
              ? Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: radius * 0.95,
                )
              : Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.62,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        if (chat.isOnline)
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: radius * 0.48,
              height: radius * 0.48,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.isSearch});

  final bool isSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 56,
            color: AppColors.muted,
          ),
          const SizedBox(height: 14),
          Text(
            isSearch ? 'No conversations found' : 'No recent conversations',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isSearch
                ? 'Try another name or message'
                : 'Start a new chat using the compose button',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.currentUser, required this.chats});

  final CurrentUser currentUser;
  final List<ChatPreview> chats;

  String get _initials {
    final parts = currentUser.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return currentUser.empId;
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              22,
              MediaQuery.paddingOf(context).top + 24,
              22,
              24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  backgroundImage: currentUser.avatarUrl.isNotEmpty
                      ? NetworkImage(currentUser.avatarUrl)
                      : null,
                  child: currentUser.avatarUrl.isNotEmpty
                      ? null
                      : Text(
                          _initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  currentUser.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currentUser.jid,
                  style: const TextStyle(color: Color(0xFFC9DCFF)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                _DrawerItem(
                  icon: Icons.group_add_outlined,
                  label: 'New group',
                  onTap: () => _drawerAction(context, 'New group'),
                ),
                _DrawerItem(
                  icon: Icons.tag_rounded,
                  label: 'New channel',
                  onTap: () => _drawerAction(context, 'New channel'),
                ),
                _DrawerItem(
                  icon: Icons.account_circle_outlined,
                  label: 'My profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.schedule_send_rounded,
                  label: 'Schedule message',
                  onTap: () => _drawerAction(context, 'Schedule message'),
                ),
                _DrawerItem(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Saved messages',
                  onTap: () => _drawerAction(context, 'Saved messages'),
                ),
                _DrawerItem(
                  icon: Icons.alarm_outlined,
                  label: 'Reminders & Follow-ups',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RemindersScreen(currentUser: currentUser),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.alternate_email_rounded,
                  label: 'Mentions',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DiscoveryListScreen(
                          title: 'Mentions',
                          view: 'mentions',
                        ),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.folder_outlined,
                  label: 'Chat folders',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatFoldersScreen(chats: chats),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.archive_outlined,
                  label: 'Archived channels',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ArchivedChannelsScreen(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Ticket dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TicketDashboardScreen(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.call_outlined,
                  label: 'Calls',
                  onTap: () => _drawerAction(context, 'Calls'),
                ),
                const Divider(height: 24, indent: 20, endIndent: 20),
                _DrawerItem(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'My Hub',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MyHubScreen(currentUser: currentUser),
                      ),
                    );
                  },
                ),
                if (ChatApi.diagnosticEmployeeIds.contains(currentUser.empId))
                  _DrawerItem(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Advanced diagnostics',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DiagnosticsScreen(),
                        ),
                      );
                    },
                  ),
                if (currentUser.empId == '302')
                  _DrawerItem(
                    icon: Icons.verified_user_outlined,
                    label: 'Release management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ReleaseManagementScreen(),
                        ),
                      );
                    },
                  ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _drawerAction(context, 'Settings'),
                ),
                _DrawerItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & feedback',
                  onTap: () => _drawerAction(context, 'Help & feedback'),
                ),
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  onTap: () {
                    Navigator.pop(context);
                    _logout(context);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) => Text(
                'Skylink v${snapshot.data?.version ?? '1.2.0'}\n'
                'Developed by RK & Co',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _drawerAction(BuildContext context, String action) async {
    Navigator.pop(context);
    if (action == 'Schedule message') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const _ScheduleMessageScreen()),
      );
    } else if (action == 'New group' || action == 'New channel') {
      final group = await showModalBottomSheet<ChatPreview>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NewGroupSheet(isChannel: action == 'New channel'),
      );
      if (group != null && context.mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => ChatScreen(chat: group)),
        );
      }
    } else if (action == 'Saved messages') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SavedMessagesScreen()),
      );
    } else if (action == 'Settings') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(currentUser: currentUser),
        ),
      );
    } else {
      _showComingSoon(context, action);
    }
  }
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, dynamic>? _report;
  String? _error;
  bool _loading = true;
  int _hours = 24;

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
      final report = await chatApi.getDiagnostics(hours: _hours);
      if (mounted) setState(() => _report = report);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to load diagnostics.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _supportReport() {
    final report = _report ?? const <String, dynamic>{};
    final summary = (report['summary'] as List? ?? const []);
    final bottlenecks = (report['bottlenecks'] as List? ?? const []);
    final buffer = StringBuffer()
      ..writeln('Skylink Advanced Diagnostics')
      ..writeln('Report: ${report['report_id'] ?? '-'}')
      ..writeln('Generated: ${report['generated_at'] ?? '-'}')
      ..writeln('Window: ${report['window_hours'] ?? _hours} hours')
      ..writeln()
      ..writeln('Bottlenecks:');
    if (bottlenecks.isEmpty) buffer.writeln('- None detected');
    for (final raw in bottlenecks.whereType<Map>()) {
      buffer.writeln(
        '- ${raw['category']}/${raw['operation']}: '
        '${raw['avg_ms']} ms avg, ${raw['max_ms']} ms max, '
        '${raw['errors']} errors [${raw['severity']}]',
      );
    }
    buffer.writeln('\nAll measurements:');
    for (final raw in summary.whereType<Map>()) {
      buffer.writeln(
        '- ${raw['category']}/${raw['operation']}: '
        '${raw['count']} samples, ${raw['avg_ms']} ms avg, '
        '${raw['max_ms']} ms max',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final summary = (report?['summary'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final bottlenecks = (report?['bottlenecks'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final traces = (report?['traces'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Share support report',
            onPressed: report == null
                ? null
                : () => SharePlus.instance.share(
                    ShareParams(
                      text: _supportReport(),
                      subject: 'Skylink support report ${report['report_id']}',
                    ),
                  ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && report == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && report == null
          ? _LoadError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${report?['report_id'] ?? 'Support report'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Android - API - Database - XMPP - Notification/File Transfer',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1h')),
                              ButtonSegment(value: 24, label: Text('24h')),
                              ButtonSegment(value: 168, label: Text('7d')),
                            ],
                            selected: {_hours},
                            onSelectionChanged: (value) {
                              _hours = value.first;
                              _load();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Detected bottlenecks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (bottlenecks.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        title: Text('No bottlenecks detected'),
                      ),
                    ),
                  ...bottlenecks.map((item) => _DiagnosticTile(item: item)),
                  const SizedBox(height: 16),
                  Text(
                    'Latency summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...summary.map((item) => _DiagnosticTile(item: item)),
                  const SizedBox(height: 16),
                  Text(
                    'Recent trace events (${traces.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  ...traces
                      .take(100)
                      .map(
                        (trace) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.timeline_rounded),
                          title: Text(' - '),
                          subtitle: Text(' - Trace '),
                          trailing: Text(
                            '${(trace['duration_ms'] as num? ?? 0).toStringAsFixed(0)} ms',
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({required this.item});

  final Map item;

  @override
  Widget build(BuildContext context) {
    final severity = '${item['severity'] ?? 'healthy'}';
    final color = switch (severity) {
      'error' || 'critical' => Colors.red,
      'slow' => Colors.orange,
      _ => Colors.green,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: const Icon(Icons.speed_rounded),
        ),
        title: Text(' - '),
        subtitle: Text(' samples - max  ms -  errors'),
        trailing: Text(
          '${item['avg_ms']} ms',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class DiscoveryListScreen extends StatefulWidget {
  const DiscoveryListScreen({
    super.key,
    required this.title,
    required this.view,
    this.jid = '',
  });

  final String title;
  final String view;
  final String jid;

  @override
  State<DiscoveryListScreen> createState() => _DiscoveryListScreenState();
}

class _DiscoveryListScreenState extends State<DiscoveryListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = chatApi.getDiscovery(view: widget.view, jid: widget.jid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final values = snapshot.data ?? const [];
          if (values.isEmpty) {
            return Center(
              child: Text('No ${widget.title.toLowerCase()} found.'),
            );
          }
          return ListView.separated(
            itemCount: values.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final item = values[index];
              final fileName = '${item['file_name'] ?? ''}';
              return ListTile(
                leading: Icon(
                  fileName.isNotEmpty
                      ? Icons.attach_file_rounded
                      : Icons.chat_bubble_outline_rounded,
                ),
                title: Text(
                  fileName.isNotEmpty ? fileName : '${item['body'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "${item['from'] ?? ''} ? ${item['created_at'] ?? ''}",
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  Timer? _timer;
  bool _loading = false;
  Map<String, dynamic> _results = {};

  Future<void> _search(String value) async {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().isEmpty) {
        if (mounted) setState(() => _results = {});
        return;
      }
      setState(() => _loading = true);
      try {
        final result = await chatApi.globalSearch(value.trim());
        if (mounted) setState(() => _results = result);
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _results['messages'] is List
        ? _results['messages'] as List
        : const [];
    final conversations = _results['conversations'] is List
        ? _results['conversations'] as List
        : const [];
    final users = _results['users'] is List
        ? _results['users'] as List
        : const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Search everything')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText:
                    'Messages, users, channels, groups, tasks, tickets, files',
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                if (conversations.isNotEmpty)
                  const ListTile(
                    title: Text(
                      'Channels and groups',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ...conversations.map(
                  (item) => ListTile(
                    leading: Icon(
                      '${item['type']}' == 'channel'
                          ? Icons.tag_rounded
                          : Icons.groups_outlined,
                    ),
                    title: Text('${item['name'] ?? ''}'),
                    subtitle: Text('${item['type'] ?? ''}'),
                  ),
                ),
                if (users.isNotEmpty)
                  const ListTile(
                    title: Text(
                      'Users',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ...users.map(
                  (item) => ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text('${item['name'] ?? ''}'),
                    subtitle: Text(
                      "${item['designation'] ?? ''} ? ${item['jid'] ?? ''}",
                    ),
                    onTap: () {
                      final contact = ChatContact.fromJson(
                        Map<String, dynamic>.from(item as Map),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(
                            chat: ChatPreview.fromContact(contact),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (messages.isNotEmpty)
                  const ListTile(
                    title: Text(
                      'Messages, files and attachments',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ...messages.map(
                  (item) => ListTile(
                    leading: Icon(
                      '${item['file_name'] ?? ''}'.isNotEmpty
                          ? Icons.attach_file_rounded
                          : Icons.chat_bubble_outline_rounded,
                    ),
                    title: Text(
                      '${item['file_name'] ?? ''}'.isNotEmpty
                          ? '${item['file_name']}'
                          : '${item['body'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${item['created_at'] ?? ''}'),
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

class ChatMediaBrowser extends StatelessWidget {
  const ChatMediaBrowser({super.key, required this.chat});

  final ChatPreview chat;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Media',
      'Files',
      'Links',
      'Voice Notes',
      'Tasks',
      'Shared Channels',
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${chat.name} media'),
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs.map((label) => Tab(text: label)).toList(),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: chatApi.getDiscovery(view: 'media', jid: chat.jid),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snapshot.data ?? const [];
            List<Map<String, dynamic>> filter(String tab) {
              return all.where((item) {
                final type = '${item['file_type'] ?? ''}'.toLowerCase();
                final body = '${item['body'] ?? ''}'.toLowerCase();
                final file = '${item['file_name'] ?? ''}';
                return switch (tab) {
                  'Media' =>
                    type.startsWith('image/') || type.startsWith('video/'),
                  'Files' =>
                    file.isNotEmpty &&
                        !type.startsWith('image/') &&
                        !type.startsWith('video/') &&
                        !type.startsWith('audio/'),
                  'Links' => RegExp(r'https?://').hasMatch(body),
                  'Voice Notes' => type.startsWith('audio/'),
                  'Tasks' =>
                    body.contains('task') ||
                        '${item['message_type']}' == 'task',
                  'Shared Channels' =>
                    body.contains('#channel') ||
                        body.contains('conference.chat'),
                  _ => true,
                };
              }).toList();
            }

            return TabBarView(
              children: tabs.map((tab) {
                final values = filter(tab);
                if (values.isEmpty) {
                  return Center(child: Text('No $tab found.'));
                }
                return ListView.builder(
                  itemCount: values.length,
                  itemBuilder: (_, index) {
                    final item = values[index];
                    return ListTile(
                      leading: Icon(
                        tab == 'Links'
                            ? Icons.link_rounded
                            : tab == 'Media'
                            ? Icons.photo_outlined
                            : Icons.insert_drive_file_outlined,
                      ),
                      title: Text(
                        '${item['file_name'] ?? ''}'.isNotEmpty
                            ? '${item['file_name']}'
                            : '${item['body'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${item['created_at'] ?? ''}'),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _ScheduleMessageScreen extends StatefulWidget {
  const _ScheduleMessageScreen();

  @override
  State<_ScheduleMessageScreen> createState() => _ScheduleMessageScreenState();
}

class _ScheduleMessageScreenState extends State<_ScheduleMessageScreen> {
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
                                _recurrenceLabel(recurrence),
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

String _recurrenceLabel(String value) {
  return switch (value) {
    'daily' => 'Every day',
    'weekly' => 'Every week',
    'monthly' => 'Every month',
    _ => 'This time only',
  };
}

class MyHubScreen extends StatelessWidget {
  const MyHubScreen({super.key, required this.currentUser});

  final CurrentUser currentUser;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Punch In / Out', Icons.fingerprint_rounded),
      ('Attendance', Icons.calendar_month_outlined),
      ('Leave Management', Icons.beach_access_outlined),
      ('Leave Application', Icons.edit_calendar_outlined),
      ('Achievements', Icons.emoji_events_outlined),
      ('Employee Directory', Icons.people_outline_rounded),
      ('Company Announcements', Icons.campaign_outlined),
      ('Tasks & Tickets', Icons.task_alt_outlined),
      ('Reminders & Follow-ups', Icons.notifications_active_outlined),
      ('Projects', Icons.workspaces_outline),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('My Hub')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 330,
          mainAxisExtent: 112,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (index == 0) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileScreen(showAttendance: true),
                    ),
                  );
                } else if (index == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AttendanceCalendarScreen(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyHubLeaveScreen(),
                    ),
                  );
                } else if (index == 3) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyHubLeaveApplyScreen(),
                    ),
                  );
                } else if (item.$1 == 'Reminders & Follow-ups') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RemindersScreen(currentUser: currentUser),
                    ),
                  );
                } else if (item.$1 == 'Tasks & Tickets') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyHubTasksScreen(),
                    ),
                  );
                } else {
                  _showComingSoon(context, item.$1);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFDCE6FF),
                      child: Icon(item.$2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ArchivedChannelsScreen extends StatelessWidget {
  const ArchivedChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived channels')),
      body: FutureBuilder<List<ChatContact>>(
        future: chatApi.getArchivedChannels(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load archived channels.'),
            );
          }
          final channels = snapshot.data ?? const [];
          if (channels.isEmpty) {
            return const Center(child: Text('No archived channels.'));
          }
          return ListView.separated(
            itemCount: channels.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final channel = ChatPreview.fromContact(channels[index]);
              return ListTile(
                leading: UserAvatar(chat: channel, radius: 24),
                title: Text(channel.name),
                subtitle: const Text('Closed - Read-only archive'),
                trailing: const Icon(Icons.lock_outline_rounded),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatFoldersScreen extends StatefulWidget {
  const ChatFoldersScreen({super.key, required this.chats});

  final List<ChatPreview> chats;

  @override
  State<ChatFoldersScreen> createState() => _ChatFoldersScreenState();
}

class _ChatFoldersScreenState extends State<ChatFoldersScreen> {
  static const _storageKey = 'chat_folders_v1';
  Map<String, List<String>> _folders = {};
  List<String> _folderOrder = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (mounted) {
        setState(() {
          _folders = decoded.map(
            (name, values) => MapEntry(
              name,
              (values as List).map((value) => '$value').toList(),
            ),
          );
          _folderOrder = _folders.keys.toList();
        });
      }
    } catch (error) {
      // Ignore damaged local folder preferences.
    }
  }

  Future<void> _save() async {
    final ordered = <String, List<String>>{};
    for (final name in _folderOrder) {
      final chats = _folders[name];
      if (chats != null) ordered[name] = chats;
    }
    _folders = ordered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_folders));
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final selected = <String>{};
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create chat folder'),
          content: SizedBox(
            width: 430,
            height: 480,
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Folder name',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: widget.chats
                        .map(
                          (chat) => CheckboxListTile(
                            value: selected.contains(chat.jid),
                            title: Text(chat.name),
                            subtitle: Text(
                              chat.isChannel
                                  ? 'Channel'
                                  : chat.isGroup
                                  ? 'Group'
                                  : chat.designation,
                            ),
                            onChanged: (value) => setDialogState(() {
                              if (value ?? false) {
                                selected.add(chat.jid);
                              } else {
                                selected.remove(chat.jid);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (created != true || name.isEmpty || selected.isEmpty) return;
    setState(() {
      _folders[name] = selected.toList();
      _folderOrder.add(name);
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat folders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFolder,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New folder'),
      ),
      body: _folders.isEmpty
          ? const Center(
              child: Text(
                'Create folders to organise users, groups and channels.',
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.only(bottom: 90),
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final name = _folderOrder.removeAt(oldIndex);
                  _folderOrder.insert(newIndex, name);
                });
                await _save();
              },
              children: _folderOrder.map((folderName) {
                final folder = MapEntry(
                  folderName,
                  _folders[folderName] ?? const <String>[],
                );
                final chats = widget.chats
                    .where((chat) => folder.value.contains(chat.jid))
                    .toList();
                return ExpansionTile(
                  key: ValueKey(folder.key),
                  leading: const Icon(Icons.folder_rounded),
                  title: Text(
                    folder.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${chats.length} chats'),
                  trailing: IconButton(
                    tooltip: 'Delete folder',
                    onPressed: () async {
                      setState(() {
                        _folders.remove(folder.key);
                        _folderOrder.remove(folder.key);
                      });
                      await _save();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  children: chats
                      .map(
                        (chat) => ListTile(
                          leading: UserAvatar(chat: chat, radius: 22),
                          title: Text(chat.name),
                          subtitle: Text(chat.message),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(chat: chat),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
    );
  }
}

class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  final _controller = TextEditingController();
  List<SavedMessage> _messages = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  Future<void> _loadCached() async {
    final cached = await chatApi.cachedSavedMessages();
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _messages = cached;
        _loading = false;
      });
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      final messages = await chatApi.getSavedMessages();
      if (mounted) setState(() => _messages = messages);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await chatApi.saveMessage(text);
      _controller.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Note saved.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this note.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved messages')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(child: Text('Save notes and messages here.'))
                : ListView.separated(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = _messages[index];
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: AppColors.outgoing,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(item.body),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Write a note',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _save,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.currentUser});

  final CurrentUser? currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: const Text('Profile photo'),
            subtitle: const Text('Choose or update your profile picture'),
            trailing: const Icon(Icons.photo_camera_outlined),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.devices_rounded),
            title: const Text('Devices'),
            subtitle: const Text('View active login sessions'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ActiveSessionsScreen(),
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('Notifications and sounds'),
            subtitle: Text('Use chat menu to mute a user or group'),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline_rounded),
            title: Text('Privacy and security'),
            subtitle: Text('Session and last-seen controls'),
          ),
          const ListTile(
            leading: Icon(Icons.data_usage_rounded),
            title: Text('Data and storage'),
            subtitle: Text('Images are compressed; documents stay original'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: const Text('Theme, font size, density and chat bubbles'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AppearanceSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.new_releases_outlined),
            title: const Text('What\'s New'),
            subtitle: const Text('Release notes for this app version'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WhatsNewScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_rounded),
            title: const Text('Check for updates'),
            subtitle: const Text('Download the latest Skylink version'),
            onTap: () async {
              final status = await chatApi.getVersionStatus();
              if (!context.mounted) return;
              if (!status.updateAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Skylink is up to date.')),
                );
                return;
              }
              await launchUrl(
                Uri.parse(status.url),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.chat_bubble_outline_rounded),
            title: Text('Chat settings'),
            subtitle: Text('Telegram-style chat preferences'),
          ),
          if (currentUser != null &&
              canAccessFlowDevelopment(
                employeeId: currentUser!.empId,
                name: currentUser!.name,
                designation: currentUser!.designation,
              ))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Development'),
              subtitle: const Text(
                'Feature registry, release register and audits',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FlowDevelopmentScreen(
                    viewerEmployeeId: currentUser!.empId,
                    viewerName: currentUser!.name,
                    viewerDesignation: currentUser!.designation,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  ReleaseNote? _note;
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
      final note = await chatApi.getReleaseNotes();
      if (!mounted) return;
      setState(() => _note = note);
      if (note != null && !note.viewed) {
        unawaited(chatApi.markReleaseNoteViewed(note.id));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to load release notes.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Scaffold(
      appBar: AppBar(title: const Text('What\'s New')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _LoadError(message: _error!, onRetry: _load)
          : note == null || note.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No release notes are available for this version yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.new_releases_rounded,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Skylink v${note.version}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Release date: ${note.releaseDate.isEmpty ? '-' : note.releaseDate}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ReleaseNoteContent(note: note),
                ],
              ),
            ),
    );
  }
}

class _ReleaseNoteContent extends StatelessWidget {
  const _ReleaseNoteContent({required this.note});

  final ReleaseNote note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReleaseNoteSection(
          icon: Icons.auto_awesome_outlined,
          title: 'New features',
          body: note.newFeatures,
        ),
        _ReleaseNoteSection(
          icon: Icons.trending_up_rounded,
          title: 'Improvements',
          body: note.improvements,
        ),
        _ReleaseNoteSection(
          icon: Icons.bug_report_outlined,
          title: 'Bug fixes',
          body: note.bugFixes,
        ),
        _ReleaseNoteSection(
          icon: Icons.security_rounded,
          title: 'Security updates',
          body: note.securityUpdates,
        ),
        _ReleaseNoteSection(
          icon: Icons.integration_instructions_outlined,
          title: 'Implementation details',
          body: note.implementationDetails,
        ),
      ],
    );
  }
}

class _ReleaseNoteSection extends StatelessWidget {
  const _ReleaseNoteSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(trimmed),
          ],
        ),
      ),
    );
  }
}

class ReleaseManagementScreen extends StatefulWidget {
  const ReleaseManagementScreen({super.key});

  @override
  State<ReleaseManagementScreen> createState() =>
      _ReleaseManagementScreenState();
}

class _ReleaseManagementScreenState extends State<ReleaseManagementScreen> {
  ReleaseGovernance? _governance;
  bool _loading = true;
  String? _error;

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
      final data = await chatApi.getReleases();
      if (mounted) {
        setState(() {
          _governance = data;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _register() async {
    final version = TextEditingController();
    final build = TextEditingController();
    final url = TextEditingController(
      text:
          'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-latest.apk',
    );
    final notes = TextEditingController();
    var platform = 'android';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Register uploaded build'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: platform,
                  items: const [
                    DropdownMenuItem(
                      value: 'android',
                      child: Text('Android APK'),
                    ),
                    DropdownMenuItem(value: 'windows', child: Text('Windows')),
                    DropdownMenuItem(
                      value: 'linux',
                      child: Text('Ubuntu/Linux'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => platform = value ?? 'android'),
                ),
                TextField(
                  controller: version,
                  decoration: const InputDecoration(labelText: 'Version'),
                ),
                TextField(
                  controller: build,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Build number'),
                ),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'Download URL'),
                ),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Release notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save as Draft'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.registerReleaseBuild(
        platform: platform,
        version: version.text.trim(),
        buildNumber: int.tryParse(build.text.trim()) ?? 0,
        url: url.text.trim(),
        notes: notes.text.trim(),
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _action(ReleaseBuild build, String action) async {
    var force = false;
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(action.replaceAll('_', ' ')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${build.platform} ${build.version}+${build.buildNumber}'),
              if (action == 'approve_for_production')
                CheckboxListTile(
                  value: force,
                  title: const Text('Enable force update'),
                  subtitle: const Text(
                    'Allowed only after Ajith approves Production.',
                  ),
                  onChanged: (value) =>
                      setDialogState(() => force = value ?? false),
                ),
              TextField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
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
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.releaseAction(
        releaseId: build.id,
        action: action,
        notes: notes.text.trim(),
        forceUpdate: force,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final governance = _governance;
    return Scaffold(
      appBar: AppBar(title: const Text('Release management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _register,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('New draft'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _LoadError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(
                        governance?.canApproveProduction == true
                            ? Icons.verified_user_rounded
                            : Icons.lock_outline_rounded,
                      ),
                      title: const Text('Production approval'),
                      subtitle: Text(
                        governance?.canApproveProduction == true
                            ? 'Ajith (302) can approve Production and force update.'
                            : 'Only Ajith (302) may approve Production.',
                      ),
                    ),
                  ),
                  ...?governance?.builds.map(
                    (build) => Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          child: Text(
                            build.platform.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          '${build.platform} ${build.version}+${build.buildNumber}',
                        ),
                        subtitle: Text(
                          '${build.stage} - ${build.status} - rollout ${build.rolloutPercent}%',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        children: [
                          if (build.notes.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(build.notes),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _action(build, 'reject_build'),
                                child: const Text('Reject'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _action(build, 'deploy_to_testers'),
                                child: const Text('Deploy testers'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _action(build, 'deploy_to_pilot_users'),
                                child: const Text('Pilot'),
                              ),
                              FilledButton(
                                onPressed:
                                    governance.canApproveProduction == true
                                    ? () => _action(
                                        build,
                                        'approve_for_production',
                                      )
                                    : null,
                                child: const Text('Approve production'),
                              ),
                              OutlinedButton(
                                onPressed:
                                    governance.canApproveProduction == true
                                    ? () => _action(build, 'rollback_release')
                                    : null,
                                child: const Text('Rollback'),
                              ),
                            ],
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

class TicketDashboardScreen extends StatefulWidget {
  const TicketDashboardScreen({super.key});

  @override
  State<TicketDashboardScreen> createState() => _TicketDashboardScreenState();
}

class _TicketDashboardScreenState extends State<TicketDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
      final data = await chatApi.getTicketDashboard();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _healthColor(String value) => switch (value) {
    'green' => Colors.green,
    'yellow' => Colors.amber,
    'red' => Colors.red,
    'black' => Colors.black,
    _ => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] is Map
        ? Map<String, dynamic>.from(_data!['summary'] as Map)
        : <String, dynamic>{};
    final tickets = _data?['tickets'] is List
        ? (_data!['tickets'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Executive ticket view')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _LoadError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricCard(
                        'Open',
                        '${summary['open_ticket_channels'] ?? 0}',
                      ),
                      _MetricCard(
                        'Critical',
                        '${summary['critical_tickets'] ?? 0}',
                      ),
                      _MetricCard(
                        'Breached',
                        '${summary['breached_tickets'] ?? 0}',
                      ),
                      _MetricCard(
                        'Near SLA',
                        '${summary['tickets_near_sla_breach'] ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...tickets.map(
                    (ticket) => Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.circle,
                          color: _healthColor('${ticket['sla_health']}'),
                          size: 16,
                        ),
                        title: Text('${ticket['name']}'),
                        subtitle: Text(
                          '${ticket['channel_kind']} - ${ticket['status_text']} - '
                          'Age ${ticket['age_label']} - SLA ${ticket['sla_usage_percent']}%',
                        ),
                        trailing: Text('${ticket['priority']}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  late ThemeMode _theme;
  late double _scale;
  late double _density;
  late bool _avatars;
  late bool _collapseLongMessages;
  late String _workspaceMode;
  String _bubble = 'rounded';

  @override
  void initState() {
    super.initState();
    _theme = appThemeMode.value;
    _scale = appMessageScale.value;
    _density = appChatDensity.value;
    _avatars = appShowAvatars.value;
    _collapseLongMessages = appCollapseLongMessages.value;
    _workspaceMode = appWorkspaceMode.value;
  }

  Future<void> _save() async {
    appThemeMode.value = _theme;
    appMessageScale.value = _scale;
    appChatDensity.value = _density;
    appShowAvatars.value = _avatars;
    appCollapseLongMessages.value = _collapseLongMessages;
    appWorkspaceMode.value = _workspaceMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _theme.name);
    await prefs.setDouble('message_scale', _scale);
    await prefs.setDouble('chat_density', _density);
    await prefs.setBool('show_avatars', _avatars);
    await prefs.setBool('collapse_long_messages', _collapseLongMessages);
    await prefs.setString('workspace_mode', _workspaceMode);
    await prefs.setString('bubble_style', _bubble);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ],
            selected: {_theme},
            onSelectionChanged: (value) {
              setState(() => _theme = value.first);
              _save();
            },
          ),
          const SizedBox(height: 24),
          Text('Message font size: ${(_scale * 100).round()}%'),
          Slider(
            value: _scale,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            onChanged: (value) => setState(() => _scale = value),
            onChangeEnd: (_) => _save(),
          ),
          Text('Chat density: ${(_density * 100).round()}%'),
          Slider(
            value: _density,
            min: 0.75,
            max: 1.25,
            divisions: 5,
            onChanged: (value) => setState(() => _density = value),
            onChangeEnd: (_) => _save(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show avatars'),
            value: _avatars,
            onChanged: (value) {
              setState(() => _avatars = value);
              _save();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Collapse long messages'),
            subtitle: const Text('Show long messages in a compact preview.'),
            value: _collapseLongMessages,
            onChanged: (value) {
              setState(() => _collapseLongMessages = value);
              _save();
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _workspaceMode,
            decoration: const InputDecoration(labelText: 'Workspace mode'),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: 'two_pane', child: Text('Two panel')),
              DropdownMenuItem(value: 'three_pane', child: Text('Three panel')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _workspaceMode = value);
              _save();
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _bubble,
            decoration: const InputDecoration(labelText: 'Bubble style'),
            items: const [
              DropdownMenuItem(value: 'rounded', child: Text('Rounded')),
              DropdownMenuItem(value: 'compact', child: Text('Compact')),
              DropdownMenuItem(value: 'classic', child: Text('Classic')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _bubble = value);
              _save();
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Live preview',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16 * _density),
              child: Text(
                'This is how your Skylink messages will look.',
                style: TextStyle(fontSize: 15 * _scale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          ? _LoadError(message: _error!, onRetry: _load)
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
          ? _LoadError(message: _error!, onRetry: _load)
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
          ? _LoadError(message: _error!, onRetry: _load)
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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

void _showNewMessageSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NewMessageSheet(),
  );
}

class _NewGroupSheet extends StatefulWidget {
  const _NewGroupSheet({this.isChannel = false});

  final bool isChannel;

  @override
  State<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _ManageGroupSheet extends StatefulWidget {
  const _ManageGroupSheet({
    required this.groupId,
    required this.initialMembers,
    required this.isOwner,
    required this.currentRole,
  });

  final int groupId;
  final List<GroupMember> initialMembers;
  final bool isOwner;
  final String currentRole;

  @override
  State<_ManageGroupSheet> createState() => _ManageGroupSheetState();
}

class _ManageGroupSheetState extends State<_ManageGroupSheet> {
  late List<GroupMember> _members;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _members = [...widget.initialMembers];
  }

  Future<void> _remove(GroupMember member) async {
    setState(() => _busy = true);
    try {
      await chatApi.manageGroupMember(
        groupId: widget.groupId,
        empId: member.empId,
        add: false,
      );
      if (mounted) setState(() => _members.remove(member));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMember() async {
    final users = await chatApi.searchUsers();
    if (!mounted) return;
    final existing = _members.map((member) => member.empId).toSet();
    final selected = await showDialog<ChatContact>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add member'),
        content: SizedBox(
          width: 420,
          height: 420,
          child: ListView(
            children: users
                .where((user) => !existing.contains(user.empId))
                .map(
                  (user) => ListTile(
                    title: Text(user.name),
                    subtitle: Text(user.designation),
                    onTap: () => Navigator.pop(dialogContext, user),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await chatApi.manageGroupMember(
        groupId: widget.groupId,
        empId: selected.empId,
        add: true,
      );
      if (!mounted) return;
      final refreshed = await chatApi.getGroupMembers(widget.groupId);
      if (mounted) setState(() => _members = refreshed.members);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Icon(Icons.groups_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Group members',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (widget.isOwner)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: Icon(Icons.person_add_rounded),
              ),
              title: const Text('Add member'),
              enabled: !_busy,
              onTap: _addMember,
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _members.length,
              itemBuilder: (_, index) {
                final member = _members[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      member.name.isEmpty
                          ? member.empId
                          : member.name[0].toUpperCase(),
                    ),
                  ),
                  title: Text(member.name),
                  subtitle: Text(
                    member.role == 'owner'
                        ? 'Owner'
                        : member.role == 'admin'
                        ? 'Admin'
                        : member.designation,
                  ),
                  trailing: widget.isOwner && member.role != 'owner'
                      ? IconButton(
                          tooltip: 'Remove member',
                          onPressed: _busy ? null : () => _remove(member),
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: Color(0xFFB3261E),
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NewGroupSheetState extends State<_NewGroupSheet> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _slaController = TextEditingController();
  final _staleController = TextEditingController(text: '120');
  final _targetDateController = TextEditingController();
  final _nextActionController = TextEditingController();
  final Set<String> _selectedIds = {};
  List<ChatContact> _users = [];
  String _channelType = 'operational';
  String _priority = 'Normal';
  Timer? _debounce;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    _slaController.dispose();
    _staleController.dispose();
    _targetDateController.dispose();
    _nextActionController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadUsers(value.trim()),
    );
  }

  Future<void> _loadUsers([String search = '']) async {
    if (mounted) setState(() => _loading = true);
    try {
      final users = await chatApi.searchUsers(search);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _pickChannelDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text.trim()) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(now.year - 1)) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    controller.text = _formatChannelDateTime(selected);
  }

  String _formatChannelDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedIds.isEmpty || _creating) {
      setState(
        () => _error =
            'Enter a ${widget.isChannel ? 'channel' : 'group'} name and select members.',
      );
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final group = widget.isChannel
          ? await chatApi.createChannel(
              name: name,
              memberEmployeeIds: _selectedIds.toList(),
              channelType: _channelType,
              priority: _priority,
              targetDate: _targetDateController.text.trim(),
              nextActionDate: _nextActionController.text.trim(),
              slaMinutes: int.tryParse(_slaController.text.trim()) ?? 0,
              staleAlertMinutes:
                  int.tryParse(_staleController.text.trim()) ?? 0,
            )
          : await chatApi.createGroup(
              name: name,
              memberIds: _selectedIds.toList(),
            );
      if (!mounted) return;
      Navigator.pop(context, ChatPreview.fromContact(group));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to create the ${widget.isChannel ? 'channel' : 'group'}.',
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isChannel ? 'New channel' : 'New group',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: TextField(
              controller: _nameController,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: widget.isChannel ? 'Channel name' : 'Group name',
                prefixIcon: Icon(
                  widget.isChannel ? Icons.tag_rounded : Icons.groups_rounded,
                ),
                counterText: '',
              ),
            ),
          ),
          if (widget.isChannel)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _channelType,
                    decoration: const InputDecoration(
                      labelText: 'Channel type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'incident',
                        child: Text('Incident'),
                      ),
                      DropdownMenuItem(value: 'action', child: Text('Action')),
                      DropdownMenuItem(
                        value: 'operational',
                        child: Text('Operational'),
                      ),
                      DropdownMenuItem(
                        value: 'project',
                        child: Text('Project'),
                      ),
                      DropdownMenuItem(
                        value: 'announcement',
                        child: Text('Announcement'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _channelType = value ?? 'operational';
                      if (_slaController.text.isEmpty) {
                        _slaController.text = switch (_channelType) {
                          'incident' => '240',
                          'action' => '1440',
                          'project' => '10080',
                          'announcement' => '0',
                          _ => '1440',
                        };
                      }
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'Normal',
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'High',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'Critical',
                              child: Text('Critical'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _priority = value ?? 'Normal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _staleController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stale alert min',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (const {
                    'ticket',
                    'action',
                    'incident',
                    'project',
                    'installation',
                    'l2_feasibility',
                    'protect',
                  }.contains(_channelType)) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _targetDateController,
                            readOnly: true,
                            onTap: () =>
                                _pickChannelDate(_targetDateController),
                            decoration: const InputDecoration(
                              labelText: 'Target date',
                              hintText: 'Select date',
                              suffixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _nextActionController,
                            readOnly: true,
                            onTap: () =>
                                _pickChannelDate(_nextActionController),
                            decoration: const InputDecoration(
                              labelText: 'Next action date',
                              hintText: 'Select date',
                              suffixIcon: Icon(Icons.event_available_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (const {
                    'ticket',
                    'incident',
                    'action',
                  }.contains(_channelType)) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _slaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'SLA minutes',
                        helperText:
                            'Green 0-50%, Yellow 50-80%, Red 80-100%, Black breached',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search members',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB3261E)),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (_, index) {
                      final user = _users[index];
                      final selected = _selectedIds.contains(user.empId);
                      final preview = ChatPreview.fromContact(user);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value ?? false) {
                              _selectedIds.add(user.empId);
                            } else {
                              _selectedIds.remove(user.empId);
                            }
                          });
                        },
                        secondary: UserAvatar(chat: preview, radius: 22),
                        title: Text(
                          preview.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          preview.designation.isEmpty
                              ? 'Employee ${preview.empId}'
                              : preview.designation,
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        widget.isChannel
                            ? Icons.add_circle_outline_rounded
                            : Icons.group_add_rounded,
                      ),
                label: Text(
                  _creating
                      ? 'Creating...'
                      : 'Create ' + (widget.isChannel ? 'channel' : 'group'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewMessageSheet extends StatefulWidget {
  const _NewMessageSheet();

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  Timer? _debounce;
  List<ChatPreview> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search([String value = '']) async {
    if (mounted) setState(() => _loading = true);
    try {
      final users = await chatApi.searchUsers(value.trim());
      if (!mounted) return;
      setState(() {
        _users = users.map(ChatPreview.fromContact).toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load users.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Text(
                  'New message',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search people',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _LoadError(message: _error!, onRetry: _search)
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, _) =>
                        const Divider(indent: 72, color: AppColors.divider),
                    itemBuilder: (_, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: UserAvatar(chat: user, radius: 23),
                        title: Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          user.designation.isEmpty
                              ? user.jid
                              : user.designation,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(chat: user),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    this.id = 0,
    required this.text,
    required this.time,
    required this.isMe,
    this.sender,
    this.isRead = true,
    this.readAt = '',
    this.attachment,
    this.replyToId = 0,
    this.threadRootId = 0,
    this.mentions = const [],
    this.isEdited = false,
    this.sourceDevice = 'unknown',
    this.sourceName = '',
    this.locationAddress = '',
    this.createdAt,
    this.isSending = false,
    this.isFailed = false,
    this.reaction = '',
    this.isStarred = false,
    this.originalSenderJid = '',
    this.originalSenderName = '',
    this.originalSourceName = '',
    this.isSystem = false,
  });

  final int id;
  final String text;
  final String time;
  final bool isMe;
  final String? sender;
  final bool isRead;
  final String readAt;
  final ChatAttachment? attachment;
  final int replyToId;
  final int threadRootId;
  final List<String> mentions;
  final bool isEdited;
  final String sourceDevice;
  final String sourceName;
  final String locationAddress;
  final DateTime? createdAt;
  final bool isSending;
  final bool isFailed;
  final String reaction;
  final bool isStarred;
  final String originalSenderJid;
  final String originalSenderName;
  final String originalSourceName;
  final bool isSystem;

  ChatMessage copyWith({
    int? id,
    String? text,
    bool? isRead,
    String? readAt,
    bool? isSending,
    bool? isFailed,
    String? reaction,
    bool? isStarred,
    String? originalSenderJid,
    String? originalSenderName,
    String? originalSourceName,
    String? locationAddress,
    bool? isSystem,
  }) => ChatMessage(
    id: id ?? this.id,
    text: text ?? this.text,
    time: time,
    isMe: isMe,
    sender: sender,
    isRead: isRead ?? this.isRead,
    readAt: readAt ?? this.readAt,
    attachment: attachment,
    replyToId: replyToId,
    threadRootId: threadRootId,
    mentions: mentions,
    isEdited: isEdited,
    sourceDevice: sourceDevice,
    sourceName: sourceName,
    locationAddress: locationAddress ?? this.locationAddress,
    createdAt: createdAt,
    isSending: isSending ?? this.isSending,
    isFailed: isFailed ?? this.isFailed,
    reaction: reaction ?? this.reaction,
    isStarred: isStarred ?? this.isStarred,
    originalSenderJid: originalSenderJid ?? this.originalSenderJid,
    originalSenderName: originalSenderName ?? this.originalSenderName,
    originalSourceName: originalSourceName ?? this.originalSourceName,
    isSystem: isSystem ?? this.isSystem,
  );

  String get previewText {
    final item = attachment;
    if (item == null) {
      final contact = _decodeContactCard(text);
      if (contact != null) {
        final name = '${contact['name'] ?? ''}'.trim();
        return name.isEmpty ? 'Contact' : 'Contact: $name';
      }
      return text.replaceAll('\n', ' ').trim();
    }
    if (item.isLocation) {
      if (item.locationAddress.isNotEmpty) return item.locationAddress;
      return item.isLiveLocation ? 'Live location' : 'Current location';
    }
    return 'Attachment: ${item.name}';
  }
}

class _AttachmentDraft {
  const _AttachmentDraft({required this.files, required this.caption});

  final List<PlatformFile> files;
  final String caption;
}

class _MessageLocationMetadata {
  const _MessageLocationMetadata({
    this.latitude,
    this.longitude,
    this.address = '',
  });

  final double? latitude;
  final double? longitude;
  final String address;

  bool get hasLocation => latitude != null && longitude != null;
}

class _PendingChatMessage {
  const _PendingChatMessage({required this.message, required this.createdAt});

  final ChatMessage message;
  final DateTime createdAt;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    this.initialMessageId = 0,
    this.onProfileTap,
  });

  final ChatPreview chat;
  final int initialMessageId;
  final VoidCallback? onProfileTap;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  final List<ChatMessage> _messages = [];
  final List<_PendingChatMessage> _pendingOutgoing = [];
  Timer? _pollTimer;
  Timer? _draftTimer;
  bool _hasText = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  bool _showEmojiPicker = false;
  double _uploadProgress = 0;
  String? _loadError;
  PresenceInfo? _presence;
  ChatMessage? _replyingTo;
  String _replyQuote = '';
  int _threadRootId = 0;
  bool _isMuted = false;
  bool _historyRequestActive = false;
  bool _presenceRequestActive = false;
  bool _showJumpToLatest = false;
  int _savedReadMessageId = 0;
  int _returnReadMessageId = 0;
  int _newMessageCount = 0;
  List<GroupMember> _groupMembers = [];
  String _groupRole = '';
  bool _canViewMessageLocations = false;
  String _mentionQuery = '';
  final Set<String> _selectedMentions = {};
  final Map<int, GlobalKey> _messageKeys = {};
  final Set<int> _selectedMessageIds = <int>{};
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final SpeechToText _speechToText = SpeechToText();
  bool _isRecordingVoice = false;
  String _voiceTranscript = '';
  String? _voiceRecordingPath;
  bool _isDragOver = false;
  Timer? _liveLocationTimer;
  bool _liveLocationSharing = false;
  DateTime? _liveLocationEndsAt;
  Position? _lastMessagePosition;
  DateTime? _lastMessagePositionAt;
  Future<Position?>? _messagePositionFuture;
  String _lastMessageAddress = '';
  double? _lastMessageAddressLatitude;
  double? _lastMessageAddressLongitude;
  DateTime? _lastMessageAddressAt;
  bool get _isSystemNotification =>
      widget.chat.jid.toLowerCase() == systemNotificationJid;

  @override
  void initState() {
    super.initState();
    _loadInitialHistory();
    _loadConversationState();
    _itemPositionsListener.itemPositions.addListener(_trackScrollPosition);
    _loadPresence();
    if (widget.chat.isGroup) _loadGroupMembers();
    _loadMessageLocationVisibility();
    _warmMessageLocationMetadata();
    registerClipboardMediaHandler(_handleClipboardMediaPaste);
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      _loadHistory(silent: true);
      if (timer.tick % 5 == 0) _loadPresence();
    });
    /*
    _messages = [
      const ChatMessage(
        text: 'Hey! How are you doing?',
        time: '10:30 AM',
        isMe: false,
        sender: 'Priya',
      ),
      const ChatMessage(
        text: 'I am doing great! Just finishing up the Skylink designs.',
        time: '10:32 AM',
        isMe: true,
      ),
      const ChatMessage(
        text: 'That sounds exciting. Can you share a preview?',
        time: '10:34 AM',
        isMe: false,
        sender: 'Priya',
      ),
      const ChatMessage(
        text: 'Of course! The new chat experience is clean and super smooth.',
        time: '10:37 AM',
        isMe: true,
      ),
      ChatMessage(
        text: widget.chat.message,
        time: widget.chat.time.contains('AM') ? widget.chat.time : '10:42 AM',
        isMe: false,
        sender: widget.chat.isGroup
            ? 'Arun'
            : widget.chat.name.split(' ').first,
      ),
    ];
    */
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      final mention = RegExp(
        r'@([A-Za-z0-9_]*)$',
      ).firstMatch(_messageController.text);
      final mentionQuery = mention?.group(1)?.toLowerCase() ?? '';
      if (hasText != _hasText || mentionQuery != _mentionQuery) {
        setState(() {
          _hasText = hasText;
          _mentionQuery = mention == null ? '' : mentionQuery;
        });
      }
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 700), () {
        chatApi
            .saveDraft(
              jid: widget.chat.jid,
              body: _messageController.text,
              replyToId: _replyingTo?.id ?? 0,
            )
            .catchError((_) {});
      });
    });
  }

  Future<void> _loadConversationState() async {
    try {
      final state = await chatApi.getConversationState(widget.chat.jid);
      final draft = state['draft'];
      final position = state['read_position'];
      if (!mounted) return;
      if (draft is Map && _messageController.text.isEmpty) {
        _messageController.text = '${draft['body'] ?? ''}';
      }
      if (position is Map) {
        _savedReadMessageId =
            int.tryParse('${position['message_id'] ?? 0}') ?? 0;
        _returnReadMessageId = _savedReadMessageId;
        if (mounted) setState(() {});
      }
    } catch (error) {
      // Conversation state can synchronize on the next refresh.
    }
  }

  Future<void> _loadInitialHistory() async {
    var cached = chatApi.cachedHistory(widget.chat.jid);
    cached ??= await chatApi.persistedHistory(widget.chat.jid);
    if (cached.isNotEmpty) _applyHistory(cached);
    await _loadHistory(silent: cached.isNotEmpty);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _draftTimer?.cancel();
    _liveLocationTimer?.cancel();
    _saveVisibleReadPosition();
    _itemPositionsListener.itemPositions.removeListener(_trackScrollPosition);
    _voiceRecorder.dispose();
    _speechToText.stop();
    unregisterClipboardMediaHandler();
    _messageController.dispose();
    super.dispose();
  }

  void _trackScrollPosition() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || _messages.isEmpty) return;
    final lastVisible = positions
        .where((position) => position.itemTrailingEdge > 0)
        .map((position) => position.index)
        .fold<int>(0, (max, index) => index > max ? index : max);
    final shouldShow = lastVisible < _messages.length - 2;
    if (shouldShow != _showJumpToLatest && mounted) {
      setState(() {
        _showJumpToLatest = shouldShow;
        if (!shouldShow) _newMessageCount = 0;
      });
    }
    final firstVisible = positions
        .where((position) => position.itemTrailingEdge > 0)
        .map((position) => position.index)
        .fold<int>(_messages.length - 1, min);
    if (firstVisible >= 0 && firstVisible < _messages.length) {
      final id = _messages[firstVisible].id;
      if (id > 0) _savedReadMessageId = id;
    }
  }

  void _saveVisibleReadPosition() {
    if (_savedReadMessageId > 0) {
      chatApi
          .saveReadPosition(
            jid: widget.chat.jid,
            messageId: _savedReadMessageId,
          )
          .catchError((_) {});
    }
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (_historyRequestActive) return;
    _historyRequestActive = true;
    try {
      final readLocation = await _messageLocationMetadata(
        positionTimeout: const Duration(milliseconds: 450),
        addressTimeout: const Duration(milliseconds: 250),
      );
      final history = await chatApi.getHistory(
        widget.chat.jid,
        readLatitude: readLocation.latitude,
        readLongitude: readLocation.longitude,
        readLocationAddress: readLocation.address,
      );
      if (!mounted) return;
      _applyHistory(history);
    } on ApiException catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _loadError = error.message;
        });
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _loadError = 'Unable to load messages.';
        });
      }
    } finally {
      _historyRequestActive = false;
    }
  }

  void _applyHistory(List<ApiMessage> history) {
    if (!mounted) return;
    final historyMessages = history.map((message) {
      final attachment = message.attachment;
      return ChatMessage(
        id: int.tryParse(message.id) ?? 0,
        text: attachment == null ? message.body : '',
        time: message.time,
        isMe: message.isMine,
        sender: message.isMine
            ? null
            : message.senderName.isEmpty
            ? widget.chat.name
            : message.senderName,
        isRead: message.status.toLowerCase() == 'read',
        readAt: message.readAt,
        attachment: attachment,
        replyToId: int.tryParse(message.replyToId) ?? 0,
        threadRootId: int.tryParse(message.threadRootId) ?? 0,
        mentions: message.mentions,
        isEdited: message.isEdited,
        sourceDevice: message.sourceDevice,
        sourceName: message.sourceName,
        locationAddress: message.locationAddress,
        createdAt: DateTime.tryParse(message.createdAt)?.toLocal(),
        originalSenderJid: message.originalSenderJid,
        originalSenderName: message.originalSenderName,
        originalSourceName: message.originalSourceName,
        isSystem: message.messageType == 'system',
      );
    }).toList();
    final now = DateTime.now();
    _pendingOutgoing.removeWhere(
      (pending) =>
          now.difference(pending.createdAt) > const Duration(minutes: 5) ||
          historyMessages.any(
            (message) => _sameOutgoingMessage(message, pending.message),
          ),
    );
    final refreshedMessages = [
      ...historyMessages,
      ..._pendingOutgoing.map((pending) => pending.message),
    ];
    final oldLength = _messages.length;
    final addedCount = max(0, refreshedMessages.length - oldLength);
    final wasEmpty = oldLength == 0;
    final viewingOlderMessages = _showJumpToLatest;
    setState(() {
      _messages
        ..clear()
        ..addAll(refreshedMessages);
      _isLoading = false;
      _loadError = null;
      if (viewingOlderMessages && addedCount > 0) {
        _newMessageCount += addedCount;
      }
    });
    if (wasEmpty) {
      _scrollToBottom();
    } else if (!viewingOlderMessages && addedCount > 0) {
      _scrollToBottom();
    }
  }

  Future<void> _loadPresence() async {
    if (widget.chat.isGroup || _presenceRequestActive) return;
    _presenceRequestActive = true;
    try {
      final presence = await chatApi.getPresence(widget.chat.jid);
      if (mounted) setState(() => _presence = presence);
    } catch (error) {
      // Keep the most recently known presence.
    } finally {
      _presenceRequestActive = false;
    }
  }

  Future<void> _loadGroupMembers() async {
    if (!widget.chat.isGroup) return;
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    try {
      final result = await chatApi.getGroupMembers(groupId);
      if (mounted) {
        setState(() {
          _groupMembers = result.members;
          _groupRole = result.currentRole;
        });
      }
    } catch (error) {
      // Group messages remain available if member details cannot refresh.
    }
  }

  Future<void> _loadMessageLocationVisibility() async {
    try {
      final visibility = await chatApi.getMyLocationVisibility();
      final enabled =
          visibility['enabled'] == true ||
          '${visibility['enabled'] ?? ''}' == '1';
      if (mounted) setState(() => _canViewMessageLocations = enabled);
    } catch (error) {
      // Message info must stay usable even if permission lookup fails.
    }
  }

  String get _presenceLabel {
    if (widget.chat.isGroup) return 'Group conversation';
    final presence = _presence;
    if (presence?.isOnline ?? widget.chat.isOnline) return 'online';
    final lastSeen = presence?.lastSeen;
    if (lastSeen == null) return 'last seen recently';
    final now = DateTime.now();
    final sameDay =
        lastSeen.year == now.year &&
        lastSeen.month == now.month &&
        lastSeen.day == now.day;
    final hour = lastSeen.hour == 0
        ? 12
        : lastSeen.hour > 12
        ? lastSeen.hour - 12
        : lastSeen.hour;
    final minute = lastSeen.minute.toString().padLeft(2, '0');
    final clock = '$hour:$minute ${lastSeen.hour >= 12 ? 'PM' : 'AM'}';
    if (sameDay) return 'last seen today at $clock';
    return 'last seen ${lastSeen.day}/${lastSeen.month} at $clock';
  }

  Future<bool> _scheduleMessageBody(String body) async {
    if (_isSystemNotification || body.trim().isEmpty) return false;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return false;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return false;
    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time.')),
      );
      return false;
    }
    try {
      await chatApi.scheduleMessage(
        message: body.trim(),
        scheduledAt: scheduledAt.toIso8601String(),
        targets: [widget.chat.jid],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message scheduled for ${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year} ${TimeOfDay.fromDateTime(scheduledAt).format(context)}.',
            ),
          ),
        );
      }
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  Future<void> _scheduleDraftMessage() async {
    final body = _messageController.text.trim();
    if (await _scheduleMessageBody(body) && mounted) {
      _messageController.clear();
      setState(() => _hasText = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_isSystemNotification) return;
    var text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    if (_replyQuote.isNotEmpty) {
      text =
          '${_replyQuote.split('\n').map((line) => '> $line').join('\n')}\n\n$text';
    }
    final chunks = _splitMessage(text);
    final detectedMentions = _mentionsFromText(text);
    final reply = _replyingTo;
    final temporary = <ChatMessage>[];
    for (var index = 0; index < chunks.length; index++) {
      temporary.add(
        ChatMessage(
          id: -(DateTime.now().microsecondsSinceEpoch + index),
          text: chunks[index],
          time: TimeOfDay.now().format(context),
          isMe: true,
          isRead: false,
          replyToId: index == 0 ? reply?.id ?? 0 : 0,
          threadRootId: _threadRootId,
          mentions: index == 0 ? detectedMentions : const [],
          sourceDevice: 'this device',
          createdAt: DateTime.now(),
          isSending: true,
        ),
      );
    }
    setState(() {
      _messages.addAll(temporary);
      _replyingTo = null;
      _replyQuote = '';
      _threadRootId = 0;
      _selectedMentions.clear();
      _showEmojiPicker = false;
    });
    _messageController.clear();
    _scrollToBottom();
    try {
      final batchId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
      final sendLocation = await _messageLocationMetadata();
      for (var index = 0; index < chunks.length; index++) {
        final messageId = await chatApi.sendMessage(
          to: widget.chat.jid,
          message: chunks[index],
          replyToId: index == 0 && (reply?.id ?? 0) > 0 ? '${reply!.id}' : '',
          mentions: index == 0 ? temporary[index].mentions : const [],
          threadRootId: temporary[index].threadRootId > 0
              ? '${temporary[index].threadRootId}'
              : '',
          latitude: sendLocation.latitude,
          longitude: sendLocation.longitude,
          locationAddress: sendLocation.address,
          clientMessageId: '$batchId-$index',
        );
        if (!mounted) return;
        setState(() {
          final messageIndex = _messages.indexWhere(
            (item) => item.id == temporary[index].id,
          );
          if (messageIndex >= 0) {
            final sent = temporary[index].copyWith(
              id: messageId,
              isSending: false,
            );
            _messages[messageIndex] = sent;
            _pendingOutgoing.add(
              _PendingChatMessage(message: sent, createdAt: DateTime.now()),
            );
          }
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        for (final pending in temporary) {
          final index = _messages.indexWhere((item) => item.id == pending.id);
          if (index >= 0) {
            _messages[index] = pending.copyWith(
              isSending: false,
              isFailed: true,
            );
          }
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        for (final pending in temporary) {
          final index = _messages.indexWhere((item) => item.id == pending.id);
          if (index >= 0) {
            _messages[index] = pending.copyWith(
              isSending: false,
              isFailed: true,
            );
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send the message: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _coordinateAddress(Position position) {
    return '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }

  bool _isFreshMessagePosition(Position? position) {
    final capturedAt = _lastMessagePositionAt;
    return position != null &&
        capturedAt != null &&
        DateTime.now().difference(capturedAt) < const Duration(minutes: 5);
  }

  bool _isFreshMessageAddress(Position position) {
    final capturedAt = _lastMessageAddressAt;
    final addressLat = _lastMessageAddressLatitude;
    final addressLng = _lastMessageAddressLongitude;
    if (_lastMessageAddress.isEmpty ||
        capturedAt == null ||
        addressLat == null ||
        addressLng == null) {
      return false;
    }
    if (DateTime.now().difference(capturedAt) > const Duration(minutes: 15)) {
      return false;
    }
    return (addressLat - position.latitude).abs() < 0.0005 &&
        (addressLng - position.longitude).abs() < 0.0005;
  }

  Future<Position?> _currentMessagePosition() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );
      _lastMessagePosition = position;
      _lastMessagePositionAt = DateTime.now();
      return position;
    } catch (error) {
      return _isFreshMessagePosition(_lastMessagePosition)
          ? _lastMessagePosition
          : null;
    }
  }

  Future<Position?> _fastMessagePosition({
    Duration timeout = const Duration(milliseconds: 1800),
  }) async {
    if (_isFreshMessagePosition(_lastMessagePosition)) {
      return _lastMessagePosition;
    }
    _messagePositionFuture ??= _currentMessagePosition().whenComplete(() {
      _messagePositionFuture = null;
    });
    try {
      return await _messagePositionFuture!.timeout(
        timeout,
        onTimeout: () => _isFreshMessagePosition(_lastMessagePosition)
            ? _lastMessagePosition
            : null,
      );
    } catch (_) {
      return _isFreshMessagePosition(_lastMessagePosition)
          ? _lastMessagePosition
          : null;
    }
  }

  Future<String> _resolveLocationAddress(Position position) async {
    try {
      final address = await chatApi.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      return address.trim().isNotEmpty
          ? address.trim()
          : _coordinateAddress(position);
    } catch (_) {
      return _coordinateAddress(position);
    }
  }

  Future<String> _fastLocationAddress(
    Position? position, {
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    if (position == null) return '';
    if (_isFreshMessageAddress(position)) return _lastMessageAddress;
    final fallback = _coordinateAddress(position);
    try {
      final address = await _resolveLocationAddress(
        position,
      ).timeout(timeout, onTimeout: () => fallback);
      final normalized = address.trim().isNotEmpty ? address.trim() : fallback;
      _lastMessageAddress = normalized;
      _lastMessageAddressLatitude = position.latitude;
      _lastMessageAddressLongitude = position.longitude;
      _lastMessageAddressAt = DateTime.now();
      return normalized;
    } catch (_) {
      return fallback;
    }
  }

  Future<_MessageLocationMetadata> _messageLocationMetadata({
    Duration positionTimeout = const Duration(milliseconds: 1800),
    Duration addressTimeout = const Duration(milliseconds: 900),
  }) async {
    final position = await _fastMessagePosition(timeout: positionTimeout);
    final address = await _fastLocationAddress(
      position,
      timeout: addressTimeout,
    );
    return _MessageLocationMetadata(
      latitude: position?.latitude,
      longitude: position?.longitude,
      address: address,
    );
  }

  Future<void> _warmMessageLocationMetadata() async {
    unawaited(
      _messageLocationMetadata(
        positionTimeout: const Duration(seconds: 3),
        addressTimeout: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _sendLocationAttachment({
    required Position position,
    required String locationAddress,
    bool isLive = false,
    int liveMinutes = 0,
    String shareId = '',
    bool showSuccess = true,
  }) async {
    final reply = _replyingTo;
    final threadRootId = _threadRootId;
    final mentions = _selectedMentions.toList();
    final messageId = await chatApi.sendLocationMessage(
      to: widget.chat.jid,
      latitude: position.latitude,
      longitude: position.longitude,
      locationAddress: locationAddress,
      isLiveLocation: isLive,
      liveMinutes: liveMinutes,
      shareId: shareId,
      replyToId: reply?.id == 0 ? '' : '${reply?.id ?? ''}',
      mentions: mentions,
      threadRootId: threadRootId > 0 ? '$threadRootId' : '',
      clientMessageId:
          '${isLive ? 'live' : 'loc'}-$shareId-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!mounted) return;
    final attachment = ChatAttachment.location(
      latitude: position.latitude,
      longitude: position.longitude,
      locationAddress: locationAddress,
      isLiveLocation: isLive,
      liveMinutes: liveMinutes,
      shareId: shareId,
    );
    setState(() {
      _messages.add(
        ChatMessage(
          id: messageId,
          text: attachment.encode(),
          time: TimeOfDay.now().format(context),
          isMe: true,
          isRead: false,
          attachment: attachment,
          replyToId: reply?.id ?? 0,
          threadRootId: threadRootId,
          mentions: mentions,
        ),
      );
      _replyingTo = null;
      _selectedMentions.clear();
      _showEmojiPicker = false;
      _threadRootId = 0;
    });
    _scrollToBottom();
    if (showSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLive ? 'Live location shared.' : 'Location shared.'),
        ),
      );
    }
  }

  Future<void> _sendCurrentLocationAttachment() async {
    if (_isUploading) return;
    final position = await _currentMessagePosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable location to send your position.'),
          ),
        );
      }
      return;
    }
    final address = await _resolveLocationAddress(position);
    await _sendLocationAttachment(position: position, locationAddress: address);
  }

  Future<int?> _pickLiveLocationMinutes() async {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Live location duration'),
              subtitle: const Text(
                'Choose how long to share your location. Updates every 1 minute.',
              ),
            ),
            for (final entry in const [
              (15, '15 minutes'),
              (60, '1 hour'),
              (180, '3 hours'),
              (480, '8 hours'),
            ])
              ListTile(
                leading: const Icon(Icons.timelapse_rounded),
                title: Text(entry.$2),
                onTap: () => Navigator.pop(sheetContext, entry.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendLiveLocationAttachment() async {
    if (_isUploading || _liveLocationSharing) return;
    final liveMinutes = await _pickLiveLocationMinutes();
    if (!mounted || liveMinutes == null) return;
    final position = await _currentMessagePosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable location to share live updates.'),
          ),
        );
      }
      return;
    }
    final shareId = 'live-${DateTime.now().microsecondsSinceEpoch}';
    final endsAt = DateTime.now().add(Duration(minutes: liveMinutes));
    _liveLocationSharing = true;
    _liveLocationEndsAt = endsAt;
    final address = await _resolveLocationAddress(position);
    await _sendLocationAttachment(
      position: position,
      locationAddress: address,
      isLive: true,
      liveMinutes: liveMinutes,
      shareId: shareId,
    );
    _liveLocationTimer?.cancel();
    _liveLocationTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      if (!mounted || !_liveLocationSharing || _liveLocationEndsAt == null) {
        timer.cancel();
        return;
      }
      if (DateTime.now().isAfter(_liveLocationEndsAt!)) {
        timer.cancel();
        if (mounted) {
          setState(() => _liveLocationSharing = false);
        }
        return;
      }
      final nextPosition = await _currentMessagePosition();
      if (nextPosition == null) return;
      final nextAddress = await _resolveLocationAddress(nextPosition);
      await _sendLocationAttachment(
        position: nextPosition,
        locationAddress: nextAddress,
        isLive: true,
        liveMinutes: liveMinutes,
        shareId: shareId,
        showSuccess: false,
      );
    });
  }

  void _stopLiveLocationSharing() {
    _liveLocationTimer?.cancel();
    setState(() {
      _liveLocationSharing = false;
      _liveLocationEndsAt = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live location sharing stopped.')),
    );
  }

  List<String> _splitMessage(String text) {
    const limit = 3500;
    if (text.length <= limit) return [text];
    final chunks = <String>[];
    var remaining = text;
    while (remaining.length > limit) {
      var split = remaining.lastIndexOf('\n', limit);
      if (split < limit ~/ 2) split = remaining.lastIndexOf(' ', limit);
      if (split < limit ~/ 2) split = limit;
      chunks.add(remaining.substring(0, split).trim());
      remaining = remaining.substring(split).trimLeft();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isSystemNotification || _isUploading) return;
    if (_isRecordingVoice) {
      await _stopAndSendVoiceRecording();
      return;
    }
    try {
      if (!await _voiceRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required to record a voice message.',
              ),
            ),
          );
        }
        return;
      }
      final path = kIsWeb
          ? 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : await _voiceRecordingFilePath();
      _voiceTranscript = '';
      final speechReady = await _speechToText.initialize();
      if (speechReady) {
        await _speechToText.listen(
          onResult: (result) => _voiceTranscript = result.recognizedWords,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
          ),
        );
      }
      await _voiceRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (mounted) {
        setState(() {
          _isRecordingVoice = true;
          _voiceRecordingPath = path;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start recording: $error')),
        );
      }
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    try {
      final stoppedPath = await _voiceRecorder.stop();
      await _speechToText.stop();
      if (mounted) setState(() => _isRecordingVoice = false);
      final path = stoppedPath ?? _voiceRecordingPath;
      if (path == null || path.isEmpty) return;
      Uint8List bytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw const ApiException('Unable to read the recorded audio.');
        }
        bytes = response.bodyBytes;
      } else {
        bytes = await File(path).readAsBytes();
      }
      if (!mounted) return;
      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });
      final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final sendLocation = await _messageLocationMetadata();
      final attachment = await chatApi.sendAttachment(
        to: widget.chat.jid,
        name: name,
        mimeType: 'audio/mp4',
        bytes: bytes,
        caption: _voiceTranscript.trim(),
        replyToId: _replyingTo?.id == 0 ? '' : '${_replyingTo?.id ?? ''}',
        threadRootId: _threadRootId > 0 ? '$_threadRootId' : '',
        latitude: sendLocation.latitude,
        longitude: sendLocation.longitude,
        locationAddress: sendLocation.address,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            id: attachment.messageId,
            text: '',
            time: TimeOfDay.now().format(context),
            isMe: true,
            isRead: false,
            attachment: attachment,
            replyToId: _replyingTo?.id ?? 0,
            threadRootId: _threadRootId,
          ),
        );
        _replyingTo = null;
        _threadRootId = 0;
      });
      _scrollToBottom();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send voice message: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _createChecklistFromComposer() async {
    final seed = _messageController.text.trim();
    await _createChecklistFromMessage(
      ChatMessage(
        text: seed,
        time: TimeOfDay.now().format(context),
        isMe: true,
      ),
    );
  }

  Future<void> _pickAndSendContact() async {
    if (kIsWeb || !Platform.isAndroid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact picker is available on Android.'),
        ),
      );
      return;
    }
    final permission = await ph.Permission.contacts.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacts permission is required to send a contact.'),
        ),
      );
      return;
    }
    try {
      final picked = await _androidPlatform.invokeMapMethod<String, dynamic>(
        'pickContact',
      );
      if (!mounted || picked == null) return;
      final phones = (picked['phones'] is List)
          ? (picked['phones'] as List)
                .map((value) => '$value')
                .where((value) => value.trim().isNotEmpty)
                .toList()
          : <String>[];
      final emails = (picked['emails'] is List)
          ? (picked['emails'] as List)
                .map((value) => '$value')
                .where((value) => value.trim().isNotEmpty)
                .toList()
          : <String>[];
      final contact = <String, dynamic>{
        'name': '${picked['name'] ?? ''}'.trim(),
        'phones': phones,
        'emails': emails,
      };
      if ('${contact['name']}'.trim().isEmpty &&
          phones.isEmpty &&
          emails.isEmpty) {
        return;
      }
      final body = _encodeContactCard(contact);
      final sendLocation = await _messageLocationMetadata();
      await chatApi.sendMessage(
        to: widget.chat.jid,
        message: body,
        replyToId: _replyingTo?.id == 0 ? '' : '${_replyingTo?.id ?? ''}',
        mentions: _selectedMentions.toList(),
        threadRootId: _threadRootId > 0 ? '$_threadRootId' : '',
        latitude: sendLocation.latitude,
        longitude: sendLocation.longitude,
        locationAddress: sendLocation.address,
        clientMessageId: 'contact-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: body,
            time: TimeOfDay.now().format(context),
            isMe: true,
            isRead: false,
            replyToId: _replyingTo?.id ?? 0,
            threadRootId: _threadRootId,
            mentions: _selectedMentions.toList(),
          ),
        );
        _replyingTo = null;
        _threadRootId = 0;
        _selectedMentions.clear();
      });
      _scrollToBottom();
    } on PlatformException catch (error) {
      if (!mounted || error.code == 'cancelled') return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to pick contact.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to send contact: $error')));
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (_isUploading) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo or image'),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Document or file'),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Create checklist'),
              onTap: () => Navigator.pop(sheetContext, 'checklist'),
            ),
            ListTile(
              leading: const Icon(Icons.contacts_rounded),
              title: const Text('Contact'),
              onTap: () => Navigator.pop(sheetContext, 'contact'),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Current location'),
              onTap: () => Navigator.pop(sheetContext, 'location'),
            ),
            ListTile(
              leading: const Icon(Icons.location_searching_rounded),
              title: const Text('Live location'),
              subtitle: const Text('Share updates every 1 minute.'),
              onTap: () => Navigator.pop(sheetContext, 'live_location'),
            ),
            if (_liveLocationSharing)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Stop live location'),
                subtitle: _liveLocationEndsAt == null
                    ? null
                    : Text(
                        'Active until ${TimeOfDay.fromDateTime(_liveLocationEndsAt!).format(context)}',
                      ),
                onTap: () => Navigator.pop(sheetContext, 'stop_live_location'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'image':
        final images = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.image,
          withData: true,
        );
        if (!mounted || images == null || images.files.isEmpty) return;
        await _sendPickedFiles(images.files);
        return;
      case 'file':
        final result = await FilePicker.pickFiles(
          allowMultiple: true,
          withData: true,
        );
        if (!mounted || result == null || result.files.isEmpty) return;
        await _sendPickedFiles(result.files);
        return;
      case 'checklist':
        await _createChecklistFromComposer();
        return;
      case 'contact':
        await _pickAndSendContact();
        return;
      case 'location':
        await _sendCurrentLocationAttachment();
        return;
      case 'live_location':
        await _sendLiveLocationAttachment();
        return;
      case 'stop_live_location':
        _stopLiveLocationSharing();
        return;
      default:
        return;
    }
  }

  Future<void> _handleDroppedFiles(List<dynamic> files) async {
    if (_isUploading) return;
    if (_isDragOver && mounted) setState(() => _isDragOver = false);
    final converted = await _platformFilesFromDroppedFiles(files);
    if (!mounted || converted.isEmpty) return;
    await _sendPickedFiles(converted);
  }

  Future<void> _handleClipboardMediaPaste(List<PastedMediaFile> files) async {
    if (!mounted || _isUploading || files.isEmpty) return;
    final converted = _platformFilesFromClipboard(files);
    if (converted.isEmpty) return;
    await _sendPickedFiles(converted);
  }

  Future<void> _sendPickedFiles(List<PlatformFile> files) async {
    if (_isUploading || files.isEmpty) return;
    final draft = await _previewAttachments(files);
    if (!mounted || draft == null || draft.files.isEmpty) return;
    files = draft.files;
    final caption = draft.caption;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    try {
      final reply = _replyingTo;
      final sendLocation = await _messageLocationMetadata();
      if (!mounted) return;
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        var bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        if (bytes == null) {
          throw ApiException('Unable to read ${file.name}.');
        }
        final mimeType = _mimeTypeForFile(file.name);
        final attachment = await chatApi.sendAttachment(
          to: widget.chat.jid,
          name: file.name,
          mimeType: mimeType,
          bytes: bytes,
          caption: index == 0 ? caption : '',
          replyToId: reply?.id == 0 ? '' : '${reply?.id ?? ''}',
          mentions: _selectedMentions.toList(),
          threadRootId: _threadRootId > 0 ? '$_threadRootId' : '',
          latitude: sendLocation.latitude,
          longitude: sendLocation.longitude,
          locationAddress: sendLocation.address,
          onProgress: (progress) {
            if (mounted) {
              setState(
                () => _uploadProgress = (index + progress) / files.length,
              );
            }
          },
        );
        if (!mounted) return;
        final message = ChatMessage(
          id: attachment.messageId,
          text: '',
          time: TimeOfDay.now().format(context),
          isMe: true,
          isRead: false,
          attachment: attachment,
          replyToId: reply?.id ?? 0,
          threadRootId: _threadRootId,
          mentions: _selectedMentions.toList(),
        );
        setState(() {
          _pendingOutgoing.add(
            _PendingChatMessage(message: message, createdAt: DateTime.now()),
          );
          _messages.add(message);
        });
      }
      setState(() {
        _replyingTo = null;
        _selectedMentions.clear();
      });
      _scrollToBottom();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to upload the file.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDragOver = false;
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<List<PlatformFile>> _platformFilesFromDroppedFiles(
    List<dynamic> files,
  ) async {
    final converted = <PlatformFile>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      converted.add(
        PlatformFile(
          name: file.name,
          size: bytes.length,
          bytes: bytes,
          path: file.path,
        ),
      );
    }
    return converted;
  }

  List<PlatformFile> _platformFilesFromClipboard(List<PastedMediaFile> files) {
    return files
        .map(
          (file) => PlatformFile(
            name: file.name,
            size: file.bytes.length,
            bytes: file.bytes,
          ),
        )
        .toList();
  }

  Future<Uint8List> _editImageBeforeSend({
    required String fileName,
    required String? path,
    required Uint8List bytes,
  }) async {
    return bytes;
  }

  Future<_AttachmentDraft?> _previewAttachments(
    List<PlatformFile> initialFiles,
  ) async {
    final captionController = TextEditingController();
    var files = List<PlatformFile>.from(initialFiles);
    try {
      return await showDialog<_AttachmentDraft>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            void send() {
              if (files.isEmpty) return;
              Navigator.pop(
                dialogContext,
                _AttachmentDraft(
                  files: List<PlatformFile>.from(files),
                  caption: captionController.text.trim(),
                ),
              );
            }

            final first = files.isEmpty ? null : files.first;
            final title = files.length == 1
                ? (_mimeTypeForFile(first!.name).startsWith('image/')
                      ? 'Send an image'
                      : 'Send as a file')
                : 'Send ${files.length} files';
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 330),
                      child: files.isEmpty
                          ? const Center(child: Text('No files selected.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: files.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 18),
                              itemBuilder: (_, index) {
                                final file = files[index];
                                final mimeType = _mimeTypeForFile(file.name);
                                final isImage = mimeType.startsWith('image/');
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox.square(
                                      dimension: 72,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.09,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: isImage && file.bytes != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  file.bytes!,
                                                  fit: BoxFit.cover,
                                                  gaplessPlayback: true,
                                                ),
                                              )
                                            : Icon(
                                                _iconForMimeType(mimeType),
                                                color: AppColors.primary,
                                                size: 34,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            file.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(_formatFileBytes(file.size)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove',
                                      onPressed: () {
                                        setDialogState(
                                          () => files.removeAt(index),
                                        );
                                        if (files.isEmpty)
                                          Navigator.pop(dialogContext);
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 14),
                    Focus(
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent)
                          return KeyEventResult.ignored;
                        final isEnter =
                            event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.numpadEnter;
                        if (!isEnter) return KeyEventResult.ignored;
                        final insertNewLine =
                            HardwareKeyboard.instance.isShiftPressed ||
                            HardwareKeyboard.instance.isControlPressed ||
                            HardwareKeyboard.instance.isMetaPressed;
                        if (insertNewLine) return KeyEventResult.ignored;
                        send();
                        return KeyEventResult.handled;
                      },
                      child: TextField(
                        controller: captionController,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Caption',
                          hintText: 'Add a caption (optional)',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: files.isEmpty ? null : send,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      captionController.dispose();
    }
  }

  IconData _iconForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.movie_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mimeType.contains('location')) return Icons.location_on_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('zip') || mimeType.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  bool _sameOutgoingMessage(ChatMessage first, ChatMessage second) {
    if (!first.isMe || !second.isMe) return false;
    final firstAttachment = first.attachment;
    final secondAttachment = second.attachment;
    if (firstAttachment != null || secondAttachment != null) {
      return firstAttachment?.url == secondAttachment?.url;
    }
    return first.text == second.text;
  }

  ChatMessage? _messageById(int id) {
    if (id <= 0) return null;
    for (final message in _messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  List<GroupMember> get _mentionSuggestions {
    if (!widget.chat.isGroup ||
        !RegExp(r'@[A-Za-z0-9_]*$').hasMatch(_messageController.text)) {
      return const [];
    }
    final special =
        [
          const GroupMember(
            empId: '@channel',
            name: 'channel',
            designation: 'Notify everyone in this channel',
            jid: '',
            role: 'special',
          ),
          const GroupMember(
            empId: '@online',
            name: 'online',
            designation: 'Notify online members',
            jid: '',
            role: 'special',
          ),
          const GroupMember(
            empId: '@admins',
            name: 'admins',
            designation: 'Notify owners and admins',
            jid: '',
            role: 'special',
          ),
        ].where((member) {
          return _mentionQuery.isEmpty || member.name.contains(_mentionQuery);
        });
    return [
      ...special,
      ..._groupMembers
          .where((member) {
            final searchable =
                '${member.name.replaceAll(' ', '_')} ${member.empId}'
                    .toLowerCase();
            return _mentionQuery.isEmpty || searchable.contains(_mentionQuery);
          })
          .take(5),
    ].take(8).toList();
  }

  void _selectMention(GroupMember member) {
    final text = _messageController.text;
    final match = RegExp(r'@[A-Za-z0-9_]*$').firstMatch(text);
    if (match == null) return;
    final mention = '@${member.name.trim().replaceAll(RegExp(r'\s+'), '_')}';
    _messageController.value = TextEditingValue(
      text: text.replaceRange(match.start, match.end, '$mention '),
      selection: TextSelection.collapsed(
        offset: match.start + mention.length + 1,
      ),
    );
    setState(() {
      _selectedMentions.add(
        member.role == 'special' ? member.empId : member.empId,
      );
      _mentionQuery = '';
    });
  }

  Future<void> _openMentionProfile(String token) async {
    final normalized = token.trim().replaceFirst('@', '').toLowerCase();
    if (normalized.isEmpty) return;
    final specialMentions = {'channel', 'online', 'admins'};
    if (specialMentions.contains(normalized)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mention target: @$normalized')));
      return;
    }
    GroupMember? member;
    for (final item in _groupMembers) {
      final byName = item.name
          .trim()
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      if (byName == normalized || item.empId.toLowerCase() == normalized) {
        member = item;
        break;
      }
    }
    if (member == null) return;
    await _showUserProfile(empId: member.empId, fallbackName: member.name);
  }

  List<String> _mentionsFromText(String text) {
    final result = <String>{..._selectedMentions};
    final tokens = RegExp(
      r'@[A-Za-z0-9_]+',
    ).allMatches(text).map((match) => match.group(0)!.toLowerCase());
    for (final token in tokens) {
      if (const {'@channel', '@online', '@admins'}.contains(token)) {
        result.add(token);
        continue;
      }
      final normalized = token.substring(1).replaceAll('_', ' ');
      for (final member in _groupMembers) {
        if (member.name.toLowerCase() == normalized ||
            member.empId.toLowerCase() == normalized) {
          result.add(member.empId);
          break;
        }
      }
    }
    return result.toList();
  }

  void _toggleMessageSelection(ChatMessage message) {
    setState(() {
      if (!_selectedMessageIds.add(message.id)) {
        _selectedMessageIds.remove(message.id);
      }
    });
  }

  List<ChatMessage> get _selectedMessages => _messages
      .where((message) => _selectedMessageIds.contains(message.id))
      .toList();

  Future<void> _copyMessageToClipboard(ChatMessage message) async {
    final content = message.text.trim().isNotEmpty
        ? cleanMojibakeText(message.text.trim())
        : cleanMojibakeText(message.attachment?.name ?? message.previewText);
    if (content.isEmpty) return;
    try {
      final copied = await copyTextToClipboard(content);
      if (!copied) throw StateError('Clipboard copy failed');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message copied.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to copy message.')));
    }
  }

  Future<void> _copySelectedMessages() async {
    final selected = _selectedMessages;
    if (selected.isEmpty) return;
    final multiple = selected.length > 1;
    final text = selected
        .map((message) {
          final content = message.text.trim().isNotEmpty
              ? cleanMojibakeText(message.text.trim())
              : cleanMojibakeText(
                  message.attachment?.name ?? message.previewText,
                );
          if (!multiple) return content;
          final sender = message.isMe
              ? 'You'
              : (message.sender ?? widget.chat.name);
          return '$sender (${message.time}): $content';
        })
        .where((value) => value.isNotEmpty)
        .join(String.fromCharCode(10));
    if (text.isEmpty) return;
    final copied = await copyTextToClipboard(text);
    if (!copied) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to copy message.')));
      return;
    }
    if (!mounted) return;
    setState(_selectedMessageIds.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.length} message(s) copied.')),
    );
  }

  Future<ChatContact?> _pickForwardTarget() async {
    final values = await Future.wait([
      chatApi.getRecentChats(),
      chatApi.searchUsers(),
    ]);
    final byJid = <String, ChatContact>{};
    for (final chat in [...values[0], ...values[1]]) {
      byJid[chat.jid.toLowerCase()] = chat;
    }
    if (!mounted) return null;
    return showModalBottomSheet<ChatContact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForwardTargetSheet(chats: byJid.values.toList()),
    );
  }

  Future<void> _forwardSelectedMessages() async {
    final selected = _selectedMessages;
    final target = await _pickForwardTarget();
    if (target == null) return;
    for (final message in selected) {
      await chatApi.sendMessage(
        to: target.jid,
        message: message.attachment?.encode() ?? message.text,
        clientMessageId:
            'multi-forward-${message.id}-${DateTime.now().microsecondsSinceEpoch}',
        forwardedFromMessageId: message.id,
        originalSenderJid: message.originalSenderJid.isNotEmpty
            ? message.originalSenderJid
            : (message.isMe ? chatApi.currentJid : widget.chat.jid),
        originalSenderName: message.originalSenderName.isNotEmpty
            ? message.originalSenderName
            : (message.isMe ? 'You' : (message.sender ?? widget.chat.name)),
        originalSourceName: message.originalSourceName.isNotEmpty
            ? message.originalSourceName
            : message.sourceName,
      );
    }
    if (mounted) {
      setState(_selectedMessageIds.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} message(s) forwarded to ${target.name}.',
          ),
        ),
      );
    }
  }

  bool get _canDeleteSelectedMessages {
    final selected = _selectedMessages;
    return selected.isNotEmpty &&
        selected.every((message) => message.isMe && message.id > 0);
  }

  Future<void> _deleteSelectedMessages() async {
    final deletable = _selectedMessages;
    if (!_canDeleteSelectedMessages) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${deletable.length} message(s)?'),
        content: const Text('The selected sent messages will be unsent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final message in deletable) {
      await chatApi.unsendMessage(message.id);
    }
    if (!mounted) return;
    setState(() {
      final ids = deletable.map((message) => message.id).toSet();
      _messages.removeWhere((message) => ids.contains(message.id));
      _selectedMessageIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${deletable.length} message(s) deleted.')),
    );
  }

  ChatMessage? get _selectedPrimaryMessage =>
      _selectedMessages.isEmpty ? null : _selectedMessages.first;

  void _clearMessageSelection() {
    if (!mounted) return;
    setState(_selectedMessageIds.clear);
  }

  Future<void> _replyToSelectedMessage() async {
    final message = _selectedPrimaryMessage;
    if (message == null || message.isSystem) return;
    if (!mounted) return;
    setState(() {
      _replyingTo = message;
      _replyQuote = '';
      _selectedMessageIds.clear();
    });
  }

  Future<void> _quoteSelectedMessage() async {
    final message = _selectedPrimaryMessage;
    if (message == null) return;
    await _quoteMessage(message);
    _clearMessageSelection();
  }

  Future<void> _bookmarkSelectedMessages() async {
    final selected = _selectedMessages
        .where((message) => message.id > 0)
        .toList();
    if (selected.isEmpty) return;
    final shouldStar = !selected.every((message) => message.isStarred);
    try {
      for (final message in selected) {
        await chatApi.starMessage(message.id, shouldStar);
      }
      if (!mounted) return;
      setState(() {
        final ids = selected.map((message) => message.id).toSet();
        for (var i = 0; i < _messages.length; i++) {
          if (ids.contains(_messages[i].id)) {
            _messages[i] = _messages[i].copyWith(isStarred: shouldStar);
          }
        }
        _selectedMessageIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldStar ? 'Message bookmarked.' : 'Bookmark removed.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _pinSelectedMessages() async {
    final selected = _selectedMessages
        .where((message) => message.id > 0)
        .toList();
    if (selected.isEmpty) return;
    try {
      for (final message in selected) {
        await chatApi.pinMessage(message.id, true);
      }
      if (!mounted) return;
      _clearMessageSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} message(s) pinned.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _createTaskFromSelectedMessage() async {
    final message = _selectedPrimaryMessage;
    if (message == null) return;
    await _createTaskFromMessage(message);
    _clearMessageSelection();
  }

  String _selectedMessagesSummary() {
    final selected = _selectedMessages;
    if (selected.isEmpty) return '';
    final parts = <String>[];
    for (final message in selected.take(6)) {
      final prefix = message.isMe
          ? 'You'
          : (message.sender ?? widget.chat.name);
      final text = message.previewText.trim();
      if (text.isEmpty) continue;
      parts.add('$prefix: $text');
    }
    if (selected.length > 6) {
      parts.add('... and ${selected.length - 6} more message(s)');
    }
    return parts.join('\n');
  }

  Future<void> _showAiSummaryForSelection() async {
    final summary = _selectedMessagesSummary();
    if (summary.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI Summary'),
        content: SizedBox(
          width: 520,
          child: SelectionArea(
            child: Text(
              'Selected ${_selectedMessages.length} message(s).\n\n$summary',
              style: const TextStyle(height: 1.45),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _translateSelection() async {
    final summary = _selectedMessagesSummary();
    if (summary.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Translate'),
        content: SizedBox(
          width: 520,
          child: SelectionArea(
            child: Text(
              'Translation workflow is ready to wire into a language service.\n\n$summary',
              style: const TextStyle(height: 1.45),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSelectionMessageInfo() async {
    final message = _selectedPrimaryMessage;
    if (message == null) return;
    await _showMessageInfo(message);
    _clearMessageSelection();
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final selectedCount = _selectedMessages.length;
    final primary = _selectedPrimaryMessage;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearMessageSelection,
      ),
      title: Text('$selectedCount selected'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(104),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SelectionToolbarAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onPressed: _copySelectedMessages,
                ),
                _SelectionToolbarAction(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onPressed: primary == null || primary.isSystem
                      ? null
                      : _replyToSelectedMessage,
                ),
                _SelectionToolbarAction(
                  icon: Icons.forward_rounded,
                  label: 'Forward',
                  onPressed: selectedCount == 0
                      ? null
                      : _forwardSelectedMessages,
                ),
                _SelectionToolbarAction(
                  icon: Icons.bookmark_add_outlined,
                  label: 'Bookmark',
                  onPressed: selectedCount == 0
                      ? null
                      : _bookmarkSelectedMessages,
                ),
                _SelectionToolbarAction(
                  icon: Icons.task_alt_rounded,
                  label: 'Create Task',
                  onPressed: primary == null
                      ? null
                      : _createTaskFromSelectedMessage,
                ),
                _SelectionToolbarAction(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Summary',
                  onPressed: selectedCount == 0
                      ? null
                      : _showAiSummaryForSelection,
                ),
                _SelectionToolbarAction(
                  icon: Icons.format_quote_rounded,
                  label: 'Quote',
                  onPressed: primary == null ? null : _quoteSelectedMessage,
                ),
                _SelectionToolbarAction(
                  icon: Icons.translate_rounded,
                  label: 'Translate',
                  onPressed: selectedCount == 0 ? null : _translateSelection,
                ),
                _SelectionToolbarAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  destructive: true,
                  onPressed: _canDeleteSelectedMessages
                      ? _deleteSelectedMessages
                      : null,
                ),
                _SelectionToolbarAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onPressed:
                      primary != null &&
                          primary.isMe &&
                          primary.id > 0 &&
                          primary.attachment == null &&
                          selectedCount == 1
                      ? () async {
                          await _editMessage(primary);
                          _clearMessageSelection();
                        }
                      : null,
                ),
                _SelectionToolbarAction(
                  icon: Icons.push_pin_outlined,
                  label: 'Pin',
                  onPressed: selectedCount == 0 ? null : _pinSelectedMessages,
                ),
                _SelectionToolbarAction(
                  icon: Icons.info_outline_rounded,
                  label: 'Message Info',
                  onPressed: primary == null || primary.id <= 0
                      ? null
                      : _showSelectionMessageInfo,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, controller) => Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.only(
              top: 8,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children:
                      [
                            '\u{1F44D}',
                            '\u{2764}\u{FE0F}',
                            '\u{1F44F}',
                            '\u{1F525}',
                            '\u{1F389}',
                            '\u{1F602}',
                            '\u{1F60E}',
                          ]
                          .map(
                            (reaction) => InkWell(
                              onTap: () => Navigator.pop(
                                sheetContext,
                                'react:$reaction',
                              ),
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  reaction,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              if (!_isSystemNotification)
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () => Navigator.pop(sheetContext, 'reply'),
                ),
              if (message.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy'),
                  onTap: () async {
                    await _copyMessageToClipboard(message);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              if (message.previewText.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.format_quote_rounded),
                  title: const Text('Quote selected lines'),
                  onTap: () => Navigator.pop(sheetContext, 'quote'),
                ),
              ListTile(
                leading: const Icon(Icons.forward_rounded),
                title: const Text('Forward'),
                onTap: () => Navigator.pop(sheetContext, 'forward'),
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Pin message'),
                onTap: () => Navigator.pop(sheetContext, 'pin'),
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Create'),
                subtitle: const Text(
                  'Task, reminder, thread, incident and more',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, 'create'),
              ),
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Send options'),
                subtitle: const Text('Send now or forward'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, 'send_options'),
              ),
              const Divider(),
              if (message.id > 0)
                ListTile(
                  leading: Icon(
                    message.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                  title: Text(message.isStarred ? 'Unstar' : 'Star message'),
                  onTap: () => Navigator.pop(sheetContext, 'star'),
                ),
              if (message.id > 0)
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Info'),
                  onTap: () => Navigator.pop(sheetContext, 'info'),
                ),
              if (message.id > 0)
                ListTile(
                  leading: const Icon(Icons.forum_outlined),
                  title: const Text('Reply in thread'),
                  onTap: () => Navigator.pop(sheetContext, 'thread'),
                ),
              if (message.text.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.bookmark_add_outlined),
                  title: const Text('Save message'),
                  onTap: () => Navigator.pop(sheetContext, 'save'),
                ),
              if (message.isMe && message.id > 0 && message.attachment == null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit message'),
                  onTap: () => Navigator.pop(sheetContext, 'edit'),
                ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share to another app'),
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
              if (message.isMe && message.id > 0)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Unsend message'),
                  textColor: const Color(0xFFB3261E),
                  iconColor: const Color(0xFFB3261E),
                  onTap: () => Navigator.pop(sheetContext, 'unsend'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action?.startsWith('react:') == true) {
      final reaction = action!.substring(6);
      await chatApi.reactToMessage(message.id, reaction);
      if (mounted) {
        setState(() {
          final index = _messages.indexOf(message);
          if (index >= 0) {
            _messages[index] = message.copyWith(reaction: reaction);
          }
        });
      }
    } else if (action == 'copy') {
      await _copyMessageToClipboard(message);
    } else if (action == 'forward') {
      await _forwardMessage(message);
    } else if (action == 'share') {
      await _shareMessage(message);
    } else if (action == 'create') {
      await _showCreateOptions(message);
    } else if (action == 'send_options') {
      await _showSendOptions(message);
    } else if (action == 'star') {
      await chatApi.starMessage(message.id, !message.isStarred);
      if (mounted) {
        setState(() {
          final index = _messages.indexOf(message);
          if (index >= 0) {
            _messages[index] = message.copyWith(isStarred: !message.isStarred);
          }
        });
      }
    } else if (action == 'pin') {
      await chatApi.pinMessage(message.id, true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message pinned.')));
      }
    } else if (action == 'info') {
      await Future<void>.delayed(Duration.zero);
      await _showMessageInfo(message);
    } else if (action == 'reply') {
      setState(() {
        _replyingTo = message;
        _replyQuote = '';
      });
    } else if (action == 'quote') {
      await _quoteMessage(message);
    } else if (action == 'thread') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _ThreadViewScreen(
            chat: widget.chat,
            root: message,
            messages: _messages,
          ),
        ),
      );
      await _loadHistory(silent: true);
    } else if (action == 'save') {
      try {
        await chatApi.saveMessage(message.previewText);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message saved.')));
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    } else if (action == 'edit') {
      await _editMessage(message);
    } else if (action == 'unsend') {
      try {
        await chatApi.unsendMessage(message.id);
        if (mounted) {
          setState(() {
            _messages.removeWhere((item) => item.id == message.id);
            _pendingOutgoing.removeWhere(
              (pending) => pending.message.id == message.id,
            );
          });
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }
  }

  Future<void> _showCreateOptions(ChatMessage message) async {
    final options = [
      ('Create task', Icons.task_alt_rounded),
      ('Update task', Icons.assignment_turned_in_outlined),
      ('Create checklist', Icons.checklist_rounded),
      ('Create reminder', Icons.notifications_active_outlined),
      ('Create meeting request', Icons.groups_2_outlined),
      ('Create thread', Icons.forum_outlined),
      ('Create follow up', Icons.update_rounded),
      ('Create calendar invite', Icons.calendar_month_outlined),
      ('Save to saved messages', Icons.bookmark_add_outlined),
      ('Create incident', Icons.warning_amber_rounded),
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const ListTile(
                leading: BackButton(),
                title: Text(
                  'Create',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  leading: Icon(option.$2, color: AppColors.primary),
                  title: Text(option.$1),
                  onTap: () => Navigator.pop(sheetContext, option.$1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'Create task') {
      await _createTaskFromMessage(message);
    } else if (selected == 'Update task') {
      await _updateTaskFromMessage(message);
    } else if (selected == 'Create checklist') {
      await _createChecklistFromMessage(message);
    } else if (selected == 'Create reminder' ||
        selected == 'Create follow up') {
      await _createReminderFromMessage(
        message,
        kind: selected == 'Create follow up' ? 'followup' : 'reminder',
      );
    } else if (selected == 'Save to saved messages') {
      try {
        await chatApi.saveMessage(message.previewText);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to saved messages.')),
          );
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save this message.')),
          );
        }
      }
    } else if (selected == 'Create thread') {
      setState(() {
        _replyingTo = message;
        _threadRootId = message.threadRootId > 0
            ? message.threadRootId
            : message.id;
      });
    } else {
      _showComingSoon(context, '$selected from this message');
    }
  }

  String _taskTitleFromMessage(ChatMessage message) {
    final raw = message.previewText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return 'Task from ${widget.chat.name}';
    return raw.length <= 90 ? raw : '${raw.substring(0, 87)}...';
  }

  int? _taskAssigneeFromConversation() {
    if (!widget.chat.isGroup) return int.tryParse(widget.chat.empId);
    return int.tryParse(chatApi.currentJid.split('@').first);
  }

  String _taskDescriptionFromMessage(ChatMessage message) {
    final lines = <String>[
      'Conversation: ${widget.chat.name}',
      if (message.id > 0) 'Message ID: ${message.id}',
      'Message:',
      message.previewText.trim().isEmpty
          ? '(attachment or empty message)'
          : message.previewText.trim(),
    ];
    return lines.join('\n');
  }

  String _reminderTitleFromMessage(ChatMessage message, String kind) {
    final raw = message.previewText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isNotEmpty) {
      return raw.length <= 90 ? raw : '${raw.substring(0, 87)}...';
    }
    return kind == 'followup'
        ? 'Follow-up from ${widget.chat.name}'
        : 'Reminder from ${widget.chat.name}';
  }

  String _reminderNotesFromMessage(ChatMessage message) {
    final lines = <String>[
      'Conversation: ${widget.chat.name}',
      if (message.id > 0) 'Message ID: ${message.id}',
      'Message:',
      message.previewText.trim().isEmpty
          ? '(attachment or empty message)'
          : message.previewText.trim(),
    ];
    return lines.join('\n');
  }

  Future<void> _createReminderFromMessage(
    ChatMessage message, {
    required String kind,
  }) async {
    final titleController = TextEditingController(
      text: _reminderTitleFromMessage(message, kind),
    );
    final notesController = TextEditingController(
      text: _reminderNotesFromMessage(message),
    );
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          kind == 'followup' ? 'Create follow up' : 'Create reminder',
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 5,
                maxLines: 9,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Continue'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    titleController.dispose();
    notesController.dispose();
    if (created != true || title.isEmpty) return;
    if (!mounted) return;
    final currentUser = await chatApi.getCurrentUser();
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReminderCreateScreen(
          currentUser: currentUser,
          initialKind: kind,
          initialTitle: title,
          initialNotes: notes,
          sourceConversationJid: widget.chat.jid,
          sourceConversationName: widget.chat.name,
          sourceMessageId: message.id,
          sourceMessageText: message.previewText,
        ),
      ),
    );
  }

  Future<void> _createTaskFromMessage(ChatMessage message) async {
    final titleController = TextEditingController(
      text: _taskTitleFromMessage(message),
    );
    final descriptionController = TextEditingController(
      text: _taskDescriptionFromMessage(message),
    );
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create task'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 5,
                maxLines: 9,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Create'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();
    if (create != true || title.isEmpty) return;
    final assignee = _taskAssigneeFromConversation();
    final groupId = widget.chat.isGroup
        ? int.tryParse(widget.chat.empId) ?? 0
        : 0;
    try {
      await chatApi.createMyHubTask(
        title: title.length <= 120 ? title : title.substring(0, 120),
        description: description,
        assignees: assignee == null ? const <int>[] : <int>[assignee],
        groupId: groupId,
      );
      await chatApi.invalidateMyHubTasksCache();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task created.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create task: $error')));
    }
  }

  bool _isOpenMyHubTask(Map<String, dynamic> task) {
    final statusText =
        '${task['status_text'] ?? task['status_label'] ?? task['status'] ?? ''}'
            .trim()
            .toLowerCase();
    final numericStatus = int.tryParse('${task['status'] ?? ''}');
    if (numericStatus != null) {
      return numericStatus != 1 &&
          numericStatus != 3 &&
          numericStatus != 4 &&
          numericStatus != 5;
    }
    return !const {
      'closed',
      'done',
      'completed',
      'complete',
      'cancelled',
      'canceled',
    }.contains(statusText);
  }

  String _taskSearchText(Map<String, dynamic> task) => [
    task['id'],
    task['task_id'],
    task['title'],
    task['deadline'],
    task['due_date'],
  ].map((value) => '${value ?? ''}'.toLowerCase()).join(' ');

  List<Map<String, dynamic>> _extractOpenMyHubTasks(Map<String, dynamic> data) {
    final raw = data['tasks'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(_isOpenMyHubTask)
        .toList();
  }

  Future<Map<String, dynamic>?> _pickOpenMyHubTask(
    List<Map<String, dynamic>> tasks,
  ) async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No open tasks available.')));
      return null;
    }
    final searchController = TextEditingController();
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? tasks
              : tasks
                    .where((task) => _taskSearchText(task).contains(query))
                    .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                children: [
                  ListTile(
                    leading: const BackButton(),
                    title: const Text(
                      'Update task',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text('Select an open task'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search by ID, title or deadline',
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No matching open tasks found'),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final task = filtered[index];
                              final id =
                                  '${task['id'] ?? task['task_id'] ?? ''}'
                                      .trim();
                              final deadline =
                                  '${task['deadline'] ?? task['due_date'] ?? ''}'
                                      .trim();
                              return ListTile(
                                leading: const Icon(Icons.task_alt_rounded),
                                title: Text('${task['title'] ?? 'Task'}'),
                                subtitle: Text(
                                  [
                                    if (id.isNotEmpty) '#$id',
                                    if (deadline.isNotEmpty) 'Due $deadline',
                                  ].join(' | '),
                                ),
                                onTap: () => Navigator.pop(sheetContext, task),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
    return selected;
  }

  Future<String?> _askTaskUpdateComment(ChatMessage message) async {
    final controller = TextEditingController(
      text: 'Update from ${widget.chat.name}:\n${message.previewText}',
    );
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Task update'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Comments'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (submit != true || text.isEmpty) return null;
    return text;
  }

  Future<void> _updateTaskFromMessage(ChatMessage message) async {
    try {
      final data = await chatApi.getMyHubTasks(forceRefresh: true);
      if (!mounted) return;
      final task = await _pickOpenMyHubTask(_extractOpenMyHubTasks(data));
      if (!mounted || task == null) return;
      final taskId = int.tryParse('${task['id'] ?? task['task_id'] ?? 0}') ?? 0;
      if (taskId <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected task has no valid ID.')),
        );
        return;
      }
      final comments = await _askTaskUpdateComment(message);
      if (!mounted || comments == null) return;
      await chatApi.updateMyHubTask(taskId: taskId, comments: comments);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task updated.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update task: $error')));
    }
  }

  Future<void> _createChecklistFromMessage(ChatMessage message) async {
    final titleController = TextEditingController(text: 'Checklist');
    final itemsController = TextEditingController(text: message.previewText);
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create live checklist'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Items',
                  helperText: 'Enter one checklist item per line.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (create != true) {
      titleController.dispose();
      itemsController.dispose();
      return;
    }
    final items = itemsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((item) => <String, dynamic>{'text': item, 'done': false})
        .toList();
    final title = titleController.text.trim().isEmpty
        ? 'Checklist'
        : titleController.text.trim();
    titleController.dispose();
    itemsController.dispose();
    if (items.isEmpty) return;
    final body =
        'SKYLINK_CHECKLIST:${jsonEncode(<String, dynamic>{'title': title, 'items': items, 'created_at': DateTime.now().toIso8601String()})}';
    final sendLocation = await _messageLocationMetadata();
    await chatApi.sendMessage(
      to: widget.chat.jid,
      message: body,
      latitude: sendLocation.latitude,
      longitude: sendLocation.longitude,
      locationAddress: sendLocation.address,
      clientMessageId: 'checklist-${DateTime.now().microsecondsSinceEpoch}',
    );
    await _loadHistory(silent: true);
  }

  Future<void> _toggleChecklist(ChatMessage message, int itemIndex) async {
    try {
      await chatApi.toggleChecklistItem(message.id, itemIndex);
      await _loadHistory(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showSendOptions(ChatMessage message) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.send_rounded),
              title: const Text('Send now'),
              onTap: () => Navigator.pop(sheetContext, 'send'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_send_rounded),
              title: const Text('Send later'),
              subtitle: const Text('Choose a future date and time'),
              onTap: () => Navigator.pop(sheetContext, 'send_later'),
            ),
            ListTile(
              leading: const Icon(Icons.forward_rounded),
              title: const Text('Forward'),
              onTap: () => Navigator.pop(sheetContext, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share to another app'),
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
          ],
        ),
      ),
    );
    if (selected == 'send_later') {
      await _scheduleMessageBody(message.previewText);
    }
    if (selected == 'forward') await _forwardMessage(message);
    if (selected == 'share') await _shareMessage(message);
  }

  Future<void> _quoteMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.previewText);
    final quote = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quote selected lines'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            helperText: 'Keep only the lines you want to quote.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Quote'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || quote == null || quote.isEmpty) return;
    setState(() {
      _replyingTo = message;
      _replyQuote = quote;
    });
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.text);
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: 4000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null || edited.isEmpty || edited == message.text) return;
    try {
      await chatApi.editMessage(message.id, edited);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexOf(message);
        if (index >= 0) {
          _messages[index] = ChatMessage(
            id: message.id,
            text: edited,
            time: message.time,
            isMe: message.isMe,
            sender: message.sender,
            isRead: message.isRead,
            replyToId: message.replyToId,
            threadRootId: message.threadRootId,
            mentions: message.mentions,
            isEdited: true,
            sourceDevice: message.sourceDevice,
            sourceName: message.sourceName,
            createdAt: message.createdAt,
            attachment: message.attachment,
            reaction: message.reaction,
            isFailed: message.isFailed,
            isSending: message.isSending,
            originalSenderJid: message.originalSenderJid,
            originalSenderName: message.originalSenderName,
            originalSourceName: message.originalSourceName,
            isSystem: message.isSystem,
          );
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message updated.')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _manageGroup() async {
    if (!widget.chat.isGroup) return;
    if (widget.onProfileTap != null) {
      widget.onProfileTap!.call();
      return;
    }
    await _loadGroupMembers();
    await _showConversationProfile();
  }

  Future<void> _toggleMute() async {
    try {
      await chatApi.setMuted(widget.chat.jid, !_isMuted);
      if (!mounted) return;
      setState(() => _isMuted = !_isMuted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isMuted ? 'Notifications muted.' : 'Notifications enabled.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _changeGroupPhoto() async {
    if (!widget.chat.isGroup) return;
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    try {
      await chatApi.updateGroupPhoto(
        groupId: groupId,
        name: file.name,
        bytes: file.bytes!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.chat.isChannel
                ? 'Channel photo updated.'
                : 'Group photo updated.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _leaveGroup() async {
    if (!widget.chat.isGroup) return;
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave ${widget.chat.isChannel ? 'channel' : 'group'}?'),
        content: const Text(
          'You will stop receiving messages from this conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await chatApi.groupMemberAction(
        groupId: groupId,
        empId: '0',
        action: 'leave',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _memberAction(GroupMember member, String action) async {
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    if (!const {'owner', 'admin'}.contains(_groupRole)) return;
    try {
      await chatApi.groupMemberAction(
        groupId: groupId,
        empId: member.empId,
        action: action,
      );
      await _loadGroupMembers();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Member updated.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_itemScrollController.isAttached || _messages.isEmpty) return;
      _itemScrollController.scrollTo(
        index: _messages.length - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.9,
      );
    });
  }

  void _jumpToMessage(int messageId) {
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index < 0 || !_itemScrollController.isAttached) return;
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0.22,
    );
  }

  Future<void> _searchMessages() async {
    final controller = TextEditingController();
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = controller.text.trim().toLowerCase();
          final results = _messages
              .where(
                (message) =>
                    query.isNotEmpty &&
                    message.previewText.toLowerCase().contains(query),
              )
              .toList();
          return AlertDialog(
            title: const Text('Search messages'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search this conversation',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: query.isNotEmpty && results.isEmpty
                        ? const Center(child: Text('No matching messages.'))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, index) {
                              final message = results[index];
                              return ListTile(
                                title: Text(
                                  message.previewText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(message.time),
                                onTap: () =>
                                    Navigator.pop(dialogContext, message.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
    if (selected != null) _jumpToMessage(selected);
  }

  String _infoText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = '${data[key] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  String _infoDisplay(Map<String, dynamic> data, List<String> keys) {
    final value = _infoText(data, keys);
    return value.isEmpty ? '-' : value;
  }

  String _readDisplay(Map<String, dynamic> data, List<String> keys) {
    final value = _infoText(data, keys);
    return value.isEmpty ? 'Not read yet' : value;
  }

  String _deviceDisplay(
    Map<String, dynamic> data,
    String deviceKey,
    String nameKey,
  ) {
    final device = _infoText(data, [deviceKey]);
    final name = _infoText(data, [nameKey]);
    if (device.isEmpty && name.isEmpty) return '-';
    if (device.isEmpty) return name;
    if (name.isEmpty) return device;
    return '$device - $name';
  }

  Widget _messageInfoRow(IconData icon, String label, String value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }

  List<Widget> _messageReaderInfoRows(
    Map<String, dynamic> data,
    bool canViewLocations,
  ) {
    final rawReaders = data['readers'];
    if (rawReaders is! List || rawReaders.isEmpty) return const [];
    final rows = <Widget>[];
    for (final rawReader in rawReaders) {
      if (rawReader is! Map) continue;
      final reader = Map<String, dynamic>.from(rawReader);
      final name = _infoText(reader, ['name', 'emp_id']);
      final readAt = _infoText(reader, ['read_at']);
      final device = _deviceDisplay(
        reader,
        'read_source_device',
        'read_source_name',
      );
      final address = _infoText(reader, ['read_location_address']);
      final readLines = <String>[
        if (name.isNotEmpty) name,
        if (readAt.isNotEmpty) readAt,
        if (device != '-') device,
      ];
      if (readLines.isNotEmpty) {
        rows.add(
          _messageInfoRow(
            Icons.person_outline_rounded,
            'Read by',
            readLines.join('\n'),
          ),
        );
      }
      if (canViewLocations && address.isNotEmpty) {
        rows.add(
          _messageInfoRow(
            Icons.my_location_outlined,
            'Read address',
            name.isEmpty ? address : '$name\n$address',
          ),
        );
      }
    }
    return rows;
  }

  Future<void> _showLocalMessageInfo(ChatMessage message, String reason) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Message info'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              _messageInfoRow(Icons.schedule_rounded, 'Sent', message.time),
              _messageInfoRow(
                Icons.done_all_rounded,
                'Read',
                message.readAt.trim().isNotEmpty
                    ? message.readAt
                    : (message.isRead ? 'Read' : 'Not read yet'),
              ),
              if (message.sourceDevice != 'unknown' &&
                  message.sourceDevice.isNotEmpty)
                _messageInfoRow(
                  Icons.devices_outlined,
                  'Sent from',
                  message.sourceName.isEmpty
                      ? cleanMojibakeText(message.sourceDevice)
                      : '${cleanMojibakeText(message.sourceDevice)} - ${cleanMojibakeText(message.sourceName)}',
                ),
              if (_canViewMessageLocations &&
                  message.locationAddress.trim().isNotEmpty)
                _messageInfoRow(
                  Icons.location_on_outlined,
                  'Send address',
                  cleanMojibakeText(message.locationAddress),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessageInfo(ChatMessage message) async {
    if (message.id <= 0) return;
    try {
      final data = await chatApi.getMessageInfo(message.id);
      if (!mounted) return;
      final info = data['message'] is Map
          ? Map<String, dynamic>.from(data['message'] as Map)
          : <String, dynamic>{};
      final canViewLocations = _canViewMessageLocations;
      final sentLocation = _infoText(info, ['location_address']).isNotEmpty
          ? _infoText(info, ['location_address'])
          : message.locationAddress;
      final readLocation = _infoText(info, ['read_location_address']);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Message info'),
          content: SizedBox(
            width: 460,
            child: ListView(
              shrinkWrap: true,
              children: [
                _messageInfoRow(
                  Icons.schedule_rounded,
                  'Sent',
                  _infoDisplay(info, ['created_at']),
                ),
                _messageInfoRow(
                  Icons.done_all_rounded,
                  'Read',
                  _readDisplay(info, ['read_at']),
                ),
                _messageInfoRow(
                  Icons.devices_outlined,
                  'Sent from',
                  _deviceDisplay(info, 'source_device', 'source_name'),
                ),
                if (_infoText(info, [
                  'read_source_device',
                  'read_source_name',
                ]).isNotEmpty)
                  _messageInfoRow(
                    Icons.phonelink_ring_outlined,
                    'Read from',
                    _deviceDisplay(
                      info,
                      'read_source_device',
                      'read_source_name',
                    ),
                  ),
                if (_infoText(info, ['edited_at']).isNotEmpty)
                  _messageInfoRow(
                    Icons.edit_outlined,
                    'Edited',
                    _infoDisplay(info, ['edited_at']),
                  ),
                if (canViewLocations && sentLocation.isNotEmpty)
                  _messageInfoRow(
                    Icons.location_on_outlined,
                    'Send address',
                    sentLocation,
                  ),
                if (canViewLocations && readLocation.isNotEmpty)
                  _messageInfoRow(
                    Icons.my_location_outlined,
                    'Read address',
                    readLocation,
                  ),
                ..._messageReaderInfoRows(data, canViewLocations),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      await _showLocalMessageInfo(message, error.message);
    } catch (error) {
      await _showLocalMessageInfo(message, '$error');
    }
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final values = await Future.wait([
      chatApi.getRecentChats(),
      chatApi.searchUsers(),
    ]);
    final byJid = <String, ChatContact>{};
    for (final chat in [...values[0], ...values[1]]) {
      byJid[chat.jid.toLowerCase()] = chat;
    }
    final chats = byJid.values.toList();
    if (!mounted) return;
    final target = await showModalBottomSheet<ChatContact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForwardTargetSheet(chats: chats),
    );
    if (target == null) return;
    final body = message.attachment?.encode() ?? message.text;
    await chatApi.sendMessage(
      to: target.jid,
      message: body,
      clientMessageId:
          'forward-${message.id}-${DateTime.now().microsecondsSinceEpoch}',
      forwardedFromMessageId: message.id,
      originalSenderJid: message.originalSenderJid.isNotEmpty
          ? message.originalSenderJid
          : (message.isMe ? chatApi.currentJid : widget.chat.jid),
      originalSenderName: message.originalSenderName.isNotEmpty
          ? message.originalSenderName
          : (message.isMe ? 'You' : (message.sender ?? widget.chat.name)),
      originalSourceName: message.originalSourceName.isNotEmpty
          ? message.originalSourceName
          : message.sourceName,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Forwarded to ${target.name}.')));
    }
  }

  Future<void> _shareMessage(ChatMessage message) async {
    final attachment = message.attachment;
    if (attachment != null) {
      await _requestAttachmentStoragePermission(context);
      final path = await chatApi.downloadAttachment(attachment);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: attachment.mimeType)],
          text: attachment.caption,
        ),
      );
    } else {
      await SharePlus.instance.share(ShareParams(text: message.text));
    }
  }

  Future<void> _renameGroup() async {
    final controller = TextEditingController(text: widget.chat.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.chat.isChannel ? 'Rename channel' : 'Rename group'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await chatApi.renameGroup(int.tryParse(widget.chat.empId) ?? 0, name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.chat.isChannel
                ? 'Channel name updated.'
                : 'Group name updated.',
          ),
        ),
      );
    }
  }

  Future<void> _closeChannel() async {
    if (!widget.chat.isChannel ||
        !const {'owner', 'admin'}.contains(_groupRole)) {
      return;
    }
    final channelId = int.tryParse(widget.chat.empId) ?? 0;
    if (channelId <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close channel?'),
        content: const Text(
          "The channel will move to the archive and disappear from every member's open channel list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close channel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await chatApi.closeChannel(channelId);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedMessageIds.isNotEmpty
          ? _buildSelectionAppBar()
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              scrolledUnderElevation: 1,
              titleSpacing: 0,
              title: InkWell(
                onTap: widget.onProfileTap ?? _showConversationProfile,
                child: Row(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(chat: widget.chat, radius: 20),
                        if (_presence?.isOnline == true &&
                            !widget.chat.isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.online,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _presenceLabel,
                            style: TextStyle(
                              color:
                                  (_presence?.isOnline ?? widget.chat.isOnline)
                                  ? AppColors.primary
                                  : AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Return to last read position',
                  onPressed: _returnReadMessageId > 0
                      ? () => _jumpToMessage(_returnReadMessageId)
                      : null,
                  icon: const Icon(Icons.bookmark_outline_rounded),
                ),
                IconButton(
                  tooltip: 'Search messages',
                  onPressed: _searchMessages,
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: 'Call',
                  onPressed: () => _showComingSoon(context, 'Voice call'),
                  icon: const Icon(Icons.call_outlined),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'Manage group') {
                      _manageGroup();
                    } else if (value == 'View profile') {
                      _showUserProfile();
                    } else if (value == 'Close channel') {
                      _closeChannel();
                    } else if (value == 'Pinned messages') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DiscoveryListScreen(
                            title: 'Pinned messages',
                            view: 'pins',
                            jid: widget.chat.jid,
                          ),
                        ),
                      );
                    } else if (value == 'Media browser') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatMediaBrowser(chat: widget.chat),
                        ),
                      );
                    } else if (value == 'Mute notifications' ||
                        value == 'Unmute notifications') {
                      _toggleMute();
                    } else {
                      _showComingSoon(context, value);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: widget.chat.isGroup
                          ? 'Manage group'
                          : 'View profile',
                      child: Text(
                        widget.chat.isChannel
                            ? 'Manage channel'
                            : widget.chat.isGroup
                            ? 'Manage group'
                            : 'View profile',
                      ),
                    ),
                    if (widget.chat.isChannel && _groupRole == 'owner')
                      const PopupMenuItem(
                        value: 'Close channel',
                        child: Text('Close and archive channel'),
                      ),
                    const PopupMenuItem(
                      value: 'Pinned messages',
                      child: Text('Pinned messages'),
                    ),
                    const PopupMenuItem(
                      value: 'Media browser',
                      child: Text('Media browser'),
                    ),
                    PopupMenuItem(
                      value: _isMuted
                          ? 'Unmute notifications'
                          : 'Mute notifications',
                      child: Text(
                        _isMuted
                            ? 'Unmute notifications'
                            : 'Mute notifications',
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: DropTarget(
              onDragEntered: (_) {
                if (mounted) setState(() => _isDragOver = true);
              },
              onDragExited: (_) {
                if (mounted) setState(() => _isDragOver = false);
              },
              onDragDone: (details) => _handleDroppedFiles(details.files),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ChatBackgroundPainter(
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _loadError != null
                          ? _LoadError(
                              message: _loadError!,
                              onRetry: _loadHistory,
                            )
                          : _messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet. Say hello!',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          : ScrollablePositionedList.builder(
                              itemScrollController: _itemScrollController,
                              itemPositionsListener: _itemPositionsListener,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                18,
                                14,
                                18,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (_, index) {
                                final message = _messages[index];
                                final previous = index > 0
                                    ? _messages[index - 1]
                                    : null;
                                final showDate =
                                    previous == null ||
                                    !_sameMessageDay(
                                      previous.createdAt,
                                      message.createdAt,
                                    );
                                return _MessageBubble(
                                  key: _messageKeys.putIfAbsent(
                                    message.id,
                                    () => GlobalKey(),
                                  ),
                                  message: message,
                                  showSender: widget.chat.isGroup,
                                  showLocationAddress: _canViewMessageLocations,
                                  replyMessage: _messageById(message.replyToId),
                                  dateLabel: showDate
                                      ? _messageDateLabel(message.createdAt)
                                      : null,
                                  onReplyTap: message.replyToId > 0
                                      ? () => _jumpToMessage(message.replyToId)
                                      : null,
                                  selected: _selectedMessageIds.contains(
                                    message.id,
                                  ),
                                  onTap: () {
                                    if (_selectedMessageIds.isNotEmpty) {
                                      _toggleMessageSelection(message);
                                    }
                                  },
                                  onLongPress: () =>
                                      _toggleMessageSelection(message),
                                  onSecondaryTap: () =>
                                      _showMessageActions(message),
                                  onSwipeReply: _isSystemNotification
                                      ? null
                                      : () => setState(() {
                                          _selectedMessageIds.clear();
                                          _replyingTo = message;
                                          _replyQuote = '';
                                        }),
                                  onSwipeBack:
                                      _showEmojiPicker ||
                                          MediaQuery.sizeOf(context).width >=
                                              900
                                      ? null
                                      : () {
                                          if (_selectedMessageIds.isNotEmpty) {
                                            setState(_selectedMessageIds.clear);
                                          }
                                          Navigator.maybePop(context);
                                        },
                                  onMentionTap: _openMentionProfile,
                                  onChecklistToggle: (itemIndex) =>
                                      _toggleChecklist(message, itemIndex),
                                );
                              },
                            ),
                    ),
                  ),
                  if (_isDragOver)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                child: Text('Drop files to send'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_mentionSuggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              color: Colors.white,
              child: ListView(
                shrinkWrap: true,
                children: _mentionSuggestions
                    .map(
                      (member) => ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          child: Icon(Icons.alternate_email_rounded),
                        ),
                        title: Text(member.name),
                        subtitle: Text(member.designation),
                        onTap: () => _selectMention(member),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_replyingTo != null && !_isSystemNotification)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingTo!.sender ??
                              (_replyingTo!.isMe ? 'You' : widget.chat.name),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _replyQuote.isNotEmpty
                              ? _replyQuote
                              : _replyingTo!.previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _replyingTo = null;
                      _replyQuote = '';
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          if (_isSystemNotification)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.paddingOf(context).bottom + 14,
              ),
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Replies are disabled for this conversation.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            )
          else
            _MessageComposer(
              controller: _messageController,
              onSend: _sendMessage,
              onSendLater: _scheduleDraftMessage,
              onVoiceRecord: _toggleVoiceRecording,
              isRecordingVoice: _isRecordingVoice,
              onAttach: _pickAndSendAttachment,
              isUploading: _isUploading,
              uploadProgress: _uploadProgress,
              showEmojiPicker: _showEmojiPicker,
              onEmojiToggle: () =>
                  setState(() => _showEmojiPicker = !_showEmojiPicker),
              onEmojiSelected: (emoji) {
                final value = _messageController.value;
                final selection = value.selection.isValid
                    ? value.selection
                    : TextSelection.collapsed(offset: value.text.length);
                final text = value.text.replaceRange(
                  selection.start,
                  selection.end,
                  emoji,
                );
                _messageController.value = TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(
                    offset: selection.start + emoji.length,
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: !_showJumpToLatest
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 76),
              child: FloatingActionButton.small(
                tooltip: _newMessageCount > 0
                    ? '$_newMessageCount new messages'
                    : 'Jump to latest',
                onPressed: () {
                  setState(() => _newMessageCount = 0);
                  _scrollToBottom();
                },
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ),
    );
  }

  Future<void> _showUserProfile({String? empId, String? fallbackName}) async {
    try {
      final targetEmpId = empId ?? widget.chat.empId;
      final user = await chatApi.getUserProfile(targetEmpId);
      if (!mounted) return;
      final title = '${user['name'] ?? fallbackName ?? widget.chat.name}';
      final designation = '${user['designation'] ?? 'Employee'}';
      final online =
          user['messenger_connected'] == true ||
          '${user['messenger_connected']}' == '1';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text('#${user['employee_id'] ?? targetEmpId}'),
                  subtitle: const Text('Employee ID'),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.work_outline_rounded),
                  title: Text(designation),
                  subtitle: const Text('Designation'),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    online
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                  ),
                  title: Text(online ? 'Online' : 'Offline'),
                  subtitle: Text(
                    'Launchpad ${user['launchpad_active'] == true ? 'active' : 'inactive'}',
                  ),
                ),
                if ('${user['device_model'] ?? ''}'.isNotEmpty ||
                    '${user['platform'] ?? ''}'.isNotEmpty ||
                    '${user['app_version'] ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices_outlined),
                    title: Text('${user['device_model'] ?? '-'}'),
                    subtitle: Text(
                      '${user['platform'] ?? '-'} - ${user['app_version'] ?? '-'}',
                    ),
                  ),
                if ('${user['last_activity'] ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text('${user['last_activity']}'),
                    subtitle: const Text('Last activity'),
                  ),
                if ('${user['latest_location_address'] ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text('${user['latest_location_address']}'),
                    subtitle: const Text('Last known location'),
                  ),
                if ('${user['mobile'] ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_outlined),
                    title: Text('${user['mobile']}'),
                    subtitle: const Text('Mobile'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showWakeupConfig() async {
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (groupId <= 0) return;
    if (!const {'owner', 'admin'}.contains(_groupRole)) {
      return;
    }
    try {
      final config = await chatApi.getWakeupConfig(
        groupId: groupId,
        jid: widget.chat.jid,
      );
      if (!mounted) return;
      var enabled =
          config['enabled'] == true ||
          '${config['enabled']}'.toLowerCase() == '1' ||
          '${config['enabled']}'.toLowerCase() == 'true';
      var interval =
          int.tryParse(
            '${config['interval_minutes'] ?? config['minutes'] ?? 1440}',
          ) ??
          1440;
      const choices = <int, String>{
        1440: '1 day',
        4320: '3 days',
        10080: '7 days',
        21600: '15 days',
        43200: '1 month',
        86400: '2 months',
        129600: '3 months',
      };
      if (!choices.containsKey(interval)) interval = 1440;
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Wake-up notification'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable wake-up notification'),
                    subtitle: const Text('Weekends are skipped.'),
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: choices.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: interval == entry.key,
                        onSelected: enabled
                            ? (_) => setDialogState(() => interval = entry.key)
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return;
      await chatApi.updateWakeupConfig(
        groupId: groupId,
        enabled: enabled,
        intervalMinutes: interval,
      );
      if (mounted) {
        setState(() {});
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showConversationProfile() async {
    if (!widget.chat.isGroup) {
      await _showUserProfile();
      return;
    }
    final groupId = int.tryParse(widget.chat.empId) ?? 0;
    if (_groupMembers.isEmpty) {
      await _loadGroupMembers();
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: UserAvatar(chat: widget.chat, radius: 48)),
            const SizedBox(height: 12),
            Text(
              widget.chat.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.chat.isChannel ? 'Channel profile' : 'Group profile',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: const Icon(Icons.people_outline_rounded),
              title: Text('${_groupMembers.length} members'),
              subtitle: Text(
                '${_groupMembers.where((member) => member.isOnline).length} online',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Wake-up notification'),
              subtitle: Text(
                const {'owner', 'admin'}.contains(_groupRole)
                    ? 'Disabled by default - tap to configure'
                    : 'Only owners/admins can change',
              ),
              onTap: const {'owner', 'admin'}.contains(_groupRole)
                  ? _showWakeupConfig
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Media, files and links'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatMediaBrowser(chat: widget.chat),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('Pinned messages'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DiscoveryListScreen(
                    title: 'Pinned messages',
                    view: 'pins',
                    jid: widget.chat.jid,
                  ),
                ),
              ),
            ),
            if (const {'owner', 'admin'}.contains(_groupRole)) ...[
              ListTile(
                leading: const Icon(Icons.person_add_alt_rounded),
                title: const Text('Manage members'),
                onTap: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _ManageGroupSheet(
                      groupId: groupId,
                      initialMembers: _groupMembers,
                      isOwner: const {'owner', 'admin'}.contains(_groupRole),
                      currentRole: _groupRole,
                    ),
                  );
                  await _loadGroupMembers();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Change photo'),
                onTap: _changeGroupPhoto,
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(
                  widget.chat.isChannel
                      ? 'Change channel name'
                      : 'Change group name',
                ),
                onTap: _renameGroup,
              ),
            ],
            const Divider(),
            const Text(
              'Members',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            ..._groupMembers.map(
              (member) => ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member.name.isEmpty ? member.empId : member.name[0],
                  ),
                ),
                title: Text(member.name.isEmpty ? member.empId : member.name),
                subtitle: Text(
                  member.role == 'owner'
                      ? 'Owner'
                      : member.role == 'admin'
                      ? 'Admin'
                      : member.isOnline
                      ? 'online'
                      : member.lastSeen == null
                      ? member.designation
                      : 'last active ${_memberLastSeen(member.lastSeen!)}',
                ),
                trailing:
                    const {'owner', 'admin'}.contains(_groupRole) &&
                        member.role != 'owner'
                    ? PopupMenuButton<String>(
                        onSelected: (action) => _memberAction(member, action),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: member.role == 'admin'
                                ? 'demote'
                                : 'promote',
                            child: Text(
                              member.role == 'admin'
                                  ? 'Change to member'
                                  : 'Promote to admin',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove member'),
                          ),
                        ],
                      )
                    : member.role == 'owner'
                    ? const Chip(label: Text('Owner'))
                    : member.isOnline
                    ? const Icon(Icons.circle, color: Colors.green, size: 12)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _memberLastSeen(DateTime value) {
    final now = DateTime.now();
    final sameDay =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final time = TimeOfDay.fromDateTime(value).format(context);
    return sameDay ? 'today at $time' : '${value.day}/${value.month} at $time';
  }

  String _friendlyChannelType(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return switch (normalized) {
      'ticket' => 'Ticket Channel',
      'action' => 'Action Channel',
      'incident' => 'Incident Channel',
      'project' => 'Project Channel',
      'approval' => 'Approval Channel',
      'announcement' => 'Announcement Channel',
      'personal_workspace' => 'Personal Workspace',
      'installation' => 'Installation Channel',
      'l2_feasibility' => 'L2 Feasibility Channel',
      'protect' => 'Protect Channel',
      _ => 'Operational Channel',
    };
  }

  bool _sameMessageDay(DateTime? first, DateTime? second) {
    if (first == null && second == null) return true;
    if (first == null || second == null) return false;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _messageDateLabel(DateTime? value) {
    if (value == null) return 'Today';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _ChatBackgroundPainter extends CustomPainter {
  const _ChatBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = isDark ? const Color(0xFF0F1722) : const Color(0xFFEDF3FA);
    canvas.drawRect(Offset.zero & size, background);

    final pattern = Paint()
      ..color = (isDark ? Colors.white : AppColors.primary).withValues(
        alpha: isDark ? 0.025 : 0.035,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const spacing = 72.0;
    for (double y = 18; y < size.height; y += spacing) {
      for (double x = 22; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 10, pattern);
        canvas.drawLine(
          Offset(x + 15, y + 16),
          Offset(x + 28, y + 29),
          pattern,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF8394A9).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.showSender,
    required this.showLocationAddress,
    required this.onLongPress,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTap,
    this.replyMessage,
    this.onReplyTap,
    this.dateLabel,
    this.onMentionTap,
    this.onSwipeReply,
    this.onSwipeBack,
    this.onChecklistToggle,
  });

  final ChatMessage message;
  final bool showSender;
  final bool showLocationAddress;
  final ChatMessage? replyMessage;
  final VoidCallback onLongPress;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final VoidCallback? onReplyTap;
  final String? dateLabel;
  final ValueChanged<String>? onMentionTap;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onSwipeBack;
  final ValueChanged<int>? onChecklistToggle;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contactCard = _decodeContactCard(message.text);
    final checklist = _decodeLiveChecklist(message.text);
    final isTaggedOrReplied =
        message.replyToId > 0 ||
        message.originalSenderName.isNotEmpty ||
        message.mentions.isNotEmpty;
    if (message.isSystem) {
      return Column(
        children: [
          if (dateLabel != null) _DateChip(label: dateLabel!),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (dateLabel != null) _DateChip(label: dateLabel!),
        GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onSecondaryTap,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 450) {
              onSwipeReply?.call();
            } else if (velocity < -450 &&
                attachment == null &&
                contactCard == null &&
                checklist == null) {
              onSwipeBack?.call();
            }
          },
          child: Align(
            alignment: message.isMe
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              margin: EdgeInsets.only(bottom: 8 * appChatDensity.value),
              padding: EdgeInsets.fromLTRB(
                13,
                9 * appChatDensity.value,
                9,
                7 * appChatDensity.value,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.24)
                    : isTaggedOrReplied
                    ? (message.isMe
                          ? const Color(0xFFC7E0FF)
                          : const Color(0xFFFFF0C8))
                    : message.isMe
                    ? dark
                          ? const Color(0xFF173B63)
                          : AppColors.outgoing
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(message.isMe ? 17 : 4),
                  bottomRight: Radius.circular(message.isMe ? 4 : 17),
                ),
                border: isTaggedOrReplied
                    ? Border.all(color: const Color(0xFFFFB020), width: 1.2)
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100C2748),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSender && !message.isMe && message.sender != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        cleanMojibakeText(message.sender!),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (replyMessage != null)
                    InkWell(
                      onTap: onReplyTap,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9),
                          border: const Border(
                            left: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replyMessage!.sender ??
                                  (replyMessage!.isMe ? 'You' : 'Message'),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              cleanMojibakeText(replyMessage!.previewText),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (message.threadRootId > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.forum_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Thread reply',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.originalSenderName.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Forwarded from ${cleanMojibakeText(message.originalSenderName)}'
                        '${message.originalSourceName.isNotEmpty ? ' - ${cleanMojibakeText(message.originalSourceName)}' : ''}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (attachment != null)
                    _AttachmentContent(attachment: attachment)
                  else if (contactCard != null)
                    _ContactMessageCard(data: contactCard)
                  else if (checklist != null)
                    _LiveChecklistCard(
                      data: checklist,
                      onToggle: onChecklistToggle,
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CollapsibleMessageText(
                          text: cleanMojibakeText(message.text),
                          onMentionTap: onMentionTap,
                        ),
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.time,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                              if (message.isEdited)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text(
                                    'edited',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              if (message.isMe) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  message.isFailed
                                      ? Icons.error_outline_rounded
                                      : message.isSending
                                      ? Icons.schedule_rounded
                                      : message.isRead
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                                  size: 16,
                                  color: message.isFailed
                                      ? Colors.red
                                      : AppColors.primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (attachment != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            message.time,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                          if (message.isMe) ...[
                            const SizedBox(width: 3),
                            Icon(
                              message.isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (message.sourceDevice != 'unknown' &&
                      message.sourceDevice.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        message.sourceName.isEmpty
                            ? 'via ${cleanMojibakeText(message.sourceDevice)}'
                            : 'via ${cleanMojibakeText(message.sourceDevice)} - ${cleanMojibakeText(message.sourceName)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (showLocationAddress &&
                      message.locationAddress.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              cleanMojibakeText(message.locationAddress),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.reaction.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(cleanMojibakeText(message.reaction)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsibleMessageText extends StatefulWidget {
  const _CollapsibleMessageText({required this.text, this.onMentionTap});

  final String text;
  final ValueChanged<String>? onMentionTap;

  @override
  State<_CollapsibleMessageText> createState() =>
      _CollapsibleMessageTextState();
}

class _CollapsibleMessageTextState extends State<_CollapsibleMessageText> {
  static const _collapsedLines = 8;
  static const _longMessageCharacters = 420;

  bool _expanded = false;

  bool get _isLong {
    if (widget.text.length > _longMessageCharacters) return true;
    return String.fromCharCode(10).allMatches(widget.text).length >=
        _collapsedLines;
  }

  @override
  void didUpdateWidget(covariant _CollapsibleMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appCollapseLongMessages,
      builder: (context, collapseLongMessages, _) {
        final collapsible = collapseLongMessages && _isLong;
        final collapsed = collapsible && !_expanded;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: appMessageScale,
              builder: (context, _, _) => SelectionArea(
                child: Text.rich(
                  _formattedMessageSpan(
                    widget.text,
                    Theme.of(context),
                    onMentionTap: widget.onMentionTap,
                  ),
                  maxLines: collapsed ? _collapsedLines : null,
                ),
              ),
            ),
            if (collapsible)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(top: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? 'Show less' : 'Read more'),
              ),
          ],
        );
      },
    );
  }
}

TextSpan _formattedMessageSpan(
  String text,
  ThemeData theme, {
  ValueChanged<String>? onMentionTap,
}) {
  text = cleanMojibakeText(text);
  final base = TextStyle(
    color: theme.colorScheme.onSurface,
    fontSize: 15 * appMessageScale.value,
    height: 1.35,
  );
  final pattern = RegExp(
    r'(\*\*[\s\S]+?\*\*|~~[\s\S]+?~~|\*[^*\n]+?\*|_[^_\n]+?_|\[color=#[0-9A-Fa-f]{6}\][\s\S]+?\[/color\]|@[A-Za-z0-9_]+)',
  );
  final spans = <InlineSpan>[];
  var offset = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > offset) {
      spans.add(TextSpan(text: text.substring(offset, match.start)));
    }
    final token = match.group(0)!;
    if (token.startsWith('**')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (token.startsWith('~~')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      );
    } else if (token.startsWith('*') || token.startsWith('_')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else if (token.startsWith('@')) {
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            fontWeight: FontWeight.w700,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onMentionTap?.call(token),
        ),
      );
    } else {
      final colorHex = token.substring(8, 14);
      final content = token.substring(15, token.length - 8);
      spans.add(
        TextSpan(
          text: content,
          style: TextStyle(color: Color(int.parse('FF$colorHex', radix: 16))),
        ),
      );
    }
    offset = match.end;
  }
  if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
  return TextSpan(style: base, children: spans);
}

class _ThreadViewScreen extends StatefulWidget {
  const _ThreadViewScreen({
    required this.chat,
    required this.root,
    required this.messages,
  });

  final ChatPreview chat;
  final ChatMessage root;
  final List<ChatMessage> messages;

  @override
  State<_ThreadViewScreen> createState() => _ThreadViewScreenState();
}

class _ThreadViewScreenState extends State<_ThreadViewScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  int get _rootId =>
      widget.root.threadRootId > 0 ? widget.root.threadRootId : widget.root.id;

  List<ChatMessage> get _replies => widget.messages
      .where((message) => message.threadRootId == _rootId)
      .toList();

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await chatApi.sendMessage(
        to: widget.chat.jid,
        message: text,
        replyToId: '${widget.root.id}',
        threadRootId: '$_rootId',
      );
      if (!mounted) return;
      _controller.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thread reply sent.')));
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

  Widget _threadMessage(ChatMessage message, {bool root = false}) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              root ? 'Original message' : (message.sender ?? 'You'),
              style: TextStyle(
                color: root ? AppColors.primary : null,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(cleanMojibakeText(message.previewText)),
            const SizedBox(height: 6),
            Text(message.time, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${_replies.length} replies'),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _threadMessage(widget.root, root: true),
                const Divider(height: 24),
                ..._replies.map(_threadMessage),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Reply in thread',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentContent extends StatelessWidget {
  const _AttachmentContent({required this.attachment});

  final ChatAttachment attachment;

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentPreviewScreen(attachment: attachment),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    try {
      await _requestAttachmentStoragePermission(context);
      final path = await chatApi.downloadAttachment(attachment);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded to $path')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachment.isLocation)
          _LocationAttachmentPreview(attachment: attachment)
        else if (attachment.isImage)
          InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.network(
                    attachment.url,
                    width: 260,
                    height: 190,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            width: 260,
                            height: 190,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (_, _, _) => _FileTile(
                      attachment: attachment,
                      onTap: () => _open(context),
                      onDownload: () => _download(context),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.46),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Download',
                        onPressed: () => _download(context),
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _FileTile(
            attachment: attachment,
            onTap: () => _open(context),
            onDownload: () => _download(context),
          ),
        if (attachment.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
            child: Text(
              attachment.caption,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.attachment,
    required this.onTap,
    this.onDownload,
  });

  final ChatAttachment attachment;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Icon(Icons.insert_drive_file_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatFileSize(attachment.size),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDownload,
              icon: const Icon(
                Icons.download_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AttachmentPreviewKind {
  image,
  audio,
  location,
  pdf,
  text,
  office,
  binary,
}

class AttachmentPreviewScreen extends StatefulWidget {
  const AttachmentPreviewScreen({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  State<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState extends State<AttachmentPreviewScreen> {
  late Future<_AttachmentPreviewData> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  String get _title =>
      widget.attachment.name.isEmpty ? 'File preview' : widget.attachment.name;

  Future<_AttachmentPreviewData> _loadPreview() async {
    final attachment = widget.attachment;
    final mime = attachment.mimeType.toLowerCase();
    final name = attachment.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    final bytes = await chatApi.readAttachmentBytes(attachment);

    if (mime.startsWith('image/')) {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.image,
        bytes: bytes,
      );
    }

    if (attachment.isAudio) {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.audio,
        bytes: bytes,
      );
    }

    if (attachment.isLocation) {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.location,
        text: attachment.locationAddress,
      );
    }

    if (mime.contains('pdf') || ext == 'pdf') {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.pdf,
        bytes: bytes,
      );
    }

    if (_isTextPreviewType(mime, ext)) {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.text,
        text: _bytesToText(bytes),
      );
    }

    if (ext == 'docx') {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.office,
        text: _extractDocxText(bytes),
      );
    }

    if (ext == 'xlsx') {
      return _AttachmentPreviewData(
        kind: _AttachmentPreviewKind.office,
        text: _extractXlsxText(bytes),
      );
    }

    return _AttachmentPreviewData(
      kind: _AttachmentPreviewKind.binary,
      text:
          'This file opens inside the app, but a rich preview engine is not available for this type yet.',
    );
  }

  Future<void> _download() async {
    try {
      await _requestAttachmentStoragePermission(context);
      final path = await chatApi.downloadAttachment(widget.attachment);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded to $path')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: _download,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_AttachmentPreviewData>(
        future: _previewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AttachmentPreviewError(
              title: _title,
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _previewFuture = _loadPreview()),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Unable to load preview.'));
          }
          return _AttachmentPreviewBody(
            attachment: widget.attachment,
            data: data,
          );
        },
      ),
    );
  }
}

class _AttachmentPreviewBody extends StatelessWidget {
  const _AttachmentPreviewBody({required this.attachment, required this.data});

  final ChatAttachment attachment;
  final _AttachmentPreviewData data;

  @override
  Widget build(BuildContext context) {
    switch (data.kind) {
      case _AttachmentPreviewKind.image:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.memory(
                data.bytes ?? Uint8List(0),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, size: 72),
              ),
            ),
          ),
        );
      case _AttachmentPreviewKind.audio:
        return _AudioAttachmentPreview(attachment: attachment);
      case _AttachmentPreviewKind.location:
        return _LocationAttachmentPreview(attachment: attachment);
      case _AttachmentPreviewKind.pdf:
        return kIsWeb
            ? SizedBox.expand(
                child: buildEmbeddedFilePreview(
                  attachment.url,
                  attachment.name,
                ),
              )
            : const _AttachmentPreviewText(
                text:
                    'PDF preview is available in the web build. Use download if you want to open it with a local app on this device.',
              );
      case _AttachmentPreviewKind.office:
      case _AttachmentPreviewKind.text:
        return _AttachmentPreviewText(text: data.text ?? '');
      case _AttachmentPreviewKind.binary:
        return _AttachmentPreviewText(text: data.text ?? '');
    }
  }
}

class _AudioAttachmentPreview extends StatefulWidget {
  const _AudioAttachmentPreview({required this.attachment});

  final ChatAttachment attachment;

  @override
  State<_AudioAttachmentPreview> createState() =>
      _AudioAttachmentPreviewState();
}

class _AudioAttachmentPreviewState extends State<_AudioAttachmentPreview> {
  final AudioPlayer _player = AudioPlayer();
  late final Future<String> _sourceFuture;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _sourceFuture = _prepareSource();
    _positionSubscription = _player.positionStream.listen((value) {
      if (mounted) setState(() => _position = value);
    });
    _durationSubscription = _player.durationStream.listen((value) {
      if (mounted) setState(() => _duration = value ?? Duration.zero);
    });
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _playing = state.playing);
    });
  }

  Future<String> _prepareSource() async {
    if (kIsWeb) {
      await _player.setUrl(widget.attachment.url);
      return widget.attachment.url;
    }
    final bytes = await chatApi.readAttachmentBytes(widget.attachment);
    final baseDir = await getTemporaryDirectory();
    final safeName = widget.attachment.name.replaceAll(
      RegExp(r'[<>:"/\|?*]'),
      '_',
    );
    final file = File(
      '${baseDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );
    await file.writeAsBytes(bytes, flush: true);
    await _player.setFilePath(file.path);
    return file.path;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _timeLabel(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _sourceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _AttachmentPreviewText(
            text:
                'Unable to load audio preview. Use download to open it locally.\n${snapshot.error}',
          );
        }
        final duration = _duration;
        final position = _position > duration ? duration : _position;
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final valueMs = position.inMilliseconds
            .clamp(0, maxMs.toInt())
            .toDouble();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _toggle,
                            icon: Icon(
                              _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.attachment.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.attachment.caption.isNotEmpty
                                    ? widget.attachment.caption
                                    : 'Voice message',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: valueMs,
                      max: maxMs,
                      onChanged: duration == Duration.zero
                          ? null
                          : (value) => _player.seek(
                              Duration(milliseconds: value.round()),
                            ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_timeLabel(position)),
                        Text(_timeLabel(duration)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocationAttachmentPreview extends StatelessWidget {
  const _LocationAttachmentPreview({required this.attachment});

  final ChatAttachment attachment;

  int _tileX(double longitude, int zoom) {
    return ((longitude + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  int _tileY(double latitude, int zoom) {
    final latRad = latitude * pi / 180.0;
    return ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) /
            2.0 *
            (1 << zoom))
        .floor();
  }

  String _tileUrl(int x, int y, int zoom) {
    return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
  }

  String get _title =>
      attachment.isLiveLocation ? 'Live location' : 'Current location';

  String get _detail {
    if (attachment.locationAddress.isNotEmpty)
      return attachment.locationAddress;
    if (attachment.latitude != null && attachment.longitude != null) {
      return '${attachment.latitude!.toStringAsFixed(5)}, ${attachment.longitude!.toStringAsFixed(5)}';
    }
    return _title;
  }

  Widget _mapTiles({required double height}) {
    final lat = attachment.latitude;
    final lon = attachment.longitude;
    if (lat == null || lon == null) {
      return _mapFallback(height: height);
    }
    const zoom = 15;
    final centerX = _tileX(lon, zoom);
    final centerY = _tileY(lat, zoom);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GridView.count(
            crossAxisCount: 3,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (var y = centerY - 1; y <= centerY + 1; y++)
                for (var x = centerX - 1; x <= centerX + 1; x++)
                  Image.network(
                    _tileUrl(x, y, zoom),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFFE8E2C6)),
                  ),
            ],
          ),
          const Center(
            child: Icon(
              Icons.location_on,
              color: Colors.redAccent,
              size: 54,
              shadows: [Shadow(color: Colors.white, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapFallback({required double height}) {
    return Container(
      height: height,
      color: const Color(0xFFE8E2C6),
      child: const Center(
        child: Icon(Icons.location_on, size: 58, color: Colors.redAccent),
      ),
    );
  }

  Future<void> _openMap(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _mapTiles(height: 320),
              ),
              const SizedBox(height: 12),
              SelectableText(_detail),
              if (attachment.isLiveLocation && attachment.liveMinutes > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Expires after ${attachment.liveMinutes} minutes. Updates every 1 minute.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return InkWell(
      onTap: () => _openMap(context),
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 318,
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _mapTiles(height: 190),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 26, 10, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              if (detail.isNotEmpty)
                                Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (attachment.isLiveLocation &&
                            attachment.liveMinutes > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${attachment.liveMinutes} min',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreviewText extends StatelessWidget {
  const _AttachmentPreviewText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SelectionArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text.isEmpty ? '(No readable content found.)' : text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreviewError extends StatelessWidget {
  const _AttachmentPreviewError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreviewData {
  const _AttachmentPreviewData({required this.kind, this.bytes, this.text});

  final _AttachmentPreviewKind kind;
  final Uint8List? bytes;
  final String? text;
}

bool _isTextPreviewType(String mimeType, String extension) {
  if (mimeType.startsWith('text/')) return true;
  return {
    'txt',
    'log',
    'md',
    'csv',
    'json',
    'xml',
    'html',
    'htm',
    'php',
    'dart',
    'js',
    'ts',
    'yaml',
    'yml',
    'css',
    'scss',
    'less',
    'py',
    'java',
    'c',
    'cpp',
    'h',
    'hpp',
    'sh',
    'bat',
    'ini',
    'conf',
  }.contains(extension);
}

String _bytesToText(Uint8List bytes) {
  return utf8.decode(bytes, allowMalformed: true);
}

String _extractDocxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final file = archive.findFile('word/document.xml');
    if (file == null) return '';
    final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
    final paragraphs = RegExp(r'<w:p[\s\S]*?</w:p>').allMatches(xml);
    final lines = <String>[];
    for (final paragraph in paragraphs) {
      final content = paragraph.group(0) ?? '';
      final runs = RegExp(r'<w:t[^>]*>([\s\S]*?)</w:t>').allMatches(content);
      final text = runs.map((m) => _xmlUnescape(m.group(1) ?? '')).join('');
      if (text.trim().isNotEmpty) lines.add(text);
    }
    return lines.isEmpty ? _stripXmlTags(xml) : lines.join('\n');
  } catch (_) {
    return '';
  }
}

String _extractXlsxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final shared = archive.findFile('xl/sharedStrings.xml');
    final sharedStrings = <String>[];
    if (shared != null) {
      final sharedXml = utf8.decode(
        shared.content as List<int>,
        allowMalformed: true,
      );
      for (final match in RegExp(
        r'<t[^>]*>([\s\S]*?)</t>',
      ).allMatches(sharedXml)) {
        sharedStrings.add(_xmlUnescape(match.group(1) ?? ''));
      }
    }
    final sheets =
        archive.files
            .where(
              (file) =>
                  file.name.startsWith('xl/worksheets/sheet') &&
                  file.name.endsWith('.xml'),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (sheets.isEmpty) return '';
    final xml = utf8.decode(
      sheets.first.content as List<int>,
      allowMalformed: true,
    );
    final rows = <String>[];
    for (final rowMatch in RegExp(
      r'<row[^>]*>([\s\S]*?)</row>',
    ).allMatches(xml)) {
      final rowXml = rowMatch.group(1) ?? '';
      final cells = <String>[];
      for (final cellMatch in RegExp(
        r'<c[^>]*?(?:t="([^"]+)")?[^>]*>([\s\S]*?)</c>',
      ).allMatches(rowXml)) {
        final cellType = cellMatch.group(1) ?? '';
        final cellXml = cellMatch.group(2) ?? '';
        final sharedIndex = RegExp(
          r'<v>(\d+)</v>',
        ).firstMatch(cellXml)?.group(1);
        final inline = RegExp(
          r'<t[^>]*>([\s\S]*?)</t>',
        ).firstMatch(cellXml)?.group(1);
        var value = '';
        if (cellType == 's' && sharedIndex != null) {
          final index = int.tryParse(sharedIndex) ?? -1;
          if (index >= 0 && index < sharedStrings.length)
            value = sharedStrings[index];
        } else if (inline != null) {
          value = _xmlUnescape(inline);
        } else {
          value = _xmlUnescape(
            RegExp(r'<v>([\s\S]*?)</v>').firstMatch(cellXml)?.group(1) ?? '',
          );
        }
        cells.add(value);
      }
      if (cells.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(cells.join('\t'));
      }
    }
    return rows.join('\n');
  } catch (_) {
    return '';
  }
}

String _xmlUnescape(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

String _stripXmlTags(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _encodeContactCard(Map<String, dynamic> contact) {
  return 'SKYLINK_CONTACT:${jsonEncode(contact)}';
}

Map<String, dynamic>? _decodeContactCard(String text) {
  const prefix = 'SKYLINK_CONTACT:';
  if (!text.startsWith(prefix)) return null;
  try {
    final value = jsonDecode(text.substring(prefix.length));
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    data['phones'] = data['phones'] is List
        ? (data['phones'] as List).map((item) => '$item').toList()
        : <String>[];
    data['emails'] = data['emails'] is List
        ? (data['emails'] as List).map((item) => '$item').toList()
        : <String>[];
    return data;
  } catch (_) {
    return null;
  }
}

class _ContactMessageCard extends StatelessWidget {
  const _ContactMessageCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = '${data['name'] ?? 'Contact'}'.trim();
    final phones = data['phones'] is List ? data['phones'] as List : const [];
    final emails = data['emails'] is List ? data['emails'] as List : const [];
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Contact' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...phones.map(
            (phone) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.call_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$phone')),
                ],
              ),
            ),
          ),
          ...emails.map(
            (email) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.mail_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$email')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _decodeLiveChecklist(String text) {
  const prefix = 'SKYLINK_CHECKLIST:';
  if (!text.startsWith(prefix)) return null;
  try {
    final value = jsonDecode(text.substring(prefix.length));
    return value is Map ? Map<String, dynamic>.from(value) : null;
  } catch (_) {
    return null;
  }
}

class _LiveChecklistCard extends StatelessWidget {
  const _LiveChecklistCard({required this.data, this.onToggle});

  final Map<String, dynamic> data;
  final ValueChanged<int>? onToggle;

  @override
  Widget build(BuildContext context) {
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final completed = items.where((item) => item['done'] == true).length;
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${data['title'] ?? 'Checklist'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$completed/${items.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: items.isEmpty ? 0 : completed / items.length,
          ),
          const SizedBox(height: 6),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final done = item['done'] == true;
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: done,
              onChanged: onToggle == null ? null : (_) => onToggle!(index),
              title: Text(
                '${item['text'] ?? ''}',
                style: TextStyle(
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        ],
      ),
    );
  }
}

class _ForwardTargetSheet extends StatefulWidget {
  const _ForwardTargetSheet({required this.chats});

  final List<ChatContact> chats;

  @override
  State<_ForwardTargetSheet> createState() => _ForwardTargetSheetState();
}

class _ForwardTargetSheetState extends State<_ForwardTargetSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final chats = widget.chats.where((chat) {
      if (query.isEmpty) return true;
      return '${chat.name} ${chat.designation} ${chat.jid}'
          .toLowerCase()
          .contains(query);
    }).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.76,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Text(
                'Forward to',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search users, groups and channels',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: chats.isEmpty
                  ? const Center(child: Text('No matching conversation found.'))
                  : ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (_, index) {
                        final chat = chats[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              chat.type == 'chat'
                                  ? Icons.person_rounded
                                  : Icons.groups_rounded,
                            ),
                          ),
                          title: Text(chat.name),
                          subtitle: Text(chat.designation),
                          onTap: () => Navigator.pop(context, chat),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSend,
    required this.onSendLater,
    required this.onVoiceRecord,
    required this.isRecordingVoice,
    required this.onAttach,
    required this.isUploading,
    required this.uploadProgress,
    required this.showEmojiPicker,
    required this.onEmojiToggle,
    required this.onEmojiSelected,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onSendLater;
  final VoidCallback onVoiceRecord;
  final bool isRecordingVoice;
  final VoidCallback onAttach;
  final bool isUploading;
  final double uploadProgress;
  final bool showEmojiPicker;
  final VoidCallback onEmojiToggle;
  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUploading)
              LinearProgressIndicator(
                value: uploadProgress <= 0 ? null : uploadProgress,
                minHeight: 3,
              ),
            Container(
              color: Theme.of(context).colorScheme.surfaceContainer,
              padding: EdgeInsets.fromLTRB(
                10,
                7,
                10,
                MediaQuery.paddingOf(context).bottom + 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x120C2748),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Emoji',
                            onPressed: onEmojiToggle,
                            icon: const Icon(
                              Icons.sentiment_satisfied_alt_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                          Expanded(
                            child: Focus(
                              onKeyEvent: (_, event) {
                                if (event is! KeyDownEvent) {
                                  return KeyEventResult.ignored;
                                }
                                final isEnter =
                                    event.logicalKey ==
                                        LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.numpadEnter;
                                if (!isEnter) {
                                  return KeyEventResult.ignored;
                                }
                                final insertNewLine =
                                    HardwareKeyboard
                                        .instance
                                        .isControlPressed ||
                                    HardwareKeyboard.instance.isMetaPressed;
                                if (insertNewLine) {
                                  final value = controller.value;
                                  final selection = value.selection.isValid
                                      ? value.selection
                                      : TextSelection.collapsed(
                                          offset: value.text.length,
                                        );
                                  final text = value.text.replaceRange(
                                    selection.start,
                                    selection.end,
                                    '\n',
                                  );
                                  controller.value = TextEditingValue(
                                    text: text,
                                    selection: TextSelection.collapsed(
                                      offset: selection.start + 1,
                                    ),
                                  );
                                  return KeyEventResult.handled;
                                }
                                if (hasText) {
                                  onSend();
                                }
                                return KeyEventResult.handled;
                              },
                              child: TextField(
                                key: const Key('messageField'),
                                controller: controller,
                                minLines: 1,
                                maxLines: 5,
                                keyboardType: TextInputType.multiline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Schedule message',
                            onPressed: hasText ? onSendLater : null,
                            icon: Icon(
                              Icons.schedule_send_rounded,
                              color: hasText
                                  ? AppColors.muted
                                  : AppColors.muted.withOpacity(0.45),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Attach',
                            onPressed: isUploading ? null : onAttach,
                            icon: isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.attach_file_rounded,
                                    color: AppColors.muted,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: onVoiceRecord,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Icon(
                          isRecordingVoice
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: hasText
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.45),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      key: const Key('sendButton'),
                      onTap: hasText ? onSend : null,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 50,
                        height: 50,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showEmojiPicker)
              MojibakeEmojiPicker(onEmojiSelected: onEmojiSelected),
          ],
        );
      },
    );
  }
}

class _SelectionToolbarAction extends StatelessWidget {
  const _SelectionToolbarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? const Color(0xFFB3261E)
        : AppColors.primary;
    final background = destructive
        ? const Color(0x11B3261E)
        : AppColors.primary.withValues(alpha: 0.08);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: foreground),
        label: Text(label),
        style: FilledButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          disabledForegroundColor: AppColors.muted,
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

String _mimeTypeForFile(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
