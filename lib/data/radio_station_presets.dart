import 'package:material_ui/material_ui.dart';

/// A single curated track seed used to build fallback station metadata.
///
/// Seeds carry presentation metadata only (title / artist / album / length).
/// They never carry audio: playback still goes through the app's normal
/// locator, so a curated station is not a promise of downloadable audio.
class RadioTrackSeed {
  const RadioTrackSeed(
    this.title,
    this.artist, {
    this.album = '',
    this.duration = const Duration(minutes: 3, seconds: 30),
  });

  final String title;
  final String artist;
  final String album;
  final Duration duration;
}

/// Presentation preset for a Spotify-inspired artist radio station.
///
/// These values are display defaults. The radio service tries the live
/// catalog first and only falls back to this metadata when the provider is
/// unavailable, so nothing here should be treated as a guaranteed catalog
/// result.
class RadioArtistPreset {
  const RadioArtistPreset({
    required this.name,
    required this.accent,
    this.searchTerm = '',
    this.collaborators = const [],
    this.tracks = const [],
    this.genre = 'OPM',
  });

  /// Display name, e.g. `Hev Abi`.
  final String name;

  /// Pastel station accent used when the provider returns no artwork.
  final Color accent;

  /// Provider search term. Defaults to [name] when empty.
  final String searchTerm;

  /// Collaborator names shown as "With ..., ... and more".
  final List<String> collaborators;

  /// Curated fallback tracks.
  final List<RadioTrackSeed> tracks;

  final String genre;

  /// Stable id fragment: `hev-abi`.
  String get slug => slugify(name);

  String get providerQuery => searchTerm.trim().isEmpty ? name : searchTerm;
}

/// Presentation preset for a non-artist station (throwback rows, anime OPs,
/// mood stations).
class RadioStationPreset {
  const RadioStationPreset({
    required this.id,
    required this.title,
    required this.artistName,
    required this.subtitle,
    required this.accent,
    this.collaborators = const [],
    this.tracks = const [],
  });

  final String id;
  final String title;
  final String artistName;
  final String subtitle;
  final Color accent;
  final List<String> collaborators;
  final List<RadioTrackSeed> tracks;
}

/// Presentation preset for a curated mix (the Home "Your Top Mixes" row).
class RadioMixPreset {
  const RadioMixPreset({
    required this.id,
    required this.title,
    required this.number,
    required this.accent,
    required this.subtitle,
    required this.tracks,
  });

  final String id;
  final String title;
  final String number;
  final Color accent;
  final String subtitle;
  final List<RadioTrackSeed> tracks;
}

/// Lowercase, accent-tolerant id fragment.
String slugify(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };
  var normalized = value.toLowerCase().trim();
  replacements.forEach((from, to) => normalized = normalized.replaceAll(from, to));
  final slug = normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'station' : slug;
}

