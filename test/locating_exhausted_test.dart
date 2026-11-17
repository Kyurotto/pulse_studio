import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/data/local_database.dart';
import 'package:music/models/song_model.dart';
import 'package:music/services/track_enrichment_service.dart';

Song _silentRadioSong(String id) => Song(
      id: id,
      title: 'Nowhere Song',
      artist: 'Nobody',
      album: 'Nowhere',
      duration: const Duration(minutes: 3),
      genre: 'OPM',
      imageUrl: '',
      gradientColors: const [],
      plays: '',
      lyrics: const [],
      audioUrl: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NOT FOUND survives fast-locate passes instead of resetting to LOCATING',
      () {
    final controller = MusicPlayerController();
    final song = _silentRadioSong('radio-dyn-1586658613');

    // Three failed full-track lookups: the row is allowed to stop claiming it
    // is still locating.
    controller.registerFullTrackFailureForTesting(song.id, times: 3);
    expect(controller.isLocatingExhausted(song.id), isTrue);

    // Every screen-open fast-locate pass used to clear the counter, so the
    // badge fell back to LOCATING forever.
    controller.fastLocateRadioSongs([song]);
    controller.fastLocateDiscoverySongs([song]);
    controller.fastLocateImportedSongs(songs: [song]);

    expect(controller.isLocatingExhausted(song.id), isTrue);

    controller.dispose();
  });

  test('a single failure keeps the row on LOCATING', () {
    final controller = MusicPlayerController();
    final song = _silentRadioSong('spotify-slow-1');

    controller.registerFullTrackFailureForTesting(song.id);
    expect(controller.isLocatingExhausted(song.id), isFalse);

    controller.registerFullTrackFailureForTesting(song.id, times: 2);
    expect(controller.isLocatingExhausted(song.id), isTrue);

    controller.dispose();
  });

  test('playback recovery is bounded instead of looping on a broken source',
      () {
    expect(
      MusicPlayerController.shouldAbandonPlaybackForTesting(0),
      isFalse,
    );
    expect(
      MusicPlayerController.shouldAbandonPlaybackForTesting(1),
      isFalse,
    );
    // Second consecutive load failure: stop hot-swapping the same broken URL.
    expect(
      MusicPlayerController.shouldAbandonPlaybackForTesting(2),
      isTrue,
    );
    expect(
      MusicPlayerController.shouldAbandonPlaybackForTesting(9),
      isTrue,
    );
  });

  test('a live googlevideo stream is not re-enriched on every play attempt',
      () {
    final future = DateTime.now()
        .add(const Duration(hours: 2))
        .millisecondsSinceEpoch ~/
        1000;
    final song = _silentRadioSong('spotify-hotswap-1')
      ..audioUrl =
          'https://rr1---sn-test.googlevideo.com/videoplayback?expire=$future&sig=abc'
      ..isPreview = false;

    // The URL is still valid: no fresh resolve, so no hot-swap can be queued.
    expect(MusicPlayerController.needsFreshStreamForTesting(song), isFalse);

    final expired = DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch ~/
        1000;
    song.audioUrl =
        'https://rr1---sn-test.googlevideo.com/videoplayback?expire=$expired&sig=abc';
    expect(MusicPlayerController.needsFreshStreamForTesting(song), isTrue);
  });

  test('re-applying an identical resolved stream does not queue a hot-swap',
      () {
    const url = 'https://rr1---sn-test.googlevideo.com/videoplayback?sig=abc';

    expect(
      MusicPlayerController.audioSourceChangedForTesting(
        previousAudioUrl: url,
        previousWasPreview: false,
        newAudioUrl: url,
        newIsPreview: false,
      ),
      isFalse,
    );

    expect(
      MusicPlayerController.audioSourceChangedForTesting(
        previousAudioUrl: url,
        previousWasPreview: false,
        newAudioUrl: '$url&refresh=1',
        newIsPreview: false,
      ),
      isTrue,
    );

    // Preview promoted to the same-looking full-track URL still reloads.
    expect(
      MusicPlayerController.audioSourceChangedForTesting(
        previousAudioUrl: url,
        previousWasPreview: true,
        newAudioUrl: url,
        newIsPreview: false,
      ),
      isTrue,
    );
  });

  test('the same downloaded file never queues a hot-swap', () {
    const file =
        '/data/user/0/com.example.music/app_flutter/offline_downloads/'
        'spotify-6zdryckXPbIeQE5npNqvNp.m4a';

    // Exactly the bug seen on device: the enrichment applied the same cached
    // path while only the preview flag flipped, and the player restarted the
    // downloaded track four times in a row.
    expect(
      MusicPlayerController.audioSourceChangedForTesting(
        previousAudioUrl: file,
        previousWasPreview: true,
        newAudioUrl: file,
        newIsPreview: false,
      ),
      isFalse,
    );

    // The same file reported through an equivalent path is still the same
    // audio, so it must not reload either.
    const otherDir =
        '/data/user/0/com.example.music/app_flutter/streaming_cache/'
        'spotify-6zdryckXPbIeQE5npNqvNp.m4a';
    expect(
      MusicPlayerController.audioSourceChangedForTesting(
        previousAudioUrl: file,
        previousWasPreview: false,
        newAudioUrl: otherDir,
        newIsPreview: false,
      ),
      isFalse,
    );

    // A different file, or a switch from a file to a stream, is a real change.
    expect(
      MusicPlayerController.audioSourceChangedForTesting(
        previousAudioUrl: file,
        previousWasPreview: false,
        newAudioUrl:
            '/data/user/0/com.example.music/app_flutter/offline_downloads/'
            'other-song.m4a',
        newIsPreview: false,
      ),
      isTrue,
    );
    expect(
      MusicPlayerController.audioSourceChangedForTesting(
        previousAudioUrl: file,
        previousWasPreview: false,
        newAudioUrl: 'https://example.com/stream.m4a',
        newIsPreview: false,
      ),
      isTrue,
    );
  });

  test('a remote enrichment never replaces a completed downloaded file',
      () async {
    final controller = MusicPlayerController();
    final dir = await Directory.systemTemp.createTemp('pulse-local-audio');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = File('${dir.path}/spotify-local.m4a');
    await file.writeAsBytes(List<int>.filled(64 * 1024, 0));

    final song = Song(
      id: 'spotify-local',
      title: 'Local Track',
      artist: 'Local Artist',
      album: 'Local Album',
      duration: const Duration(minutes: 3),
      genre: 'OPM',
      imageUrl: '',
      gradientColors: const [],
      plays: '',
      lyrics: const [],
      audioUrl: file.path,
    );

    controller.applyEnrichmentForTesting(
      song,
      TrackEnrichment(
        previewUrl: 'https://example.com/stream.m4a',
        isFullTrack: true,
        isYouTube: false,
      ),
    );

    expect(song.audioUrl, file.path);
    expect(song.isPreview, isFalse);
  });

  test('a dead remote stream stays blocked across enrichment passes and restarts',
      () async {
    final controller = MusicPlayerController();
    await controller.abandonRemoteStreamForTesting('radio-dyn-dead-stream');

    // Background passes must not retry it: this is what kept flipping the row
    // from NOT FOUND back to FULL TRACK with the same 403 googlevideo URL.
    expect(
      await controller.isAutoRetryBlockedForTesting('radio-dyn-dead-stream'),
      isTrue,
    );

    // A fresh controller models the next app launch. The marker is persisted
    // in app_settings, so the row does not start over as LOCATING.
    final restarted = MusicPlayerController();
    expect(
      await restarted.isAutoRetryBlockedForTesting('radio-dyn-dead-stream'),
      isTrue,
    );
  });

  test('manual retry clears the dead-stream marker', () async {
    final controller = MusicPlayerController();
    await controller.abandonRemoteStreamForTesting('radio-dyn-dead-stream-2');
    expect(
      await controller.isAutoRetryBlockedForTesting('radio-dyn-dead-stream-2'),
      isTrue,
    );

    controller.resetEnrichmentBackoff('radio-dyn-dead-stream-2');

    expect(
      await controller.isAutoRetryBlockedForTesting('radio-dyn-dead-stream-2'),
      isFalse,
    );
  });

  test('an exhausted row stays NOT FOUND after an app restart', () async {
    const id = 'radio-dyn-exhausted-restart';
    await LocalDatabase.instance.saveSetting(
      'locating_failed_$id',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );

    final restarted = MusicPlayerController();
    expect(
      await restarted.isLocatingExhaustedAfterLoadForTesting(id),
      isTrue,
    );

    restarted.resetEnrichmentBackoff(id);
    expect(
      await restarted.isLocatingExhaustedAfterLoadForTesting(id),
      isFalse,
    );
  });

  test('playback recovery does not resurrect a quarantined video id', () async {
    final controller = MusicPlayerController();
    final song = _silentRadioSong('radio-dyn-1862232298')
      ..youtubeVideoId = 'dSMhsTaLCHs';
    await controller.abandonRemoteStreamForTesting(song.id);

    // The startup backfill calls this recovery path. It used to fall through
    // to a direct YouTube lookup after enrichment was blocked, attaching a
    // fresh googlevideo signature that answered 403 again and flipping the row
    // back to FULL TRACK.
    await controller.recoverAudioForTesting(song);

    expect(song.hasAudio, isFalse);
    expect(song.isPreview, isFalse);
    expect(
      await controller.isAutoRetryBlockedForTesting(song.id),
      isTrue,
    );
  });
}
