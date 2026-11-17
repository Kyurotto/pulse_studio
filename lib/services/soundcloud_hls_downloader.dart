// lib/services/soundcloud_hls_downloader.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Materialises a SoundCloud HLS audio stream into a single playable file.
///
/// SoundCloud only serves **full-length** tracks as fragmented-MP4 HLS
/// (`#EXT-X-MAP` init segment followed by `.m4s` media segments); the only
/// progressive URLs it still exposes are 30-second snippets. Handing the
/// playlist to ExoPlayer failed on device (gzip/source errors), and a playlist
/// URL can never be stored as an offline download. Concatenating the init
/// segment with the media segments in order produces a valid AAC/MP4 file that
/// ExoPlayer plays normally and that can be kept for offline mode.
class SoundCloudHlsDownloader {
  SoundCloudHlsDownloader({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static final RegExp _uriAttribute = RegExp(r'URI="([^"]+)"');

  /// True when [url] is a SoundCloud media playlist that this downloader can
  /// turn into a file. Other HLS sources are deliberately not accepted: they
  /// use codecs/segmentation that the app has never been able to play.
  static bool isSoundCloudPlaylistUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('playback.media-streaming.soundcloud.cloud');
  }

  /// Downloads every segment of [playlistUrl] into [target] in order.
  ///
  /// Returns the number of bytes written, or 0 when nothing usable could be
  /// fetched (in which case [target] is removed so a truncated file can never
  /// be mistaken for a finished download).
  Future<int> download({
    required String playlistUrl,
    required File target,
  }) async {
    try {
      var sourceUrl = playlistUrl;
      var manifest = await _fetchText(sourceUrl);
      if (manifest == null) return await _fail(target);

      // A master playlist only lists variants; follow the first one.
      if (!manifest.contains('#EXT-X-MAP') &&
          manifest.contains('#EXT-X-STREAM-INF')) {
        final variant = _firstMediaLine(manifest);
        if (variant == null) return await _fail(target);
        sourceUrl = _resolve(sourceUrl, variant);
        manifest = await _fetchText(sourceUrl);
        if (manifest == null) return await _fail(target);
      }

      String? initUri;
      final segmentUris = <String>[];
      for (final rawLine in const LineSplitter().convert(manifest)) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        if (line.startsWith('#EXT-X-MAP')) {
          final match = _uriAttribute.firstMatch(line);
          if (match != null) initUri = match.group(1);
          continue;
        }
        if (line.startsWith('#')) continue;
        segmentUris.add(line);
      }
      if (segmentUris.isEmpty) return await _fail(target);

      final sink = target.openWrite();
      var written = 0;
      var ok = true;
      try {
        if (initUri != null && initUri.isNotEmpty) {
          final initBytes = await _fetchBytes(_resolve(sourceUrl, initUri));
          if (initBytes == null) {
            ok = false;
          } else {
            sink.add(initBytes);
            written += initBytes.length;
          }
        }
        if (ok) {
          for (final segment in segmentUris) {
            final bytes = await _fetchBytes(_resolve(sourceUrl, segment));
            if (bytes == null || bytes.isEmpty) {
              ok = false;
              break;
            }
            sink.add(bytes);
            written += bytes.length;
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (!ok || written == 0) return await _fail(target);
      return written;
    } catch (_) {
      return await _fail(target);
    }
  }

  Future<int> _fail(File target) async {
    try {
      if (await target.exists()) await target.delete();
    } catch (_) {}
    return 0;
  }

  String? _firstMediaLine(String manifest) {
    for (final rawLine in const LineSplitter().convert(manifest)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      return line;
    }
    return null;
  }

  String _resolve(String base, String relative) =>
      Uri.parse(base).resolve(relative).toString();

  Future<String?> _fetchText(String url) async {
    final bytes = await _fetchBytes(url);
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Segment fetches are retried: a mobile connection regularly stalls one
  /// request out of twenty, and a single lost segment must not discard an
  /// otherwise complete track.
  Future<List<int>?> _fetchBytes(String url) async {
    var lastError = 'no response';
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await _client
            .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
        lastError = 'status ${response.statusCode}';
      } catch (e) {
        lastError = e.toString();
      }
      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    final uri = Uri.tryParse(url);
    debugPrint(
      '[HLS] segment failed after 3 tries ($lastError) '
      '${uri?.host ?? url} ${uri?.path ?? ''}',
    );
    return null;
  }

  void dispose() => _client.close();
}