/// Curated artist presets used by the Home dashboard.
///
/// Order matters: the first entries double as the quick-filter pills and the
/// recommended-stations row.
const List<RadioArtistPreset> radioArtistPresets = [
  RadioArtistPreset(
    name: 'Hev Abi',
    accent: Color(0xFFD6B4E8),
    collaborators: ['Kristina Dawn', 'Flow G', 'Glock-9'],
    genre: 'Hip-Hop',
    tracks: [
      RadioTrackSeed('Makasarili Malambing', 'Kristina Dawn, Hev Abi'),
      RadioTrackSeed('Walang Alam', 'Hev Abi'),
      RadioTrackSeed('Babaero', 'Hev Abi'),
      RadioTrackSeed('Kung Alam Mo Lang', 'Hev Abi'),
      RadioTrackSeed('Sumugal', 'Hev Abi'),
    ],
  ),
  RadioArtistPreset(
    name: 'Flow G',
    accent: Color(0xFF8BB7F0),
    collaborators: ['SUPAFLY', 'Lo ki', 'Hev Abi'],
    genre: 'Hip-Hop',
    tracks: [
      RadioTrackSeed('Ebeb', 'Flow G'),
      RadioTrackSeed('Praning', 'Flow G'),
      RadioTrackSeed('Since Day One', 'Skusta Clee, Flow G'),
      RadioTrackSeed('TMA', 'groundZERO Records, Tyler, Primera, ODP'),
      RadioTrackSeed('Rosas', 'Yuridope, Skusta Clee'),
    ],
  ),
  RadioArtistPreset(
    name: 'Bruno Mars',
    accent: Color(0xFFF7A278),
    collaborators: ['Anderson .Paak', 'Cardi B', 'Mark Ronson'],
    genre: 'Pop',
    tracks: [
      RadioTrackSeed('Just the Way You Are', 'Bruno Mars'),
      RadioTrackSeed('Locked Out of Heaven', 'Bruno Mars'),
      RadioTrackSeed('When I Was Your Man', 'Bruno Mars'),
      RadioTrackSeed('Talking to the Moon', 'Bruno Mars'),
    ],
  ),
  RadioArtistPreset(
    name: 'VK Blanka',
    accent: Color(0xFFBAE6FD),
    collaborators: ['Vaundy', 'Kenshi Yonezu', 'Official HIGE DANdism'],
    genre: 'J-Pop',
    tracks: [
      RadioTrackSeed('Kirari', 'VK Blanka'),
      RadioTrackSeed('Akatoki', 'VK Blanka'),
      RadioTrackSeed('Koi no Uta', 'VK Blanka'),
    ],
  ),
  RadioArtistPreset(
    name: 'Tothapi',
    accent: Color(0xFF27272A),
    collaborators: ['Maki', 'Cup of Joe', 'Dilaw'],
    tracks: [
      RadioTrackSeed('Pahinga', 'Tothapi'),
      RadioTrackSeed('Gabi', 'Tothapi'),
      RadioTrackSeed('Sana', 'Tothapi'),
    ],
  ),
  RadioArtistPreset(
    name: 'Maki',
    accent: Color(0xFFFDA4AF),
    collaborators: ['Tothapi', 'Cup of Joe', 'Adie'],
    tracks: [
      RadioTrackSeed('Saan?', 'Maki'),
      RadioTrackSeed('Bakit Ba Ikaw', 'Maki'),
      RadioTrackSeed('Nandito Ako', 'Maki'),
    ],
  ),
  RadioArtistPreset(
    name: 'Lola Amour',
    accent: Color(0xFFA5EAB7),
    collaborators: ['Ben&Ben', 'Cup of Joe', 'Dilaw'],
    tracks: [
      RadioTrackSeed('Fallen', 'Lola Amour'),
      RadioTrackSeed('Pumapagibig', 'Lola Amour'),
      RadioTrackSeed('Maybe Maybe', 'Lola Amour'),
    ],
  ),
  RadioArtistPreset(
    name: 'Orange & Lemons',
    accent: Color(0xFFFB923C),
    collaborators: ['Sugarfree', 'Eraserheads', 'Kamikazee'],
    tracks: [
      RadioTrackSeed('Hanggang Kailan', 'Orange & Lemons'),
      RadioTrackSeed('Pinoy Ako', 'Orange & Lemons'),
      RadioTrackSeed('Yakap Sa Dilim', 'Orange & Lemons'),
    ],
  ),
  RadioArtistPreset(
    name: 'Arthur Nery',
    accent: Color(0xFFDDD6FE),
    collaborators: ['Adie', 'Zack Tabudlo', 'Maki'],
    tracks: [
      RadioTrackSeed('Binhi', 'Arthur Nery'),
      RadioTrackSeed('Pagsamo', 'Arthur Nery'),
      RadioTrackSeed('Isa Lang', 'Arthur Nery'),
    ],
  ),
  RadioArtistPreset(
    name: 'TJ Monterde',
    accent: Color(0xFFFDE047),
    collaborators: ['Arthur Nery', 'Adie', 'Maki'],
    tracks: [
      RadioTrackSeed('Palagi', 'TJ Monterde'),
      RadioTrackSeed('Kung Siya Man', 'TJ Monterde'),
      RadioTrackSeed('Dating Tayo', 'TJ Monterde'),
    ],
  ),
  RadioArtistPreset(
    name: 'LANY',
    accent: Color(0xFFA5EAB7),
    collaborators: ['Bazzi', 'elijah woods', 'Alex Crichton'],
    genre: 'Pop',
    tracks: [
      RadioTrackSeed('ILYSB', 'LANY'),
      RadioTrackSeed('Malibu Nights', 'LANY'),
      RadioTrackSeed('Good Girls', 'LANY'),
    ],
  ),
  RadioArtistPreset(
    name: 'Ben&Ben',
    accent: Color(0xFFF7A278),
    collaborators: ['IV OF SPADES', 'Adie', 'Cup of Joe'],
    tracks: [
      RadioTrackSeed('Leaves', 'Ben&Ben'),
      RadioTrackSeed('Paninindigan Kita', 'Ben&Ben'),
      RadioTrackSeed('Kathang Isip', 'Ben&Ben'),
    ],
  ),
  RadioArtistPreset(
    name: 'Cup of Joe',
    accent: Color(0xFF8DD8B5),
    collaborators: ['Dilaw', 'Maki', 'Denise Julia'],
    tracks: [
      RadioTrackSeed('Tataya', 'Cup of Joe'),
      RadioTrackSeed('Misteryoso', 'Cup of Joe'),
      RadioTrackSeed('Sagada', 'Cup of Joe'),
    ],
  ),
  RadioArtistPreset(
    name: 'Air Supply',
    accent: Color(0xFF8CECD4),
    collaborators: ['Chicago', 'Peter Cetera', 'Bread'],
    genre: 'Soft Rock',
    tracks: [
      RadioTrackSeed('All Out of Love', 'Air Supply'),
      RadioTrackSeed('Making Love Out of Nothing at All', 'Air Supply'),
      RadioTrackSeed('Lost in Love', 'Air Supply'),
    ],
  ),
  RadioArtistPreset(
    name: 'Sugarfree',
    accent: Color(0xFFFDE047),
    collaborators: ['Eraserheads', 'Soapdish', 'Orange & Lemons'],
    tracks: [
      RadioTrackSeed('Hari ng Sablay', 'Sugarfree'),
      RadioTrackSeed('Burnout', 'Sugarfree'),
      RadioTrackSeed('Makita Kang Muli', 'Sugarfree'),
    ],
  ),
  RadioArtistPreset(
    name: 'Adie',
    accent: Color(0xFF7DD3FC),
    collaborators: ['Janine Teñoso', 'Arthur Nery', 'Zack Tabudlo'],
    tracks: [
      RadioTrackSeed('Paraluman', 'Adie'),
      RadioTrackSeed('Mahika', 'Adie, Janine Berdin'),
      RadioTrackSeed('Tahanan', 'Adie'),
    ],
  ),
  RadioArtistPreset(
    name: 'Dilaw',
    accent: Color(0xFFFCD34D),
    collaborators: ['Cup of Joe', 'Maki', 'SunKissed Lola'],
    tracks: [
      RadioTrackSeed('Uhaw (Tayong Lahat)', 'Dilaw'),
      RadioTrackSeed('Janice', 'Dilaw'),
    ],
  ),
  RadioArtistPreset(
    name: 'Cueshé',
    accent: Color(0xFF94A3B8),
    collaborators: ['Sugarfree', 'Eraserheads', 'Sponge Cola'],
    genre: 'Alternative',
    tracks: [
      RadioTrackSeed('Stay', 'Cueshé'),
      RadioTrackSeed('Ulan', 'Cueshé'),
    ],
  ),
  RadioArtistPreset(
    name: 'MATÉO',
    accent: Color(0xFF334155),
    collaborators: ['Adie', 'Arthur Nery', 'Maki'],
    genre: 'R&B',
    tracks: [
      RadioTrackSeed('Lambing', 'MATÉO'),
      RadioTrackSeed('Pahinga', 'MATÉO'),
    ],
  ),
  RadioArtistPreset(
    name: 'Eraserheads',
    accent: Color(0xFFFB923C),
    collaborators: ['Rivermaya', 'Parokya Ni Edgar', 'Kamikazee'],
    genre: 'Alternative',
    tracks: [
      RadioTrackSeed('Ang Huling El Bimbo', 'Eraserheads'),
      RadioTrackSeed('With a Smile', 'Eraserheads'),
      RadioTrackSeed('Ligaya', 'Eraserheads'),
    ],
  ),
];

