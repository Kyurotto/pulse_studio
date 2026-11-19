// lib/services/web_youtube_audio_resolver.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'track_enrichment_service.dart';

/// A complete audio track fetched from YouTube through an Invidious proxy.
class WebYouTubeAudio {
  const WebYouTubeAudio({
    required this.bytes,
    required this.contentType,
    required this.videoId,
    required this.streamUrl,
    required this.title,
    required this.author,
    required this.duration,
  });

  final Uint8List bytes;
  final String contentType;
  final String videoId;

  /// Stable Invidious `/latest_version` URL the bytes came from. Safe to keep
  /// in the song row: unlike a `googlevideo.com` link it does not expire.
  final String streamUrl;
  final String title;
  final String author;
  final Duration duration;
}

/// Resolves and downloads full-length YouTube audio for the web build.
///
/// YouTube's media CDN (`*.googlevideo.com`) does not send CORS headers, so a
/// browser page cannot read the stream that [TrackEnrichmentService] finds.
/// Invidious proxies the same audio behind `/latest_version?...&local=true`,
/// which does allow cross-origin reads, and its `/api/v1/search` endpoint is
/// also CORS-enabled. This resolver therefore:
///
/// 1. searches Invidious for the song (or reuses a known video id),
/// 2. ranks the results with the same studio/version policy as the native
///    provider chain,
/// 3. downloads the best AAC (itag 140, then 139) rendition as bytes.
///
/// Only used by the browser download path. Failures are swallowed and return
/// null so the caller can fall back to a preview or report the track as
/// undownloadable.
class WebYouTubeAudioResolver {
  WebYouTubeAudioResolver({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _primaryBase = 'https://yt.chocolatemoo53.com';
  static const String _instancesUrl =
      'https://api.invidious.io/instances.json?sort_by=health';

  /// The primary instance proxies downloads through Invidious Companion
  /// subdomains. Requesting `/latest_version` on the main host redirects with
  /// a response that has **no** CORS headers, so a browser fetch dies there.
  /// The companion's `/companion/latest_version` 302 does send
  /// `Access-Control-Allow-Origin: *`, and so does its final `videoplayback`
  /// response, making the whole chain readable from a page. The instance
  /// rotates between these hosts, so all of them are tried.
  static const List<String> _primaryCompanions = [
    'https://yt-comp1.chocolatemoo53.com',
    'https://yt-comp2.chocolatemoo53.com',
    'https://yt-comp3.chocolatemoo53.com',
    'https://yt-comp4.chocolatemoo53.com',
    'https://yt-comp5.chocolatemoo53.com',
    'https://yt-comp6.chocolatemoo53.com',
  ];

  /// `140` is AAC 128 kbps (broad browser support); `139` is the 48 kbps AAC
  /// fallback used by older uploads that have no 140 rendition.
  static const List<String> _audioItags = ['140', '139'];

  static const int _minimumBytes = 50000;
  static const int _maxConcurrentDownloads = 2;
  static const Duration _searchTimeout = Duration(seconds: 15);
  static const Duration _probeTimeout = Duration(seconds: 12);
  static const Duration _downloadTimeout = Duration(seconds: 75);
  static const Duration _totalBudget = Duration(seconds: 180);

  static const Set<String> _ignoredTitleWords = {
    'official',
    'video',
    'audio',
    'lyric',
    'lyrics',
    'music',
    'visualizer',
    'visualiser',
    'hd',
    'hq',
    '4k',
    'remastered',
    'explicit',
    'clean',
    'mv',
  };

  /// Extra upload kinds that are never the studio recording when the catalog
  /// title does not ask for them. Karaoke/cover/instrumental are already
  /// handled by [TrackEnrichmentService.isNonStudioVariant].
  static final RegExp _rejectPattern = RegExp(
    r'\b(reaction|teaser|trailer|interview|making of|behind the scenes|'
    r'how to play|guitar lesson|piano lesson|drum cover|8d audio|'
    r'bass boosted|nightcore|slowed|sped up)\b',
  );

  /// Uploads that overlay subtitles/translations are still the same recording,
  /// but a clean official upload is a better download. Penalise, don't reject.
  static final RegExp _subtitlePattern = RegExp(
    r'\b(sub|subtitulad[oa]s?|subtitles?|traducid[oa]|traducci[oó]n|letra|'
    r'lyrics?)\b',
  );

  String? _preferredBase;
  String? _preferredCompanion;
  int _companionCursor = 0;
  List<String>? _knownBases;
  int _activeDownloads = 0;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  /// Resolves [title]/[artist] to a complete audio file.
  ///
  /// [videoId] (or a YouTube id embedded in [audioUrl]) is tried before
  /// searching. Returns null when no candidate could be downloaded.
  Future<WebYouTubeAudio?> resolve({
    required String title,
    required String artist,
    Duration? duration,
    String? videoId,
    String? audioUrl,
  }) {
    return _withSlot(() async {
      if (title.trim().isEmpty) return null;
      final deadline = DateTime.now().add(_totalBudget);
      final bases = await _candidateBases();

      final directId =
          _normalizeVideoId(videoId) ??
          _videoIdFromUrl(videoId) ??
          _videoIdFromUrl(audioUrl);
      debugPrint(
        '[WebYouTube] resolve "$title" / "$artist" '
        'dur=${duration?.inSeconds ?? 0}s id=${directId ?? '-'}',
      );
      if (directId != null) {
        final direct = await _downloadVideo(
          directId,
          deadline: deadline,
          fallbackTitle: title,
          fallbackAuthor: artist,
          fallbackDuration: duration,
        );
        if (direct != null) return direct;
      }

      final candidates = await _search(
        title: title,
        artist: artist,
        duration: duration,
        bases: bases,
        deadline: deadline,
      );
      for (final candidate in candidates) {
        if (DateTime.now().isAfter(deadline)) break;
        final hit = await _downloadVideo(
          candidate.videoId,
          deadline: deadline,
          fallbackTitle: candidate.title,
          fallbackAuthor: candidate.author,
          fallbackDuration: candidate.duration,
        );
        if (hit != null) return hit;
      }
      debugPrint('[WebYouTube] unresolved "$title" / "$artist"');
      return null;
    });
  }

  void dispose() => _client.close();

  Future<T> _withSlot<T>(Future<T> Function() action) async {
    if (_activeDownloads >= _maxConcurrentDownloads) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
    }
    _activeDownloads++;
    try {
      return await action();
    } finally {
      _activeDownloads--;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    }
  }

  Future<List<String>> _candidateBases() async {
    final cached = _knownBases;
    final preferred = _preferredBase;
    if (cached != null) {
      if (preferred == null || cached.first == preferred) return cached;
      return <String>[preferred, ...cached.where((b) => b != preferred)];
    }

    final bases = <String>[_primaryBase];
    try {
      final response = await _client
          .get(Uri.parse(_instancesUrl))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! List || entry.length < 2) continue;
            final info = entry[1];
            if (info is! Map) continue;
            // A browser can only use instances that send CORS headers and
            // expose the API; everything else fails before a byte is read.
            if (info['api'] != true || info['cors'] != true) continue;
            final uri = info['uri'];
            if (uri is String &&
                uri.startsWith('https://') &&
                !bases.contains(uri)) {
              bases.add(uri);
            }
          }
        }
      }
    } catch (_) {}
    _knownBases = bases;
    return bases;
  }

  Future<List<_YouTubeCandidate>> _search({
    required String title,
    required String artist,
    required Duration? duration,
    required List<String> bases,
    required DateTime deadline,
  }) async {
    final queries = <String>{
      '$title $artist'.trim(),
      '$title $artist audio'.trim(),
    };

    for (final base in bases) {
      for (final query in queries) {
        if (DateTime.now().isAfter(deadline)) return const [];
        try {
          final uri = Uri.parse(
            '$base/api/v1/search',
          ).replace(queryParameters: {'q': query, 'type': 'video'});
          final response = await _client
              .get(uri, headers: {'Accept': 'application/json'})
              .timeout(_searchTimeout);
          if (response.statusCode != 200) continue;
          final decoded = jsonDecode(
            utf8.decode(response.bodyBytes, allowMalformed: true),
          );
          if (decoded is! List) continue;

          final candidates = <_YouTubeCandidate>[];
          for (final item in decoded) {
            if (item is! Map) continue;
            final id = _normalizeVideoId(item['videoId']);
            final hitTitle = item['title'];
            if (id == null || hitTitle is! String || hitTitle.isEmpty) {
              continue;
            }
            final author = item['author'];
            final length = item['lengthSeconds'];
            candidates.add(
              _YouTubeCandidate(
                videoId: id,
                title: hitTitle,
                author: author is String ? author : '',
                duration: Duration(
                  seconds: length is int
                      ? math.max(0, length)
                      : int.tryParse('$length') ?? 0,
                ),
              ),
            );
          }
          final ranked = _rank(
            candidates,
            title: title,
            artist: artist,
            duration: duration,
          );
          if (ranked.isNotEmpty) {
            _preferredBase = base;
            return ranked;
          }
          debugPrint(
            '[WebYouTube] search "$query" via ${uri.host}: '
            '${candidates.length} hits, none matched',
          );
        } catch (e) {
          debugPrint('[WebYouTube] search via $base failed: $e');
        }
      }
    }
    return const [];
  }

  List<_YouTubeCandidate> _rank(
    List<_YouTubeCandidate> candidates, {
    required String title,
    required String artist,
    required Duration? duration,
  }) {
    final scored = <({_YouTubeCandidate candidate, int score})>[];
    for (final candidate in candidates) {
      final score = _score(
        candidate,
        title: title,
        artist: artist,
        duration: duration,
      );
      if (score >= 0) scored.add((candidate: candidate, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.isNotEmpty) {
      debugPrint(
        '[WebYouTube] ranked: '
        '${scored.take(3).map((e) => '${e.score}:${e.candidate.title} '
            '(${e.candidate.duration.inSeconds}s)').join(' | ')}',
      );
    }
    return scored.map((entry) => entry.candidate).toList();
  }

  /// Returns a score for [candidate], or -1 when it is clearly a different
  /// song/version. Mirrors the native provider's studio-first policy.
  int _score(
    _YouTubeCandidate candidate, {
    required String title,
    required String artist,
    required Duration? duration,
  }) {
    final seconds = candidate.duration.inSeconds;
    if (seconds > 0 && seconds < 45) return -1;
    if (seconds > 1200) return -1;

    final wantKey = TrackEnrichmentService.normalizeKey(title);
    final hitKey = TrackEnrichmentService.normalizeKey(candidate.title);
    if (wantKey.isEmpty || hitKey.isEmpty) return -1;

    final combined = '${candidate.title} ${candidate.author}';
    if (!TrackEnrichmentService.versionCompatible(title, candidate.title)) {
      return -1;
    }
    if (TrackEnrichmentService.isNonStudioVariant(combined, '$title $artist')) {
      return -1;
    }

    // A live/remix/acoustic/demo rendition is a different recording unless the
    // catalog title asks for one (versionCompatible only rejects when both
    // sides carry a conflicting tag).
    final wantTags = TrackEnrichmentService.versionTags(title);
    final hitTags = TrackEnrichmentService.versionTags(candidate.title);
    for (final tag in hitTags) {
      if ((tag == 'live' ||
              tag == 'remix' ||
              tag == 'acoustic' ||
              tag == 'demo') &&
          !wantTags.contains(tag)) {
        return -1;
      }
    }

    final lowered = combined.toLowerCase();
    if (_rejectPattern.hasMatch(lowered) &&
        !_rejectPattern.hasMatch(title.toLowerCase())) {
      return -1;
    }

    final wantTokens = _titleTokens(wantKey);
    var hitTokens = _titleTokens(hitKey);
    var tokens = wantTokens;
    if (tokens.isEmpty || hitTokens.isEmpty) {
      // A title made only of noise words ("Video", "Audio") still needs a
      // usable comparison, so fall back to every significant word.
      tokens = _allWords(wantKey);
      hitTokens = _allWords(hitKey);
    }
    if (tokens.isEmpty || hitTokens.isEmpty) return -1;
    final matched = tokens.intersection(hitTokens).length;
    final coverage = matched / tokens.length;
    if (coverage < 0.75) return -1;

    var score = (coverage * 20).round();
    if (matched == tokens.length) score += 5;

    final artistTokens = _artistTokens(artist, title);
    if (artistTokens.isNotEmpty) {
      final hitWords =
          '$hitKey ${TrackEnrichmentService.normalizeKey(candidate.author)}';
      var artistHits = 0;
      for (final token in artistTokens) {
        if (_containsPhrase(hitWords, token)) artistHits++;
      }
      if (artistHits == 0) return -1;
      score += 6 + math.min(2, artistHits - 1);
    }

    if (lowered.contains('official audio') ||
        lowered.contains('[audio]') ||
        lowered.contains('(audio)') ||
        lowered.contains('topic')) {
      score += 4;
    } else if (lowered.contains('official music video') ||
        lowered.contains('official video') ||
        lowered.contains('music video')) {
      score -= 1;
    }
    if (_subtitlePattern.hasMatch(lowered)) score -= 2;

    if (seconds > 0 && (duration?.inSeconds ?? 0) > 35) {
      final diff = (seconds - duration!.inSeconds).abs();
      if (diff <= 3) {
        score += 8;
      } else if (diff <= 8) {
        score += 5;
      } else if (diff <= 15) {
        score += 2;
      } else if (diff > 30) {
        score -= 5;
      }
    }
    return score;
  }

  Set<String> _titleTokens(String normalized) => normalized
      .split(' ')
      .where((word) => word.length > 1 && !_ignoredTitleWords.contains(word))
      .toSet();

  Set<String> _allWords(String normalized) =>
      normalized.split(' ').where((word) => word.length > 1).toSet();

  List<String> _artistTokens(String artist, String title) {
    final tokens = <String>{
      ...artist.split(RegExp(r'[,&/]|\bfeat\.?|\bft\.?', caseSensitive: false)),
      ..._featuredArtistNames(title),
    };
    final result = <String>[];
    for (final raw in tokens) {
      final normalized = TrackEnrichmentService.normalizeKey(
        raw.replaceAll(
          RegExp(r'(records|music|topic|official)', caseSensitive: false),
          '',
        ),
      );
      if (normalized.length < 2) continue;
      if (normalized == 'the' || normalized == 'and') continue;
      if (!result.contains(normalized)) result.add(normalized);
    }
    return result;
  }

  List<String> _featuredArtistNames(String title) {
    final match = RegExp(
      r'\b(?:feat|ft|featuring)\.?\s+([^\)\]\}\(]+)',
      caseSensitive: false,
    ).firstMatch(title);
    if (match == null) return const [];
    return (match.group(1) ?? '')
        .split(RegExp(r',|&|\band\b', caseSensitive: false))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  bool _containsPhrase(String haystack, String needle) {
    if (haystack.isEmpty || needle.isEmpty) return false;
    if (haystack.contains(needle)) return true;
    final compactHaystack = haystack.replaceAll(' ', '');
    final compactNeedle = needle.replaceAll(' ', '');
    return compactNeedle.isNotEmpty && compactHaystack.contains(compactNeedle);
  }

  /// Companion endpoints in the order they should be tried: the host that
  /// last worked first, then the rest starting at a rotating offset so a dead
  /// host does not cost every download the same probe.
  List<String> _downloadEndpoints() {
    final preferred = _preferredCompanion;
    final ordered = <String>[];
    if (preferred != null && _primaryCompanions.contains(preferred)) {
      ordered.add(preferred);
    }
    final rest = _primaryCompanions.where((h) => h != preferred).toList();
    if (rest.isNotEmpty) {
      final start = _companionCursor++ % rest.length;
      ordered.addAll(rest.skip(start));
      ordered.addAll(rest.take(start));
    }
    return [for (final host in ordered) '$host/companion/latest_version'];
  }

  /// Checks that [endpoint] can serve [videoId] before paying for the whole
  /// track. A two-kilobyte range request surfaces a CORS/network failure or a
  /// missing rendition in about a second instead of stalling for the full
  /// download timeout.
  Future<bool> _probeEndpoint(
    String endpoint,
    String videoId,
    String itag,
  ) async {
    final host = Uri.parse(endpoint).host;
    try {
      final uri = Uri.parse(endpoint).replace(
        queryParameters: {'id': videoId, 'itag': itag, 'local': 'true'},
      );
      final response = await _client
          .get(uri, headers: {'Accept': '*/*', 'Range': 'bytes=0-2047'})
          .timeout(_probeTimeout);
      if (response.statusCode != 200 && response.statusCode != 206) {
        debugPrint(
          '[WebYouTube] probe $videoId itag $itag via $host: '
          'HTTP ${response.statusCode}',
        );
        return false;
      }
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') ||
          contentType.contains('application/json')) {
        debugPrint(
          '[WebYouTube] probe $videoId itag $itag via $host: '
          'unexpected $contentType',
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[WebYouTube] probe $videoId itag $itag via $host failed: $e');
      return false;
    }
  }

  Future<WebYouTubeAudio?> _downloadVideo(
    String videoId, {
    required DateTime deadline,
    required String fallbackTitle,
    required String fallbackAuthor,
    required Duration? fallbackDuration,
  }) async {
    final endpoints = _downloadEndpoints();
    final failed = <String>{};

    for (final itag in _audioItags) {
      for (final endpoint in endpoints) {
        if (failed.contains(endpoint)) continue;
        if (DateTime.now().isAfter(deadline)) return null;
        final host = Uri.parse(endpoint).host;
        if (!await _probeEndpoint(endpoint, videoId, itag)) continue;
        if (DateTime.now().isAfter(deadline)) return null;

        try {
          final uri = Uri.parse(endpoint).replace(
            queryParameters: {'id': videoId, 'itag': itag, 'local': 'true'},
          );
          final response = await _client
              .get(uri, headers: {'Accept': '*/*'})
              .timeout(_downloadTimeout);
          if (response.statusCode != 200 && response.statusCode != 206) {
            failed.add(endpoint);
            debugPrint(
              '[WebYouTube] $videoId itag $itag via $host: '
              'HTTP ${response.statusCode}',
            );
            continue;
          }
          final contentType = response.headers['content-type'] ?? 'audio/mp4';
          if (contentType.contains('text/html') ||
              contentType.contains('application/json')) {
            debugPrint(
              '[WebYouTube] $videoId itag $itag via $host: '
              'unexpected $contentType',
            );
            continue;
          }
          final bytes = response.bodyBytes;
          if (bytes.length < _minimumBytes) {
            debugPrint(
              '[WebYouTube] $videoId itag $itag via $host: '
              'short response (${bytes.length} bytes)',
            );
            continue;
          }
          _preferredCompanion = host;
          debugPrint(
            '[WebYouTube] $videoId itag $itag via $host '
            '(${bytes.length} bytes)',
          );
          return WebYouTubeAudio(
            bytes: bytes,
            contentType: contentType,
            videoId: videoId,
            streamUrl: uri.toString(),
            title: fallbackTitle,
            author: fallbackAuthor,
            duration: fallbackDuration ?? Duration.zero,
          );
        } catch (e) {
          // A CORS/network failure will not fix itself for another itag:
          // remember the endpoint and move on to the next host.
          failed.add(endpoint);
          debugPrint('[WebYouTube] $videoId itag $itag via $host failed: $e');
        }
      }
    }
    return null;
  }

  static String? _normalizeVideoId(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.length == 11 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  static String? _videoIdFromUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final uri = Uri.tryParse(value);
      if (uri == null) return null;
      if (uri.host.endsWith('youtu.be')) {
        final id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
        return _normalizeVideoId(id);
      }
      if (uri.host.endsWith('youtube.com') ||
          uri.host.endsWith('youtube-nocookie.com')) {
        return _normalizeVideoId(uri.queryParameters['v']);
      }
      if (uri.host.contains('googlevideo.com') ||
          uri.path.endsWith('/latest_version')) {
        return _normalizeVideoId(uri.queryParameters['id']);
      }
    } catch (_) {}
    return null;
  }
}

class _YouTubeCandidate {
  const _YouTubeCandidate({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
  });

  final String videoId;
  final String title;
  final String author;
  final Duration duration;
}
