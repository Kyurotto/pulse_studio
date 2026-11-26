import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/auth/auth_service.dart';
import 'package:music/auth/saved_credential_store.dart';
import 'package:music/data/local_database.dart';
import 'package:music/services/biometric_auth_service.dart';
import 'package:music/theme/app_theme.dart';
import 'package:music/views/auth_gate.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'biometric_auth_service_test.dart';

class MemorySavedCredentialStore extends SavedCredentialStore {
  MemorySavedCredentialStore([Map<String, String>? initial])
    : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<void> savePassword(String email, String password) async {
    values[email.trim().toLowerCase()] = password;
  }

  @override
  Future<String?> readPassword(String email) async {
    return values[email.trim().toLowerCase()];
  }

  @override
  Future<void> deletePassword(String email) async {
    values.remove(email.trim().toLowerCase());
  }
}

/// Pumps frames while allowing real SQLite / platform-channel futures to
/// complete. `pumpAndSettle` alone can return before `AuthView`'s initState
/// database reads finish, which makes the first frame flaky.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String description = 'condition',
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump();
    if (condition()) {
      // Do not call pumpAndSettle here: the sign-in button may still show
      // its progress spinner while the awaited credential writes finish.
      // Callers that need the spinner gone use settlePlatformWork().
      await tester.pump();
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
  }
  fail('Timed out waiting for $description');
}

/// Current text in the first (email) field, or null before it is built.
String? emailFieldText(WidgetTester tester) {
  final fields = find.byType(TextFormField).evaluate();
  if (fields.isEmpty) return null;
  return tester
      .widget<TextFormField>(find.byType(TextFormField).first)
      .controller
      ?.text;
}

