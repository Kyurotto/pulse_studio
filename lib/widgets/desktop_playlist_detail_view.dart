import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../auth/auth_service.dart';
import '../controllers/music_player_controller.dart';
import '../models/song_model.dart';
import '../services/radio_discovery_service.dart';
import '../theme/app_theme.dart';
import 'animated_visualizer.dart';
import 'song_artwork_widget.dart';

enum _PlaylistSortOrder { custom, title, artist, album, duration }

/// Desktop playlist detail view that renders directly inside the center pane
/// of the dashboard, exactly matching the Spotify Desktop layout.
class DesktopPlaylistDetailView extends StatefulWidget {
  final MusicPlaylist playlist;
  final MusicPlayerController controller;
  final VoidCallback? onBack;
  final ValueChanged<Song>? onSongTap;
  final ValueChanged<Song>? onAddToPlaylist;
  final VoidCallback? onDelete;

  const DesktopPlaylistDetailView({
    super.key,
    required this.playlist,
    required this.controller,
    this.onBack,
    this.onSongTap,
    this.onAddToPlaylist,
    this.onDelete,
  });

  @override
  State<DesktopPlaylistDetailView> createState() =>
      _DesktopPlaylistDetailViewState();
}

class _DesktopPlaylistDetailViewState extends State<DesktopPlaylistDetailView> {
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  _PlaylistSortOrder _sortOrder = _PlaylistSortOrder.custom;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerFastLocateAndAutoDownload();
    });
  }

  @override
  void didUpdateWidget(covariant DesktopPlaylistDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playlist.id != oldWidget.playlist.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _triggerFastLocateAndAutoDownload();
      });
    }
  }

  void _triggerFastLocateAndAutoDownload() {
    final songs = _resolveSongs();
    final locateTargets = songs.take(20).toList(growable: false);
    final isRadio =
        widget.playlist.id.startsWith('radio-') ||
        widget.playlist.id.startsWith('artist-') ||
        widget.playlist.id.startsWith('dailymix-') ||
        songs.any((s) =>
            s.id.startsWith('radio-') ||
            s.id.startsWith('artist-') ||
            s.id.startsWith('dm-'));
    if (isRadio) {
      widget.controller.fastLocateRadioSongs(locateTargets);
    } else {
      widget.controller.fastLocateDiscoverySongs(locateTargets);
    }
    if (widget.controller.autoDownloadOnImport && songs.isNotEmpty) {
      widget.controller.downloadPlaylistSongs(
        songs,
        playlist: widget.playlist,
        title: widget.playlist.title,
        subtitle: widget.playlist.subtitle,
        maxConcurrentWorkers: 3,
      );
      widget.controller.prioritizePlaylistDownloads(songs);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Song> _resolveSongs() {
    var songs = widget.controller.songsForPlaylist(widget.playlist.id);
    if (songs.isEmpty) {
      final radio = RadioDiscoveryService.instance
          .getPopularRadios()
          .where(
            (r) =>
                r.id == widget.playlist.id ||
                'radio-${r.id}' == widget.playlist.id,
          )
          .firstOrNull;
      if (radio != null && radio.songs.isNotEmpty) {
        songs = radio.songs;
      }
    }
    if (songs.isEmpty && widget.playlist.songIds.isNotEmpty) {
      final found = <Song>[];
      for (final id in widget.playlist.songIds) {
        final s = widget.controller.songById(id);
        if (s != null) found.add(s);
      }
      songs = found;
    }
    final seenKeys = <String>{};
    final seenIds = <String>{};
    final deduplicated = <Song>[];
    for (final s in songs) {
      if (!seenIds.add(s.id)) continue;
      final key =
          '${s.title.toLowerCase().trim()}|${s.artist.toLowerCase().trim()}';
      if (key != '|' && !seenKeys.add(key)) continue;

      final liveSong = widget.controller.songById(s.id) ?? s;
      if (liveSong.audioUrl.isEmpty ||
          (!liveSong.audioUrl.startsWith('http') &&
              !liveSong.audioUrl.startsWith('asset') &&
              (!kIsWeb && !File(liveSong.audioUrl).existsSync()))) {
        final cached =
            MusicPlayerController.findCachedAudioFileSync(liveSong.id);
        if (cached != null &&
            cached.existsSync() &&
            cached.lengthSync() > 1024) {
          liveSong.audioUrl = cached.path;
          liveSong.isPreview = false;
          liveSong.isYouTubeAudio = false;
        }
      }
      deduplicated.add(liveSong);
    }
    return deduplicated;
  }

  List<Song> _filterAndSortSongs(List<Song> base) {
    var result = List<Song>.from(base);
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where(
            (s) =>
                s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q) ||
                s.album.toLowerCase().contains(q),
          )
          .toList();
    }

    switch (_sortOrder) {
      case _PlaylistSortOrder.title:
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case _PlaylistSortOrder.artist:
        result.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
        break;
      case _PlaylistSortOrder.album:
        result.sort(
          (a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
        );
        break;
      case _PlaylistSortOrder.duration:
        result.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case _PlaylistSortOrder.custom:
        break;
    }
    return result;
  }

  String _formatTotalRuntime(List<Song> songs) {
    var totalSeconds = 0;
    for (final s in songs) {
      totalSeconds += s.duration.inSeconds;
    }
    if (totalSeconds <= 0) return '0 min';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}'.trim();
    }
    return '$minutes min';
  }

  String _getUserDisplayName() {
    final name = AuthService.instance.userDisplayName.trim();
    if (name.isNotEmpty && name != 'Guest') return name;
    final email = AuthService.instance.userEmail.trim();
    if (email.isNotEmpty && email != 'guest@pulsemusic.app') {
      return email.split('@').first;
    }
    return 'johnlaurencenovicio';
  }

  String _getSortLabel() {
    switch (_sortOrder) {
      case _PlaylistSortOrder.title:
        return 'Title';
      case _PlaylistSortOrder.artist:
        return 'Artist';
      case _PlaylistSortOrder.album:
        return 'Album';
      case _PlaylistSortOrder.duration:
        return 'Duration';
      case _PlaylistSortOrder.custom:
        return 'Custom order';
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = _resolveSongs();
    final displayedSongs = _filterAndSortSongs(songs);
    final currentSongId = widget.controller.currentSong?.id;
    final isThisPlaylistQueue = _isActiveQueueFor(songs);
    final canResumeQueue =
        isThisPlaylistQueue &&
        currentSongId != null &&
        songs.any((s) => s.id == currentSongId);
    final isPlayingThisPlaylist = canResumeQueue && widget.controller.isPlaying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Spotify-style Hero Banner
        _buildHeroBanner(context, songs),

        // 2. Action Controls Bar (Play button, Shuffle, Download, Search, Sort)
        _buildActionsBar(context, songs, isPlayingThisPlaylist, canResumeQueue),

        // 3. Track Table
        _buildTrackTable(context, displayedSongs),

        const SizedBox(height: 48),
      ],
    );
  }

  /// True when the player's active queue contains exactly this playlist's
  /// songs, regardless of order (a shuffled play still belongs to it).
  bool _isActiveQueueFor(List<Song> songs) {
    final queue = widget.controller.queue;
    if (queue.isEmpty || queue.length != songs.length) return false;
    final queueIds = queue.map((s) => s.id).toSet();
    final songIds = songs.map((s) => s.id).toSet();
    return queueIds.length == songIds.length && queueIds.containsAll(songIds);
  }
  Widget _buildHeroBanner(BuildContext context, List<Song> songs) {
    final dominantColor = widget.playlist.gradient.isNotEmpty
        ? widget.playlist.gradient.first
        : const Color(0xFF385A7C);

    final topArtists = songs
        .map((s) => s.artist)
        .where((a) => a.trim().isNotEmpty)
        .toSet()
        .take(3)
        .join(', ');
    final description =
        widget.playlist.subtitle.isNotEmpty &&
            !widget.playlist.subtitle.toLowerCase().startsWith('created')
        ? widget.playlist.subtitle
        : (topArtists.isNotEmpty
              ? 'With $topArtists and more'
              : widget.playlist.subtitle);

    final creator = _getUserDisplayName();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            dominantColor.withValues(alpha: 0.70),
            dominantColor.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button row
          if (widget.onBack != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.onBack,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Playlist Artwork
              Container(
                width: 196,
                height: 196,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.playlist.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.playlist.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) =>
                              _buildArtworkFallback(context),
                        )
                      : _buildArtworkFallback(context),
                ),
              ),
              const SizedBox(width: 24),

              // Playlist Metadata Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Public Playlist',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.playlist.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.2,
                        height: 1.1,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white24,
                          child: Text(
                            creator.isNotEmpty ? creator[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Made for $creator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          ' • ',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Flexible(
                          child: Text(
                            '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}, ${_formatTotalRuntime(songs)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'About recommendations and the impact of promotion',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkFallback(BuildContext context) {
    final colors = widget.playlist.gradient.isNotEmpty
        ? widget.playlist.gradient
        : [AppTheme.primaryOf(context), AppTheme.secondaryOf(context)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, size: 68, color: Colors.white),
      ),
    );
  }

  Widget _buildActionsBar(
    BuildContext context,
    List<Song> songs,
    bool isPlayingThisPlaylist,
    bool canResumeQueue,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
      child: Row(
        children: [
          // Big Circular Play Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                if (songs.isEmpty) return;
                if (canResumeQueue) {
                  // The active queue is this playlist: resume the paused
                  // track instead of restarting at the first one.
                  widget.controller.togglePlayPause();
                } else {
                  widget.controller.playSongList(songs, startIndex: 0);
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryOf(context),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryOf(
                        context,
                      ).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isPlayingThisPlaylist
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 32,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),

          // Shuffle Button
          IconButton(
            tooltip: 'Shuffle',
            icon: const Icon(Icons.shuffle_rounded, size: 24),
            color: Colors.white70,
            onPressed: () {
              if (songs.isEmpty) return;
              final shuffled = List<Song>.from(songs)..shuffle();
              widget.controller.playSongList(shuffled, startIndex: 0);
            },
          ),

          // Download all Button
          IconButton(
            tooltip: 'Download playlist for offline',
            icon: const Icon(Icons.arrow_circle_down_rounded, size: 26),
            color: Colors.white70,
            onPressed: () {
              if (songs.isEmpty) return;
              widget.controller.downloadPlaylistSongs(
                songs,
                playlist: widget.playlist,
                title: widget.playlist.title,
                subtitle: widget.playlist.subtitle,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloading "${widget.playlist.title}"...'),
                ),
              );
            },
          ),

          // More Options Button (...)
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
            color: AppTheme.cardSurfaceOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.borderOf(context)),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_to_queue',
                child: Row(
                  children: [
                    Icon(Icons.queue_music_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Add to queue'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download_all',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Download all tracks'),
                  ],
                ),
              ),
              if (widget.onDelete != null) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete_playlist',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppTheme.accentPink,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Delete playlist',
                        style: TextStyle(color: AppTheme.accentPink),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            onSelected: (val) {
              if (val == 'add_to_queue' && songs.isNotEmpty) {
                widget.controller.enqueueList(songs);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ${songs.length} songs to queue'),
                  ),
                );
              } else if (val == 'download_all' && songs.isNotEmpty) {
                widget.controller.downloadPlaylistSongs(
                  songs,
                  playlist: widget.playlist,
                  title: widget.playlist.title,
                );
              } else if (val == 'delete_playlist') {
                widget.onDelete?.call();
              }
            },
          ),

          const Spacer(),

          // Search in Playlist
          if (_isSearchOpen)
            Container(
              width: 180,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardSurfaceOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: Colors.white60,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search in playlist...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white60,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _isSearchOpen = false;
                        _searchController.clear();
                      });
                    },
                  ),
                ],
              ),
            )
          else
            IconButton(
              tooltip: 'Search in playlist',
              icon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: Colors.white70,
              ),
              onPressed: () => setState(() => _isSearchOpen = true),
            ),

          const SizedBox(width: 8),

          // Sort dropdown
          PopupMenuButton<_PlaylistSortOrder>(
            tooltip: 'Sort by',
            color: AppTheme.cardSurfaceOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.borderOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getSortLabel(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _PlaylistSortOrder.custom,
                child: Text('Custom order'),
              ),
              const PopupMenuItem(
                value: _PlaylistSortOrder.title,
                child: Text('Title'),
              ),
              const PopupMenuItem(
                value: _PlaylistSortOrder.artist,
                child: Text('Artist'),
              ),
              const PopupMenuItem(
                value: _PlaylistSortOrder.album,
                child: Text('Album'),
              ),
              const PopupMenuItem(
                value: _PlaylistSortOrder.duration,
                child: Text('Duration'),
              ),
            ],
            onSelected: (val) => setState(() => _sortOrder = val),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTable(BuildContext context, List<Song> songs) {
    if (songs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(
              Icons.queue_music_rounded,
              size: 48,
              color: Colors.white24,
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No songs match "${_searchController.text}"'
                  : 'This playlist is empty',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 32,
                child: Text(
                  '#',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 44), // Artwork column spacer
              const SizedBox(width: 14),
              const Expanded(
                flex: 5,
                child: Text(
                  'Title',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60,
                  ),
                ),
              ),
              const Expanded(
                flex: 4,
                child: Text(
                  'Album',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60,
                  ),
                ),
              ),
              const SizedBox(
                width: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: Colors.white60,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 44), // Trailing actions spacer
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5, color: Colors.white12),

        // Track rows
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isCurrent = widget.controller.currentSong?.id == song.id;
            final isCurrentPlaying = isCurrent && widget.controller.isPlaying;

            return _DesktopTrackRow(
              index: index + 1,
              song: song,
              isCurrent: isCurrent,
              isPlaying: isCurrentPlaying,
              onTap: () {
                widget.controller.playSongList(songs, startIndex: index);
                widget.onSongTap?.call(song);
              },
              onAddToPlaylist: widget.onAddToPlaylist,
            );
          },
        ),
      ],
    );
  }
}

