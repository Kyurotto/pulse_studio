import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:music/data/local_database.dart';
import 'package:music/services/biometric_auth_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeLocalAuthentication extends Fake implements LocalAuthentication {
  FakeLocalAuthentication({
    this.canCheck = true,
    this.isSupported = true,
    this.availableBiometrics = const [BiometricType.fingerprint],
    this.authResult = true,
    this.authException,
    this.authenticateException,
    this.busyRetriesRemaining = 0,
  });

  bool canCheck;
  bool isSupported;
  List<BiometricType> availableBiometrics;
  bool authResult;
  Exception? authException;
  LocalAuthException? authenticateException;
  int busyRetriesRemaining = 0;
  int authenticateCalls = 0;

  String? lastLocalizedReason;
  bool? lastBiometricOnly;
  bool? lastPersistAcrossBackgrounding;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (authException != null) throw authException!;
    return availableBiometrics;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalls++;
    lastLocalizedReason = localizedReason;
    lastBiometricOnly = biometricOnly;
    lastPersistAcrossBackgrounding = persistAcrossBackgrounding;
    if (busyRetriesRemaining > 0) {
      busyRetriesRemaining--;
      throw const LocalAuthException(
        code: LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
      );
    }
    if (authenticateException != null) throw authenticateException!;
    if (authException != null) throw authException!;
    return authResult;
  }
}

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
    LocalDatabase.setDatabaseForTesting(db);
  });

  tearDown(() async {
    LocalDatabase.setDatabaseForTesting(null);
  });

  group('BiometricAuthService', () {
    test('reports biometric enrollment when methods exist', () async {
      final fakeAuth = FakeLocalAuthentication(
        availableBiometrics: [BiometricType.fingerprint],
      );
      final service = BiometricAuthService(localAuth: fakeAuth);

      final enrolled = await service.isBiometricEnrolled();
      expect(enrolled, isTrue);
    });

    test('reports biometric unavailable when no methods enrolled', () async {
      final fakeAuth = FakeLocalAuthentication(
        availableBiometrics: [],
      );
      final service = BiometricAuthService(localAuth: fakeAuth);

      final enrolled = await service.isBiometricEnrolled();
      expect(enrolled, isFalse);
    });

    test('reports false when getAvailableBiometrics throws an exception', () async {
      final fakeAuth = FakeLocalAuthentication(
        authException: Exception('Hardware unavailable'),
      );
      final service = BiometricAuthService(localAuth: fakeAuth);

      final enrolled = await service.isBiometricEnrolled();
      expect(enrolled, isFalse);
    });

    test('authenticateForUnlock returns true on successful prompt', () async {
      final fakeAuth = FakeLocalAuthentication(authResult: true);
      final service = BiometricAuthService(localAuth: fakeAuth);

      final success = await service.authenticateForUnlock();
      expect(success, isTrue);
      expect(fakeAuth.lastPersistAcrossBackgrounding, isTrue);
      if (defaultTargetPlatform == TargetPlatform.windows) {
        expect(fakeAuth.lastBiometricOnly, isFalse);
      } else {
        expect(fakeAuth.lastBiometricOnly, isTrue);
      }
    });

    test('authenticateForUnlock returns false on cancellation or failure', () async {
      final fakeAuth = FakeLocalAuthentication(authResult: false);
      final service = BiometricAuthService(localAuth: fakeAuth);

      final success = await service.authenticateForUnlock();
      expect(success, isFalse);
    });

    test('authenticateForUnlock returns false on exception', () async {
      final fakeAuth = FakeLocalAuthentication(
        authException: Exception('Sensor locked out'),
      );
      final service = BiometricAuthService(localAuth: fakeAuth);

      final success = await service.authenticateForUnlock();
      expect(success, isFalse);
    });

    test('detailed prompt reports cancellation with an actionable message', () async {
      final fakeAuth = FakeLocalAuthentication(
        authenticateException: const LocalAuthException(
          code: LocalAuthExceptionCode.userCanceled,
        ),
      );
      final service = BiometricAuthService(localAuth: fakeAuth);

      final outcome = await service.authenticateForUnlockDetailed();
      expect(outcome.succeeded, isFalse);
      expect(outcome.failure, BiometricAuthFailure.canceled);
      expect(outcome.userMessage, contains('cancelled'));
    });

    test('busy biometric hardware is retried once', () async {
      final fakeAuth = FakeLocalAuthentication(authResult: true)
        ..busyRetriesRemaining = 1;
      final service = BiometricAuthService(localAuth: fakeAuth);

      final outcome = await service.authenticateForUnlockDetailed();
      expect(outcome.succeeded, isTrue);
      expect(fakeAuth.authenticateCalls, 2);
    });

    test('missing enrollment produces Windows Hello guidance', () async {
      final fakeAuth = FakeLocalAuthentication(
        authenticateException: const LocalAuthException(
          code: LocalAuthExceptionCode.noBiometricsEnrolled,
        ),
      );
      final service = BiometricAuthService(localAuth: fakeAuth);

      final outcome = await service.authenticateForUnlockDetailed();
      expect(outcome.failure, BiometricAuthFailure.notEnrolled);
      expect(outcome.userMessage, contains('Windows Hello'));
    });

    test('enableBiometricUnlock and isBiometricUnlockEnabled manage per-account configuration', () async {
      final service = BiometricAuthService(localAuth: FakeLocalAuthentication());

      expect(await service.isBiometricUnlockEnabled('user_123'), isFalse);

      await service.enableBiometricUnlock('user_123');
      expect(await service.isBiometricUnlockEnabled('user_123'), isTrue);
      expect(await service.isBiometricUnlockEnabled('user_456'), isFalse);

      await service.disableBiometricUnlock();
      expect(await service.isBiometricUnlockEnabled('user_123'), isFalse);
    });

    test('on desktop platforms, isBiometricUnlockEnabled is auto-enabled when enrolled', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final service = BiometricAuthService(
          localAuth: FakeLocalAuthentication(
            availableBiometrics: [BiometricType.fingerprint],
          ),
        );
        expect(await service.isBiometricUnlockEnabled('user_desktop'), isTrue);

        final serviceNoBio = BiometricAuthService(
          localAuth: FakeLocalAuthentication(availableBiometrics: []),
        );
        expect(await serviceNoBio.isBiometricUnlockEnabled('user_desktop'), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('never stores passwords or biometric templates', () async {
      final service = BiometricAuthService(localAuth: FakeLocalAuthentication());
      await service.enableBiometricUnlock('user_abc');

      final allSettings = await LocalDatabase.instance.getAllSettings();
      expect(allSettings.containsKey('biometric_password'), isFalse);
      expect(allSettings.containsKey('password'), isFalse);
      expect(allSettings[BiometricAuthService.keyBiometricUnlockEnabled], equals('true'));
      expect(allSettings[BiometricAuthService.keyBiometricAccountId], equals('user_abc'));
    });
  });
}
