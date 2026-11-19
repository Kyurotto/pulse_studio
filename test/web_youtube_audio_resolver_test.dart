import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music/services/web_youtube_audio_resolver.dart';

/// Builds a resolver backed by a fake network. The instance list is stubbed to
/// fail so the primary host is the only search base, and companion hosts are
/// answered per test.
WebYouTubeAudioResolver resolverWith(
  Future<http.Response> Function(http.Request request) handler,
) {
  return WebYouTubeAudioResolver(
    client: MockClient((request) async {
      if (request.url.host == 'api.invidious.io') {
        return http.Response('', 500);
      }
      return handler(request);
    }),
  );
}

http.Response searchJson(List<Map<String, Object>> results) => http.Response(
  jsonEncode(results),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response audioBytes(int length) => http.Response.bytes(
  Uint8List(length),
  200,
  headers: {'content-type': 'audio/mp4'},
);

Map<String, Object> video({
  required String id,
  required String title,
  required String author,
  required int seconds,
}) => {
  'videoId': id,
  'title': title,
  'author': author,
  'lengthSeconds': seconds,
};

void main() {
  test(
    'downloads a complete track from the first working companion host',
    () async {
      final requested = <String>[];
      final resolver = resolverWith((request) async {
        if (request.url.path == '/companion/latest_version') {
          requested.add(request.url.host);
          final id = request.url.queryParameters['id'];
          if (id != 'kA9hWx8cMYc') return http.Response('', 404);
          if (request.url.host == 'yt-comp1.chocolatemoo53.com') {
            return audioBytes(60000);
          }
          throw http.ClientException('Failed to fetch', request.url);
        }
        return http.Response('', 404);
      });

      final hit = await resolver.resolve(
        title: 'Yellow',
        artist: 'Coldplay',
        duration: const Duration(seconds: 273),
        videoId: 'kA9hWx8cMYc',
      );

      expect(hit, isNotNull);
      expect(hit!.videoId, 'kA9hWx8cMYc');
      expect(hit.bytes.length, 60000);
      expect(hit.contentType, contains('audio/mp4'));
      expect(hit.streamUrl, contains('yt-comp1.chocolatemoo53.com'));
      expect(requested.first, 'yt-comp1.chocolatemoo53.com');
      resolver.dispose();
    },
  );

  test('fails over to the next companion host after a CORS failure', () async {
    final resolver = resolverWith((request) async {
      if (request.url.path == '/companion/latest_version') {
        if (request.url.host == 'yt-comp1.chocolatemoo53.com') {
          throw http.ClientException('Failed to fetch', request.url);
        }
        if (request.url.host == 'yt-comp2.chocolatemoo53.com') {
          return audioBytes(70000);
        }
        return http.Response('', 404);
      }
      return http.Response('', 404);
    });

    final hit = await resolver.resolve(
      title: 'Yellow',
      artist: 'Coldplay',
      videoId: 'kA9hWx8cMYc',
    );

    expect(hit, isNotNull);
    expect(hit!.streamUrl, contains('yt-comp2.chocolatemoo53.com'));
    expect(hit.bytes.length, 70000);
    resolver.dispose();
  });

  test(
    'searches, rejects karaoke, and prefers the clean studio upload',
    () async {
      final downloadedIds = <String>[];
      final resolver = resolverWith((request) async {
        if (request.url.path == '/api/v1/search') {
          return searchJson([
            video(
              id: 'KARAOKE0001',
              title: 'Yellow (Karaoke Version)',
              author: 'Sing King',
              seconds: 273,
            ),
            video(
              id: 'SUBTITLES01',
              title: 'Coldplay - Yellow (Sub Español + Lyrics)',
              author: 'Lyrics World',
              seconds: 271,
            ),
            video(
              id: 'OFFICIAL001',
              title: 'Coldplay - Yellow (Official Video)',
              author: 'Coldplay',
              seconds: 273,
            ),
            video(
              id: 'LIVEVERSION',
              title: 'Coldplay - Yellow (Live in Buenos Aires)',
              author: 'Coldplay',
              seconds: 300,
            ),
          ]);
        }
        if (request.url.path == '/companion/latest_version') {
          if (request.headers['Range'] == null) {
            downloadedIds.add(request.url.queryParameters['id'] ?? '');
          }
          return audioBytes(65000);
        }
        return http.Response('', 404);
      });

      final hit = await resolver.resolve(
        title: 'Yellow',
        artist: 'Coldplay',
        duration: const Duration(seconds: 273),
      );

      expect(hit, isNotNull);
      expect(hit!.videoId, 'OFFICIAL001');
      expect(downloadedIds, ['OFFICIAL001']);
      resolver.dispose();
    },
  );

  test('returns null when every search hit is a different recording', () async {
    var downloadAttempts = 0;
    final resolver = resolverWith((request) async {
      if (request.url.path == '/api/v1/search') {
        return searchJson([
          video(
            id: 'KARAOKE0001',
            title: 'Yellow (Karaoke Version)',
            author: 'Sing King',
            seconds: 273,
          ),
          video(
            id: 'COVER000001',
            title: 'Yellow - Piano Cover',
            author: 'Relaxing Keys',
            seconds: 250,
          ),
        ]);
      }
      if (request.url.path == '/companion/latest_version') {
        downloadAttempts++;
        return audioBytes(65000);
      }
      return http.Response('', 404);
    });

    final hit = await resolver.resolve(
      title: 'Yellow',
      artist: 'Coldplay',
      duration: const Duration(seconds: 273),
    );

    expect(hit, isNull);
    expect(downloadAttempts, 0);
    resolver.dispose();
  });
}
