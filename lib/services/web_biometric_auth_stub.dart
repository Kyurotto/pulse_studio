import 'biometric_auth_service.dart';

/// Non-web stub for browser WebAuthn biometric verification.
class WebBiometricAuth {
  const WebBiometricAuth();

  Future<bool> isPlatformAuthenticatorAvailable() async => false;

  Future<BiometricAuthOutcome> authenticate({
    required String reason,
    String? accountEmail,
  }) async {
    return const BiometricAuthOutcome.failed(BiometricAuthFailure.unsupported);
  }
}
