import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music/models/song_model.dart';
import 'package:music/services/radio_discovery_service.dart';

Song _song({
  required String id,
  required String title,
  String artist = 'Hev Abi',
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    album: title,
    duration: const Duration(minutes: 3),
    genre: 'Hip-Hop',
    imageUrl: '',
    gradientColors: const [],
    plays: '',
    lyrics: const [],
  );
}

http.Client _catalogClient() {
  return MockClient((request) async {
    final body = jsonEncode({
      'results': [
        {
          'trackId': 1,
          'trackName': 'Walang Alam',
          'artistName': 'Hev Abi',
          'collectionName': 'Kung Alam Mo Lang',
          'trackTimeMillis': 192000,
          'artworkUrl100': 'https://example.com/a/100x100bb.jpg',
          'previewUrl': 'https://example.com/preview.m4a',
          'primaryGenreName': 'Hip-Hop',
        },
        {
          'trackId': 2,
          'trackName': 'Babaero',
          'artistName': 'Hev Abi',
          'collectionName': 'Babaero',
          'trackTimeMillis': 180000,
          'artworkUrl100': 'https://example.com/b/100x100bb.jpg',
          'previewUrl': 'https://example.com/preview2.m4a',
          'primaryGenreName': 'Hip-Hop',
        },
      ],
    });
    return http.Response(body, 200, headers: {'content-type': 'application/json'});
  });
}

http.Client _offlineClient() {
  return MockClient((request) async {
    throw http.ClientException('offline');
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('curated stations', () {
    test('popular stations are non-empty and carry playable metadata', () {
      final service = RadioDiscoveryService(client: _offlineClient());
      final stations = service.getPopularStations();
      expect(stations, isNotEmpty);
      expect(stations.every((s) => s.songs.isNotEmpty), isTrue);
      expect(stations.any((s) => s.id == 'flow-g'), isTrue);
    });

    test('recommended stations contain the curated OPM presets', () {
      final service = RadioDiscoveryService(client: _offlineClient());
      final titles = service.getRecommendedStations().map((s) => s.title);
      expect(
        titles,
        containsAll([
          'Tothapi Radio',
          'Maki Radio',
          'Lola Amour Radio',
          'Orange & Lemons Radio',
          'Arthur Nery Radio',
          'TJ Monterde Radio',
        ]),
      );
    });

    test('recents fall back to the curated default order', () {
      final service = RadioDiscoveryService(client: _offlineClient());
      final recent = service.getRecentStations();
      expect(recent.map((s) => s.id).toList(), [
        'artist-hev-abi',
        'artist-flow-g',
        'recent-black-clover-op',
        'recent-2000s',
        'artist-sugarfree',
      ]);
    });

    test('top mixes are labelled and non-empty', () {
      final service = RadioDiscoveryService(client: _offlineClient());
      final mixes = service.getTopMixes();
      expect(mixes.length, 5);
      expect(mixes.first.title, '2000s Mix');
      expect(mixes.map((m) => m.title), contains('Adie Mix'));
      expect(mixes.every((m) => m.songs.isNotEmpty), isTrue);
    });

    test('more-like defaults to Hev Abi and starts with the seed artist', () {
      final service = RadioDiscoveryService(client: _offlineClient());
      final stations = service.getMoreLikeStations('');
      expect(stations, isNotEmpty);
      expect(stations.first.artistName, 'Hev Abi');
      expect(stations.length, greaterThan(1));
    });

    test('more-like uses the requested artist as the seed', () {
      final service = RadioDiscoveryService(client: _offlineClient());
      final stations = service.getMoreLikeStations('Maki');
      expect(stations.first.title, 'Maki Radio');
      expect(stations.every((s) => s.songs.isNotEmpty), isTrue);
    });
  });

  group('artist radio search', () {
    test('empty queries return null', () async {
      final service = RadioDiscoveryService(client: _offlineClient());
      expect(await service.searchArtistRadio('   '), isNull);
    });

    test('provider failures fall back to curated station metadata', () async {
      final service = RadioDiscoveryService(client: _offlineClient());
      final station = await service.searchArtistRadio('Hev Abi');
      expect(station, isNotNull);
      expect(station!.title, 'Hev Abi Radio');
      expect(station.songs, isNotEmpty);
    });

    test('catalog results are parsed, de-duplicated and cached', () async {
      final service = RadioDiscoveryService(client: _catalogClient());
      final first = await service.searchArtistRadio('Hev Abi');
      final second = await service.searchArtistRadio('Hev Abi');
      expect(first, isNotNull);
      expect(first!.songs.length, 2);
      expect(first.songs.first.title, 'Walang Alam');
      expect(identical(first, second), isTrue);
    });
  });

  group('track de-duplication', () {
    test('removes duplicate ids and duplicate title/artist pairs', () {
      final songs = [
        _song(id: 'a', title: 'Walang Alam'),
        _song(id: 'a', title: 'Walang Alam (duplicate id)'),
        _song(id: 'b', title: 'Walang Alam'),
        _song(id: 'c', title: 'Babaero'),
      ];
      final result = RadioDiscoveryService.dedupeSongs(songs);
      expect(result.map((s) => s.id).toList(), ['a', 'c']);
    });
  });

  group('recent station bookkeeping', () {
    test('recording a played station updates the seed and recents', () async {
      final service = RadioDiscoveryService(client: _offlineClient());
      final station = service.getRecommendedStations().first;
      await service.recordStationPlayed(station);
      expect(service.lastPlayedArtist, station.artistName);
      expect(service.getRecentStations().first.id, station.id);
      expect(
        service.getMoreLikeStations(service.lastPlayedArtist).first.artistName,
        station.artistName,
      );
    });

    test('refresh keeps curated defaults when no history is available',
        () async {
      final service = RadioDiscoveryService(client: _offlineClient());
      await service.refreshRecentStations();
      expect(service.getRecentStations(), isNotEmpty);
      expect(service.getRecentStations().first.id, 'artist-hev-abi');
    });
  });
}
