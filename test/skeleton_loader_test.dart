import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/theme/app_theme.dart';
import 'package:music/widgets/skeleton_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildThemedSkeleton(Widget child, {ThemeMode mode = ThemeMode.dark}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('Skeleton Loader Widget Tests', () {
    testWidgets('DashboardSkeleton renders discovery rail placeholders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildThemedSkeleton(
          const DashboardSkeleton(reduceAnimations: false),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DashboardSkeleton), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('DashboardSkeleton renders cleanly in light mode', (tester) async {
      await tester.pumpWidget(
        buildThemedSkeleton(
          const DashboardSkeleton(reduceAnimations: false),
          mode: ThemeMode.light,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DashboardSkeleton), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('ExploreSkeleton renders radio carousel placeholders', (tester) async {
      await tester.pumpWidget(
        buildThemedSkeleton(
          const ExploreSkeleton(reduceAnimations: false),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ExploreSkeleton), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('LibrarySkeletonGrid renders responsive playlist grid placeholders', (tester) async {
      await tester.pumpWidget(
        buildThemedSkeleton(
          const LibrarySkeletonGrid(reduceAnimations: false),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LibrarySkeletonGrid), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('LibrarySkeleton renders full library header and cards placeholders', (tester) async {
      await tester.pumpWidget(
        buildThemedSkeleton(
          const LibrarySkeleton(reduceAnimations: false),
          mode: ThemeMode.light,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LibrarySkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('ShimmerLoading respects reduceAnimations=true and disables animation sweep', (tester) async {
      await tester.pumpWidget(
        buildThemedSkeleton(
          const DashboardSkeleton(reduceAnimations: true),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // When reduceAnimations is true, ShaderMask is bypassed and child is rendered directly
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(DashboardSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });
  });
}
