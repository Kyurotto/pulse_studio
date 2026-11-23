import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../data/local_database.dart';
import 'audio_capabilities.dart';

/// Why a device-biometric prompt did not complete.
enum BiometricAuthFailure {
  canceled,
  notEnrolled,
  noHardware,
  busy,
  inProgress,
  lockedOut,
  timeout,
  uiUnavailable,
  unsupported,
  unknown,
}

/// Result of a device-biometric prompt, including a user-facing reason.
class BiometricAuthOutcome {
  const BiometricAuthOutcome._(this.succeeded, this.failure, this.detail);

  const BiometricAuthOutcome.success() : this._(true, null, null);

  const BiometricAuthOutcome.failed(
    BiometricAuthFailure failure, [
    String? detail,
  ]) : this._(false, failure, detail);

  final bool succeeded;
  final BiometricAuthFailure? failure;
  final String? detail;

  /// Short, actionable message shown on the sign-in screen.
  String get userMessage {
    switch (failure) {
      case null:
        return 'Verification succeeded.';
      case BiometricAuthFailure.canceled:
        return 'Verification was cancelled. Try again or use your password.';
      case BiometricAuthFailure.notEnrolled:
        return 'Windows Hello or fingerprint is not set up on this device. '
            'Add a fingerprint or PIN in device settings, then try again.';
      case BiometricAuthFailure.noHardware:
        return 'This device has no biometric hardware. Use your password.';
      case BiometricAuthFailure.busy:
        return 'The biometric sensor is busy right now. Try again in a moment '
            'or use your password.';
      case BiometricAuthFailure.inProgress:
        return 'A verification prompt is already open. Finish that prompt or '
            'wait a moment, then try again.';
      case BiometricAuthFailure.lockedOut:
        return 'Biometric verification is temporarily locked after too many '
            'attempts. Use your password, then try again later.';
      case BiometricAuthFailure.timeout:
        return 'Verification timed out. Try again or use your password.';
      case BiometricAuthFailure.uiUnavailable:
        return 'The verification prompt could not be shown. Use your password.';
      case BiometricAuthFailure.unsupported:
        return 'Biometric sign-in is not available in this build. '
            'Use your password.';
      case BiometricAuthFailure.unknown:
        final reason = detail?.trim();
        return reason == null || reason.isEmpty
            ? 'Verification failed. Try again or use your password.'
            : 'Verification failed: $reason';
    }
  }
}

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
    if (AudioCapabilities.isDesktop) {
      // On desktop (Windows Hello / device auth), app unlock is automatically enabled
      // without requiring manual activation whenever biometrics or credentials are enrolled.
      return await isBiometricEnrolled(strict: strict);
    }
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

  /// Prompts the operating system's biometric or device-authentication dialog
  /// and reports a specific failure reason instead of collapsing every error
  /// into `false`.
  ///
  /// [BiometricAuthFailure.busy] is retried once because Windows Hello can
  /// return `deviceBusy` briefly after the lock screen or another prompt.
  Future<BiometricAuthOutcome> authenticateForUnlockDetailed({
    String? customReason,
  }) async {
    if (!isPlatformSupported) {
      return const BiometricAuthOutcome.failed(
        BiometricAuthFailure.unsupported,
      );
    }
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final reason =
        customReason ??
        (isWindows
            ? 'Verify your identity with Windows Hello to unlock Pulse Studio'
            : 'Unlock Pulse Studio');
    return _attemptAuthentication(reason, allowBusyRetry: true);
  }

  Future<BiometricAuthOutcome> _attemptAuthentication(
    String reason, {
    required bool allowBusyRetry,
  }) async {
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    try {
      final verified = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: !isWindows,
        persistAcrossBackgrounding: true,
      );
      if (verified) return const BiometricAuthOutcome.success();
      return const BiometricAuthOutcome.failed(BiometricAuthFailure.canceled);
    } on LocalAuthException catch (error) {
      final failure = _mapFailure(error.code);
      if (failure == BiometricAuthFailure.busy && allowBusyRetry) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return _attemptAuthentication(reason, allowBusyRetry: false);
      }
      debugPrint(
        '[BiometricAuthService] prompt failed: code=${error.code.name} '
        'description=${error.description}',
      );
      return BiometricAuthOutcome.failed(failure, error.description);
    } on UnsupportedError catch (error) {
      debugPrint(
        '[BiometricAuthService] unsupported configuration: ${error.message}',
      );
      return BiometricAuthOutcome.failed(
        BiometricAuthFailure.unsupported,
        error.message,
      );
    } on MissingPluginException catch (error) {
      debugPrint('[BiometricAuthService] plugin missing: $error');
      return const BiometricAuthOutcome.failed(
        BiometricAuthFailure.unsupported,
      );
    } catch (error) {
      debugPrint('[BiometricAuthService] unexpected prompt failure: $error');
      return BiometricAuthOutcome.failed(
        BiometricAuthFailure.unknown,
        error.toString(),
      );
    }
  }

  static BiometricAuthFailure _mapFailure(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return BiometricAuthFailure.canceled;
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return BiometricAuthFailure.notEnrolled;
      case LocalAuthExceptionCode.noBiometricHardware:
        return BiometricAuthFailure.noHardware;
      case LocalAuthExceptionCode.authInProgress:
        return BiometricAuthFailure.inProgress;
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return BiometricAuthFailure.busy;
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return BiometricAuthFailure.lockedOut;
      case LocalAuthExceptionCode.timeout:
        return BiometricAuthFailure.timeout;
      case LocalAuthExceptionCode.uiUnavailable:
        return BiometricAuthFailure.uiUnavailable;
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return BiometricAuthFailure.unknown;
    }
  }

  /// Legacy boolean wrapper. Prefer [authenticateForUnlockDetailed] when the
  /// caller can surface a specific failure reason.
  Future<bool> authenticateForUnlock({String? customReason}) async {
    final outcome = await authenticateForUnlockDetailed(
      customReason: customReason,
    );
    return outcome.succeeded;
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
