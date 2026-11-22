import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/auth/auth_service.dart';
import 'package:music/data/local_database.dart';
import 'package:music/services/biometric_auth_service.dart';
import 'package:music/theme/app_theme.dart';
import 'package:music/views/auth_gate.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'biometric_auth_service_test.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        display_name TEXT NOT NULL,
        photo_url TEXT,
        role TEXT NOT NULL DEFAULT 'user',
        auth_provider TEXT NOT NULL,
        password_hash TEXT,
        backup_email TEXT,
        phone_number TEXT,
        created_at INTEGER NOT NULL DEFAULT 0,
        last_login_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_sessions (
        user_id TEXT PRIMARY KEY,
        saved_at INTEGER NOT NULL
      )
    ''');
    LocalDatabase.setDatabaseForTesting(db);
    await AuthService.instance.signOut();
  });

  tearDown(() async {
    await AuthService.instance.signOut();
    LocalDatabase.setDatabaseForTesting(null);
  });

  Widget buildTestWidget() {
    return MaterialApp(theme: AppTheme.darkTheme, home: const AuthGate());
  }

  testWidgets(
    'AuthGate shows normal password form (AuthView) when no session exists',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to continue to Pulse Studio.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
      expect(find.byType(BiometricLockView), findsNothing);
    },
  );

  testWidgets(
    'AuthGate shows AuthView instead of BiometricLockView on desktop when app is locked',
    (WidgetTester tester) async {
      final fakeAuth = FakeLocalAuthentication();
      BiometricAuthService.instance = BiometricAuthService(localAuth: fakeAuth);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(BiometricLockView), findsNothing);
      expect(find.byType(AuthView), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  testWidgets(
    'BiometricLockView renders lock UI with account info and unlock options',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testUser = LocalUser(
        id: 'test_user_1',
        email: 'john@example.com',
        displayName: 'John Laurence',
        role: 'user',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const BiometricLockView(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pulse Studio Locked'), findsOneWidget);
      expect(find.text('Welcome back, John Laurence'), findsOneWidget);
      expect(find.text('john@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
      expect(find.text('Use Password Instead'), findsOneWidget);
    },
  );

  testWidgets(
    'BiometricLockView displays error message when biometric unlock fails',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Inject failing biometric service
      final fakeAuth = FakeLocalAuthentication(authResult: false);
      BiometricAuthService.instance = BiometricAuthService(localAuth: fakeAuth);

      const testUser = LocalUser(
        id: 'test_user_2',
        email: 'user2@example.com',
        displayName: 'User Two',
        role: 'user',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const BiometricLockView(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      // Tap unlock button
      final unlockBtn = find.byType(ElevatedButton);
      expect(unlockBtn, findsOneWidget);
      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      // Verify error message is displayed and view remains locked
      expect(
        find.textContaining('Biometric verification was not completed'),
        findsOneWidget,
      );
      expect(find.text('Pulse Studio Locked'), findsOneWidget);
    },
  );

  testWidgets(
    'BiometricLockView Use Password Instead calls lockToPasswordSignIn and clears session',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testUser = LocalUser(
        id: 'test_user_3',
        email: 'user3@example.com',
        displayName: 'User Three',
        role: 'user',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const BiometricLockView(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      final usePasswordBtn = find.widgetWithText(
        TextButton,
        'Use Password Instead',
      );
      expect(usePasswordBtn, findsOneWidget);

      await tester.tap(usePasswordBtn);
      // The lock is cleared only after clearActiveSession() succeeds, so wait
      // for the real database cleanup instead of pumping simulated time.
      expect(AuthService.instance.isAppLocked, isTrue);
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump();
        if (!AuthService.instance.isAppLocked) break;
      }

      expect(AuthService.instance.currentUser, isNull);
      expect(AuthService.instance.isAppLocked, isFalse);
    },
  );
}
