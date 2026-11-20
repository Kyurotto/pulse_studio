import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'playback_engine.dart';

/// Windows audio backend built on libmpv (`media_kit`).
///
/// Two players are kept alive so the next track can be loaded while the
/// current one is still audible. Around the end of a track the engine starts
/// the idle player and ramps both volumes, which gives overlapping crossfades
/// and a gapless-enough handoff without a silent gap.
///
/// Every controller-facing stream reports the *active* player only, so the
/// queue/UI code never sees the outgoing track's position after a handoff.
class MediaKitPlaybackEngine extends PlaybackEngine {
  MediaKitPlaybackEngine({double initialVolume = 0.8})
    : _baseVolume = initialVolume.clamp(0.0, 1.0).toDouble() {
    mk.MediaKit.ensureInitialized();
    for (var i = 0; i < 2; i++) {
      _players.add(mk.Player());
    }
    _bindStreams();
  }

  final List<mk.Player> _players = <mk.Player>[];
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<PlayerState> _stateCtrl =
      StreamController<PlayerState>.broadcast();
  final StreamController<PlaybackEvent> _errorCtrl =
      StreamController<PlaybackEvent>.broadcast();
  final StreamController<EngineHandoff> _handoffCtrl =
      StreamController<EngineHandoff>.broadcast();

  int _activeIndex = 0;
  double _baseVolume;
  bool _disposed = false;

  DspSettings? _pendingDsp;
  bool _pushingDsp = false;
  bool _gapless = true;
  double _crossfadeSeconds = 0;

  EnginePreload? _preloaded;
  bool _preloadedReady = false;
  int _preloadGeneration = 0;
  int _preloadTargetIndex = -1;
  EnginePreload? _queuedPreload;

  _HandoffState? _handoff;
  bool _completionEmitted = false;
  Duration _lastPosition = Duration.zero;
  DateTime? _seekedAt;

  mk.Player get _activePlayer => _players[_activeIndex];
  mk.Player get _idlePlayer => _players[1 - _activeIndex];

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  @override
  Stream<PlayerState> get playerStateStream => _stateCtrl.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _errorCtrl.stream;

  @override
  Stream<int?> get androidAudioSessionIdStream => const Stream<int?>.empty();

  @override
  Stream<EngineHandoff> get handoffStream => _handoffCtrl.stream;

  @override
  bool get supportsNativeDsp => true;

  @override
  bool get playing => _activePlayer.state.playing;

  @override
  double get volume => _baseVolume;

  @override
  Duration? get duration {
    final value = _activePlayer.state.duration;
    return value > Duration.zero ? value : null;
  }

  @override
  PlayerState get playerState =>
      PlayerState(_activePlayer.state.playing, _processingState(_activePlayer));

  Duration get _overlapDuration {
    if (!_gapless) return Duration.zero;
    if (_crossfadeSeconds > 0) {
      return Duration(milliseconds: (_crossfadeSeconds * 1000).round());
    }
    // Gapless without an explicit crossfade still overlaps by a hair so the
    // two players never leave an audible hole between tracks.
    return const Duration(milliseconds: 180);
  }

  void _bindStreams() {
    for (final player in _players) {
      _subscriptions.add(
        player.stream.position.listen((position) {
          _handlePosition(player, position);
        }),
      );
      _subscriptions.add(
        player.stream.duration.listen((value) {
          if (_disposed || !identical(player, _activePlayer)) return;
          if (value > Duration.zero) _durationCtrl.add(value);
        }),
      );
      _subscriptions.add(
        player.stream.playing.listen((_) => _emitStateIfActive(player)),
      );
      _subscriptions.add(
        player.stream.buffering.listen((_) => _emitStateIfActive(player)),
      );
      _subscriptions.add(
        player.stream.completed.listen((completed) {
          _handleCompleted(player, completed);
        }),
      );
      _subscriptions.add(
        player.stream.error.listen((error) {
          if (_disposed) return;
          final msg = error.toString().toLowerCase();
          // Non-fatal DSP filter initialization errors should never abort media playback!
          if (msg.contains('filter') || msg.contains('af')) {
            debugPrint(
              '[MediaKitPlaybackEngine] Non-fatal audio filter error ignored: $error',
            );
            final dynamic platform = player.platform;
            if (platform != null) {
              unawaited(
                platform.command(<String>['af', 'clr']).catchError((_) {}),
              );
            }
            return;
          }
          _errorCtrl.addError(error);
        }),
      );
    }
  }

