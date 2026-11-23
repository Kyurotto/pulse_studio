import 'web_offline_audio_api.dart';
import 'web_offline_audio_stub.dart'
    if (dart.library.js_interop) 'web_offline_audio_web.dart' as platform;

export 'web_offline_audio_api.dart';

/// Creates the persistent audio store for the current platform.
///
/// On the web this is a Cache API store; on Android/desktop/iOS it is a no-op
/// because downloads are written to the app documents directory instead.
WebOfflineAudioStore createWebOfflineAudioStore({String? cacheName}) =>
    platform.createWebOfflineAudioStore(cacheName: cacheName);
