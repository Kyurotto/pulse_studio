import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/models/song_model.dart';
import 'package:music/services/radio_discovery_service.dart';
import 'package:music/views/music_dashboard_view.dart';

Song _song(String id, String title) {
  return Song(
    id: id,
    title: title,
    artist: 'Hev Abi',
    album: title,
    duration: const Duration(minutes: 3),
    genre: 'Hip-Hop',
    imageUrl: '',
    gradientColors: const [Color(0xFFD6B4E8), Color(0xFF8B5CF6)],
    plays: '',
    lyrics: const [],
  );
}

RadioStation _station({String artist = 'Hev Abi'}) {
  return RadioStation(
    id: 'artist-hev-abi',
    title: '$artist Radio',
    artistName: artist,
    subtitle: 'With Kristina Dawn, Flow G and more',
    backgroundColor: const Color(0xFFD6B4E8),
    gradientColors: const [Color(0xFFD6B4E8), Color(0xFF8B5CF6)],
    songs: [
      _song('fake-1', 'Walang Alam'),
      _song('fake-2', 'Babaero'),
    ],
  );
}

DailyMix _mix() {
  return DailyMix(
    id: 'mix-2000s',
    title: '2000s Mix',
    number: '01',
    accentColor: const Color(0xFFF59E0B),
    gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
    subtitle: 'Usher, Nelly and more',
    songs: [_song('mix-1', 'Yeah!')],
  );
}

class _FakeRadioService extends RadioDiscoveryService {
  _FakeRadioService() : super();

  @override
  String get lastPlayedArtist => 'Hev Abi';

  @override
  List<RadioStation> getPopularStations() => [_station()];

  @override
  List<RadioStation> getRecentStations() => [_station()];

  @override
  List<RadioStation> getRecommendedStations() => [_station(artist: 'Maki')];

  @override
  List<DailyMix> getTopMixes() => [_mix()];

  @override
  List<RadioStation> getMoreLikeStations(String artistName) => [_station()];

  @override
  List<String> getQuickFilterArtists() => const ['Flow G', 'Hev Abi'];

  @override
  Future<void> refreshRecentStations() async {}

  @override
  Future<void> recordStationPlayed(RadioStation station) async {}

  @override
  Future<RadioStation?> searchArtistRadio(String query) async {
    if (query.trim().isEmpty || query.contains('no-match')) return null;
    return _station();
  }
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required MusicPlayerController controller,
  required RadioDiscoveryService radioService,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final errors = <Object>[];
  await runZonedGuarded(
    () async {
      await tester.pumpWidget(
        MaterialApp(
          home: MusicDashboardView(
            controller: controller,
            radioService: radioService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
    (Object error, StackTrace stack) {
      if (error is MissingPluginException) return;
      errors.add(error);
    },
  );
  expect(errors, isEmpty);
}

void main() {
  testWidgets('Home renders the radio dashboard, not discovery rows', (
    tester,
  ) async {
    final controller = MusicPlayerController();
    final service = _FakeRadioService();

    await _pumpDashboard(tester, controller: controller, radioService: service);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Podcasts'), findsOneWidget);
    expect(find.text('Audiobooks'), findsOneWidget);
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Popular Radio'), findsOneWidget);
    expect(find.text('Recommended Stations'), findsOneWidget);
    expect(find.text('Your Top Mixes'), findsOneWidget);
    expect(find.text('More like Hev Abi'), findsOneWidget);
    expect(find.text('2000s Mix'), findsOneWidget);

    // The old YouTube-style discovery feed is gone from Home.
    expect(find.text('Quick Picks'), findsNothing);
    expect(find.text('Covers & Remixes'), findsNothing);
    expect(find.text('Trending For You'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('Podcasts category shows a coming-soon empty state', (
    tester,
  ) async {
    final controller = MusicPlayerController();
    final service = _FakeRadioService();

    await _pumpDashboard(tester, controller: controller, radioService: service);
    await tester.tap(find.text('Podcasts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Podcasts are coming soon'), findsOneWidget);
    expect(find.text('Popular Radio'), findsNothing);
    expect(find.text('Browse music'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('Touch cards expose overflow and play actions', (tester) async {
    final controller = MusicPlayerController();
    final service = _FakeRadioService();

    await _pumpDashboard(tester, controller: controller, radioService: service);

    expect(find.byTooltip('More options'), findsWidgets);
    expect(find.byTooltip('Play station'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('Search shows the generated station above track results', (
    tester,
  ) async {
    final controller = MusicPlayerController();
    final service = _FakeRadioService();
    controller.setSearchQuery('Hev Abi');

    await _pumpDashboard(tester, controller: controller, radioService: service);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hev Abi Radio'), findsOneWidget);
    expect(find.text('Play radio'), findsOneWidget);
    expect(find.text('View station'), findsOneWidget);
    expect(find.text('Tracks'), findsOneWidget);

    final radioY = tester.getTopLeft(find.text('Hev Abi Radio')).dy;
    final tracksY = tester.getTopLeft(find.text('Tracks')).dy;
    expect(radioY, lessThan(tracksY));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('Search empty state renders when nothing matches', (
    tester,
  ) async {
    final controller = MusicPlayerController();
    final service = _FakeRadioService();
    controller.setSearchQuery('zzzz-no-match');

    await _pumpDashboard(tester, controller: controller, radioService: service);

    expect(find.text('No results for "zzzz-no-match"'), findsOneWidget);
    expect(find.text('Play radio'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('Header home button returns to the dashboard and clears search', (
    tester,
  ) async {
    final controller = MusicPlayerController();
    final service = _FakeRadioService();
    controller.setNavIndex(1);
    controller.setSearchQuery('Hev Abi');

    await _pumpDashboard(tester, controller: controller, radioService: service);

    expect(find.byTooltip('Back to dashboard'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to dashboard'));
    await tester.pump();

    expect(controller.currentNavIndex, 0);
    expect(controller.searchQuery, isEmpty);
    expect(find.text('Popular Radio'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });
}
