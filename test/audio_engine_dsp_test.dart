import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/services/audio_capabilities.dart';
import 'package:music/services/playback_engine.dart';

void main() {
  group('buildDspFilterGraph', () {
    test('clears the chain when every stage is off', () {
      expect(
        buildDspFilterGraph(
          const DspSettings(equalizerEnabled: false, normalize: false),
        ),
        isEmpty,
      );
      expect(
        buildDspFilterGraph(const DspSettings(bands: [0, 0, 0, 0, 0])),
        isEmpty,
      );
    });

    test('emits one octave equalizer band per non-flat frequency', () {
      final graph = buildDspFilterGraph(
        const DspSettings(bands: [6, -3, 0, 1.5, 4]),
      );

      expect(graph, startsWith('lavfi=['));
      expect(graph, endsWith(']'));
      expect(graph, contains('equalizer=f=60:t=o:width=1:g=6.00'));
      expect(graph, contains('equalizer=f=230:t=o:width=1:g=-3.00'));
      expect(graph, isNot(contains('f=910')));
      expect(graph, contains('equalizer=f=3600:t=o:width=1:g=1.50'));
      expect(graph, contains('equalizer=f=14000:t=o:width=1:g=4.00'));
    });

    test('clamps out-of-range gains instead of passing them to libmpv', () {
      final graph = buildDspFilterGraph(
        const DspSettings(bands: [40, -40, 0, 0, 0]),
      );

      expect(graph, contains('f=60:t=o:width=1:g=12.00'));
      expect(graph, contains('f=230:t=o:width=1:g=-12.00'));
      expect(graph, isNot(contains('g=40')));
    });

    test('appends normalization and mono downmix after the equalizer', () {
      final graph = buildDspFilterGraph(
        const DspSettings(bands: [3, 0, 0, 0, 0], normalize: true, mono: true),
      );

      final eqIndex = graph.indexOf('equalizer=');
      final normalizeIndex = graph.indexOf('dynaudnorm=');
      final monoIndex = graph.indexOf('pan=stereo');
      expect(eqIndex, greaterThanOrEqualTo(0));
      expect(normalizeIndex, greaterThan(eqIndex));
      expect(monoIndex, greaterThan(normalizeIndex));
      expect(graph, contains('pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1'));
    });

    test('mono and normalization work without an equalizer curve', () {
      final graph = buildDspFilterGraph(
        const DspSettings(equalizerEnabled: false, normalize: true, mono: true),
      );

      expect(graph, isNot(contains('equalizer=')));
      expect(graph, contains('dynaudnorm='));
      expect(graph, contains('pan=stereo'));
    });
  });

  group('AudioCapabilities', () {
    test('desktop capabilities check on windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(AudioCapabilities.supportsEqualizer, isTrue);
      expect(AudioCapabilities.supportsLoudnessNormalization, isTrue);
      expect(AudioCapabilities.supportsMonoAudio, isTrue);
      expect(AudioCapabilities.supportsCellularDataPolicy, isTrue);
    });

    test('android supports mono audio through the patched engine', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(AudioCapabilities.isAndroid, isTrue);
      expect(AudioCapabilities.supportsMonoAudio, isTrue);
    });
  });
}