  void _handlePosition(mk.Player player, Duration position) {
    if (_disposed || !identical(player, _activePlayer)) return;
    _positionCtrl.add(position);

    final delta = position - _lastPosition;
    _lastPosition = position;

    if (_handoff != null || player.state.completed) return;
    if (!_gapless || !_preloadedReady || _preloaded == null) return;
    if (!player.state.playing) return;

    // Do not crossfade immediately after the user seeks into the ending —
    // they asked to hear that part, not to skip it.
    final seekedAt = _seekedAt;
    if (seekedAt != null &&
        DateTime.now().difference(seekedAt) < const Duration(seconds: 2)) {
      return;
    }

    final total = player.state.duration;
    if (total <= Duration.zero) return;

    // A seek (either direction) must not be mistaken for normal playback
    // reaching the transition window.
    if (delta < -const Duration(milliseconds: 500) ||
        delta > const Duration(seconds: 3)) {
      return;
    }

    final overlap = _overlapDuration;
    if (overlap <= Duration.zero) return;
    final remaining = total - position;
    if (remaining <= Duration.zero || remaining > overlap) return;
    unawaited(_beginHandoff(remaining < overlap ? remaining : overlap));
  }

  void _handleCompleted(mk.Player player, bool completed) {
    if (_disposed || !completed || !identical(player, _activePlayer)) return;
    if (_handoff != null) return;

    // Position updates can miss the narrow end-of-track window, especially on
    // short songs. If the next track is already buffered, start it now instead
    // of reporting completion and letting the controller tear down and reload
    // the player (which would add the exact gap gapless mode is meant to hide).
    if (_gapless && _preloadedReady && _preloaded != null) {
      unawaited(_beginHandoff(const Duration(milliseconds: 80)));
      return;
    }

    if (_completionEmitted) return;
    _completionEmitted = true;
    _stateCtrl.add(PlayerState(false, ProcessingState.completed));
    _positionCtrl.add(player.state.position);
  }

  void _emitStateIfActive(mk.Player player) {
    if (_disposed || !identical(player, _activePlayer)) return;
    _emitState();
  }

  void _emitState() {
    if (_disposed) return;
    _stateCtrl.add(
      PlayerState(_activePlayer.state.playing, _processingState(_activePlayer)),
    );
  }

