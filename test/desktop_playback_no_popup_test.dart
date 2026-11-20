import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/models/song_model.dart';
import 'package:music/services/audio_capabilities.dart';
import 'package:music/widgets/desktop_lyrics_view.dart';
import 'package:music/widgets/right_panel.dart';
import 'package:music/widgets/spotify_lyrics_sheet.dart';
import 'package:music/widgets/bottom_player_bar.dart';

void main() {
  final testSong = Song(
    id: 'test-song-kakaiba',
    title: 'Kakaiba',
    artist: 'Ex Battalion',
    album: 'Hev Abi Radio',
    duration: const Duration(minutes: 5, seconds: 2),
    audioUrl: 'https://example.com/audio.mp3',
    imageUrl: '',
    plays: '100',
    genre: 'Hip-Hop',
    gradientColors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
    lyrics: [
      '[00:10.00]JRoa',
      '[00:20.00]Ex B',
      '[00:30.00]Huh with your boy S',
    ],
  );

  group('AudioCapabilities.isDesktopUi tests', () {
    testWidgets('Returns false when on mobile target platform (Android / iOS)', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(AudioCapabilities.isMobile, isTrue);
        expect(AudioCapabilities.isDesktop, isFalse);
        expect(AudioCapabilities.isDesktopUi(), isFalse);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(AudioCapabilities.isDesktopUi(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Returns true when on Windows desktop target platform', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(AudioCapabilities.isDesktop, isTrue);
        expect(AudioCapabilities.isMobile, isFalse);
        expect(AudioCapabilities.isDesktopUi(), isTrue);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(AudioCapabilities.isDesktopUi(context), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('RightActivityPanel layout tests', () {
    testWidgets('Renders circle music, title, artist, slider, controls, square image, title again, and lyrics preview', (
      WidgetTester tester,
    ) async {
      final controller = MusicPlayerController();
      try {
        controller.playSong(testSong);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 1000,
                child: RightActivityPanel(
                  controller: controller,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify Title & Artist rendered (both top and below square image)
        expect(find.text('Kakaiba'), findsNWidgets(2));
        expect(find.textContaining('Ex Battalion'), findsWidgets);

        // 2. Verify Slider and Timestamps exist
        expect(find.byType(Slider), findsWidgets);

        // 3. Verify Playback Controls: Shuffle, Previous, Play/Pause, Next, Repeat
        expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
        expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

        // 4. Verify Square image section header
        expect(find.text('Hev Abi Radio'), findsOneWidget);

        // 5. Verify Lyrics preview card
        expect(find.text('Lyrics preview'), findsOneWidget);
        expect(find.text('JRoa'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('DesktopLyricsView renders in dashboard center with full lyrics and back button', (
      WidgetTester tester,
    ) async {
      final controller = MusicPlayerController();
      bool closed = false;
      try {
        controller.playSong(testSong);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DesktopLyricsView(
                controller: controller,
                onClose: () => closed = true,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify top bar info and back button
        expect(find.text('Back to Dashboard'), findsOneWidget);
        expect(find.text('Kakaiba'), findsOneWidget);
        expect(find.textContaining('Ex Battalion'), findsOneWidget);

        // Verify synchronized lyrics lines
        expect(find.text('JRoa'), findsOneWidget);
        expect(find.text('Ex B'), findsOneWidget);
        expect(find.text('Huh with your boy S'), findsOneWidget);

        // Tap Back to Dashboard
        await tester.tap(find.text('Back to Dashboard'));
        await tester.pump();

        expect(closed, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });

    testWidgets('SpotifyLyricsSheet.show is suppressed on Desktop UI', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final controller = MusicPlayerController();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      SpotifyLyricsSheet.show(
                        context,
                        song: testSong,
                        controller: controller,
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // On desktop, SpotifyLyricsSheet modal must NOT be inserted into widget tree
        expect(find.byType(SpotifyLyricsSheet), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        controller.dispose();
      }
    });

    testWidgets('BottomPlayerBar is hidden on Desktop UI when AudioCapabilities.isDesktopUi is true', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final controller = MusicPlayerController();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final isDesktop = AudioCapabilities.isDesktopUi(context);
                return Scaffold(
                  body: Column(
                    children: [
                      const Expanded(child: Text('Center Content')),
                      if (!isDesktop)
                        BottomPlayerBar(controller: controller),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        expect(find.byType(BottomPlayerBar), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        controller.dispose();
      }
    });

    testWidgets('BottomPlayerBar is visible on Mobile UI when AudioCapabilities.isDesktopUi is false', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controller = MusicPlayerController();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final isDesktop = AudioCapabilities.isDesktopUi(context);
                return Scaffold(
                  body: Column(
                    children: [
                      const Expanded(child: Text('Center Content')),
                      if (!isDesktop)
                        BottomPlayerBar(controller: controller),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        expect(find.byType(BottomPlayerBar), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        controller.dispose();
      }
    });
  });
}

