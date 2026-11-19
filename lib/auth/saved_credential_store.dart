import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the saved password for a remembered account in the platform's
/// encrypted credential storage (Android Keystore, iOS Keychain, Windows DPAPI,
/// macOS Keychain).
///
/// This is what lets the sign-in screen autofill the password and lets the
/// fingerprint button sign in without asking the user to type it again.
/// SQLite only ever holds a salted password hash — never the plaintext.
class SavedCredentialStore {
  SavedCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Replaceable for widget tests.
  static SavedCredentialStore instance = SavedCredentialStore();

  final FlutterSecureStorage _storage;

  static const String _keyPrefix = 'pulse_saved_login_';

  String _keyFor(String email) {
    final cleanEmail = email.trim().toLowerCase();
    // Hash the address so the key itself does not expose the user's email.
    final digest = sha256.convert(utf8.encode(cleanEmail));
    return '$_keyPrefix$digest';
  }

  Future<void> savePassword(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return;
    try {
      await _storage.write(key: _keyFor(email), value: password);
    } catch (error) {
      debugPrint('[SavedCredentialStore] Could not save password: $error');
    }
  }

  Future<String?> readPassword(String email) async {
    if (email.trim().isEmpty) return null;
    try {
      final value = await _storage.read(key: _keyFor(email));
      return (value == null || value.isEmpty) ? null : value;
    } catch (error) {
      debugPrint('[SavedCredentialStore] Could not read password: $error');
      return null;
    }
  }

  /// Deletes the saved password for [email].
  ///
  /// Failures from secure storage propagate so callers can keep the
  /// remembered account entry (and let the user retry) instead of reporting
  /// success while the password remains on the device.
  Future<void> deletePassword(String email) async {
    if (email.trim().isEmpty) return;
    await _storage.delete(key: _keyFor(email));
  }
}
