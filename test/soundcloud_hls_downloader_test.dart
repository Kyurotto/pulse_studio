import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music/services/soundcloud_hls_downloader.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sc_hls_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  String manifest(Iterable<String> segments) => [
    '#EXTM3U',
    '#EXT-X-VERSION:7',
    '#EXT-X-TARGETDURATION:10',
    '#EXT-X-PLAYLIST-TYPE:VOD',
    '#EXT-X-MAP:URI="/audio/init.mp4"',
    for (final segment in segments) ...['#EXTINF:10.0,', segment],
    '#EXT-X-ENDLIST',
  ].join('\n');

  test('detects only SoundCloud media playlists', () {
    expect(
      SoundCloudHlsDownloader.isSoundCloudPlaylistUrl(
        'https://playback.media-streaming.soundcloud.cloud/x/aac_160k/y/playlist.m3u8',
      ),
      isTrue,
    );
    expect(
      SoundCloudHlsDownloader.isSoundCloudPlaylistUrl(
        'https://example.com/stream.m3u8',
      ),
      isFalse,
    );
    expect(SoundCloudHlsDownloader.isSoundCloudPlaylistUrl(''), isFalse);
  });

  test('concatenates the init segment and every media segment in order', () async {
    final requests = <String>[];
    final downloader = SoundCloudHlsDownloader(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path.endsWith('playlist.m3u8')) {
          return http.Response(
            manifest(['/audio/data000.m4s', '/audio/data001.m4s']),
            200,
          );
        }
        if (request.url.path == '/audio/init.mp4') {
          return http.Response.bytes([1, 2, 3], 200);
        }
        if (request.url.path == '/audio/data000.m4s') {
          return http.Response.bytes([10, 11], 200);
        }
        if (request.url.path == '/audio/data001.m4s') {
          return http.Response.bytes([20, 21], 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final target = File('${tempDir.path}/track.m4a');
    final bytes = await downloader.download(
      playlistUrl:
          'https://playback.media-streaming.soundcloud.cloud/x/playlist.m3u8',
      target: target,
    );

    expect(bytes, 7);
    expect(target.readAsBytesSync(), [1, 2, 3, 10, 11, 20, 21]);
    expect(requests.first, endsWith('playlist.m3u8'));
  });

  test('follows a master playlist down to the first variant', () async {
    final downloader = SoundCloudHlsDownloader(
      client: MockClient((request) async {
        if (request.url.path == '/master.m3u8') {
          return http.Response(
            [
              '#EXTM3U',
              '#EXT-X-STREAM-INF:BANDWIDTH=160000',
              'audio_160k/index.m3u8',
            ].join('\n'),
            200,
          );
        }
        if (request.url.path == '/audio_160k/index.m3u8') {
          return http.Response(manifest(['data000.m4s']), 200);
        }
        if (request.url.path == '/audio/init.mp4') {
          return http.Response.bytes([7], 200);
        }
        if (request.url.path == '/audio_160k/data000.m4s') {
          return http.Response.bytes([9, 9], 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final target = File('${tempDir.path}/variant.m4a');
    final bytes = await downloader.download(
      playlistUrl:
          'https://playback.media-streaming.soundcloud.cloud/master.m3u8',
      target: target,
    );

    expect(bytes, 3);
    expect(target.readAsBytesSync(), [7, 9, 9]);
  });

  test('removes a partial file when a segment fails', () async {
    final downloader = SoundCloudHlsDownloader(
      client: MockClient((request) async {
        if (request.url.path.endsWith('playlist.m3u8')) {
          return http.Response(
            manifest(['data000.m4s', 'data001.m4s']),
            200,
          );
        }
        if (request.url.path == '/data000.m4s') {
          return http.Response.bytes([1, 2, 3, 4], 200);
        }
        return http.Response('gone', 410);
      }),
    );

    final target = File('${tempDir.path}/broken.m4a');
    final bytes = await downloader.download(
      playlistUrl:
          'https://playback.media-streaming.soundcloud.cloud/broken/playlist.m3u8',
      target: target,
    );

    expect(bytes, 0);
    expect(target.existsSync(), isFalse);
  });

  test('returns zero and leaves no file when the manifest is unreadable', () async {
    final downloader = SoundCloudHlsDownloader(
      client: MockClient((_) async => http.Response('nope', 500)),
    );

    final target = File('${tempDir.path}/missing.m4a');
    final bytes = await downloader.download(
      playlistUrl:
          'https://playback.media-streaming.soundcloud.cloud/missing/playlist.m3u8',
      target: target,
    );

    expect(bytes, 0);
    expect(target.existsSync(), isFalse);
  });

  test('keeps query-string signatures when resolving segment URLs', () async {
    Uri? initRequest;
    final downloader = SoundCloudHlsDownloader(
      client: MockClient((request) async {
        if (request.url.path.endsWith('playlist.m3u8')) {
          return http.Response(
            [
              '#EXTM3U',
              '#EXT-X-MAP:URI="init.mp4?expires=1&Signature=abc"',
              '#EXTINF:10.0,',
              'data000.m4s?expires=1&Signature=def',
              '#EXT-X-ENDLIST',
            ].join('\n'),
            200,
          );
        }
        if (request.url.path.endsWith('init.mp4')) {
          initRequest = request.url;
          return http.Response.bytes([1], 200);
        }
        if (request.url.path.endsWith('data000.m4s')) {
          return http.Response.bytes([2], 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final target = File('${tempDir.path}/signed.m4a');
    final bytes = await downloader.download(
      playlistUrl:
          'https://playback.media-streaming.soundcloud.cloud/signed/playlist.m3u8',
      target: target,
    );

    expect(bytes, 2);
    expect(initRequest?.queryParameters['Signature'], 'abc');
    expect(
      utf8.decode(target.readAsBytesSync(), allowMalformed: true).length,
      greaterThan(0),
    );
  });
}