  ProcessingState _processingState(mk.Player player) {
    if (player.state.completed) return ProcessingState.completed;
    if (player.state.playlist.medias.isEmpty) return ProcessingState.idle;
    if (player.state.buffering) return ProcessingState.buffering;
    return ProcessingState.ready;
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    Duration? initialPosition,
    bool preload = true,
  }) async {
    await _resetPlayers();
    final uri = _sourceUri(source);
    if (uri == null) return null;

    await _activePlayer.open(
      mk.Media(uri, httpHeaders: _sourceHeaders(source)),
      play: false,
    );
    await _activePlayer.setVolume(_baseVolume * 100);

    final start = initialPosition ?? Duration.zero;
    if (start > Duration.zero) {
      await _activePlayer.seek(start);
    }
    _lastPosition = start;
    _positionCtrl.add(start);

    final loaded = _activePlayer.state.duration;
    if (loaded > Duration.zero) _durationCtrl.add(loaded);
    _emitState();
    return loaded;
  }

  @override
  Future<void> play() async {
    await _activePlayer.play();
    _emitState();
  }

  @override
  Future<void> pause() async {
    if (_handoff != null) await _collapseHandoff();
    await _activePlayer.pause();
    _emitState();
  }

  @override
  Future<void> stop() async {
    await _resetPlayers();
    _positionCtrl.add(Duration.zero);
    _emitState();
  }

  @override
  Future<void> seek(Duration position) async {
    _completionEmitted = false;
    _lastPosition = position;
    _seekedAt = DateTime.now();
    await _activePlayer.seek(position);
    _positionCtrl.add(position);
    _emitState();
  }

  @override
  Future<void> setVolume(double volume) async {
    _baseVolume = volume.clamp(0.0, 1.0).toDouble();
    // During a handoff the ramp owns both players' volumes; writing the base
    // volume here would stamp on the fade (the controller re-asserts volume
    // for a few seconds after starting a track).
    if (_handoff != null) return;
    try {
      await _activePlayer.setVolume(_baseVolume * 100);
    } catch (_) {}
    try {
      await _idlePlayer.setVolume(0);
    } catch (_) {}
  }

  @override
  Future<void> applyDsp(DspSettings settings) async {
    _pendingDsp = settings;
    // Equalizer sliders fire continuously. Coalesce updates so libmpv only
    // ever sees the newest curve instead of a backlog of stale ones.
    if (_pushingDsp) return;
    _pushingDsp = true;
    try {
      while (_pendingDsp != null) {
        final next = _pendingDsp!;
        _pendingDsp = null;
        await _pushDsp(next);
      }
    } finally {
      _pushingDsp = false;
    }
  }

  @override
  void setTransition({
    required bool gapless,
    required double crossfadeSeconds,
  }) {
    _gapless = gapless;
    _crossfadeSeconds = crossfadeSeconds.clamp(0.0, 12.0).toDouble();
    if (!_gapless) cancelPreload();
  }

  @override
  Future<void> preloadNext(EnginePreload preload) async {
    if (_disposed || !_gapless) return;
    if (_handoff != null) {
      // A transition is already in progress; load this once it settles.
      _queuedPreload = preload;
      return;
    }
    if (_preloadedReady &&
        _preloaded != null &&
        _preloaded!.songId == preload.songId &&
        _preloaded!.uri == preload.uri) {
      return;
    }

    final generation = ++_preloadGeneration;
    _preloaded = preload;
    _preloadedReady = false;
    final targetIndex = 1 - _activeIndex;
    _preloadTargetIndex = targetIndex;
    final idle = _players[targetIndex];
    try {
      await idle.setVolume(0);
      await idle.open(
        mk.Media(preload.uri, httpHeaders: preload.headers),
        play: false,
      );
      if (_disposed || generation != _preloadGeneration) return;
      await idle.setVolume(0);
      _preloadedReady = true;
      _preloadTargetIndex = -1;
    } catch (error) {
      debugPrint('[MediaKitPlaybackEngine] Preload failed: $error');
      if (generation == _preloadGeneration) {
        _preloaded = null;
        _preloadedReady = false;
        _preloadTargetIndex = -1;
      }
    }
  }

  @override
  void cancelPreload() {
    _preloadGeneration++;
    _queuedPreload = null;
    _preloaded = null;
    _preloadedReady = false;
    if (_handoff == null && !_disposed) {
      unawaited(_idlePlayer.stop().catchError((_) {}));
    }
  }

  Future<void> _beginHandoff(Duration fade) async {
    final preload = _preloaded;
    if (_handoff != null || !_preloadedReady || preload == null) return;

    final from = _activePlayer;
    final to = _idlePlayer;
    final state = _HandoffState(from: from, to: to, songId: preload.songId);
    _handoff = state;
    _preloaded = null;
    _preloadedReady = false;
    _preloadGeneration++;
    // The new track is the audible one from this moment on, so every stream
    // (position, duration, state) follows it.
    _activeIndex = 1 - _activeIndex;
    _lastPosition = Duration.zero;
    _completionEmitted = false;

    try {
      await to.setVolume(0);
      await to.play();
    } catch (error) {
      debugPrint('[MediaKitPlaybackEngine] Handoff start failed: $error');
    }

    if (_disposed || !identical(_handoff, state)) return;

    _handoffCtrl.add(EngineHandoff(songId: preload.songId, fadeDuration: fade));
    final loaded = to.state.duration;
    if (loaded > Duration.zero) _durationCtrl.add(loaded);
    _emitState();

    state.fadeTotal = fade;
    state.startedAt = DateTime.now();
    _scheduleFadeTick(state);
  }

  void _scheduleFadeTick(_HandoffState state) {
    if (_disposed || !identical(_handoff, state)) return;

    final totalMs = state.fadeTotal.inMilliseconds;
    if (totalMs <= 0) {
      unawaited(_finishHandoff(state));
      return;
    }

    final elapsed = DateTime.now().difference(state.startedAt).inMilliseconds;
    final progress = (elapsed / totalMs).clamp(0.0, 1.0);
    // Equal-power curves keep the perceived loudness steady through the
    // overlap instead of dipping in the middle like a linear crossfade.
    final fadeOut = math.cos(progress * math.pi / 2);
    final fadeIn = math.sin(progress * math.pi / 2);
    final fromVolume = (_baseVolume * 100 * fadeOut)
        .clamp(0.0, 100.0)
        .toDouble();
    final toVolume = (_baseVolume * 100 * fadeIn).clamp(0.0, 100.0).toDouble();

    unawaited(
      _applyFadeVolumes(state, fromVolume, toVolume).whenComplete(() {
        if (_disposed || !identical(_handoff, state)) return;
        if (progress >= 1.0) {
          unawaited(_finishHandoff(state));
        } else {
          state.timer = Timer(const Duration(milliseconds: 40), () {
            _scheduleFadeTick(state);
          });
        }
      }),
    );
  }

  Future<void> _applyFadeVolumes(
    _HandoffState state,
    double fromVolume,
    double toVolume,
  ) async {
    try {
      await state.from.setVolume(fromVolume);
    } catch (_) {}
    try {
      await state.to.setVolume(toVolume);
    } catch (_) {}
  }

  Future<void> _finishHandoff(_HandoffState state) async {
    if (_disposed || !identical(_handoff, state)) return;
    _handoff = null;
    state.timer?.cancel();
    try {
      await state.from.pause();
    } catch (_) {}
    try {
      await state.from.stop();
    } catch (_) {}
    try {
      await state.from.setVolume(0);
    } catch (_) {}
    try {
      await state.to.setVolume(_baseVolume * 100);
    } catch (_) {}
    _lastPosition = Duration.zero;
    _emitState();
    _drainQueuedPreload();
  }

  Future<void> _collapseHandoff() async {
    final state = _handoff;
    if (state == null) return;
    _handoff = null;
    state.timer?.cancel();
    try {
      await state.from.pause();
    } catch (_) {}
    try {
      await state.from.stop();
    } catch (_) {}
    try {
      await state.from.setVolume(0);
    } catch (_) {}
    try {
      await state.to.setVolume(_baseVolume * 100);
    } catch (_) {}
    _lastPosition = Duration.zero;
    _emitState();
    _drainQueuedPreload();
  }

  void _drainQueuedPreload() {
    final queued = _queuedPreload;
    _queuedPreload = null;
    if (queued != null) unawaited(preloadNext(queued));
  }

  Future<void> _resetPlayers() async {
    _preloadGeneration++;
    _preloaded = null;
    _preloadedReady = false;
    _queuedPreload = null;
    final handoff = _handoff;
    _handoff = null;
    handoff?.timer?.cancel();
    _completionEmitted = false;
    _lastPosition = Duration.zero;

    for (final player in _players) {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.setVolume(0);
      } catch (_) {}
    }
    // Never open the new source on a player that may still be finishing a
    // preload/`open` call from the old track.
    _activeIndex = _preloadTargetIndex == 0 ? 1 : 0;
    _preloadTargetIndex = -1;
    _seekedAt = null;
  }

  Future<void> _pushDsp(DspSettings settings) async {
    // libmpv on desktop reliably supports FFmpeg's lavfi equalizer filters.
    // Compound filters like dynaudnorm or pan fail in this libmpv audio pipeline,
    // which causes "Audio filter initialized failed!" and stalls the audio decoder.
    // Filter to the stable equalizer curve so Bass Boost / EQ presets work perfectly
    // without stalling playback.
    final graph = buildDspFilterGraph(
      DspSettings(
        equalizerEnabled: settings.equalizerEnabled,
        bands: settings.bands,
        normalize: false,
        mono: false,
      ),
    );
    for (final player in _players) {
      final dynamic platform = player.platform;
      if (platform == null) continue;
      try {
        if (graph.isEmpty) {
          await platform.command(<String>['af', 'clr']);
        } else {
          await platform.command(<String>['set', 'af', graph]);
        }
      } catch (error) {
        debugPrint('[MediaKitPlaybackEngine] DSP update failed: $error');
        try {
          await platform.command(<String>['af', 'clr']);
        } catch (_) {}
      }
    }
  }

  String? _sourceUri(AudioSource source) {
    if (source is UriAudioSource) {
      if (source.uri.isScheme('file')) {
        return source.uri.toFilePath();
      }
      return source.uri.toString();
    }
    return null;
  }

  Map<String, String>? _sourceHeaders(AudioSource source) {
    if (source is UriAudioSource) return source.headers;
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _handoff?.timer?.cancel();
    _handoff = null;
    _preloaded = null;
    _preloadedReady = false;
    _queuedPreload = null;

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    for (final player in _players) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();

    await _positionCtrl.close();
    await _durationCtrl.close();
    await _stateCtrl.close();
    await _errorCtrl.close();
    await _handoffCtrl.close();
  }
}

class _HandoffState {
  _HandoffState({required this.from, required this.to, required this.songId});

  final mk.Player from;
  final mk.Player to;
  final String songId;
  Timer? timer;
  DateTime startedAt = DateTime.now();
  Duration fadeTotal = Duration.zero;
}
