/// Platform-neutral contract for the browser's persistent audio cache.
///
/// Native builds store downloads as files on disk, so this interface is only
/// implemented by the web build. The stub implementation keeps every other
/// platform on the existing file-based path.
abstract class WebOfflineAudioStore {
  /// Reads the list of previously downloaded tracks from browser storage.
  Future<void> hydrate();

  /// True when [songId] has a complete track stored in the browser.
  bool has(String songId);

  /// Creates (and memoizes) a `blob:` URL for the stored track.
  ///
  /// Returns null when the browser holds no copy for [songId].
  Future<String?> objectUrl(String songId);

  /// Persists [bytes] as the complete track for [songId].
  Future<bool> save(
    String songId,
    List<int> bytes, {
    required String contentType,
  });

  /// Deletes the stored track and revokes its blob URL.
  Future<void> remove(String songId);

  /// Total bytes used by downloaded tracks.
  Future<int> sizeBytes();

  /// Deletes every downloaded track.
  Future<void> clear();

  /// Releases in-memory blob URLs without touching the stored tracks.
  Future<void> dispose();
}
