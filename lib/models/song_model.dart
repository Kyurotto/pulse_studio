import 'package:material_ui/material_ui.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;

  /// Mutable so a resolved full-length stream can correct the Spotify
  /// metadata duration (or a 30s clip can report its real length).
  Duration duration;
  final String genre;
  String imageUrl;
  final List<Color> gradientColors;
  final String plays;

  /// Sung lyric lines only.
  ///
  /// Instrumental breaks, drum/guitar/piano solos, section markers such as
  /// `[Chorus]`, and musical-symbol cues are stripped centrally on assignment
  /// so every view (mobile sheet, desktop view, right panel) shares the exact
  /// same list. Keeping one normalized list also guarantees that a lyric line
  /// index computed from playback progress points at the line being rendered.
  List<String> _lyrics;
  List<String> get lyrics => _lyrics;
  set lyrics(List<String> value) => _lyrics = cleanSungLyrics(value);

  String audioUrl;
  final bool isFeatured;
  bool isLiked;
  bool isPreview;

  /// True when audio comes from YouTube (URLs expire after a few hours —
  /// the player resolves a fresh one when a saved URL fails to load).
  bool isYouTubeAudio;
  String youtubeVideoId;
  bool isEnrichingLyrics;

  /// True when the catalog rates this track as explicit (or its metadata
  /// carries an explicit marker). Used by the Explicit Content Filter.
  bool isExplicit;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.genre,
    required this.imageUrl,
    required this.gradientColors,
    required this.plays,
    required List<String> lyrics,
    this.audioUrl = '',
    this.isFeatured = false,
    this.isLiked = false,
    this.isPreview = false,
    this.isYouTubeAudio = false,
    this.youtubeVideoId = '',
    this.isEnrichingLyrics = false,
    bool? isExplicit,
  }) : _lyrics = cleanSungLyrics(lyrics),
       isExplicit = isExplicit ?? looksExplicit(title, album);

  /// Heuristic fallback for sources that do not publish a content rating
  /// (notably YouTube). Catalog ratings (iTunes `trackExplicitness` and
  /// Spotify `isExplicit`) always take precedence when available.
  static bool looksExplicit(String title, [String album = '']) {
    final text = '$title $album';
    final bracketMarker = RegExp(
      r'(\(|\[)\s*(explicit|dirty)\s*(\)|\])',
      caseSensitive: false,
    );
    if (bracketMarker.hasMatch(text)) return true;
    final phraseMarker = RegExp(
      r'\bexplicit\s+(version|content|lyrics)\b',
      caseSensitive: false,
    );
    if (phraseMarker.hasMatch(text)) return true;
    return text.toLowerCase().contains('parental advisory');
  }

  /// True when this song can actually produce sound (local asset or URL).
  bool get hasAudio => audioUrl.isNotEmpty;

  /// True when this song has no resolved audio yet and is actively locating.
  bool get isLocating => !hasAudio;

  /// Imported Spotify metadata starts silent — only true until enrichment
  /// resolves a playable preview URL.
  bool get isSilentPlaceholder => id.startsWith('spotify-') && !hasAudio;

  /// True when this song resolved to a full-length stream or audio file
  /// (not a 30-second preview clip and not silent).
  bool get isFullTrack => hasAudio && !isPreview;

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Compiled once. These run for every lyric line on every playback tick
  // (~10x/sec while the lyrics view is open), and rebuilding a RegExp per call
  // was measurable jank on phones.
  static final RegExp _lrcTimestampPattern = RegExp(
    r'^\[(\d+):(\d+)(?:[.:](\d+))?\]',
  );
  static final RegExp _lrcAltTimestampPattern = RegExp(r'^\[(\d+):(\d+\.?\d*)\]');
  static final RegExp _lrcBracketPattern = RegExp(r'^\s*\[.*?\]');

  /// Bare section headers that appear without brackets in unsynced lyric
  /// dumps, e.g. `CHORUS`, `Verse 2`, `PRE-CHORUS`, `BRIDGE`.
  static final RegExp _bareSectionMarker = RegExp(
    r'^(?:intro|outro|verse(?:\s*\d+)?|pre[- ]?chorus|chorus|hook|refrain|bridge|instrumental|interlude|breakdown|skit|spoken|ad[- ]?lib)(?:\s*[:\-–]\s*.*)?$',
    caseSensitive: false,
  );

  /// Instrument annotations such as `Drums: ...`, `Guitar - ...`, `Bass:`.
  static final RegExp _instrumentLabel = RegExp(
    r'^(?:drums?|guitars?|bass|piano|keys?|synth(?:esizer)?|strings|violin|sax(?:ophone)?|trumpet|brass|organ|percussion|808s?|beat)\s*[:\-–]\s*.*$',
    caseSensitive: false,
  );

  /// Repeat counters such as `(x2)`, `[2x]`, `x3`, `repeat chorus`.
  static final RegExp _repeatMarker = RegExp(
    r'^[\[(]?\s*(?:x\s*\d+|\d+\s*x|repeat(?:\s+(?:chorus|verse|hook))?)\s*[\])]?$',
    caseSensitive: false,
  );

  /// Pure musical symbols, notes, or punctuation (e.g. ♫, ♪, 🎵, ---, ***).
  static final RegExp _musicalSymbols = RegExp(r'[\s♫♪🎵🎶\-_*#~.]+');

  /// Bracketed structural marker such as `[Chorus]`, `(Verse 2)`, `[Bridge: X]`.
  static final RegExp _bracketedSectionMarker = RegExp(
    r'^[\[(]\s*(?:intro|outro|verse|pre[- ]?chorus|chorus|hook|refrain|bridge|instrumental|interlude|solo|break|skit|spoken|ad[- ]?lib)\b[^\])]*[\])]$',
    caseSensitive: false,
  );

  /// Bracketed instrument/cue description such as `(Guitar solo)` or `[Music]`.
  static final RegExp _bracketedCue = RegExp(
    r'^[(\[\{/*~]\s*(?:drum|drums|guitar|piano|bass|violin|saxophone|brass|synth|organ|keyboard|instrumental|music|solo|interlude|intro|outro|bridge|beat|drop|rhythm|melody|groove|applause|cheering|laughter|sound\s*effect).*?[)\]\}/*~]$',
    caseSensitive: false,
  );

  static Duration? parseLyricTimestamp(String line) {
    final trimmed = line.trim();
    final match = _lrcTimestampPattern.firstMatch(trimmed);
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final frac = match.group(3);
      int millis = 0;
      if (frac != null && frac.isNotEmpty) {
        if (frac.length == 1) {
          millis = int.parse(frac) * 100;
        } else if (frac.length == 2) {
          millis = int.parse(frac) * 10;
        } else {
          millis = int.parse(frac.substring(0, 3));
        }
      }
      return Duration(milliseconds: min * 60000 + sec * 1000 + millis);
    }
    final alt = _lrcAltTimestampPattern.firstMatch(trimmed);
    if (alt != null) {
      final min = int.parse(alt.group(1)!);
      final sec = double.parse(alt.group(2)!);
      return Duration(milliseconds: (min * 60000 + sec * 1000).round());
    }
    return null;
  }

  static String stripTimestamp(String line) {
    return line.replaceAll(_lrcBracketPattern, '').trim();
  }

  /// Checks whether a lyric line represents instrumental sections, drum solos,
  /// sound/cue markers, or musical symbols rather than sung lyrics.
  static bool isInstrumentalOrCueLine(String rawLine) {
    final clean = stripTimestamp(rawLine).trim();
    if (clean.isEmpty) return true;

    // Filter pure musical symbols, notes, or punctuation (e.g. ♫, ♪, 🎵, 🎶, ---, ***)
    final textWithoutSymbols = clean.replaceAll(_musicalSymbols, '').trim();
    if (textWithoutSymbols.isEmpty) return true;

    final lower = clean.toLowerCase();

    // Section headers such as [Chorus], [Verse 2], or [Bridge: Artist] are
    // structural markers, not sung words.
    if (_bracketedSectionMarker.hasMatch(clean)) return true;
    if (_bareSectionMarker.hasMatch(clean)) return true;
    if (_repeatMarker.hasMatch(clean)) return true;
    if (_instrumentLabel.hasMatch(clean)) return true;

    // Check if the line is enclosed in brackets/parentheses and describes an instrument or non-vocal cue
    if (_bracketedCue.hasMatch(lower)) return true;

    // Check direct instrumental keywords when they make up the line
    final cueKeywords = const [
      'instrumental',
      'drum solo',
      'drums solo',
      'guitar solo',
      'piano solo',
      'bass solo',
      'sax solo',
      'saxophone solo',
      'violin solo',
      'synth solo',
      'guitar intro',
      'drum intro',
      'piano intro',
      'instrumental break',
      'instrumental melody',
      'instrumental groove',
      'instrumental groove & rhythm',
      'dynamic melody & rhythm',
      'harmonic bridge',
      'dynamic bridge',
      'beat drop',
      'music break',
    ];
    for (final kw in cueKeywords) {
      if (lower == kw || lower == '($kw)' || lower == '[$kw]') {
        return true;
      }
    }

    return false;
  }

  /// Filters out all non-vocal, drum, and instrumental cue lines from lyrics.
  static List<String> cleanSungLyrics(List<String> rawLyrics) {
    if (rawLyrics.isEmpty) return const [];
    return rawLyrics.where((line) => !isInstrumentalOrCueLine(line)).toList();
  }

  /// True when at least one line carries an LRC timestamp, i.e. the lyrics can
  /// actually be synced. Plain (untimed) lyrics cannot be aligned reliably, so
  /// the UI shows them without a fake moving highlight.
  static bool hasSyncedLyrics(List<String> lyrics) =>
      lyrics.any((line) => parseLyricTimestamp(line) != null);

  /// Latency compensation so the highlighted line transitions right when the
  /// vocal starts instead of trailing behind audio buffer latency.
  ///
  /// This is only the automatic baseline; each song can add a manual
  /// calibration offset on top of it (persisted per track).
  static const Duration defaultLyricsLeadOffset = Duration(milliseconds: 250);

  /// Which lyric line should be active for this playback position.
  ///
  /// Uses synced timestamps if available with lead-offset compensation for accurate
  /// vocal alignment. Otherwise, plain (untimed) lyric lines are spread evenly across the track.
  static int lyricsLineIndexForProgress(
    List<String> lyrics,
    Duration position,
    Duration total, {
    Duration leadOffset = defaultLyricsLeadOffset,
  }) {
    if (lyrics.isEmpty) return 0;
    final effectiveTotal =
        total > Duration.zero ? total : const Duration(minutes: 3);

    final hasTimestamped = hasSyncedLyrics(lyrics);
    if (hasTimestamped) {
      final effectivePos = position + leadOffset;
      int lastIndex = -1;
      for (int i = 0; i < lyrics.length; i++) {
        final time = parseLyricTimestamp(lyrics[i]);
        if (time != null) {
          // Scan the whole list instead of breaking on the first future
          // timestamp: LRC files occasionally contain out-of-order or
          // repeated timestamps, and breaking there pinned the highlight to
          // a line that had already been sung.
          if (effectivePos >= time) {
            lastIndex = i;
          }
        }
      }
      if (lastIndex >= 0) return lastIndex;
      final firstIdx = lyrics.indexWhere((l) => parseLyricTimestamp(l) != null);
      return firstIdx >= 0 ? firstIdx : 0;
    }

    final posUs = position.inMicroseconds;
    final totalUs = effectiveTotal.inMicroseconds;
    if (posUs <= 0 || totalUs <= 0) return 0;
    final progress = posUs / totalUs;
    if (progress >= 1) return lyrics.length - 1;
    final idx = (progress * lyrics.length).floor();
    if (idx < 0) return 0;
    if (idx >= lyrics.length) return lyrics.length - 1;
    return idx;
  }

  /// Playback position for a tapped lyric line (inverse of
  /// [lyricsLineIndexForProgress]) so tapping a line seeks the player.
  static Duration positionForLyricsLine(
    List<String> lyrics,
    int lineIndex,
    Duration total,
  ) {
    if (lyrics.isEmpty) return Duration.zero;
    final effectiveTotal =
        total > Duration.zero ? total : const Duration(minutes: 3);
    final clamped = lineIndex.clamp(0, lyrics.length - 1).toInt();

    final time = parseLyricTimestamp(lyrics[clamped]);
    if (time != null) return time;

    final micros = (effectiveTotal.inMicroseconds * clamped) ~/ lyrics.length;
    return Duration(microseconds: micros);
  }
}

