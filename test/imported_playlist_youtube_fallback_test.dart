import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/models/song_model.dart';
import 'package:music/services/track_enrichment_service.dart';

/// Regression coverage for imported Spotify playlists stuck on LOCATING when
/// YouTube cannot serve a stream. Imports must fall back to the other
/// full-track sources; Explore radio/discovery must stay YouTube-only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response jsonOk(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );

  http.Response saavnOk(String title, String artist, String url) => jsonOk({
        'success': true,
        'data': {
          'results': [
            {
              'id': 'saavn-test',
              'name': title,
              'artists': {
                'primary': [
                  {'name': artist},
                ],
              },
              'duration': 226,
              'image': [
                {'url': 'https://example.com/cover500.jpg'},
              ],
              'downloadUrl': [
                {'quality': '96kbps', 'url': 'https://example.com/low.mp3'},
                {'quality': '320kbps', 'url': url},
              ],
            },
          ],
        },
      });

  test(
      'Spotify import falls back to a full-length Saavn stream when YouTube fails',
      () async {
    var saavnQueries = 0;
    final service = TrackEnrichmentService(
      client: MockClient((request) async {
        final host = request.url.host;
        if (host.contains('youtube.com') || host.contains('googlevideo.com')) {
          return http.Response('blocked', 403);
        }
        if (host == 'saavn.sumit.co') {
          saavnQueries++;
          return saavnOk(
            '24K Magic',
            'Bruno Mars',
            'https://example.com/24k-full.mp3',
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final enrichment = await service.enrichTrack(
      title: '24K Magic',
      artist: 'Bruno Mars',
      duration: const Duration(minutes: 3, seconds: 46),
      allowPreviewFallback: false,
      prioritizeYouTube: true,
      youtubeOnly: false,
    );

    expect(saavnQueries, greaterThan(0));
    expect(enrichment.previewUrl, 'https://example.com/24k-full.mp3');
    expect(enrichment.isFullTrack, isTrue);
    expect(enrichment.isYouTube, isFalse);
    service.dispose();
  });

  test('youtubeOnly stays strict for radio and never hits Saavn', () async {
    var saavnQueries = 0;
    final service = TrackEnrichmentService(
      client: MockClient((request) async {
        final host = request.url.host;
        if (host.contains('youtube.com') || host.contains('googlevideo.com')) {
          return http.Response('blocked', 403);
        }
        if (host == 'saavn.sumit.co') {
          saavnQueries++;
          return saavnOk(
            '24K Magic',
            'Bruno Mars',
            'https://example.com/24k-full.mp3',
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final enrichment = await service.enrichTrack(
      title: '24K Magic',
      artist: 'Bruno Mars',
      duration: const Duration(minutes: 3, seconds: 46),
      allowPreviewFallback: false,
      prioritizeYouTube: true,
      youtubeOnly: true,
    );

    expect(saavnQueries, 0);
    expect(enrichment.hasAudio, isFalse);
    service.dispose();
  });

  test('strict YouTube policy covers radio/discovery but not imports', () {
    Song song(String id) => Song(
          id: id,
          title: '24K Magic',
          artist: 'Bruno Mars',
          album: '24K Magic',
          duration: const Duration(minutes: 3, seconds: 46),
          genre: 'Pop',
          imageUrl: '',
          gradientColors: const [],
          plays: '',
          lyrics: const [],
        );

    expect(
      MusicPlayerController.requiresStrictYouTubeForTesting(
        song('spotify-0Uhh62UWXbznRfVKbHhbsr'),
      ),
      isFalse,
    );
    expect(
      MusicPlayerController.requiresStrictYouTubeForTesting(
        song('itunes-1011384691'),
      ),
      isFalse,
    );
    expect(
      MusicPlayerController.requiresStrictYouTubeForTesting(song('radio-opm-1')),
      isTrue,
    );
    expect(
      MusicPlayerController.requiresStrictYouTubeForTesting(
        song('discovery-opm-1'),
      ),
      isTrue,
    );
  });
}
