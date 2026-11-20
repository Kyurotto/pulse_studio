import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Native DSP state that the desktop engine renders into the audio pipeline.
///
/// The mobile engine has no equivalent, so [PlaybackEngine.applyDsp] is a
/// no-op there. Keeping the settings in one value object makes it impossible
/// for the equalizer, normalizer, and mono downmix to disagree about the
/// current state.
class DspSettings {
  const DspSettings({
    this.equalizerEnabled = true,
    this.bands = const <double>[0, 0, 0, 0, 0],
    this.normalize = false,
    this.mono = false,
  });

  /// Whether the five-band curve should be applied at all.
  final bool equalizerEnabled;

  /// Gain in dB for 60 Hz, 230 Hz, 910 Hz, 3.6 kHz and 14 kHz.
  final List<double> bands;

  /// Dynamic loudness normalization (`dynaudnorm`).
  final bool normalize;

  /// Downmix both channels to an equal-power mono signal.
  final bool mono;

  bool get isFlat =>
      !normalize &&
      !mono &&
      (!equalizerEnabled || bands.every((band) => band.abs() < 0.05));
}

/// Frequencies used by the app's five-band equalizer preset model.
const List<int> dspEqualizerFrequencies = <int>[60, 230, 910, 3600, 14000];

/// Builds an mpv/FFmpeg audio filter chain for [settings].
///
/// Returns an empty string when nothing needs to be applied; the engine then
/// clears the `af` property instead of installing an identity graph.
///
/// Exposed for tests: the string is the actual contract with libmpv, and a
/// typo in it silently disables the equalizer.
String buildDspFilterGraph(DspSettings settings) {
  final filters = <String>[];

  if (settings.equalizerEnabled && settings.bands.length == 5) {
    for (var i = 0; i < dspEqualizerFrequencies.length; i++) {
      final gain = settings.bands[i].clamp(-12.0, 12.0).toDouble();
      if (gain.abs() < 0.05) continue;
      // `t=o` = octave width; 1.0 octave is close to Android's 5-band layout
      // while staying well behaved at both ends of the spectrum.
      filters.add(
        'equalizer=f=${dspEqualizerFrequencies[i]}:t=o:width=1:'
        'g=${gain.toStringAsFixed(2)}',
      );
    }
  }

  if (settings.normalize) {
    // Frame length 250 ms keeps gain changes musical instead of pumping on
    // every beat. `g` is the Gaussian window size, not a gain value.
    filters.add('dynaudnorm=f=250:g=15');
  }

  if (settings.mono) {
    // Equal-power downmix: both outputs carry the average of L and R.
    filters.add('pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1');
  }

  if (filters.isEmpty) return '';
  return 'lavfi=[${filters.join(',')}]';
}

/// A track the engine may load ahead of time for a gapless/crossfade handoff.
class EnginePreload {
  const EnginePreload({required this.songId, required this.uri, this.headers});

  final String songId;
  final String uri;
  final Map<String, String>? headers;
}

/// Emitted when the engine started [songId] before the previous track ended.
class EngineHandoff {
  const EngineHandoff({required this.songId, required this.fadeDuration});

  final String songId;
  final Duration fadeDuration;
}

/// The audio backend used by [MusicPlayerController].
///
/// `just_audio` remains the mobile backend and keeps its exact behaviour. On
/// Windows, [MediaKitPlaybackEngine] implements the same surface on top of
/// libmpv so the controller can own queue/state logic while the engine owns
/// the real DSP and overlapping transitions.
abstract class PlaybackEngine {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<PlayerState> get playerStateStream;
  Stream<PlaybackEvent> get playbackEventStream;
  Stream<int?> get androidAudioSessionIdStream;

  bool get playing;
  double get volume;
  Duration? get duration;
  PlayerState get playerState;

  Future<void> setVolume(double volume);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<Duration?> setAudioSource(
    AudioSource source, {
    Duration? initialPosition,
    bool preload = true,
  });
  Future<void> dispose();

  /// True when the backend can apply the native DSP graph and overlapping
  /// transitions itself.
  bool get supportsNativeDsp => false;

  Future<void> applyDsp(DspSettings settings) async {}

  /// Applies the current gapless/automix configuration.
  void setTransition({
    required bool gapless,
    required double crossfadeSeconds,
  }) {}

  /// Loads [preload] into the idle player without making a sound.
  Future<void> preloadNext(EnginePreload preload) async {}

  /// Drops any track preloaded for the next transition.
  void cancelPreload() {}

  /// Fires as soon as the preloaded track becomes the audible/active one.
  Stream<EngineHandoff> get handoffStream =>
      const Stream<EngineHandoff>.empty();
}

/// Adapts the existing `just_audio` player to [PlaybackEngine].
///
/// This is intentionally a thin pass-through: every mobile behaviour,
/// including the Android audio-effects pipeline and notification integration,
/// stays on `just_audio`.
class JustAudioPlaybackEngine extends PlaybackEngine {
  JustAudioPlaybackEngine(this._player);

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _player.playbackEventStream;

  @override
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  @override
  bool get playing => _player.playing;

  @override
  double get volume => _player.volume;

  @override
  Duration? get duration => _player.duration;

  @override
  PlayerState get playerState => _player.playerState;

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    Duration? initialPosition,
    bool preload = true,
  }) {
    return _player.setAudioSource(
      source,
      initialPosition: initialPosition,
      preload: preload,
    );
  }

  @override
  Future<void> dispose() => _player.dispose();
}
