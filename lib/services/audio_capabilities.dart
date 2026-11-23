import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Central place for audio features that depend on the native audio stack.
///
/// The settings screen uses these flags so a toggle is never presented as if
/// it works when the current engine cannot honour it.
class AudioCapabilities {
  const AudioCapabilities._();

  /// Set by `main()` after the libmpv backend has been initialized.
  ///
  /// Tests never run `main()`, so `flutter test` keeps exercising the
  /// `just_audio` path even on a Windows host.
  static bool _desktopDspActive = false;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isDesktop => isWindows || isLinux || isMacOS;

  static bool get isMobile => isAndroid || isIOS;

  /// Returns whether the UI should behave as desktop (e.g. desktop OS or wide screen)
  /// rather than a phone.
  static bool isDesktopUi([BuildContext? context]) {
    if (isDesktop) return true;
    if (isMobile) return false;
    if (context != null) {
      final width = MediaQuery.maybeOf(context)?.size.width;
      if (width != null) return width >= 750;
    }
    return false;
  }

  /// True when the app is running on Windows with the libmpv engine active.
  /// Used for DSP push logic — NOT for UI lock/unlock decisions.
  static bool get desktopDspActive => isWindows && _desktopDspActive;

  static void activateDesktopDsp() {
    _desktopDspActive = true;
  }

  // ─── UI capability flags ───────────────────────────────────────────────────
  // These are used by settings_view.dart to decide whether a toggle is enabled.
  // On Windows we always show controls as enabled regardless of whether the
  // libmpv runtime flag has been set yet — the DSP push happens at playback
  // time, not at settings display time.

  /// Whether the current backend can apply the five-band EQ curve.
  /// Android: AndroidEqualizer. Windows: libmpv equalizer filter.
  static bool get supportsEqualizer => isAndroid || isWindows;

  /// The original `just_audio`/Android effects path. Kept separate from
  /// [supportsEqualizer] so the Android MethodChannel service is never used
  /// just because the desktop DSP exists.
  static bool get supportsAndroidEqualizer => isAndroid;

  /// Android has `AndroidLoudnessEnhancer`; Windows uses `dynaudnorm`.
  static bool get supportsLoudnessNormalization => isAndroid || isWindows;

  /// Android downmixes through the patched `just_audio` ExoPlayer sink
  /// (`packages/just_audio`); Windows uses the libmpv FFmpeg `pan` filter.
  /// Other platforms (iOS, Linux, desktop `just_audio` fallback, web) have no
  /// channel-mapping stage.
  static bool get supportsMonoAudio => isAndroid || isWindows;

  /// The Windows engine overlaps two players for a real crossfade.
  static bool get supportsOverlappingCrossfade => isWindows;

  /// The Windows engine preloads the next track and hands off without an
  /// added silent gap.
  static bool get supportsTrueGapless => isWindows;

  /// Cellular download rules apply on mobile devices, desktop (Windows, Linux, macOS),
  /// and web browser where mobile hotspots, tethering, or cellular modems can be used.
  static bool get supportsCellularDataPolicy => isMobile || isDesktop || kIsWeb;
}
