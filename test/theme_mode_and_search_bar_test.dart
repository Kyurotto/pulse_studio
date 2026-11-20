import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/main.dart';
import 'package:music/theme/app_theme.dart';
import 'package:music/views/settings_view.dart';

void main() {
  group('Theme Mode Settings Tests', () {
    test('AppTheme switches between dark, light, and system modes and persists', () async {
      await AppTheme.setThemeMode(ThemeMode.dark, save: false);
      expect(AppTheme.themeMode, ThemeMode.dark);
      expect(AppTheme.isDark(), isTrue);

      await AppTheme.setThemeMode(ThemeMode.light, save: false);
      expect(AppTheme.themeMode, ThemeMode.light);
      expect(AppTheme.isDark(), isFalse);

      await AppTheme.setThemeMode(ThemeMode.system, save: false);
      expect(AppTheme.themeMode, ThemeMode.system);
    });

    testWidgets('SettingsView displays Theme tile and allows choosing dark, light, auto modes', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open Content and display category
      await tester.tap(find.text('Content and display'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Theme tile is present
      expect(find.text('Theme'), findsOneWidget);

      // Tap Theme tile to open dialog
      await tester.tap(find.text('Theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Choose theme dialog options
      expect(find.text('Choose theme'), findsOneWidget);
      expect(find.text('Dark mode'), findsWidgets);
      expect(find.text('Light mode'), findsOneWidget);
      expect(find.text('Auto (System)'), findsWidgets);

      // Select Light mode
      await tester.tap(find.text('Light mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify mode updated
      expect(AppTheme.themeMode, ThemeMode.light);
      expect(find.text('Light mode'), findsOneWidget);

      // Tap Theme again to select Auto (System)
      await tester.tap(find.text('Theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Auto (System)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(AppTheme.themeMode, ThemeMode.system);
      expect(find.text('Auto (System)'), findsWidgets);

      // Clean up & drain sqflite transaction warning timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Dashboard Scaffold changes to light background when ThemeMode.light is active', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await AppTheme.setThemeMode(ThemeMode.light, save: false);

      await tester.pumpWidget(const MusicApp(firebaseEnabled: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsWidgets);
      final scaffoldWidget = tester.widget<Scaffold>(scaffoldFinder.first);
      expect(scaffoldWidget.backgroundColor, AppTheme.lightBackground);

      // Switch to dark mode
      await AppTheme.setThemeMode(ThemeMode.dark, save: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final darkScaffold = tester.widget<Scaffold>(scaffoldFinder.first);
      expect(darkScaffold.backgroundColor, AppTheme.background);

      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Search Bar Visibility Scope Tests', () {
    testWidgets('Search bar displays on Dashboard, but NOT on Explore or Library', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MusicApp(firebaseEnabled: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Dashboard / Home Tab (currentNavIndex == 0)
      // Search bar MUST be present
      expect(
        find.widgetWithText(TextField, 'Search songs, artists, albums...'),
        findsOneWidget,
        reason: 'Dashboard must display the search bar',
      );

      // 2. Switch to Explore Tab (currentNavIndex == 1)
      await tester.tap(find.text('Explore'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Search bar MUST NOT be displayed on Explore
      expect(
        find.widgetWithText(TextField, 'Search songs, artists, albums...'),
        findsNothing,
        reason: 'Explore tab must NOT display the search bar',
      );
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'Explore tab has no search bar at all',
      );

      // 3. Switch to Library Tab (currentNavIndex == 2)
      await tester.tap(find.text('Library'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Search bar MUST NOT be displayed on Library
      expect(
        find.widgetWithText(TextField, 'Search songs, artists, albums...'),
        findsNothing,
        reason: 'Library tab must NOT display the search bar',
      );
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'Library tab has no search bar at all',
      );

      // 4. Switch back to Home / Dashboard (currentNavIndex == 0)
      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Search bar MUST display again on Dashboard
      expect(
        find.widgetWithText(TextField, 'Search songs, artists, albums...'),
        findsOneWidget,
        reason: 'Returning to Dashboard must display the search bar again',
      );

      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
