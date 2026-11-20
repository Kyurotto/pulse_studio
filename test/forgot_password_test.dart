import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/auth/password_recovery_api.dart';
import 'package:music/data/local_database.dart';
import 'package:music/views/auth_gate.dart';
import 'package:music/views/forgot_password_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeForgotPasswordAccountStore extends ForgotPasswordAccountStore {
  FakeForgotPasswordAccountStore(this.accounts);

  final Map<String, Map<String, Object?>> accounts;

  int requestCount = 0;
  String? requestedEmail;
  String? verifiedCode;
  String? completedRequestId;
  String? completedToken;
  String? completedPassword;
  String? updatedId;
  String? updatedPassword;
  String? rememberedEmail;
  String? rememberedName;
  String? savedEmail;
  String? savedPassword;

  Object? requestError;
  Object? verifyError;
  Object? completeError;

  @override
  Future<Map<String, Object?>?> findByEmail(String email) async {
    return accounts[email.trim().toLowerCase()];
  }

  @override
  Future<PasswordRecoveryRequestResult> requestOtp(String email) async {
    if (requestError != null) throw requestError!;
    requestCount++;
    requestedEmail = email.trim().toLowerCase();
    return PasswordRecoveryRequestResult(
      requestId: 'test-request-$requestCount',
      message:
          'If an eligible account exists for this address, a verification '
          'code will be sent.',
    );
  }

  @override
  Future<PasswordRecoveryVerifyResult> verifyOtp({
    required String email,
    required String code,
    required String requestId,
  }) async {
    if (verifyError != null) throw verifyError!;
    verifiedCode = code;
    if (code != '123456') {
      throw const PasswordRecoveryException('Invalid verification code.');
    }
    return const PasswordRecoveryVerifyResult(
      resetToken: 'test-reset-token',
      message: 'Code verified successfully.',
    );
  }

  @override
  Future<void> completeReset({
    required String requestId,
    required String resetToken,
    required String newPassword,
  }) async {
    if (completeError != null) throw completeError!;
    completedRequestId = requestId;
    completedToken = resetToken;
    completedPassword = newPassword;
  }

  @override
  Future<void> updatePassword({
    required String id,
    required String newPassword,
  }) async {
    updatedId = id;
    updatedPassword = newPassword;
  }

  @override
  Future<void> rememberAccount({
    required String email,
    required String displayName,
  }) async {
    rememberedEmail = email;
    rememberedName = displayName;
  }

  @override
  Future<void> savePassword({
    required String email,
    required String newPassword,
  }) async {
    savedEmail = email;
    savedPassword = newPassword;
  }
}

Map<String, Object?> localAccount({
  String id = '2',
  String email = 'musicfan@gmail.com',
  String provider = 'password',
}) {
  return {
    'id': id,
    'email': email,
    'display_name': email.split('@').first,
    'role': 'user',
    'auth_provider': provider,
  };
}

Future<void> pumpDialog(
  WidgetTester tester, {
  required FakeForgotPasswordAccountStore store,
  ValueChanged<String>? onPasswordResetSuccess,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ForgotPasswordDialog(
          accountStore: store,
          onPasswordResetSuccess: onPasswordResetSuccess,
        ),
      ),
    ),
  );
}

Finder emailField() => find.byType(TextFormField).first;

