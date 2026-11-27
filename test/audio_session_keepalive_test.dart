import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Audio session keepalive wiring', () {
    test('Windows runner compiles and wires AudioSessionKeepalive', () {
      final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
      final header = File('windows/runner/flutter_window.h').readAsStringSync();
      final cpp = File('windows/runner/flutter_window.cpp').readAsStringSync();
      final keepaliveCpp =
          File('windows/runner/audio_session_keepalive.cpp').readAsStringSync();

      expect(cmake, contains('audio_session_keepalive.cpp'));
      expect(header, contains('AudioSessionKeepalive audio_session_keepalive_'));
      expect(cpp, contains('audio_session_keepalive_.Start()'));
      expect(cpp, contains('audio_session_keepalive_.Stop()'));
      expect(keepaliveCpp, contains('AUDCLNT_BUFFERFLAGS_SILENT'));
      expect(keepaliveCpp, contains('OnDefaultDeviceChanged'));
    });

    test('Web index.html loads silent AudioContext keepalive script', () {
      final indexHtml = File('web/index.html').readAsStringSync();
      final keepaliveJs =
          File('web/audio_session_keepalive.js').readAsStringSync();

      expect(indexHtml, contains('audio_session_keepalive.js'));
      expect(keepaliveJs, contains('AudioContext'));
      expect(keepaliveJs, contains('gain.gain.value = 0'));
      expect(keepaliveJs, contains('pointerdown'));
      expect(keepaliveJs, contains('ctx.resume()'));
    });
  });
}
