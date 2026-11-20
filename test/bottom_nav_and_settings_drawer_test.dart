import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/main.dart';
import 'package:music/widgets/sidebar_nav.dart';

void main() {
  testWidgets(
    'Bottom navigation layer renders Home, Explore, and Library with icons and labels on mobile',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MusicApp(firebaseEnabled: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify bottom navigation icons exist with size 22 in bottom bar
      final homeFinder = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.home_rounded && w.size == 22.0,
      );
      final exploreFinder = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.explore_rounded && w.size == 22.0,
      );
      final libraryFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == Icons.library_music_rounded &&
            w.size == 22.0,
      );

      expect(homeFinder, findsOneWidget);
      expect(exploreFinder, findsOneWidget);
      expect(libraryFinder, findsOneWidget);

      // Verify bottom layer items labels exist
      expect(find.textContaining('Home'), findsWidgets);
      expect(find.textContaining('Explore'), findsWidgets);
      expect(find.textContaining('Library'), findsWidgets);

      // Tap Library in bottom layer
      await tester.tap(libraryFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Home in bottom layer
      await tester.tap(homeFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets(
    'Top header contains full-width single-line search bar without redundant notifications or settings icons',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MusicApp(firebaseEnabled: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify search input is present in the top header
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Verify notifications and settings icons are removed from top bar
      expect(find.byTooltip('Notifications'), findsNothing);
      expect(find.byTooltip('Settings'), findsNothing);
    },
  );

  testWidgets('Left hamburger opens the drawer with account shortcuts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MusicApp(firebaseEnabled: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final menuButton = find.byTooltip('Open menu');
    expect(menuButton, findsOneWidget);
    expect(
      find.descendant(
        of: menuButton,
        matching: find.byIcon(Icons.menu_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(menuButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    expect(find.text('Listening stats'), findsOneWidget);
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Your Updates'), findsOneWidget);
    expect(find.text('Settings and privacy'), findsOneWidget);
  });

  testWidgets(
    'Desktop removes duplicate sidebar from dashboard; left hamburger opens drawer',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MusicApp(firebaseEnabled: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify duplicate sidebar items are removed from the dashboard body
      expect(find.byType(SidebarNav), findsNothing);

      // 2. No right hamburger / Navigation menu tooltip
      expect(find.byTooltip('Navigation menu'), findsNothing);

      // 3. Left hamburger exists on desktop and opens drawer with account shortcuts
      final openMenuBtn = find.byTooltip('Open menu');
      expect(openMenuBtn, findsOneWidget);
      await tester.tap(openMenuBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final drawerFinder = find.byType(Drawer);
      expect(find.descendant(of: drawerFinder, matching: find.text('View profile')), findsOneWidget);
      expect(find.descendant(of: drawerFinder, matching: find.text('Listening stats')), findsOneWidget);
      expect(find.descendant(of: drawerFinder, matching: find.text('Recents')), findsOneWidget);
      expect(find.descendant(of: drawerFinder, matching: find.text('Your Updates')), findsOneWidget);
      expect(find.descendant(of: drawerFinder, matching: find.text('Settings and privacy')), findsOneWidget);
    },
  );

  testWidgets(
    'Phone view does not include right hamburger menu button',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MusicApp(firebaseEnabled: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Phone must NOT have the right navigation menu hamburger
      expect(find.byTooltip('Navigation menu'), findsNothing);

      // Phone still has the left drawer menu
      expect(find.byTooltip('Open menu'), findsOneWidget);
    },
  );
}
