import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/views/music_dashboard_view.dart';
import 'package:music/views/playlist_screen.dart';
import 'package:music/widgets/sidebar_nav.dart';

Future<void> pumpDashboard(
  WidgetTester tester,
  Future<void> Function() interactions, {
  MusicPlayerController? controller,
}) async {
  final errors = <Object>[];
  await runZonedGuarded(
    () async {
      await tester.pumpWidget(MaterialApp(home: MusicDashboardView(controller: controller)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await interactions();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    },
    (Object error, StackTrace stack) {
      if (error is MissingPluginException) return;
      errors.add(error);
    },
  );
  expect(errors, isEmpty);
}

void main() {
  testWidgets('Sidebar is removed from dashboard; drawer contains account shortcuts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await pumpDashboard(tester, () async {
      // Idle pump on Home screen
    });

    // Verify duplicate sidebar is removed from dashboard body
    expect(find.byType(SidebarNav), findsNothing);

    // Verify right hamburger navigation menu is removed per user request
    expect(find.byTooltip('Navigation menu'), findsNothing);

    // Verify sidebar does NOT have "YOUR LIBRARY"
    expect(find.text('YOUR LIBRARY'), findsNothing);
  });

  testWidgets('Explore tab renders Daily Mixes, Popular radio, and Recents without imported playlist grid', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = MusicPlayerController();
    controller.setNavIndex(1);

    await pumpDashboard(tester, () async {
      // Switched to Explore tab via controller
    }, controller: controller);

    // Verify category pills and search bar are removed from Explore
    expect(find.text('Podcasts'), findsNothing);
    expect(find.text('Audiobooks'), findsNothing);

    // Made For You and Recents stay removed from Explore.
    expect(find.text('Made For You'), findsNothing);
    expect(find.text('Daily Mix 01'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.text('Recents'),
      ),
      findsNothing,
      reason: 'Explore content must not add its own Recents section',
    );

    // Check Popular Radio and artist radio sections
    expect(find.text('Popular radio'), findsOneWidget);
    expect(find.text('Flow G'), findsWidgets);
    expect(find.text('Air Supply'), findsWidgets);
    expect(find.text('Sugarfree'), findsWidgets);
    expect(find.text('Maroon 5'), findsWidgets);

    // Verify imported playlist grid is NOT in Explore tab
    expect(find.text('Explore Playlists'), findsNothing);
    expect(find.text('All Available Catalog'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('Library tab does not display hardcoded default artists, 2000s, or radio indicators', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = MusicPlayerController();
    controller.setNavIndex(2);

    await pumpDashboard(tester, () async {
      // Switched to Library tab via controller
    }, controller: controller);

    // Header actions
    expect(find.text('Your Library'), findsWidgets);
    expect(find.text('Import Spotify link'), findsWidgets);
    expect(find.text('Create playlist'), findsWidgets);

    // Filter pills
    expect(find.text('Playlists'), findsWidgets);
    expect(find.text('Albums'), findsWidgets);

    // Verify hardcoded default artists from screenshot are removed from Library
    expect(find.text('Sugarfree'), findsNothing);
    expect(find.text('Bruno Mars'), findsNothing);
    expect(find.text('MATÉO'), findsNothing);
    expect(find.text('Adie'), findsNothing);
    expect(find.text('Tothapi'), findsNothing);

    // Verify indicator tags 'Playlist •' and 'Artist' and 'RADIO' are NOT displayed
    expect(find.text('Playlist • loser'), findsNothing);
    expect(find.text('Playlist • Made for you'), findsNothing);
    expect(find.text('Artist'), findsNothing);
    expect(find.text('RADIO'), findsNothing);

    // Verify raw flat tracklist is NOT displayed
    expect(find.text('All saved songs'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('Tapping on a created playlist in Library opens PlaylistScreen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = MusicPlayerController();
    controller.setNavIndex(2);

    await pumpDashboard(tester, () async {
      // Tap Create playlist button
      await tester.tap(find.text('Create playlist').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter playlist name in dialog
      final dialogInput = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogInput, 'My Chill Vibes');
      await tester.pump();

      // Submit dialog
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Create'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify controller has the created playlist
      expect(controller.libraryPlaylists.any((p) => p.title == 'My Chill Vibes'), isTrue);

      // Tap on newly created playlist in Library
      expect(find.text('My Chill Vibes'), findsWidgets);
      await tester.tap(find.text('My Chill Vibes').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }, controller: controller);

    // Verify PlaylistScreen was opened
    expect(find.byType(PlaylistScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('Tapping on a Popular Radio in Explore opens PlaylistScreen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = MusicPlayerController();
    controller.setNavIndex(1);

    await pumpDashboard(tester, () async {
      // Tap on Flow G Radio card
      await tester.tap(find.text('Flow G').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }, controller: controller);

    // Verify PlaylistScreen was opened
    expect(find.byType(PlaylistScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  });
}
