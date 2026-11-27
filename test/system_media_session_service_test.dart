import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/controllers/music_player_controller.dart';
import 'package:music/services/system_media_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SystemMediaSessionService', () {
    test('never opens an OS session while running widget tests', () async {
      // The host is Windows, but no plugin is registered under `flutter test`;
      // the service must stay inert so the rest of the suite is unaffected.
      expect(SystemMediaSessionService.isSupportedPlatform, isFalse);

      final controller = MusicPlayerController();
      addTearDown(controller.dispose);

      await SystemMediaSessionService.instance.attach(controller);
      // Re-attaching (e.g. sign-out / sign-in) must stay safe as well.
      await SystemMediaSessionService.instance.attach(controller);
      SystemMediaSessionService.instance.detach();
    });

    test('maps the app repeat modes onto the OS media repeat modes', () {
      expect(
        SystemMediaSessionService.repeatModeFor(PlaybackRepeatMode.off),
        MediaRepeatMode.none,
      );
      expect(
        SystemMediaSessionService.repeatModeFor(PlaybackRepeatMode.all),
        MediaRepeatMode.all,
      );
      expect(
        SystemMediaSessionService.repeatModeFor(PlaybackRepeatMode.one),
        MediaRepeatMode.one,
      );
    });

    test('does not activate on fresh launch without restored state', () {
      final controller = MusicPlayerController();
      addTearDown(controller.dispose);

      expect(controller.hasRestoredPlaybackState, isFalse);
      expect(controller.isPlaying, isFalse);
      expect(SystemMediaSessionService.shouldActivateFor(controller), isFalse);
    });
  });
}
