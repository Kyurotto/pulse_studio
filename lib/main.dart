import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'data/local_database.dart';
import 'services/audio_capabilities.dart';
import 'services/display_rate_service.dart';
import 'services/radio_discovery_service.dart';
import 'theme/app_theme.dart';
import 'views/auth_gate.dart';
import 'views/music_dashboard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows: initialize the libmpv-backed engine before the player controller
  // is built. Widget tests never run main(), so they keep using just_audio.
  if (!kIsWeb && Platform.isWindows) {
    try {
      MediaKit.ensureInitialized();
      AudioCapabilities.activateDesktopDsp();
    } catch (e) {
      debugPrint('[MusicApp] media_kit initialization failed: $e');
    }
  }

  // Configure the shared AudioSession BEFORE any AudioPlayer is constructed.
  // MusicPlayerController creates its AudioPlayer as a field initializer, which
  // runs ahead of the constructor body — so configuring the session inside the
  // controller left ExoPlayer without an activated session, and imported
  // Spotify tracks started muted on Android. Doing it here guarantees the
  // session is configured (and focus-requestable) before playback begins.
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('[MusicApp] AudioSession pre-configure failed: $e');
  }

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.music.app.channel.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('[MusicApp] JustAudioBackground init failed: $e');
  }

  // On desktop platforms, initialise the FFI-based SQLite implementation
  // before any database access so the native library is loaded in time.
  // On web, use sqflite_common_ffi_web with WebAssembly SQLite.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  try {
    await LocalDatabase.instance.initialize();
  } catch (e) {
    debugPrint('[MusicApp] LocalDatabase initialization error: $e');
  }
  await AppTheme.init();
  DisplayRateService.instance.initialize();
  try {
    await RadioDiscoveryService.instance.loadCachedRadios();
  } catch (_) {}
  // Initialize Firebase on every platform so Google OAuth can
  // return the real accurate profile. Guarded: local auth still works
  // when Firebase options are missing (e.g. desktop without config).
  try {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Firebase.initializeApp();
    } else if (kIsWeb ||
        Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[MusicApp] Firebase not configured, using local auth: $e');
  }
  runApp(const MusicApp(firebaseEnabled: true));
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key, this.firebaseEnabled = false});

  final bool firebaseEnabled;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Pulse Studio',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          // Always go through AuthGate when enabled (local session works on every platform).
          // When disabled (e.g. in tests), mount MusicDashboardView directly.
          home: firebaseEnabled ? const AuthGate() : const MusicDashboardView(),
        );
      },
    );
  }
}
