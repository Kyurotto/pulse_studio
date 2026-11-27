import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_media_session/flutter_media_session.dart';

import '../controllers/music_player_controller.dart';

/// Publishes the current track to the operating system's media hub.
///
/// * **Windows** — opens a System Media Transport Controls (SMTC) session.
///   That single session is what Windows 11 renders in the Quick Settings
///   media card (the Wi-Fi / Bluetooth / Airplane panel), the volume flyout,
///   the lock screen, and in third-party now-playing readers such as Crest.
/// * **Web** — publishes through the browser Media Session API, which feeds
///   the Chrome/Edge media hub, the OS media overlay, and hardware media keys.
///
/// Android and iOS are deliberately left alone: `just_audio_background`
/// already owns the notification and lock-screen surface there.
///
/// The session is opened lazily on the first play or as soon as a saved track
/// is restored paused from the previous session (so the OS does not show an
/// idle sample track on a fresh install), stays alive while paused, and is torn
/// down when the controller is disposed.
class SystemMediaSessionService {
  SystemMediaSessionService._();

  static final SystemMediaSessionService instance =
      SystemMediaSessionService._();

  /// AUMID used by Windows to resolve the app name and icon in SMTC.
  ///
  /// For unpackaged builds the same id is attached to a Start Menu shortcut so
  /// the flyout shows "Pulse Studio" instead of "Unknown Application".
  static const String appUserModelId = 'PulseStudio.Music';
  static const String appDisplayName = 'Pulse Studio';

  /// Buttons offered to the OS. Play/pause share one SMTC toggle; next,
  /// previous and seek are wired to [MusicPlayerController].
  static final Set<MediaAction> _availableActions = <MediaAction>{
    MediaAction.play,
    MediaAction.pause,
    MediaAction.skipToNext,
    MediaAction.skipToPrevious,
    MediaAction.seekTo,
  };

  /// The OS extrapolates the progress bar from `speed`, so one push per second
  /// is plenty; media_kit emits positions ~25x more often than that.
  static const Duration _positionPushInterval = Duration(seconds: 1);

  /// A seek can move the position by more than the throttle window while
  /// paused, in which case the OS still needs an immediate update.
  static const Duration _positionJumpThreshold = Duration(seconds: 2);

  final FlutterMediaSession _session = FlutterMediaSession();

  MusicPlayerController? _controller;
  bool _listening = false;
  bool _activated = false;
  bool _identityConfigured = false;
  bool _syncingMetadata = false;
  bool _metadataPushQueued = false;

  String? _lastSongId;
  String? _lastArtwork;
  Duration? _lastDuration;
  PlaybackStatus? _lastStatus;
  Duration _lastPosition = Duration.zero;
  DateTime _lastPositionPush = DateTime.fromMillisecondsSinceEpoch(0);

  /// Artwork lookups touch the filesystem, so remember the answer per song.
  final Map<String, String?> _artworkMemo = <String, String?>{};

  /// Whether this build can publish an OS media session at all.
  ///
  /// Widget tests run on the host, where `Platform.isWindows` is true but no
  /// plugin is registered; the `FLUTTER_TEST` guard keeps them untouched.
  static bool get isSupportedPlatform {
    if (kIsWeb) return true;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isWindows;
  }

  /// Registers the Windows AUMID (and, for portable builds, the Start Menu
  /// shortcut) at launch, so SMTC can resolve "Pulse Studio" and its icon
  /// before the first track plays.
  ///
  /// No-op outside Windows; safe to call more than once.
  Future<void> initialize() => _configureIdentity();

  /// Starts mirroring [controller] into the OS media hub.
  ///
  /// Safe to call more than once: a newer controller replaces the previous
  /// one (e.g. after signing out and back in).
  Future<void> attach(MusicPlayerController controller) async {
    if (!isSupportedPlatform) return;
    detach();

    _controller = controller;
    _listening = true;
    controller.addListener(_handleControllerChanged);
    controller.positionListenable.addListener(_handlePositionChanged);

    await _configureIdentity();
    _handleControllerChanged();
  }

  /// Stops mirroring and removes the OS session, if one was opened.
  void detach() {
    final controller = _controller;
    if (_listening && controller != null) {
      controller.removeListener(_handleControllerChanged);
      controller.positionListenable.removeListener(_handlePositionChanged);
    }
    _listening = false;
    _controller = null;
    _artworkMemo.clear();
    _resetDedupe();

    if (!_activated) return;
    _activated = false;
    _session.clearActionHandler();
    unawaited(_session.deactivate().catchError((_) {}));
  }

  /// Maps the app's repeat state onto the OS-facing one.
  @visibleForTesting
  static MediaRepeatMode repeatModeFor(PlaybackRepeatMode mode) {
    switch (mode) {
      case PlaybackRepeatMode.one:
        return MediaRepeatMode.one;
      case PlaybackRepeatMode.all:
        return MediaRepeatMode.all;
      case PlaybackRepeatMode.off:
        return MediaRepeatMode.none;
    }
  }

  /// Registers the AUMID and, for portable builds, the Start Menu shortcut
  /// Windows needs to resolve the display name and icon.
  Future<void> _configureIdentity() async {
    if (_identityConfigured || kIsWeb || !Platform.isWindows) return;
    _identityConfigured = true;
    try {
      await _session.setAppId(
        appUserModelId,
        displayName: appDisplayName,
        iconPath: Platform.resolvedExecutable,
      );
    } catch (error) {
      debugPrint('[SystemMediaSession] identity setup failed: $error');
    }
  }

