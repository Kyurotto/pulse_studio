import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_offline_audio_api.dart';

WebOfflineAudioStore createWebOfflineAudioStore() => _CacheApiAudioStore();

/// Browser implementation of [WebOfflineAudioStore] backed by the Cache API.
///
/// Cache storage survives reloads without needing a service worker, holds
/// multi-megabyte payloads far better than localStorage, and is included in
/// the origin's storage quota (`navigator.storage.persist()` is requested on
/// the first download so Chrome does not evict it under pressure).
///
/// Audio is fetched with `package:http`, which is subject to CORS. Sources
/// such as the JioSaavn CDN, Archive.org and iTunes previews allow
/// cross-origin reads; YouTube's media CDN does not, so those rows stay
/// stream-only in the browser build.
class _CacheApiAudioStore implements WebOfflineAudioStore {
  static const String _cacheName = 'pulse_offline_audio_v1';
  static const String _keyPrefix = 'https://pulse-offline.local/audio/';

  final Set<String> _ids = <String>{};
  final Map<String, String> _objectUrls = <String, String>{};
  Future<web.Cache>? _cacheFuture;
  bool _hydrated = false;
  bool _persistenceRequested = false;

  Future<web.Cache> _openCache() {
    final existing = _cacheFuture;
    if (existing != null) return existing;
    final future = web.window.caches.open(_cacheName).toDart;
    _cacheFuture = future;
    // A failed open (private mode, blocked storage) must not poison every
    // later call: drop the cached future so the next attempt retries.
    unawaited(
      future.then(
        (_) {},
        onError: (Object _) {
          if (identical(_cacheFuture, future)) _cacheFuture = null;
        },
      ),
    );
    return future;
  }

  String _keyFor(String songId) =>
      '$_keyPrefix${Uri.encodeComponent(songId)}';

  String? _songIdFromKey(String url) {
    if (!url.startsWith(_keyPrefix)) return null;
    final encoded = url.substring(_keyPrefix.length);
    if (encoded.isEmpty) return null;
    try {
      return Uri.decodeComponent(encoded);
    } catch (_) {
      return encoded;
    }
  }

  Future<void> _requestPersistence() async {
    if (_persistenceRequested) return;
    _persistenceRequested = true;
    try {
      final storage = web.window.navigator.storage;
      final persisted = (await storage.persisted().toDart).toDart;
      if (!persisted) {
        await storage.persist().toDart;
      }
    } catch (_) {}
  }

  @override
  Future<void> hydrate() async {
    if (_hydrated) return;
    try {
      final cache = await _openCache();
      final requests = (await cache.keys().toDart).toDart;
      for (final request in requests) {
        final id = _songIdFromKey(request.url);
        if (id != null) _ids.add(id);
      }
    } catch (_) {}
    _hydrated = true;
  }

  @override
  bool has(String songId) => _ids.contains(songId);

  @override
  Future<String?> objectUrl(String songId) async {
    final memo = _objectUrls[songId];
    if (memo != null) return memo;
    try {
      final cache = await _openCache();
      final response = await cache.match(_keyFor(songId).toJS).toDart;
      if (response == null) {
        _ids.remove(songId);
        return null;
      }
      final blob = await response.blob().toDart;
      final url = web.URL.createObjectURL(blob);
      _objectUrls[songId] = url;
      _ids.add(songId);
      return url;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> save(
    String songId,
    List<int> bytes, {
    required String contentType,
  }) async {
    if (songId.isEmpty || bytes.isEmpty) return false;
    try {
      await _requestPersistence();
      final cache = await _openCache();
      final blob = web.Blob(
        <JSAny>[Uint8List.fromList(bytes).toJS].toJS,
        web.BlobPropertyBag(type: contentType),
      );
      await cache.put(_keyFor(songId).toJS, web.Response(blob)).toDart;
      _ids.add(songId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> remove(String songId) async {
    _ids.remove(songId);
    final url = _objectUrls.remove(songId);
    if (url != null) {
      try {
        web.URL.revokeObjectURL(url);
      } catch (_) {}
    }
    try {
      final cache = await _openCache();
      await cache.delete(_keyFor(songId).toJS).toDart;
    } catch (_) {}
  }

  @override
  Future<int> sizeBytes() async {
    try {
      final cache = await _openCache();
      final requests = (await cache.keys().toDart).toDart;
      var total = 0;
      for (final request in requests) {
        final response = await cache.match(request.url.toJS).toDart;
        if (response == null) continue;
        final blob = await response.blob().toDart;
        total += blob.size.toInt();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clear() async {
    for (final url in _objectUrls.values) {
      try {
        web.URL.revokeObjectURL(url);
      } catch (_) {}
    }
    _objectUrls.clear();
    _ids.clear();
    try {
      await web.window.caches.delete(_cacheName).toDart;
    } catch (_) {}
    _cacheFuture = null;
    _hydrated = true;
  }

  @override
  Future<void> dispose() async {
    for (final url in _objectUrls.values) {
      try {
        web.URL.revokeObjectURL(url);
      } catch (_) {}
    }
    _objectUrls.clear();
  }
}