/// Gives non-UI futures (secure storage, biometric settings) time to finish.
Future<void> settlePlatformWork(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

/// Runs the test as a desktop build, where the manual fingerprint button is
/// still shown under the Sign in button.
void useDesktopPlatform() {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}

/// Runs the test as a phone build, where the fingerprint button is hidden and
/// the prompt opens from a saved-account tap.
void usePhonePlatform() {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}

void main() {
  const email = 'johnlaurencenovicio@gmail.com';
  const password = 'Secret123';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late MemorySavedCredentialStore credentials;
  late FakeLocalAuthentication fakeLocalAuth;
  late BiometricAuthService biometrics;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    LocalDatabase.setDatabaseForTesting(db);
    await LocalDatabase.instance.createAllTables(db);
    await LocalDatabase.instance.saveUser(
      id: '2',
      email: email,
      displayName: 'John Laurence',
      passwordHash: LocalDatabase.hashPassword(password),
    );
    await LocalDatabase.instance.saveRememberedAccount(
      email: email,
      displayName: 'John Laurence',
    );
    await BiometricAuthService(
      localAuth: FakeLocalAuthentication(),
    ).enableBiometricUnlock('2');

    credentials = MemorySavedCredentialStore({email: password});
    fakeLocalAuth = FakeLocalAuthentication(authResult: true);
    biometrics = BiometricAuthService(localAuth: fakeLocalAuth);

    await AuthService.instance.signOut();
  });

  tearDown(() async {
    await AuthService.instance.signOut();
    LocalDatabase.setDatabaseForTesting(null);
    await db.close();
  });

  Widget buildAuthView() {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: AuthView(
        key: UniqueKey(),
        credentialStore: credentials,
        biometricService: biometrics,
      ),
    );
  }

  testWidgets(
    'tapping a saved account prompts fingerprint and signs in automatically',
    (tester) async {
      useDesktopPlatform();
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildAuthView());
      await pumpUntil(
        tester,
        () => find.byIcon(Icons.arrow_drop_down_rounded).evaluate().isNotEmpty,
        description: 'saved accounts dropdown icon ready',
      );
      await settlePlatformWork(tester);

      // Saved accounts are not pre-filled on the login screen at startup so
      // neither the email nor the password is leaked when reopening the app.
      expect(find.text('Saved accounts'), findsNothing);
      expect(find.text('Sign in with fingerprint'), findsNothing);

      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller?.text, isEmpty);
      expect(fields[1].controller?.text, isEmpty);

      await tester.tap(find.text('Email address'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Saved accounts'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget);
      // The account advertises that fingerprint is ready for it.
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);

      // One tap on the saved account fills the email (never exposing the
      // password in the field), opens the device biometric prompt, and signs
      // in with the stored password once verified.
      await tester.tap(find.text('••••••••'));
      await pumpUntil(
        tester,
        () => AuthService.instance.currentUser != null,
        description: 'fingerprint sign-in from saved account tap',
      );
      await settlePlatformWork(tester);

      expect(find.text('Saved accounts'), findsNothing);
      expect(fields[0].controller?.text, email);
      expect(fields[1].controller?.text, isEmpty);
      expect(fakeLocalAuth.lastLocalizedReason, contains('Pulse Studio'));
      expect(AuthService.instance.currentUser, isA<LocalUser>());
      expect((AuthService.instance.currentUser as LocalUser).id, '2');
    },
  );

  testWidgets('choosing an account from the floating menu fills both fields', (
    tester,
  ) async {
    useDesktopPlatform();
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Turn fingerprint off so this test isolates the dropdown's autofill
    // behavior. Automatic fingerprint sign-in is covered by the first test.
    fakeLocalAuth.availableBiometrics = [];
    fakeLocalAuth.isSupported = false;
    await tester.runAsync(() => biometrics.disableBiometricUnlock());

    await tester.pumpWidget(buildAuthView());
    await pumpUntil(
      tester,
      () => find.byIcon(Icons.arrow_drop_down_rounded).evaluate().isNotEmpty,
      description: 'saved accounts dropdown icon ready',
    );
    await settlePlatformWork(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'someone.else@example.com');
    await tester.enterText(fields.at(1), 'different1');
    await tester.pumpAndSettle();

    // Editing the email clears the remembered selection.
    expect(find.text('Sign in with fingerprint'), findsNothing);

    await tester.tap(find.text('Email address'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Saved accounts'), findsOneWidget);

    await tester.tap(find.text('••••••••'));
    await tester.pumpAndSettle();

    final updated = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(updated[0].controller?.text, email);
    expect(updated[1].controller?.text, isEmpty);
    expect(find.text('Saved accounts'), findsNothing);
    // No biometric prompt without fingerprint setup; password stays hidden.
    expect(fakeLocalAuth.lastLocalizedReason, isNull);
    expect(find.text('Sign in with fingerprint'), findsNothing);
  });

  testWidgets(
    'signing in with Remember me saves the account and enables fingerprint for the next login',
    (tester) async {
      useDesktopPlatform();
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start from a clean, first-time state. Real SQLite futures must run
      // through runAsync inside a widget test.
      await tester.runAsync(() async {
        await LocalDatabase.instance.removeRememberedAccount(email);
        await biometrics.disableBiometricUnlock();
      });
      credentials.values.clear();

      await tester.pumpWidget(buildAuthView());
      await settlePlatformWork(tester);

      // No inline saved-account panel, and no popup until the email field
      // is tapped.
      expect(find.text('Saved accounts'), findsNothing);
      expect(find.text('Sign in with fingerprint'), findsNothing);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await pumpUntil(
        tester,
        () => AuthService.instance.userEmail == email,
        description: 'password sign-in',
      );
      await settlePlatformWork(tester);

      expect(AuthService.instance.userEmail, email);
      final savedPassword = await tester.runAsync(
        () => credentials.readPassword(email),
      );
      expect(savedPassword, password);

      final remembered = await tester.runAsync(
        () => LocalDatabase.instance.getRememberedAccounts(),
      );
      expect(
        remembered!.any(
          (row) => (row['email'] as String?)?.toLowerCase() == email,
        ),
        isTrue,
      );
      final fingerprintEnabled = await tester.runAsync(
        () => biometrics.isBiometricUnlockEnabled('2'),
      );
      expect(fingerprintEnabled, isTrue);

      // Signing out must keep the fingerprint configuration, while keeping
      // the login fields blank on reopen.
      await tester.runAsync(() => AuthService.instance.signOut());
      await tester.pumpWidget(buildAuthView());
      await pumpUntil(
        tester,
        () => find.byIcon(Icons.arrow_drop_down_rounded).evaluate().isNotEmpty,
        description: 'saved accounts dropdown after sign-out',
      );
      await settlePlatformWork(tester);

      expect(emailFieldText(tester), isEmpty);
      expect(find.text('Saved accounts'), findsNothing);
      expect(find.text('Sign in with fingerprint'), findsNothing);

      await tester.tap(find.text('Email address'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Saved accounts'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget);
    },
  );

  testWidgets(
    'saved account without a stored password shows no validation error',
    (tester) async {
      useDesktopPlatform();
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      credentials.values.clear();
      // Simulate a device without enrolled biometrics for this validation
      // test. The fallback for password-less accounts with biometrics is
      // covered by the next test.
      fakeLocalAuth.availableBiometrics = [];
      fakeLocalAuth.isSupported = false;

      await tester.pumpWidget(buildAuthView());
      await pumpUntil(
        tester,
        () => find.byIcon(Icons.arrow_drop_down_rounded).evaluate().isNotEmpty,
        description: 'saved accounts dropdown icon ready',
      );
      await settlePlatformWork(tester);

      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller?.text, isEmpty);
      expect(fields[1].controller?.text, isEmpty);
      expect(find.text('Use at least 6 characters.'), findsNothing);
      // No saved password and no enrolled biometrics means there is nothing
      // to submit after a biometric check, so fingerprint is not offered.
      expect(find.text('Sign in with fingerprint'), findsNothing);
      expect(
        find.text('Saved password filled — tap the eye icon to view it.'),
        findsNothing,
      );

      await tester.tap(find.text('Email address'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Saved accounts'), findsOneWidget);
      expect(find.text('Password not saved'), findsOneWidget);
      expect(find.text('Use at least 6 characters.'), findsNothing);
    },
  );

  testWidgets(
    'password-less saved account signs in with fingerprint via local fallback',
    (tester) async {
      useDesktopPlatform();
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // This is the state left by older builds: the account is remembered and
      // has a local password hash, but no plaintext password and no biometric
      // toggle were ever stored on the device.
      await tester.runAsync(() async {
        credentials.values.clear();
        await biometrics.disableBiometricUnlock();
      });

      await tester.pumpWidget(buildAuthView());
      await pumpUntil(
        tester,
        () => find.byIcon(Icons.arrow_drop_down_rounded).evaluate().isNotEmpty,
        description: 'saved accounts dropdown icon ready',
      );
      await settlePlatformWork(tester);

      expect(emailFieldText(tester), isEmpty);
      expect(find.text('Sign in with fingerprint'), findsNothing);
      await tester.tap(find.text('Email address'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Saved accounts'), findsOneWidget);
      expect(find.text('Fingerprint sign-in ready'), findsOneWidget);
      expect(find.text('Password not saved'), findsNothing);

      await tester.tap(find.text('Fingerprint sign-in ready'));
      await pumpUntil(
        tester,
        () => AuthService.instance.currentUser != null,
        description: 'fingerprint sign-in with local fallback',
      );
      await settlePlatformWork(tester);

      expect(fakeLocalAuth.lastLocalizedReason, contains('Pulse Studio'));
      expect(AuthService.instance.currentUser, isA<LocalUser>());
      expect((AuthService.instance.currentUser as LocalUser).id, '2');

      final enabled = await tester.runAsync(
        () => biometrics.isBiometricUnlockEnabled('2'),
      );
      expect(enabled, isTrue);
    },
  );

  testWidgets(
    'unchecking Remember me forgets the account and disables fingerprint',
    (tester) async {
      usePhonePlatform();
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildAuthView());
      await pumpUntil(
        tester,
        () => find.byIcon(Icons.arrow_drop_down_rounded).evaluate().isNotEmpty,
        description: 'saved accounts dropdown icon ready',
      );
      await settlePlatformWork(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await pumpUntil(
        tester,
        () => AuthService.instance.currentUser != null,
        description: 'password sign-in with Remember me unchecked',
      );
      await settlePlatformWork(tester);

      final remembered = await tester.runAsync(
        () => LocalDatabase.instance.getRememberedAccounts(),
      );
      final savedPassword = await tester.runAsync(
        () => credentials.readPassword(email),
      );
      final fingerprintEnabled = await tester.runAsync(
        () => biometrics.isBiometricUnlockEnabled('2'),
      );
      expect(remembered, isEmpty);
      expect(savedPassword, isNull);
      expect(fingerprintEnabled, isFalse);
    },
  );

  testWidgets(
    'phone hides the fingerprint button and a saved account tap still prompts',
    (tester) async {
      usePhonePlatform();
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildAuthView());
      await pumpUntil(
        tester,
        () => find.byIcon(Icons.arrow_drop_down_rounded).evaluate().isNotEmpty,
        description: 'saved accounts dropdown icon ready',
      );
      await settlePlatformWork(tester);

      // Phones hide the manual button; the prompt opens from the account tap.
      expect(find.text('Sign in with fingerprint'), findsNothing);

      await tester.tap(find.text('Email address'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Saved accounts'), findsOneWidget);

      await tester.tap(find.text('••••••••'));
      await pumpUntil(
        tester,
        () => AuthService.instance.currentUser != null,
        description: 'fingerprint sign-in from a phone saved account tap',
      );
      await settlePlatformWork(tester);

      expect(fakeLocalAuth.lastLocalizedReason, contains('Pulse Studio'));
      expect(AuthService.instance.currentUser, isA<LocalUser>());
    },
  );
}