/// Non-artist stations used by the Recents row.
const RadioStationPreset blackCloverRadioPreset = RadioStationPreset(
  id: 'recent-black-clover-op',
  title: 'Black Clover OP',
  artistName: 'Black Clover',
  subtitle: 'Anime openings and high-energy tracks',
  accent: Color(0xFFB91C1C),
  collaborators: ['Vickeblanka', 'Kankaku Piero', 'Snow Man'],
  tracks: [
    RadioTrackSeed('Black Rover', 'Vickeblanka'),
    RadioTrackSeed('Black Catcher', 'Vickeblanka'),
    RadioTrackSeed('Everlasting Shine', 'Snow Man'),
  ],
);

const RadioStationPreset twoThousandsRadioPreset = RadioStationPreset(
  id: 'recent-2000s',
  title: '2000s',
  artistName: '2000s',
  subtitle: 'Throwback hits from the 2000s',
  accent: Color(0xFFF59E0B),
  collaborators: ['Usher', 'Nelly', 'Black Eyed Peas'],
  tracks: [
    RadioTrackSeed('Yeah!', 'Usher'),
    RadioTrackSeed('Hot in Herre', 'Nelly'),
    RadioTrackSeed('Where Is the Love?', 'Black Eyed Peas'),
  ],
);

/// Default "Recents" order. Artist names resolve through
/// [radioArtistPresets]; the two station presets are added explicitly.
const List<String> defaultRecentStationNames = [
  'Hev Abi',
  'Flow G',
  'Black Clover OP',
  '2000s',
  'Sugarfree',
];

