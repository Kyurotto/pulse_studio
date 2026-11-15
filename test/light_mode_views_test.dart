import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/main.dart';
import 'package:music/theme/app_theme.dart';
import 'package:music/views/listening_stats_view.dart';
import 'package:music/views/recents_view.dart';

void main() {
  testWidgets('ListeningStatsView adapts to Light Mode correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const ListeningStatsView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(AppTheme.lightBackground));

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, equals(AppTheme.lightSurface));

    expect(find.text('Listening Stats'), findsOneWidget);

    final emptyTitle = tester.widget<Text>(find.text('No listening history yet'));
    expect(emptyTitle.style?.color, equals(AppTheme.lightTextPrimary));
  });

  testWidgets('RecentsView adapts to Light Mode correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const RecentsView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(AppTheme.lightBackground));

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, equals(AppTheme.lightSurface));

    expect(find.text('Recents'), findsOneWidget);

    final emptyTitle = tester.widget<Text>(find.text('Nothing played yet'));
    expect(emptyTitle.style?.color, equals(AppTheme.lightTextPrimary));
  });

  testWidgets('Your Updates modal adapts to Light Mode correctly', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MusicApp(firebaseEnabled: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Open drawer via menu button
    final menuButton = find.byTooltip('Open menu');
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Tap "Your Updates"
    final yourUpdates = find.text('Your Updates');
    expect(yourUpdates, findsOneWidget);
    await tester.tap(yourUpdates);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Now modal bottom sheet should be open
    expect(find.text('Now Playing Artwork & Action Buttons'), findsOneWidget);
    expect(find.text('10-Band Graphic Equalizer'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}

