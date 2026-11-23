import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/data/local_database.dart';
import 'package:music/models/song_model.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Local audio cache accounting', () {
    late Directory root;
    late Directory audioDir;
    late Directory artworkDir;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('pulse_cache_test_');
      audioDir = Directory(p.join(root.path, 'offline_audio'));
      artworkDir = Directory(
        p.join(root.path, 'legacy', 'pulse_music_offline'),
      );
      await audioDir.create(recursive: true);
      await artworkDir.create(recursive: true);
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    Future<File> writeFile(Directory dir, String name, int bytes) async {
      final file = File(p.join(dir.path, name));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List<int>.filled(bytes, 0));
      return file;
    }

    test(
      'counts nested audio and artwork files across cache directories',
      () async {
        await writeFile(audioDir, 'track-a.m4a', 2048);
        await writeFile(audioDir, 'track-b.mp3', 1024);
        await writeFile(audioDir, 'track-a.jpg', 256);
        await writeFile(
          Directory(p.join(audioDir.path, 'nested')),
          'track-c.m4a',
          512,
        );
        await writeFile(artworkDir, 'legacy-track.m4a', 4096);

        final bytes = await LocalDatabase.getLocalAudioCacheSizeBytes(
          dirs: [audioDir, artworkDir],
        );

        expect(bytes, 2048 + 1024 + 256 + 512 + 4096);
      },
    );

    test('does not double count directories listed twice', () async {
      await writeFile(audioDir, 'track.m4a', 1000);

      final bytes = await LocalDatabase.getLocalAudioCacheSizeBytes(
        dirs: [audioDir, audioDir],
      );

      expect(bytes, 1000);
    });

    test('missing cache directory contributes zero bytes', () async {
      final missing = Directory(p.join(root.path, 'missing', 'offline_audio'));
      await writeFile(audioDir, 'track.m4a', 750);

      final bytes = await LocalDatabase.getLocalAudioCacheSizeBytes(
        dirs: [missing, audioDir],
      );

      expect(bytes, 750);
      expect(await missing.exists(), isFalse);
    });

    test(
      'clear deletes cached files, reports freed bytes, and bumps revision',
      () async {
        await writeFile(audioDir, 'track-a.m4a', 2048);
        await writeFile(audioDir, 'track-a.jpg', 256);
        await writeFile(
          Directory(p.join(audioDir.path, 'nested')),
          'track-b.mp3',
          1024,
        );
        await writeFile(artworkDir, 'legacy-track.m4a', 4096);
        final untouched = await writeFile(
          Directory(p.join(root.path, 'library')),
          'library.db',
          9999,
        );

        final before = LocalDatabase.audioCacheRevision.value;
        final freed = await LocalDatabase.clearLocalAudioCache(
          dirs: [audioDir, artworkDir],
        );

        expect(freed, 2048 + 256 + 1024 + 4096);
        expect(LocalDatabase.audioCacheRevision.value, before + 1);
        expect(
          await LocalDatabase.getLocalAudioCacheSizeBytes(
            dirs: [audioDir, artworkDir],
          ),
          0,
        );
        expect(await untouched.exists(), isTrue);
        expect(await untouched.length(), 9999);
        expect(await audioDir.exists(), isTrue);
        expect(await artworkDir.exists(), isTrue);
      },
    );

    test(
      'persistent offline_downloads are preserved while streaming_cache is cleared',
      () async {
        final persistentDir = Directory(p.join(root.path, 'offline_downloads'));
        final streamingCacheDir = Directory(
          p.join(root.path, 'streaming_cache'),
        );
        await persistentDir.create(recursive: true);
        await streamingCacheDir.create(recursive: true);

        final persistentSong = await writeFile(
          persistentDir,
          'downloaded-track.m4a',
          5000,
        );
        final streamedSong = await writeFile(
          streamingCacheDir,
          'streamed-track.m4a',
          3000,
        );

        // When clearing streaming cache dirs only:
        final freed = await LocalDatabase.clearLocalAudioCache(
          dirs: [streamingCacheDir],
        );

        expect(freed, 3000);
        expect(await streamedSong.exists(), isFalse);
        expect(await persistentSong.exists(), isTrue);
        expect(await persistentSong.length(), 5000);
      },
    );
  });

  group('Local audio storage usage (downloads + playback cache)', () {
    late Directory root;
    late Directory downloadsDir;
    late Directory cacheDir;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('pulse_usage_test_');
      downloadsDir = Directory(p.join(root.path, 'offline_downloads'));
      cacheDir = Directory(p.join(root.path, 'streaming_cache'));
      await downloadsDir.create(recursive: true);
      await cacheDir.create(recursive: true);
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    Future<File> writeBytes(Directory dir, String name, int bytes) async {
      final file = File(p.join(dir.path, name));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List<int>.filled(bytes, 0));
      return file;
    }

    test('splits permanent downloads from the playback cache', () async {
      await writeBytes(downloadsDir, 'song-a.m4a', 4096);
      await writeBytes(downloadsDir, 'song-a.jpg', 128);
      await writeBytes(cacheDir, 'streamed.m4a', 2048);

      final usage = await LocalDatabase.getLocalAudioStorageUsage(
        downloadDirs: [downloadsDir],
        cacheDirs: [cacheDir],
      );

      expect(usage.downloadBytes, 4096 + 128);
      expect(usage.cacheBytes, 2048);
      expect(usage.totalBytes, 4096 + 128 + 2048);
    });

    test('a directory listed in both sets is only counted once', () async {
      await writeBytes(downloadsDir, 'song.m4a', 1000);

      final usage = await LocalDatabase.getLocalAudioStorageUsage(
        downloadDirs: [downloadsDir],
        cacheDirs: [downloadsDir],
      );

      expect(usage.totalBytes, 1000);
      expect(usage.cacheBytes, 0);
    });

    test('total grows when a song is downloaded, then played', () async {
      final empty = await LocalDatabase.getLocalAudioStorageUsage(
        downloadDirs: [downloadsDir],
        cacheDirs: [cacheDir],
      );
      expect(empty.totalBytes, 0);

      await writeBytes(downloadsDir, 'new-download.m4a', 5000);
      final afterDownload = await LocalDatabase.getLocalAudioStorageUsage(
        downloadDirs: [downloadsDir],
        cacheDirs: [cacheDir],
      );
      expect(afterDownload.totalBytes, 5000);

      await writeBytes(cacheDir, 'played.m4a', 2500);
      final afterPlay = await LocalDatabase.getLocalAudioStorageUsage(
        downloadDirs: [downloadsDir],
        cacheDirs: [cacheDir],
      );
      expect(afterPlay.totalBytes, 7500);
    });

    test('clearing the playback cache keeps downloads counted', () async {
      await writeBytes(downloadsDir, 'kept.m4a', 4096);
      await writeBytes(cacheDir, 'temp.m4a', 1024);

      final freed = await LocalDatabase.clearLocalAudioCache(dirs: [cacheDir]);
      expect(freed, 1024);

      final usage = await LocalDatabase.getLocalAudioStorageUsage(
        downloadDirs: [downloadsDir],
        cacheDirs: [cacheDir],
      );
      expect(usage.downloadBytes, 4096);
      expect(usage.cacheBytes, 0);
      expect(usage.totalBytes, 4096);
    });
  });

  group('MusicPlayerController cache clearing', () {
    late Directory root;
    late Directory streamingDir;
    late Directory downloadsDir;
    late MusicPlayerController controller;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('pulse_controller_cache_');
      streamingDir = Directory(p.join(root.path, 'streaming_cache'));
      downloadsDir = Directory(p.join(root.path, 'offline_downloads'));
      await streamingDir.create(recursive: true);
      await downloadsDir.create(recursive: true);
      controller = MusicPlayerController();
    });

    tearDown(() async {
      controller.dispose();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test(
      'clears temporary cache, keeps downloads, and resets cached song paths',
      () async {
        final streamed = File(p.join(streamingDir.path, 'streamed.m4a'));
        await streamed.writeAsBytes(List<int>.filled(2048, 1));
        final downloaded = File(p.join(downloadsDir.path, 'downloaded.m4a'));
        await downloaded.writeAsBytes(List<int>.filled(4096, 2));

        final streamedSong = Song(
          id: 'controller-streaming-cache-test',
          title: 'Streamed',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
          genre: 'Pop',
          imageUrl: '',
          gradientColors: const [],
          plays: '',
          lyrics: const [],
          audioUrl: streamed.path,
        );
        controller.addSong(streamedSong);

        final downloadedSong = Song(
          id: 'controller-downloaded-cache-test',
          title: 'Downloaded',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
          genre: 'Pop',
          imageUrl: '',
          gradientColors: const [],
          plays: '',
          lyrics: const [],
          audioUrl: downloaded.path,
        );
        controller.addSong(downloadedSong);

        final freed = await controller.clearAudioCache(dirs: [streamingDir]);

        expect(freed, 2048);
        expect(await streamed.exists(), isFalse);
        expect(await downloaded.exists(), isTrue);
        expect(streamedSong.audioUrl, isEmpty);
        expect(controller.isSongDownloaded(streamedSong.id), isFalse);
        expect(controller.isSongDownloaded(downloadedSong.id), isTrue);
      },
    );

    test(
      'caches downloaded-track artwork and metadata once without copying audio',
      () async {
        final downloaded = File(p.join(downloadsDir.path, 'downloaded.m4a'));
        await downloaded.writeAsBytes(List<int>.filled(4096, 2));
        final artwork = File(p.join(root.path, 'source-artwork.jpg'));
        await artwork.writeAsBytes(List<int>.filled(256, 3));

        final song = Song(
          id: 'downloaded-track-metadata-test',
          title: 'Downloaded',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
          genre: 'Pop',
          imageUrl: artwork.path,
          gradientColors: const [],
          plays: '1,000',
          lyrics: const ['First line', 'Second line'],
          audioUrl: downloaded.path,
        );

        await controller.cachePlaybackMetadataForTesting(song, streamingDir);
        final firstSize = await LocalDatabase.getLocalAudioCacheSizeBytes(
          dirs: [streamingDir],
        );
        await controller.cachePlaybackMetadataForTesting(song, streamingDir);
        final secondSize = await LocalDatabase.getLocalAudioCacheSizeBytes(
          dirs: [streamingDir],
        );

        expect(firstSize, greaterThan(0));
        expect(secondSize, firstSize);
        expect(
          await File(
            p.join(streamingDir.path, '${song.id}.metadata.json'),
          ).exists(),
          isTrue,
        );
        expect(
          await File(p.join(streamingDir.path, '${song.id}.jpg')).exists(),
          isTrue,
        );
        expect(
          await File(p.join(streamingDir.path, '${song.id}.m4a')).exists(),
          isFalse,
        );
        expect(await downloaded.exists(), isTrue);
      },
    );
  });
}