/// Curated mixes for the Home "Your Top Mixes" row.
const List<RadioMixPreset> radioMixPresets = [
  RadioMixPreset(
    id: 'mix-2000s',
    title: '2000s Mix',
    number: '01',
    accent: Color(0xFFF59E0B),
    subtitle: 'Usher, Nelly, Black Eyed Peas and more',
    tracks: [
      RadioTrackSeed('Yeah!', 'Usher'),
      RadioTrackSeed('Hot in Herre', 'Nelly'),
      RadioTrackSeed('Where Is the Love?', 'Black Eyed Peas'),
      RadioTrackSeed('In the End', 'Linkin Park'),
    ],
  ),
  RadioMixPreset(
    id: 'mix-hip-hop',
    title: 'Hip Hop Mix',
    number: '02',
    accent: Color(0xFF8B5CF6),
    subtitle: 'Flow G, Hev Abi, Skusta Clee and more',
    tracks: [
      RadioTrackSeed('Ebeb', 'Flow G'),
      RadioTrackSeed('Walang Alam', 'Hev Abi'),
      RadioTrackSeed('Since Day One', 'Skusta Clee, Flow G'),
      RadioTrackSeed('Praning', 'Flow G'),
    ],
  ),
  RadioMixPreset(
    id: 'mix-pop',
    title: 'Pop Mix',
    number: '03',
    accent: Color(0xFFF472B6),
    subtitle: 'Bruno Mars, Taylor Swift, Maroon 5 and more',
    tracks: [
      RadioTrackSeed('Just the Way You Are', 'Bruno Mars'),
      RadioTrackSeed('Blank Space', 'Taylor Swift'),
      RadioTrackSeed('Sugar', 'Maroon 5'),
      RadioTrackSeed('Leaves', 'Ben&Ben'),
    ],
  ),
  RadioMixPreset(
    id: 'mix-2020s',
    title: '2020s Mix',
    number: '04',
    accent: Color(0xFF22D3EE),
    subtitle: 'Maki, Adie, Dilaw, Cup of Joe and more',
    tracks: [
      RadioTrackSeed('Saan?', 'Maki'),
      RadioTrackSeed('Paraluman', 'Adie'),
      RadioTrackSeed('Uhaw (Tayong Lahat)', 'Dilaw'),
      RadioTrackSeed('Tataya', 'Cup of Joe'),
    ],
  ),
  RadioMixPreset(
    id: 'mix-adie',
    title: 'Adie Mix',
    number: '05',
    accent: Color(0xFF60A5FA),
    subtitle: 'Adie, Janine Berdin, Arthur Nery and more',
    tracks: [
      RadioTrackSeed('Paraluman', 'Adie'),
      RadioTrackSeed('Mahika', 'Adie, Janine Berdin'),
      RadioTrackSeed('Tahanan', 'Adie'),
      RadioTrackSeed('Binhi', 'Arthur Nery'),
    ],
  ),
];

/// Finds a preset by artist name, ignoring "Radio", case and punctuation.
RadioArtistPreset? findArtistPreset(String name) {
  final target = slugify(name.replaceAll(RegExp(r'radio$', caseSensitive: false), ''));
  for (final preset in radioArtistPresets) {
    final presetSlug = slugify(preset.name);
    if (presetSlug == target || target.contains(presetSlug) || presetSlug.contains(target)) {
      return preset;
    }
  }
  return null;
}

/// Normalizes a provider/caller artist string before comparing.
bool artistNamesMatch(String a, String b) {
  final left = slugify(a);
  final right = slugify(b);
  return left == right || left.contains(right) || right.contains(left);
}
