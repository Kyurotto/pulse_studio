import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/services/audio_capabilities.dart';
import 'package:music/theme/app_theme.dart';
import 'package:music/views/settings_view.dart';

void main() {
  testWidgets(
    'SettingsView renders 5 Spotify-style categories and excludes unwanted sections',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(380, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = MusicPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsView(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Top Bar
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // 2. Verify the 5 Included Categories exist
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Content and display'), findsOneWidget);
      expect(find.text('Playback'), findsOneWidget);
      expect(find.text('Data-saving and offline'), findsOneWidget);
      expect(find.text('Media quality'), findsOneWidget);

      // 3. Verify Subtitles
      expect(find.text('Username • Close account'), findsOneWidget);
      expect(
        find.text('Reduce animations • Canvas • Allow explicit content'),
        findsOneWidget,
      );
      expect(find.text('Gapless playback • Autoplay • Equalizer'), findsOneWidget);
      expect(
        find.text('Data saver mode • Downloads over cellular'),
        findsOneWidget,
      );
      expect(
        find.text('Wi-Fi streaming quality • Audio download quality'),
        findsOneWidget,
      );

      // 4. Verify Excluded Categories are NOT present
      expect(find.text('Advertising'), findsNothing);
      expect(find.text('About and support'), findsNothing);
      expect(find.text('Apps and devices'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Privacy and social'), findsNothing);
      expect(find.text('Go Premium'), findsNothing);
      expect(find.text('Free account'), findsNothing);

      // 5. Open Content and display category
      await tester.tap(find.text('Content and display'));
      await tester.pumpAndSettle();

      // Verify Reduce animations switch is present
      expect(find.text('Reduce animations'), findsOneWidget);
      expect(find.text('Canvas'), findsOneWidget);
      expect(find.text('Allow explicit content'), findsOneWidget);
      expect(find.text('Show lyrics automatically'), findsOneWidget);

      // Verify toggling Reduce animations
      expect(controller.reduceAnimations, isFalse);
      final reduceAnimSwitch = find.ancestor(
        of: find.text('Reduce animations'),
        matching: find.byType(SwitchListTile),
      );
      expect(reduceAnimSwitch, findsOneWidget);
      await tester.tap(reduceAnimSwitch);
      await tester.pumpAndSettle();

      expect(controller.reduceAnimations, isTrue);

      // Pop subpage back to main settings
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // 6. Test Search Bar
      final searchIcon = find.byIcon(Icons.search_rounded);
      expect(searchIcon, findsOneWidget);
      await tester.tap(searchIcon);
      await tester.pumpAndSettle();

      // Enter search query "animations"
      await tester.enterText(find.byType(TextField), 'animations');
      await tester.pumpAndSettle();

      // Verify that Reduce animations appears in search results
      expect(find.text('Reduce animations'), findsOneWidget);

      // Clean up controller
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    },
  );

  testWidgets(
    'SettingsView navigates to Account, Playback, Data-saving, and Media quality subpages',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(380, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = MusicPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsView(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Test Account subpage
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Log out'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Test Playback subpage
      await tester.tap(find.text('Playback'));
      await tester.pumpAndSettle();
      expect(find.text('Crossfade'), findsOneWidget);
      expect(find.text('Gapless Playback'), findsOneWidget);
      expect(find.text('Equalizer'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Test Data-saving subpage
      await tester.tap(find.text('Data-saving and offline'));
      await tester.pumpAndSettle();
      expect(find.text('Data Saver Mode'), findsOneWidget);
      expect(find.text('Downloads over cellular'), findsOneWidget);
      expect(find.text('Local Audio Cache'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Test Media quality subpage
      await tester.tap(find.text('Media quality'));
      await tester.pumpAndSettle();
      expect(find.text('Wi-Fi streaming quality'), findsOneWidget);
      expect(find.text('Audio download quality'), findsOneWidget);

      // Clean up
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    },
  );

  testWidgets(
    'Settings subviews use black text, subtle borders, and black sliders in Light Mode',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = MusicPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: SettingsView(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Account category in light mode
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      // Verify "Edit" button pill has black text and black icon
      final editText = tester.widget<Text>(find.text('Edit'));
      expect(editText.style?.color, AppTheme.lightTextPrimary);

      expect(
        find.byIcon(Icons.edit_rounded),
        findsWidgets,
      );

      // Verify profile card text has dark/black text
      final profileName = tester.widget<Text>(find.text('Guest'));
      expect(profileName.style?.color, AppTheme.lightTextPrimary);

      // Back to main settings
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // 2. Playback category in light mode
      await tester.tap(find.text('Playback'));
      await tester.pumpAndSettle();

      // Verify Crossfade label is dark
      final crossfadeLabel = tester.widget<Text>(find.text('Crossfade'));
      expect(crossfadeLabel.style?.color, AppTheme.lightTextPrimary);

      // Verify Slider activeTrackColor and thumbColor are black/dark in light mode
      final sliderThemeFinder = find.byType(SliderTheme);
      expect(sliderThemeFinder, findsOneWidget);
      final sliderTheme = tester.widget<SliderTheme>(sliderThemeFinder);
      expect(sliderTheme.data.activeTrackColor, AppTheme.lightPrimary);
      expect(sliderTheme.data.thumbColor, AppTheme.lightPrimary);

      // Verify Equalizer row reflects what the current platform can actually do.
      final eqSupported = AudioCapabilities.supportsEqualizer;
      final eqIcon = tester.widget<Icon>(
        find.byIcon(
          eqSupported ? Icons.tune_rounded : Icons.lock_outline_rounded,
        ),
      );
      expect(
        eqIcon.color,
        eqSupported ? AppTheme.lightPrimary : AppTheme.lightTextMuted,
      );

      final eqTitle = tester.widget<Text>(find.text('Equalizer'));
      expect(
        eqTitle.style?.color,
        eqSupported ? AppTheme.lightTextPrimary : AppTheme.lightTextMuted,
      );

      // Back to main settings
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // 3. Data-saving category in light mode
      await tester.tap(find.text('Data-saving and offline'));
      await tester.pumpAndSettle();

      final cacheTitle = tester.widget<Text>(find.text('Local Audio Cache'));
      expect(cacheTitle.style?.color, AppTheme.lightTextPrimary);

      // Back to main settings
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // 4. Media quality category in light mode
      await tester.tap(find.text('Media quality'));
      await tester.pumpAndSettle();

      final wifiTitle = tester.widget<Text>(find.text('Wi-Fi streaming quality'));
      expect(wifiTitle.style?.color, AppTheme.lightTextPrimary);

      final dlTitle = tester.widget<Text>(find.text('Audio download quality'));
      expect(dlTitle.style?.color, AppTheme.lightTextPrimary);

      // Clean up
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    },
  );

  testWidgets(
    'SettingsView marks controls the current audio engine cannot honour',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = MusicPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsView(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Playback'));
      await tester.pumpAndSettle();

      if (AudioCapabilities.supportsEqualizer) {
        final eqTile = tester.widget<ListTile>(
          find.widgetWithText(ListTile, 'Equalizer'),
        );
        expect(eqTile.onTap, isNotNull);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      } else {
        final eqTile = tester.widget<ListTile>(
          find.widgetWithText(ListTile, 'Equalizer'),
        );
        expect(eqTile.onTap, isNull);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      }

      if (AudioCapabilities.supportsLoudnessNormalization) {
        final normalize = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Normalize Volume'),
        );
        expect(normalize.onChanged, isNotNull);
      } else {
        final normalize = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Normalize Volume'),
        );
        expect(normalize.onChanged, isNull);
        expect(normalize.value, isFalse);
      }

      if (AudioCapabilities.supportsMonoAudio) {
        final mono = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Mono Audio'),
        );
        expect(mono.onChanged, isNotNull);
      } else {
        final mono = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Mono Audio'),
        );
        expect(mono.onChanged, isNull);
      }

      // The crossfade slider only works while Automix is enabled; turning
      // Automix off must visibly disable it instead of silently ignoring it.
      await tester.tap(find.widgetWithText(SwitchListTile, 'Automix'));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
      expect(find.text('Turn on Automix to use crossfade'), findsOneWidget);

      // Data-saving page: cellular-only controls are disabled on desktop.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Data-saving and offline'));
      await tester.pumpAndSettle();

      if (!AudioCapabilities.supportsCellularDataPolicy) {
        final cellular = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Downloads over cellular'),
        );
        expect(cellular.onChanged, isNull);
        expect(cellular.value, isFalse);
        expect(
          find.textContaining('Only applies on mobile devices'),
          findsOneWidget,
        );
      } else {
        final cellular = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Downloads over cellular'),
        );
        expect(cellular.onChanged, isNotNull);
        expect(
          find.textContaining('Off: songs are saved for offline use only on Wi-Fi'),
          findsOneWidget,
        );
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    },
  );

  testWidgets(
    'SettingsView hides "Cache played songs" on Windows and displays automatic cache info',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final controller = MusicPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Data-saving and offline'));
      await tester.pumpAndSettle();

      // "Cache played songs" switch tile should be removed on Windows
      expect(find.text('Cache played songs'), findsNothing);
      expect(
        find.text('Played songs are automatically stored in cache for offline listening.'),
        findsOneWidget,
      );
      expect(controller.autoCachePlayedSongs, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    },
  );

  testWidgets(
    'SettingsView shows "Cache played songs" switch tile on Android',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final controller = MusicPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Data-saving and offline'));
      await tester.pumpAndSettle();

      // "Cache played songs" switch tile should be visible on Android
      expect(find.text('Cache played songs'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    },
  );
}
