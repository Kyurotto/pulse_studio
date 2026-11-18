import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Exception thrown during the password recovery process.
class PasswordRecoveryException implements Exception {
  final String message;
  final String? code;

  const PasswordRecoveryException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Result returned from requesting a password reset.
class PasswordRecoveryRequestResult {
  final String requestId;
  final String message;

  const PasswordRecoveryRequestResult({
    required this.requestId,
    required this.message,
  });
}

/// Result returned from verifying the OTP.
class PasswordRecoveryVerifyResult {
  final String resetToken;
  final String message;

  const PasswordRecoveryVerifyResult({
    required this.resetToken,
    required this.message,
  });
}

/// Client API to interact with the trusted backend for OTP password recovery.
///
/// The Flutter application never handles SMTP secrets, generates OTPs,
/// or directly changes database password hashes. The production backend is a
/// Google Apps Script web app (free tier) that emails the code through the
/// account that deployed it.
class PasswordRecoveryApi {
  final String baseUrl;
  final http.Client _client;

  PasswordRecoveryApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? defaultBaseUrl,
      _client = client ?? http.Client();

  /// Compile-time override:
  /// `flutter build apk --dart-define=PULSE_BACKEND_URL=https://.../exec`
  static const String _envBaseUrl = String.fromEnvironment('PULSE_BACKEND_URL');

  /// Google Apps Script web app URL. Replace this after deploying
  /// `apps_script/Code.gs` (see `apps_script/README.md`).
  static const String _appsScriptBaseUrl =
      'https://script.google.com/macros/s/AKfycbwte_inb5WJtOYmDkNGcG5SHOeq5vWIgo9FgklYM5Wa_FWXno_d_GSSur2Bv3WlHS7D7w/exec';

  static String get defaultBaseUrl =>
      _envBaseUrl.isNotEmpty ? _envBaseUrl : _appsScriptBaseUrl;

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Request a password reset verification code for [email].
  ///
  /// Enforces client-side validation that the address is syntactically valid
  /// and belongs to the `@gmail.com` domain.
  Future<PasswordRecoveryRequestResult> requestPasswordReset(
    String email,
  ) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      throw const PasswordRecoveryException('Enter your email address.');
    }

    final gmailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@gmail\.com$',
      caseSensitive: false,
    );

    if (!gmailRegex.hasMatch(cleanEmail)) {
      throw const PasswordRecoveryException(
        'Please enter a valid Gmail address (@gmail.com).',
        code: 'invalid_gmail_domain',
      );
    }

    final data = await _call('request_password_reset', {'email': cleanEmail});
    final requestId = data['requestId'] as String? ?? '';

    if (requestId.isEmpty) {
      throw const PasswordRecoveryException(
        'The server did not return a verification request. Please try again.',
        code: 'invalid_response',
      );
    }

    return PasswordRecoveryRequestResult(
      requestId: requestId,
      message:
          data['message'] as String? ??
          'A verification code was sent to your Gmail address.',
    );
  }

  /// Verify the 6-digit numeric OTP submitted by the user.
  Future<PasswordRecoveryVerifyResult> verifyPasswordResetOtp({
    required String email,
    required String code,
    required String requestId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    if (cleanCode.length != 6 || int.tryParse(cleanCode) == null) {
      throw const PasswordRecoveryException(
        'Verification code must be exactly 6 digits.',
        code: 'invalid_code_format',
      );
    }

    final data = await _call('verify_password_reset_otp', {
      'email': cleanEmail,
      'code': cleanCode,
      'requestId': requestId,
    });
    final resetToken = data['resetToken'] as String? ?? '';

    if (resetToken.isEmpty) {
      throw const PasswordRecoveryException(
        'The server did not return a reset token. Please try again.',
        code: 'invalid_response',
      );
    }

    return PasswordRecoveryVerifyResult(
      resetToken: resetToken,
      message: data['message'] as String? ?? 'Code verified successfully.',
    );
  }

  /// Complete the password reset with the one-time reset token and new
  /// password.
  Future<void> completePasswordReset({
    required String requestId,
    required String resetToken,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw const PasswordRecoveryException(
        'Use a password with at least 6 characters.',
        code: 'weak_password',
      );
    }

    await _call('complete_password_reset', {
      'requestId': requestId,
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }

  /// Sends one action to the Apps Script endpoint and validates the JSON
  /// contract. Apps Script always returns HTTP 200 (even for failures) and
  /// redirects to `script.googleusercontent.com`, so both the redirect and
  /// the `success` flag are handled explicitly.
  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (baseUrl.isEmpty || baseUrl.contains('REPLACE_WITH_APPS_SCRIPT')) {
      throw const PasswordRecoveryException(
        'Password recovery is not configured yet. Please try again later.',
        code: 'backend_not_configured',
      );
    }

    try {
      final request = http.Request('POST', Uri.parse(baseUrl))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'action': action, ...payload})
        ..followRedirects = false;

      final streamed = await _client.send(request).timeout(_requestTimeout);
      var response = await http.Response.fromStream(
        streamed,
      ).timeout(_requestTimeout);

      // Google Apps Script answers with a 302 to script.googleusercontent.com.
      // Follow it with a GET so the actual JSON body is read.
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location =
            response.headers['location'] ?? response.headers['Location'];
        if (location == null || location.isEmpty) {
          throw const PasswordRecoveryException(
            'Unexpected response from the password recovery service.',
            code: 'invalid_response',
          );
        }
        response = await _client
            .get(Uri.parse(location))
            .timeout(_requestTimeout);
      }

      final data = _parseJson(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Never treat an HTML page or an empty body as success.
        if (data['success'] != true) {
          throw PasswordRecoveryException(
            data['message'] as String? ??
                'The password recovery service rejected the request.',
            code: data['error'] as String?,
          );
        }
        return data;
      }

      throw PasswordRecoveryException(
        data['message'] as String? ??
            'The password recovery service is unavailable. Please try again.',
        code: data['error'] as String?,
      );
    } on PasswordRecoveryException {
      rethrow;
    } catch (e) {
      debugPrint('[PasswordRecoveryApi] $action error: $e');
      throw const PasswordRecoveryException(
        'Network error. Please check your connection and try again.',
        code: 'network_error',
      );
    }
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