Future<void> requestCode(WidgetTester tester, String email) async {
  await tester.enterText(emailField(), email);
  await tester.tap(find.text('Send verification code'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('ForgotPasswordDialog Widget Tests', () {
    testWidgets('Email step rejects a non-Gmail address', (tester) async {
      final store = FakeForgotPasswordAccountStore({});
      await pumpDialog(tester, store: store);

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Send verification code'), findsOneWidget);

      await tester.enterText(emailField(), 'user@yahoo.com');
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid @gmail.com address.'),
        findsOneWidget,
      );
      expect(store.requestCount, 0);
    });

    testWidgets(
      'Local account must verify an emailed OTP before setting a password',
      (tester) async {
        const email = 'musicfan@gmail.com';
        final store = FakeForgotPasswordAccountStore({
          email: localAccount(email: email),
        });
        String? completedEmail;

        await pumpDialog(
          tester,
          store: store,
          onPasswordResetSuccess: (value) => completedEmail = value,
        );

        await requestCode(tester, email);

        // Step 2: the code was requested from the backend, not generated here.
        expect(store.requestCount, 1);
        expect(store.requestedEmail, email);
        expect(find.text('Verify Your Email'), findsOneWidget);
        expect(find.textContaining('mu******@gmail.com'), findsOneWidget);
        expect(find.text('Verify code'), findsOneWidget);
        expect(find.text('Set New Password'), findsNothing);

        // Wrong code stays on the OTP step.
        await tester.enterText(find.byType(TextFormField).first, '000000');
        await tester.tap(find.text('Verify code'));
        await tester.pumpAndSettle();

        expect(store.verifiedCode, '000000');
        expect(find.text('Invalid verification code.'), findsOneWidget);
        expect(find.text('Set New Password'), findsNothing);

        // Correct code unlocks the new-password step.
        await tester.enterText(find.byType(TextFormField).first, '123456');
        await tester.tap(find.text('Verify code'));
        await tester.pumpAndSettle();

        expect(find.text('Set New Password'), findsOneWidget);
        expect(
          find.textContaining('Set a new password for $email'),
          findsOneWidget,
        );

        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));

        // The new-password fields participate in system autofill.
        expect(find.byType(AutofillGroup), findsOneWidget);
        final textFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(
          textFields.every(
            (field) =>
                field.autofillHints?.contains(AutofillHints.newPassword) ??
                false,
          ),
          isTrue,
        );

        // Mismatched confirmation is rejected.
        await tester.enterText(fields.at(0), 'SecretPass123');
        await tester.enterText(fields.at(1), 'DifferentPass');
        await tester.tap(find.text('Reset password'));
        await tester.pumpAndSettle();

        expect(find.text('Passwords do not match.'), findsOneWidget);
        expect(store.updatedId, isNull);

        // Matching confirmation completes the reset and saves the local hash.
        await tester.enterText(fields.at(1), 'SecretPass123');
        await tester.tap(find.text('Reset password'));
        await tester.pumpAndSettle();

        expect(store.completedRequestId, 'test-request-1');
        expect(store.completedToken, 'test-reset-token');
        expect(store.completedPassword, 'SecretPass123');
        expect(store.updatedId, '2');
        expect(store.updatedPassword, 'SecretPass123');
        expect(store.rememberedEmail, email);
        expect(store.rememberedName, 'musicfan');
        expect(store.savedEmail, email);
        expect(store.savedPassword, 'SecretPass123');
        expect(find.text('Password Reset Successfully!'), findsOneWidget);

        await tester.tap(find.text('Back to Sign in'));
        await tester.pumpAndSettle();

        expect(completedEmail, email);
      },
    );

    testWidgets('Unknown email shows a clear error and does not send an OTP', (
      tester,
    ) async {
      final store = FakeForgotPasswordAccountStore({});
      await pumpDialog(tester, store: store);

      await requestCode(tester, 'nobody@gmail.com');

      expect(store.requestCount, 0);
      expect(
        find.text(
          'No Pulse Studio account found for nobody@gmail.com. '
          'Check the address or create a new account.',
        ),
        findsOneWidget,
      );
      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Verify Your Email'), findsNothing);
    });

    testWidgets('OTP delivery failure keeps the user on the email step', (
      tester,
    ) async {
      const email = 'musicfan@gmail.com';
      final store =
          FakeForgotPasswordAccountStore({email: localAccount(email: email)})
            ..requestError = const PasswordRecoveryException(
              'Unable to send verification code. Please try again later.',
            );
      await pumpDialog(tester, store: store);

      await requestCode(tester, email);

      expect(
        find.text('Unable to send verification code. Please try again later.'),
        findsOneWidget,
      );
      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Verify Your Email'), findsNothing);
    });

    testWidgets('Resend becomes available after the cooldown', (tester) async {
      const email = 'musicfan@gmail.com';
      final store = FakeForgotPasswordAccountStore({
        email: localAccount(email: email),
      });
      await pumpDialog(tester, store: store);

      await requestCode(tester, email);
      expect(store.requestCount, 1);
      expect(find.textContaining('Resend in '), findsOneWidget);

      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Resend code'), findsOneWidget);

      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();

      expect(store.requestCount, 2);
      expect(
        find.text('A new verification code has been sent.'),
        findsOneWidget,
      );
      expect(find.text('Verify Your Email'), findsOneWidget);
    });

    testWidgets('Expired code cannot be verified', (tester) async {
      const email = 'musicfan@gmail.com';
      final store = FakeForgotPasswordAccountStore({
        email: localAccount(email: email),
      });
      await pumpDialog(tester, store: store);

      await requestCode(tester, email);
      await tester.pump(const Duration(seconds: 301));

      await tester.enterText(find.byType(TextFormField).first, '123456');
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();

      expect(
        find.text('Verification code has expired. Please request a new one.'),
        findsOneWidget,
      );
      expect(store.verifiedCode, isNull);
      expect(find.text('Set New Password'), findsNothing);
    });

    testWidgets(
      'AuthView shows "Forgot password?" in sign-in mode and hides in register mode',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(const MaterialApp(home: AuthView()));

        expect(find.text('Forgot password?'), findsOneWidget);

        // Switch to register mode
        final createAccountBtn = find.text('Create account').last;
        await tester.ensureVisible(createAccountBtn);
        await tester.tap(createAccountBtn);
        await tester.pumpAndSettle();

        // Forgot password should now be hidden
        expect(find.text('Forgot password?'), findsNothing);

        // Switch back to sign-in mode
        final signInBtn = find.text('Sign in').last;
        await tester.ensureVisible(signInBtn);
        await tester.tap(signInBtn);
        await tester.pumpAndSettle();

        expect(find.text('Forgot password?'), findsOneWidget);
      },
    );
  });

  group('LocalDatabase.updatePasswordHash', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      LocalDatabase.setDatabaseForTesting(db);
      await LocalDatabase.instance.createAllTables(db);
      await LocalDatabase.instance.initialize();
    });

    tearDown(() async {
      await db.close();
      LocalDatabase.setDatabaseForTesting(null);
    });

    test('replaces the password without clearing recovery details', () async {
      const email = 'recovery@gmail.com';
      await LocalDatabase.instance.saveUser(
        id: '2',
        email: email,
        displayName: 'Recovery User',
        passwordHash: LocalDatabase.hashPassword('OldPass123'),
        backupEmail: 'backup@yahoo.com',
        phoneNumber: '+639171234567',
      );

      await LocalDatabase.instance.updatePasswordHash(
        id: '2',
        newPassword: 'NewPass456',
      );

      expect(
        await LocalDatabase.instance.verifyLocalPassword(email, 'OldPass123'),
        isNull,
      );
      final verified = await LocalDatabase.instance.verifyLocalPassword(
        email,
        'NewPass456',
      );
      expect(verified, isNotNull);
      expect(verified!['backup_email'], 'backup@yahoo.com');
      expect(verified['phone_number'], '+639171234567');
    });

    test('rejects short passwords and unknown accounts', () async {
      await LocalDatabase.instance.saveUser(
        id: '3',
        email: 'short@gmail.com',
        displayName: 'Short User',
        passwordHash: LocalDatabase.hashPassword('OldPass123'),
      );

      expect(
        () => LocalDatabase.instance.updatePasswordHash(
          id: '3',
          newPassword: '12345',
        ),
        throwsArgumentError,
      );
      expect(
        () => LocalDatabase.instance.updatePasswordHash(
          id: 'missing-user',
          newPassword: 'NewPass456',
        ),
        throwsStateError,
      );
    });
  });
}
