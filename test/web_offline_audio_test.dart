import 'package:flutter_test/flutter_test.dart';
import 'package:music/services/web_offline_audio_api.dart';
import 'package:music/services/web_offline_audio_stub.dart';

/// In-memory implementation of WebOfflineAudioStore for testing contract behavior
/// including preview tracking, verifyExists, and removal error propagation.
class FakeWebOfflineAudioStore implements WebOfflineAudioStore {
  final Set<String> _ids = <String>{};
  final Set<String> _previewIds = <String>{};
  final Map<String, String> _objectUrls = <String, String>{};
  final Map<String, List<int>> storage = <String, List<int>>{};
  final Map<String, List<int>> auxiliaryStorage = <String, List<int>>{};
  bool shouldFailRemove = false;
  bool shouldFailHydrate = false;
  bool hydrated = false;

  @override
  Future<void> hydrate() async {
    if (shouldFailHydrate) {
      throw Exception('Hydrate cache listing failed');
    }
    hydrated = true;
  }

  @override
  bool has(String songId) => _ids.contains(songId);

  @override
  bool isPreview(String songId) => _previewIds.contains(songId);

  @override
  Future<bool> verifyExists(String songId) async {
    if (!storage.containsKey(songId)) {
      invalidate(songId);
      return false;
    }
    _ids.add(songId);
    return true;
  }

  @override
  void invalidate(String songId) {
    _ids.remove(songId);
    _previewIds.remove(songId);
    _objectUrls.remove(songId);
  }

  @override
  Future<String?> objectUrl(String songId) async {
    if (!storage.containsKey(songId)) {
      invalidate(songId);
      return null;
    }
    return _objectUrls[songId] ?? 'blob:https://pulse-offline.local/$songId';
  }

  @override
  Future<bool> save(
    String songId,
    List<int> bytes, {
    required String contentType,
    bool preview = false,
  }) async {
    storage[songId] = bytes;
    _ids.add(songId);
    if (preview) {
      _previewIds.add(songId);
    } else {
      _previewIds.remove(songId);
    }
    return true;
  }

  @override
  Future<bool> saveAuxiliary(
    String songId,
    String name,
    List<int> bytes, {
    required String contentType,
  }) async {
    auxiliaryStorage['$songId::$name'] = bytes;
    return true;
  }

  @override
  Future<bool> hasAuxiliary(String songId, String name) async =>
      auxiliaryStorage.containsKey('$songId::$name');

  @override
  Future<void> remove(String songId) async {
    if (shouldFailRemove) {
      throw Exception('Cache storage deletion failed');
    }
    storage.remove(songId);
    invalidate(songId);
  }

  @override
  Future<int> sizeBytes() async {
    final audioBytes = storage.values.fold<int>(
      0,
      (int sum, bytes) => sum + bytes.length,
    );
    final auxiliaryBytes = auxiliaryStorage.values.fold<int>(
      0,
      (int sum, bytes) => sum + bytes.length,
    );
    return audioBytes + auxiliaryBytes;
  }

  @override
  Future<void> clear() async {
    storage.clear();
    auxiliaryStorage.clear();
    _ids.clear();
    _previewIds.clear();
    _objectUrls.clear();
  }

  @override
  Future<void> dispose() async {
    _objectUrls.clear();
  }
}

void main() {
  group('WebOfflineAudioStore contract', () {
    test('stub implementation provides defaults without crashing', () async {
      final stub = createWebOfflineAudioStore();
      await stub.hydrate();
      expect(stub.has('test'), isFalse);
      expect(stub.isPreview('test'), isFalse);
      expect(await stub.verifyExists('test'), isFalse);
      expect(await stub.objectUrl('test'), isNull);
      expect(
        await stub.save('test', [1, 2, 3], contentType: 'audio/mpeg'),
        isFalse,
      );
      expect(
        await stub.saveAuxiliary('test', 'metadata.json', [
          1,
          2,
          3,
        ], contentType: 'application/json'),
        isFalse,
      );
      expect(await stub.hasAuxiliary('test', 'metadata.json'), isFalse);
      await stub.remove('test');
      stub.invalidate('test');
      expect(await stub.sizeBytes(), 0);
      await stub.clear();
      await stub.dispose();
    });

    test('distinguishes preview downloads from full tracks', () async {
      final store = FakeWebOfflineAudioStore();
      await store.save(
        'track-prev',
        [1, 2, 3],
        contentType: 'audio/mpeg',
        preview: true,
      );
      expect(store.has('track-prev'), isTrue);
      expect(store.isPreview('track-prev'), isTrue);

      await store.save(
        'track-full',
        [1, 2, 3, 4, 5],
        contentType: 'audio/mpeg',
        preview: false,
      );
      expect(store.has('track-full'), isTrue);
      expect(store.isPreview('track-full'), isFalse);

      // Upgrade preview to full
      await store.save(
        'track-prev',
        [1, 2, 3, 4, 5, 6],
        contentType: 'audio/mpeg',
        preview: false,
      );
      expect(store.has('track-prev'), isTrue);
      expect(store.isPreview('track-prev'), isFalse);
    });

    test('verifyExists purges missing entries from in-memory index', () async {
      final store = FakeWebOfflineAudioStore();
      await store.save('track-1', [1, 2, 3], contentType: 'audio/mpeg');
      expect(store.has('track-1'), isTrue);

      // Simulate external eviction from underlying cache
      store.storage.remove('track-1');
      // in-memory index still had it until verifyExists is called
      expect(store.has('track-1'), isTrue);

      final exists = await store.verifyExists('track-1');
      expect(exists, isFalse);
      expect(store.has('track-1'), isFalse);
    });

    test(
      'auxiliary entries are keyed once and counted in storage usage',
      () async {
        final store = FakeWebOfflineAudioStore();
        await store.save('track-1', [1, 2, 3], contentType: 'audio/mpeg');
        await store.saveAuxiliary('track-1', 'metadata.json', [
          4,
          5,
        ], contentType: 'application/json');
        await store.saveAuxiliary('track-1', 'metadata.json', [
          6,
          7,
          8,
          9,
        ], contentType: 'application/json');

        expect(await store.hasAuxiliary('track-1', 'metadata.json'), isTrue);
        expect(await store.sizeBytes(), 3 + 4);
      },
    );

    test(
      'remove propagates failure and preserves in-memory index on error',
      () async {
        final store = FakeWebOfflineAudioStore();
        await store.save('track-err', [1, 2, 3], contentType: 'audio/mpeg');
        store.shouldFailRemove = true;

        expect(
          () async => await store.remove('track-err'),
          throwsA(isA<Exception>()),
        );
        // Because removal failed, in-memory index is not purged
        expect(store.has('track-err'), isTrue);

        // Now succeed
        store.shouldFailRemove = false;
        await store.remove('track-err');
        expect(store.has('track-err'), isFalse);
      },
    );
  });
}