class MusicPlaylist {
  final String id;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final List<String> songIds;
  String imageUrl;

  MusicPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.gradient,
    List<String>? songIds,
    this.imageUrl = '',
  }) : songIds = songIds ?? [];

  int get trackCount => songIds.length;
}

class SampleMusicData {
  /// No pre-loaded sample songs — the app starts with an empty library.
  static List<Song> get sampleSongs => [];

  /// Bundled tracks with offline assets available for direct matching.
  static List<Song> get bundledTracks => [
        Song(
          id: 'lose-yourself',
          title: 'Lose Yourself',
          artist: 'Eminem',
          album: '8 Mile Soundtrack',
          duration: const Duration(minutes: 5, seconds: 21),
          genre: 'Hip-Hop',
          imageUrl: '',
          gradientColors: const [Color(0xFFE52D27), Color(0xFFB31217)],
          plays: '2.5B',
          audioUrl: 'assets/audio/lose-yourself.m4a',
          isFeatured: true,
          lyrics: const [
            "Look, if you had one shot, or one opportunity",
            "To seize everything you ever wanted in one moment",
            "Would you capture it, or just let it slip?",
            "Yo, his palms are sweaty, knees weak, arms are heavy",
            "There's vomit on his sweater already, mom's spaghetti",
            "He's nervous, but on the surface he looks calm and ready",
            "To drop bombs, but he keeps on forgettin'",
            "What he wrote down, the whole crowd goes so loud",
            "He opens his mouth, but the words won't come out",
            "He's chokin', how? Everybody's jokin' now",
            "The clocks run out, time's up, over, blaow",
            "Snap back to reality, ope there goes gravity",
            "Ope, there goes Rabbit, he choked, he's so mad",
            "But he won't give up that easy? No, he won't have it",
            "He knows his whole back's to these ropes, it don't matter",
            "He's dope, he knows that, but he's broke, he's so stagnant",
          ],
        ),
        Song(
          id: 'blank-space',
          title: 'Blank Space',
          artist: 'Taylor Swift',
          album: '1989',
          duration: const Duration(minutes: 3, seconds: 51),
          genre: 'Pop',
          imageUrl: '',
          gradientColors: const [Color(0xFF654EA3), Color(0xFFEAAFC8)],
          plays: '1.9B',
          audioUrl: 'assets/audio/blank-space.m4a',
          lyrics: const [
            "Nice to meet you, where you been?",
            "I could show you incredible things",
            "Magic, madness, heaven, sin",
            "Saw you there and I thought",
            "'Oh, my God, look at that face'",
            "You look like my next mistake",
            "Love's a game, wanna play?",
            "New money, suit and tie",
            "I can read you like a magazine",
            "Ain't it funny? Rumors fly",
            "And I know you heard about me",
            "So it's gonna be forever",
            "Or it's gonna go down in flames",
            "You can tell me when it's over, mm",
            "If the high was worth the pain",
            "Got a long list of ex-lovers",
            "They'll tell you I'm insane",
            "'Cause you know I love the players",
            "And you love the game",
            "'Cause we're young, and we're reckless",
            "We'll take this way too far",
            "It'll leave you breathless, mm",
            "Or with a nasty scar",
            "Got a long list of ex-lovers",
            "They'll tell you I'm insane",
            "But I've got a blank space, baby",
            "And I'll write your name",
          ],
        ),
        Song(
          id: 'just-the-way-you-are',
          title: 'Just the Way You Are',
          artist: 'Bruno Mars',
          album: 'Doo-Wops & Hooligans',
          duration: const Duration(minutes: 3, seconds: 39),
          genre: 'Pop',
          imageUrl: '',
          gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
          plays: '2.3B',
          audioUrl: 'assets/audio/just-the-way-you-are.m4a',
          lyrics: const [
            "Oh, her eyes, her eyes make the stars look like they're not shinin'",
            "Her hair, her hair falls perfectly without her tryin'",
            "She's so beautiful and I tell her everyday",
            "When I see your face",
            "There's not a thing that I would change",
            "'Cause you're amazing",
            "Just the way you are",
          ],
        ),
      ];

  /// No pre-loaded artist playlists.
  static List<MusicPlaylist> get initialPlaylists => [];

  static List<MusicPlaylist> get playlists => initialPlaylists;

  static List<String> get genres => const ['All', 'Pop', 'Hip-Hop', 'Acoustic', 'Funk'];
}
