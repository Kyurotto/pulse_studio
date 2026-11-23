import 'web_offline_audio_api.dart';

/// Native builds have no browser cache; downloads continue to use files.
WebOfflineAudioStore createWebOfflineAudioStore({String? cacheName}) =>
    _UnsupportedWebOfflineAudioStore();

class _UnsupportedWebOfflineAudioStore implements WebOfflineAudioStore {
  @override
  Future<void> hydrate() async {}

  @override
  bool has(String songId) => false;

  @override
  bool isPreview(String songId) => false;

  @override
  Future<bool> verifyExists(String songId) async => false;

  @override
  void invalidate(String songId) {}

  @override
  Future<String?> objectUrl(String songId) async => null;

  @override
  Future<bool> save(
    String songId,
    List<int> bytes, {
    required String contentType,
    bool preview = false,
  }) async => false;

  @override
  Future<bool> saveAuxiliary(
    String songId,
    String name,
    List<int> bytes, {
    required String contentType,
  }) async => false;

  @override
  Future<bool> hasAuxiliary(String songId, String name) async => false;

  @override
  Future<void> remove(String songId) async {}

  @override
  Future<int> sizeBytes() async => 0;

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}
}
