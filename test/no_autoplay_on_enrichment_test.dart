import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/models/song_model.dart';
import 'package:music/services/track_enrichment_service.dart';

Song _importedSong({String id = 'spotify-autoplay-regression'}) {
  return Song(
    id: id,
    title: 'Background Resolved Track',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: const Duration(minutes: 3),
    genre: 'Spotify',
    imageUrl: '',
    gradientColors: const [Colors.blue, Colors.purple],
    plays: '',
    lyrics: const [],
    audioUrl: '',
    isPreview: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Background enrichment must not autoplay', () {
    test(
      'resolving the queue cursor before the user presses play stays paused',
      () {
        final controller = MusicPlayerController();
        addTearDown(controller.dispose);

        final song = _importedSong();
        controller.addSong(song);

        // The queue cursor points at the first saved song on startup, but the
        // user has not started playback yet.
        expect(controller.currentSong?.id, song.id);
        expect(controller.isPlaying, isFalse);

        final changed = controller.applyEnrichmentForTesting(
          song,
          const TrackEnrichment(
            previewUrl: 'https://example.com/resolved-full-track.m4a',
            isFullTrack: true,
          ),
        );

        expect(changed, isTrue);
        expect(song.audioUrl, 'https://example.com/resolved-full-track.m4a');
        expect(
          controller.isPlaying,
          isFalse,
          reason: 'Background enrichment must not start playback on its own',
        );
      },
    );

    test('enrichment still hot-swaps while user playback is active', () {
      final controller = MusicPlayerController();
      addTearDown(controller.dispose);

      final song = _importedSong(id: 'spotify-hot-swap');
      song.audioUrl = 'https://example.com/preview.m4a';
      song.isPreview = true;
      controller.addSong(song);
      controller.playSong(song);

      expect(controller.isPlaying, isTrue);

      final changed = controller.applyEnrichmentForTesting(
        song,
        const TrackEnrichment(
          previewUrl: 'https://example.com/full-track.m4a',
          isFullTrack: true,
        ),
      );

      expect(changed, isTrue);
      expect(song.audioUrl, 'https://example.com/full-track.m4a');
      expect(
        controller.isPlaying,
        isTrue,
        reason: 'An active playback session keeps playing after a hot-swap',
      );
    });
  });
}
