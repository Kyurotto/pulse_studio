import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../data/local_database.dart';

/// Service responsible for device biometric capabilities and local app-unlock.
///
/// Note: This service performs local on-device verification only.
/// It does NOT authenticate directly with Firebase, does NOT store or handle
/// user passwords, and does NOT hold biometric templates.
class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  static BiometricAuthService instance = BiometricAuthService();

  final LocalAuthentication _localAuth;

  static const String keyBiometricUnlockEnabled = 'biometric_unlock_enabled';
  static const String keyBiometricAccountId = 'biometric_account_id';

  /// Whether the current platform supports local biometric/device authentication.
  /// Supported: Android, iOS, macOS, Windows.
  /// Unsupported: Web, Linux.
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Checks whether at least one biometric authentication method (fingerprint,
  /// Face ID, Touch ID, Windows Hello) is enrolled on the device.
  ///
  /// When [strict] is true, platform errors propagate instead of being
  /// reported as "not enrolled", so security-critical callers can fail closed.
  Future<bool> isBiometricEnrolled({bool strict = false}) async {
    if (!isPlatformSupported) return false;
    try {
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      if (strict) rethrow;
      return false;
    }
  }

  /// Returns whether Biometric Unlock is enabled for the specified account ID
  /// (Firebase UID or local SQLite user ID) on this device.
  ///
  /// When [strict] is true, storage errors propagate instead of being
  /// reported as "disabled", so security-critical callers can fail closed.
  Future<bool> isBiometricUnlockEnabled(
    String accountId, {
    bool strict = false,
  }) async {
    if (!isPlatformSupported || accountId.isEmpty) return false;
    try {
      final enabled = await LocalDatabase.instance.getSetting(
        keyBiometricUnlockEnabled,
      );
      final storedId = await LocalDatabase.instance.getSetting(
        keyBiometricAccountId,
      );
      return enabled == 'true' && storedId == accountId;
    } catch (_) {
      if (strict) rethrow;
      return false;
    }
  }

  /// Prompts the operating system's biometric or device-authentication dialog.
  ///
  /// Returns `true` if authentication succeeded, `false` if cancelled, failed,
  /// or if hardware is unavailable.
  Future<bool> authenticateForUnlock({String? customReason}) async {
    if (!isPlatformSupported) return false;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final reason =
        customReason ??
        (isWindows
            ? 'Verify your identity with Windows Hello to unlock Pulse Studio'
            : 'Unlock Pulse Studio');

    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: !isWindows,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Enables Biometric Unlock for the given [accountId] on this device.
  Future<void> enableBiometricUnlock(String accountId) async {
    if (accountId.isEmpty) return;
    try {
      await LocalDatabase.instance.setSetting(
        keyBiometricUnlockEnabled,
        'true',
      );
      await LocalDatabase.instance.setSetting(keyBiometricAccountId, accountId);
    } catch (_) {}
  }

  /// Clears the Biometric Unlock configuration on this device.
  Future<void> disableBiometricUnlock() async {
    try {
      await LocalDatabase.instance.removeSetting(keyBiometricUnlockEnabled);
      await LocalDatabase.instance.removeSetting(keyBiometricAccountId);
    } catch (_) {}
  }
}
