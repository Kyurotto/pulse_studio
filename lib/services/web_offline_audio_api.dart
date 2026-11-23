/// Platform-neutral contract for the browser's persistent audio cache.
///
/// Native builds store downloads as files on disk, so this interface is only
/// implemented by the web build. The stub implementation keeps every other
/// platform on the existing file-based path.
abstract class WebOfflineAudioStore {
  /// Reads the list of previously downloaded tracks from browser storage.
  Future<void> hydrate();

  /// True when [songId] has a track stored in the browser.
  bool has(String songId);

  /// True when the stored copy for [songId] is a preview.
  bool isPreview(String songId);

  /// Verifies that [songId] actually exists in underlying storage.
  /// If missing, purges the ID from the in-memory index.
  Future<bool> verifyExists(String songId);

  /// Drops [songId] from the in-memory index and revokes any memoized blob URL.
  void invalidate(String songId);

  /// Creates (and memoizes) a `blob:` URL for the stored track.
  ///
  /// Returns null when the browser holds no copy for [songId].
  Future<String?> objectUrl(String songId);

  /// Persists [bytes] as the track for [songId].
  Future<bool> save(
    String songId,
    List<int> bytes, {
    required String contentType,
    bool preview = false,
  });

  /// Persists non-audio playback data such as artwork or metadata under the
  /// track's temporary playback-cache namespace.
  ///
  /// Auxiliary entries never appear as downloadable tracks and are counted by
  /// [sizeBytes] so the Local Audio Cache reflects their storage use.
  Future<bool> saveAuxiliary(
    String songId,
    String name,
    List<int> bytes, {
    required String contentType,
  }) async => false;

  /// True when a named auxiliary entry already exists for [songId].
  Future<bool> hasAuxiliary(String songId, String name) async => false;

  /// Deletes the stored track and revokes its blob URL.
  Future<void> remove(String songId);

  /// Total bytes used by downloaded tracks.
  Future<int> sizeBytes();

  /// Deletes every downloaded track.
  Future<void> clear();

  /// Releases in-memory blob URLs without touching the stored tracks.
  Future<void> dispose();
}