class _DesktopTrackRow extends StatefulWidget {
  final int index;
  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final ValueChanged<Song>? onAddToPlaylist;

  const _DesktopTrackRow({
    required this.index,
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    this.onAddToPlaylist,
  });

  @override
  State<_DesktopTrackRow> createState() => _DesktopTrackRowState();
}

class _DesktopTrackRowState extends State<_DesktopTrackRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isCurrent
                  ? AppTheme.primaryOf(context).withValues(alpha: 0.12)
                  : (_isHovered
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Track # or play indicator
                SizedBox(
                  width: 32,
                  child: Center(
                    child: widget.isPlaying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: AnimatedVisualizer(
                              isPlaying: true,
                              barCount: 4,
                              maxHeight: 14,
                              barWidth: 2,
                            ),
                          )
                        : (_isHovered
                              ? const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${widget.index}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isCurrent
                                        ? AppTheme.primaryOf(context)
                                        : Colors.white60,
                                  ),
                                )),
                  ),
                ),
                const SizedBox(width: 12),

                // Artwork Thumbnail
                SongArtworkWidget(song: widget.song, size: 40, borderRadius: 4),
                const SizedBox(width: 14),

                // Title & Artist
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isCurrent
                              ? AppTheme.primaryOf(context)
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (widget.song.isExplicit) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3.5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white60,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Text(
                                'E',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              widget.song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Album column
                Expanded(
                  flex: 4,
                  child: Text(
                    widget.song.album.isNotEmpty
                        ? widget.song.album
                        : widget.song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                ),

                // Duration
                SizedBox(
                  width: 60,
                  child: Text(
                    widget.song.formattedDuration,
                    style: const TextStyle(fontSize: 13, color: Colors.white60),
                    textAlign: TextAlign.right,
                  ),
                ),

                // Trailing more options button (visible on hover or when playing)
                SizedBox(
                  width: 44,
                  child: _isHovered || widget.isCurrent
                      ? IconButton(
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            if (widget.onAddToPlaylist != null) {
                              widget.onAddToPlaylist!(widget.song);
                            }
                          },
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
