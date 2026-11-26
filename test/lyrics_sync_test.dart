import 'package:flutter_test/flutter_test.dart';
import 'package:music/models/song_model.dart';

Song _song(List<String> lyrics) => Song(
  id: 'test-song',
  title: 'Test Song',
  artist: 'Test Artist',
  album: 'Test Album',
  duration: const Duration(minutes: 3),
  genre: 'Pop',
  imageUrl: '',
  gradientColors: const [],
  plays: '0',
  lyrics: lyrics,
);

void main() {
  group('Central lyric normalization', () {
    test('strips instrumental, cue, and section-marker lines', () {
      final song = _song([
        '[00:00.00] [Intro]',
        '[00:05.00] First sung line',
        '[00:10.00] (Guitar solo)',
        '[00:15.00] ♫',
        '[00:20.00] (Instrumental Break)',
        '[00:25.00] Second sung line',
        '[00:30.00] [Chorus]',
        '[00:35.00] Drum solo',
      ]);

      expect(song.lyrics, [
        '[00:05.00] First sung line',
        '[00:25.00] Second sung line',
      ]);
    });

    test('re-normalizes when lyrics are reassigned', () {
      final song = _song(const ['First line']);
      song.lyrics = const [
        '[00:01.00] Kept line',
        '[00:02.00] (Piano interlude)',
      ];
      expect(song.lyrics, ['[00:01.00] Kept line']);
    });

    test('keeps parenthesised sung ad-libs', () {
      final song = _song(const ['(Oh-oh-oh)', '(Yeah, yeah)']);
      expect(song.lyrics, ['(Oh-oh-oh)', '(Yeah, yeah)']);
    });

    test('hasSyncedLyrics distinguishes LRC from plain lyrics', () {
      expect(
        Song.hasSyncedLyrics(['[00:12.50] Timed line']),
        isTrue,
      );
      expect(Song.hasSyncedLyrics(['Plain line']), isFalse);
      expect(Song.hasSyncedLyrics(const []), isFalse);
    });

    test('drops bare section headers from unsynced lyric dumps', () {
      final song = _song(const [
        'Verse 1',
        'First sung line',
        'CHORUS',
        'Second sung line',
        'PRE-CHORUS',
        'BRIDGE',
      ]);
      expect(song.lyrics, ['First sung line', 'Second sung line']);
    });

    test('drops instrument annotations and repeat counters', () {
      final song = _song(const [
        'Drums: session player',
        'Guitar - main riff',
        'Real lyric here',
        '(x2)',
        '[2x]',
        'repeat chorus',
      ]);
      expect(song.lyrics, ['Real lyric here']);
    });

    test('keeps words that merely contain an instrument name', () {
      final song = _song(const [
        'Bass in the beat, drums in my chest',
        'Bridge over the water',
        'Solo',
      ]);
      expect(song.lyrics, [
        'Bass in the beat, drums in my chest',
        'Bridge over the water',
        'Solo',
      ]);
    });

    test('parses common LRC timestamp shapes', () {
      expect(
        Song.parseLyricTimestamp('[01:02.34] line'),
        const Duration(minutes: 1, seconds: 2, milliseconds: 340),
      );
      expect(
        Song.parseLyricTimestamp('[01:02.345] line'),
        const Duration(minutes: 1, seconds: 2, milliseconds: 345),
      );
      expect(
        Song.parseLyricTimestamp('[1:02] line'),
        const Duration(minutes: 1, seconds: 2),
      );
      expect(Song.parseLyricTimestamp('[ar:Artist]'), isNull);
      expect(Song.parseLyricTimestamp('Plain line'), isNull);
    });
  });

  group('Accurate line tracking', () {
    test('handles out-of-order timestamps without pinning an old line', () {
      final lyrics = [
        '[00:10.00] Ten',
        '[00:30.00] Thirty',
        '[00:20.00] Twenty',
      ];
      // At 25s the line at 20s is the latest one that has started, even
      // though a later entry (30s) appears before it in the list.
      expect(
        Song.lyricsLineIndexForProgress(
          lyrics,
          const Duration(seconds: 25),
          const Duration(minutes: 1),
          leadOffset: Duration.zero,
        ),
        2,
      );
    });

    test('lead offset shifts the highlight to the vocal start', () {
      final lyrics = ['[00:00.00] Intro', '[00:10.00] Verse'];
      const total = Duration(minutes: 1);
      const position = Duration(milliseconds: 9800);

      expect(
        Song.lyricsLineIndexForProgress(
          lyrics,
          position,
          total,
          leadOffset: Duration.zero,
        ),
        0,
      );
      expect(
        Song.lyricsLineIndexForProgress(
          lyrics,
          position,
          total,
          leadOffset: const Duration(milliseconds: 250),
        ),
        1,
      );
    });
  });
}