  Future<void> _activate() async {
    if (_activated) return;
    _activated = true;
    try {
      await _session.activate();
      await FlutterMediaSessionPlatform.instance.updateAvailableActions(
        _availableActions,
      );
      _session.setActionHandler(
        onPlay: () => _controller?.play(),
        onPause: () => _controller?.pause(),
        onSkipToNext: () => _controller?.next(),
        onSkipToPrevious: () => _controller?.previous(),
        onStop: () => _controller?.pause(),
        onSeekTo: (position) => _controller?.seekTo(position),
      );
    } catch (error) {
      _activated = false;
      debugPrint('[SystemMediaSession] activate failed: $error');
      return;
    }

    final controller = _controller;
    if (controller == null) return;
    await _pushMetadata(controller);
    await _pushPlaybackState(controller, force: true);
  }

  /// Whether [controller] has state that should be published to the OS media
  /// hub right now: either actively playing or restored paused from a previous
  /// session.
  @visibleForTesting
  static bool shouldActivateFor(MusicPlayerController controller) =>
      controller.isPlaying || controller.hasRestoredPlaybackState;

  void _handleControllerChanged() {
    final controller = _controller;
    if (controller == null || !_listening) return;

    if (!_activated) {
      // Publish once playback starts, or immediately when a saved track is
      // restored paused from the previous session so OS media controls appear
      // right away without advertising sample tracks on a fresh install.
      if (shouldActivateFor(controller)) unawaited(_activate());
      return;
    }

    final song = controller.currentSong;
    if (song == null) return;

    if (_lastSongId != song.id ||
        _lastDuration != controller.currentDuration) {
      unawaited(_pushMetadata(controller));
    }
    unawaited(_pushPlaybackState(controller));
  }

  void _handlePositionChanged() {
    final controller = _controller;
    if (controller == null || !_activated || !controller.isPlaying) return;
    unawaited(_pushPlaybackState(controller));
  }

  Future<void> _pushMetadata(MusicPlayerController controller) async {
    if (!_activated) return;
    if (_syncingMetadata) {
      // A rapid skip landed while the previous artwork lookup was running;
      // replay the push once it finishes so the OS never keeps stale metadata.
      _metadataPushQueued = true;
      return;
    }
    final song = controller.currentSong;
    if (song == null) return;

    _syncingMetadata = true;
    try {
      final artwork = await _artworkFor(controller, song.id);
      if (!_activated || !identical(_controller, controller)) return;
      if (controller.currentSong?.id != song.id) {
        // The user skipped again while the artwork lookup ran; replay with the
        // track that is actually current instead of publishing stale metadata.
        _metadataPushQueued = true;
        return;
      }

      final duration = controller.currentDuration;
      if (_lastSongId == song.id &&
          _lastArtwork == artwork &&
          _lastDuration == duration) {
        return;
      }

      _lastSongId = song.id;
      _lastArtwork = artwork;
      _lastDuration = duration;

      await FlutterMediaSessionPlatform.instance.updateMetadata(
        MediaMetadata(
          title: song.title,
          artist: song.artist,
          album: song.album.isNotEmpty ? song.album : appDisplayName,
          artworkUri: artwork,
          duration: duration > Duration.zero ? duration : song.duration,
        ),
      );
    } catch (error) {
      debugPrint('[SystemMediaSession] metadata update failed: $error');
    } finally {
      _syncingMetadata = false;
      if (_metadataPushQueued) {
        _metadataPushQueued = false;
        if (_activated && identical(_controller, controller)) {
          unawaited(_pushMetadata(controller));
        }
      }
    }
  }

  Future<void> _pushPlaybackState(
    MusicPlayerController controller, {
    bool force = false,
  }) async {
    if (!_activated) return;
    final song = controller.currentSong;
    if (song == null) return;

    final status = controller.isPlaying
        ? PlaybackStatus.playing
        : PlaybackStatus.paused;
    final position = controller.currentPosition;
    final now = DateTime.now();

    final statusChanged = _lastStatus != status;
    final songChanged = _lastSongId != song.id;
    final jumped =
        (position - _lastPosition).abs() > _positionJumpThreshold;

    if (!force && !statusChanged && !songChanged && !jumped) {
      if (!controller.isPlaying) return;
      if (now.difference(_lastPositionPush) < _positionPushInterval) return;
    }

    _lastStatus = status;
    _lastPosition = position;
    _lastPositionPush = now;

    try {
      await FlutterMediaSessionPlatform.instance.updatePlaybackState(
        PlaybackState(
          status: status,
          position: position,
          speed: 1.0,
          // The engine does not expose a buffered position; mirroring the
          // playhead keeps the progress bar honest instead of showing a
          // permanently full buffer.
          bufferedPosition: position,
          repeatMode: repeatModeFor(controller.repeatMode),
          shuffleModeEnabled: controller.isShuffle,
        ),
      );
    } catch (error) {
      debugPrint('[SystemMediaSession] playback state update failed: $error');
    }
  }

  Future<String?> _artworkFor(
    MusicPlayerController controller,
    String songId,
  ) async {
    if (_artworkMemo.containsKey(songId)) return _artworkMemo[songId];
    final song = controller.currentSong;
    if (song == null || song.id != songId) return null;
    final artwork = await controller.systemMediaArtworkFor(song);
    _artworkMemo[songId] = artwork;
    return artwork;
  }

  void _resetDedupe() {
    _metadataPushQueued = false;
    _lastSongId = null;
    _lastArtwork = null;
    _lastDuration = null;
    _lastStatus = null;
    _lastPosition = Duration.zero;
    _lastPositionPush = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
