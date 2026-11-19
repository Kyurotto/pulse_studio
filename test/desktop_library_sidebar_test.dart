import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/widgets/desktop_library_sidebar.dart';
import 'package:music/views/music_dashboard_view.dart';

void main() {
  group('DesktopLibrarySidebar Widget Tests', () {
    late MusicPlayerController controller;

    setUp(() {
      controller = MusicPlayerController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('Renders header with Your Library and Create button', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool createTapped = false;
      bool importTapped = false;
      bool libraryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLibrarySidebar(
              controller: controller,
              onCreatePlaylist: () => createTapped = true,
              onImportSpotify: () => importTapped = true,
              onLibraryTap: () => libraryTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Your Library'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.download_rounded),
        findsOneWidget,
      ); // Header logo button

      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(createTapped, isTrue);

      // Tap header import logo button
      await tester.tap(find.byTooltip('Import Spotify link or export ZIP'));
      await tester.pump();
      expect(importTapped, isTrue);

      // Tap Your Library
      await tester.tap(find.text('Your Library'));
      await tester.pump();
      expect(libraryTapped, isTrue);
    });

    testWidgets(
      'Renders hero banner category filter pills for Playlists, Albums, and Artists',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DesktopLibrarySidebar(controller: controller)),
          ),
        );
        await tester.pump();

        expect(find.text('Playlists'), findsOneWidget);
        expect(find.text('Albums'), findsOneWidget);
        expect(find.text('Artists'), findsOneWidget);

        // Tap Playlists chip to toggle
        await tester.tap(find.text('Playlists'));
        await tester.pump();

        // Tap again to toggle off
        await tester.tap(find.text('Playlists'));
        await tester.pump();
      },
    );

    testWidgets(
      'Renders playlists on the left side below the search bar and triggers onPlaylistSelected',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Create a test playlist
        controller.createPlaylist('Favorites Hits');

        String? selectedPlaylist;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DesktopLibrarySidebar(
                controller: controller,
                onPlaylistSelected: (id) => selectedPlaylist = id,
              ),
            ),
          ),
        );
        await tester.pump();

        // Category chips exist
        expect(find.text('Playlists'), findsOneWidget);
        expect(find.text('Albums'), findsOneWidget);
        expect(find.text('Artists'), findsOneWidget);

        // Playlist is rendered below the search bar
        expect(find.text('Favorites Hits'), findsOneWidget);

        // Tapping the playlist item triggers onPlaylistSelected
        await tester.tap(find.text('Favorites Hits'));
        await tester.pump();
        expect(selectedPlaylist, isNotNull);
      },
    );

    testWidgets(
      'Dashboard renders DesktopLibrarySidebar on desktop and hides it on mobile',
      (WidgetTester tester) async {
        // 1. Desktop size (1280x800)
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(home: MusicDashboardView(controller: controller)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(DesktopLibrarySidebar), findsOneWidget);

        // 2. Mobile size (360x740)
        tester.view.physicalSize = const Size(360, 740);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(DesktopLibrarySidebar), findsNothing);

        tester.view.resetPhysicalSize();
      },
    );
  });
}
