import 'web_offline_audio_api.dart';

/// Native builds have no browser cache; downloads continue to use files.
WebOfflineAudioStore createWebOfflineAudioStore() =>
    _UnsupportedWebOfflineAudioStore();

class _UnsupportedWebOfflineAudioStore implements WebOfflineAudioStore {
  @override
  Future<void> hydrate() async {}

  @override
  bool has(String songId) => false;

  @override
  Future<String?> objectUrl(String songId) async => null;

  @override
  Future<bool> save(
    String songId,
    List<int> bytes, {
    required String contentType,
  }) async => false;

  @override
  Future<void> remove(String songId) async {}

  @override
  Future<int> sizeBytes() async => 0;

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}
}
