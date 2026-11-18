import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music/auth/password_recovery_api.dart';

void main() {
  const baseUrl = 'https://script.google.com/macros/s/test-deployment/exec';

  group('PasswordRecoveryApi (Apps Script backend)', () {
    test('posts the action and follows the Apps Script redirect', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://script.googleusercontent.com/macros/echo?x=1',
            },
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'requestId': 'req-123',
            'message': 'A 6-digit code was sent.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PasswordRecoveryApi(baseUrl: baseUrl, client: client);
      final result = await api.requestPasswordReset('User@Gmail.com');

      expect(result.requestId, 'req-123');
      expect(requests.first.method, 'POST');
      expect(requests.first.url.toString(), baseUrl);
      final payload = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(payload['action'], 'request_password_reset');
      expect(payload['email'], 'user@gmail.com');
      expect(requests.last.method, 'GET');
    });

    test('treats success:false as an error even with HTTP 200', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': 'rate_limited',
            'message': 'Too many code requests. Please try again later.',
          }),
          200,
        ),
      );

      final api = PasswordRecoveryApi(baseUrl: baseUrl, client: client);

      await expectLater(
        api.requestPasswordReset('user@gmail.com'),
        throwsA(
          isA<PasswordRecoveryException>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having((e) => e.message, 'message', contains('Too many')),
        ),
      );
    });

    test('does not accept an HTML page as a successful reset', () async {
      final client = MockClient(
        (_) async => http.Response('<html>Sign in</html>', 200),
      );

      final api = PasswordRecoveryApi(baseUrl: baseUrl, client: client);

      await expectLater(
        api.completePasswordReset(
          requestId: 'req-1',
          resetToken: 'token',
          newPassword: 'Secret123',
        ),
        throwsA(isA<PasswordRecoveryException>()),
      );
    });

    test('verify requires a reset token in the response', () async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode({'success': true, 'message': 'ok'}), 200),
      );

      final api = PasswordRecoveryApi(baseUrl: baseUrl, client: client);

      await expectLater(
        api.verifyPasswordResetOtp(
          email: 'user@gmail.com',
          code: '123456',
          requestId: 'req-1',
        ),
        throwsA(
          isA<PasswordRecoveryException>().having(
            (e) => e.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    });
  });
}
