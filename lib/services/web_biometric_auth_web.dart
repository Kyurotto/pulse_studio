import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'biometric_auth_service.dart';

/// Browser WebAuthn platform-authenticator helper (Windows Hello, Touch ID,
/// Face ID, Android biometrics) using `navigator.credentials`.
class WebBiometricAuth {
  const WebBiometricAuth();

  static const String _storagePrefix = 'pulse_webauthn_cred_';

  /// Returns true when the browser is in a secure context and exposes a
  /// user-verifying platform authenticator (Windows Hello / Touch ID / etc.).
  Future<bool> isPlatformAuthenticatorAvailable() async {
    try {
      if (!web.window.isSecureContext) return false;
      final pkc = globalContext['PublicKeyCredential'];
      if (pkc == null || pkc.isUndefinedOrNull) return false;
      final fn = (pkc as JSObject)['isUserVerifyingPlatformAuthenticatorAvailable'];
      if (fn == null || fn.isUndefinedOrNull) return false;
      final promise = (pkc).callMethod<JSPromise<JSBoolean>>(
        'isUserVerifyingPlatformAuthenticatorAvailable'.toJS,
      );
      final result = await promise.toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the browser's platform authenticator (WebAuthn) for [accountEmail].
  ///
  /// Uses a stored local credential ID when available (`credentials.get`), or
  /// registers a new platform credential (`credentials.create`) on first use.
  Future<BiometricAuthOutcome> authenticate({
    required String reason,
    String? accountEmail,
  }) async {
    try {
      if (!web.window.isSecureContext) {
        return const BiometricAuthOutcome.failed(
          BiometricAuthFailure.uiUnavailable,
          'Biometric sign-in in a browser requires HTTPS or localhost.',
        );
      }
      final available = await isPlatformAuthenticatorAvailable();
      if (!available) {
        return const BiometricAuthOutcome.failed(
          BiometricAuthFailure.notEnrolled,
        );
      }

      final cleanEmail = (accountEmail ?? 'user@pulse.local').trim().toLowerCase();
      final storageKey = _storageKeyFor(cleanEmail);
      final existingCredId = web.window.localStorage.getItem(storageKey);

      if (existingCredId != null && existingCredId.isNotEmpty) {
        try {
          final credBytes = _base64UrlDecode(existingCredId);
          final verified = await _getAssertion(credBytes);
          if (verified) {
            return const BiometricAuthOutcome.success();
          }
          return const BiometricAuthOutcome.failed(
            BiometricAuthFailure.canceled,
          );
        } catch (error) {
          final name = _domExceptionName(error);
          if (name == 'InvalidStateError' || name == 'NotFoundError') {
            // Credential was removed from the device/browser; re-register below.
            web.window.localStorage.removeItem(storageKey);
          } else {
            return _mapDomError(error);
          }
        }
      }

      final newCredId = await _createCredential(cleanEmail);
      if (newCredId != null && newCredId.isNotEmpty) {
        web.window.localStorage.setItem(storageKey, newCredId);
        return const BiometricAuthOutcome.success();
      }
      return const BiometricAuthOutcome.failed(BiometricAuthFailure.canceled);
    } catch (error) {
      return _mapDomError(error);
    }
  }

  Future<bool> _getAssertion(Uint8List credentialId) async {
    final options = {
      'publicKey': {
        'challenge': _randomBytes(32),
        'timeout': 60000,
        'rpId': web.window.location.hostname,
        'userVerification': 'required',
        'allowCredentials': [
          {
            'type': 'public-key',
            'id': credentialId,
            'transports': ['internal', 'hybrid'],
          },
        ],
      },
    }.jsify() as web.CredentialRequestOptions;

    final credential = await web.window.navigator.credentials.get(options).toDart;
    return credential != null;
  }

  Future<String?> _createCredential(String email) async {
    final userBytes = Uint8List.fromList(utf8.encode(email));
    final options = {
      'publicKey': {
        'challenge': _randomBytes(32),
        'rp': {
          'name': 'Pulse Studio',
          'id': web.window.location.hostname,
        },
        'user': {
          'id': userBytes,
          'name': email,
          'displayName': email,
        },
        'pubKeyCredParams': [
          {'type': 'public-key', 'alg': -7},
          {'type': 'public-key', 'alg': -257},
        ],
        'authenticatorSelection': {
          'authenticatorAttachment': 'platform',
          'userVerification': 'required',
          'residentKey': 'preferred',
        },
        'timeout': 60000,
      },
    }.jsify() as web.CredentialCreationOptions;

    final credential = await web.window.navigator.credentials
        .create(options)
        .toDart;
    if (credential == null) return null;
    final rawId = (credential as JSObject)['rawId'];
    if (rawId == null || rawId.isUndefinedOrNull) return null;
    final buffer = (rawId as JSArrayBuffer).toDart;
    return _base64UrlEncode(buffer.asUint8List());
  }

  static String _storageKeyFor(String email) {
    final encoded = base64Url.encode(utf8.encode(email)).replaceAll('=', '');
    return '$_storagePrefix$encoded';
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  static String _base64UrlEncode(Uint8List bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _base64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return Uint8List.fromList(base64.decode(normalized));
  }

  static String _domExceptionName(Object error) {
    try {
      final obj = error as JSObject;
      final name = obj['name'];
      if (name != null && !name.isUndefinedOrNull) {
        return (name as JSString).toDart;
      }
    } catch (_) {}
    return '';
  }

  static String _domExceptionMessage(Object error) {
    try {
      final obj = error as JSObject;
      final msg = obj['message'];
      if (msg != null && !msg.isUndefinedOrNull) {
        return (msg as JSString).toDart;
      }
    } catch (_) {}
    return error.toString();
  }

  static BiometricAuthOutcome _mapDomError(Object error) {
    final name = _domExceptionName(error);
    final message = _domExceptionMessage(error);
    switch (name) {
      case 'NotAllowedError':
      case 'AbortError':
        return const BiometricAuthOutcome.failed(BiometricAuthFailure.canceled);
      case 'NotSupportedError':
        return const BiometricAuthOutcome.failed(
          BiometricAuthFailure.notEnrolled,
        );
      case 'SecurityError':
        return BiometricAuthOutcome.failed(
          BiometricAuthFailure.uiUnavailable,
          message,
        );
      default:
        return BiometricAuthOutcome.failed(
          BiometricAuthFailure.unknown,
          message,
        );
    }
  }
}
