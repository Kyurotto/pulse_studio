import 'package:material_ui/material_ui.dart';
import '../theme/app_theme.dart';
import '../controllers/music_player_controller.dart';
import '../models/song_model.dart';

/// Desktop left sidebar modeled after the Spotify Web / Desktop Player layout.
/// Displays "Your Library" with quick "+ Create" action, category filter pills
/// ([Playlists], [Albums], [Artists]), and inline search & sort.
/// Per user request, music artist, album, and playlist items are not rendered yet.
class DesktopLibrarySidebar extends StatefulWidget {
  final MusicPlayerController controller;
  final ValueChanged<String>? onPlaylistSelected;
  final ValueChanged<String>? onArtistSelected;
  final ValueChanged<String>? onAlbumSelected;
  final VoidCallback? onCreatePlaylist;
  final VoidCallback? onImportSpotify;
  final VoidCallback? onLibraryTap;
  final String? selectedPlaylistId;
  final double width;

  const DesktopLibrarySidebar({
    super.key,
    required this.controller,
    this.onPlaylistSelected,
    this.onArtistSelected,
    this.onAlbumSelected,
    this.onCreatePlaylist,
    this.onImportSpotify,
    this.onLibraryTap,
    this.selectedPlaylistId,
    this.width = 280,
  });

  @override
  State<DesktopLibrarySidebar> createState() => _DesktopLibrarySidebarState();
}

class _DesktopLibrarySidebarState extends State<DesktopLibrarySidebar> {
  String? _selectedFilter; // null = All, 'Playlists', 'Albums', 'Artists'
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant DesktopLibrarySidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPlaylistId != null &&
        widget.selectedPlaylistId != oldWidget.selectedPlaylistId &&
        _selectedFilter != null &&
        _selectedFilter != 'Playlists') {
      _selectedFilter = null;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterTap(String filter) {
    setState(() {
      if (_selectedFilter == filter) {
        _selectedFilter = null; // Toggle off
      } else {
        _selectedFilter = filter;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            border: Border(
              right: BorderSide(color: AppTheme.borderOf(context), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Library Header Row ("Your Library" and "+ Create")
              _buildHeader(context),

              // Category filter pills ([Playlists], [Albums], [Artists])
              _buildFilterChips(context),

              // Search & Sort bar (Search icon, "Recents ☰")
              _buildSearchAndSortRow(context),

              const SizedBox(height: 4),

              // Items area below the search bar
              Expanded(child: _buildItemsList(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsList(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    if (_selectedFilter == 'Artists') {
      return _buildArtistsList(context, query);
    } else if (_selectedFilter == 'Albums') {
      return _buildAlbumsList(context, query);
    } else {
      return _buildPlaylistsList(context, query);
    }
  }

  Widget _buildPlaylistsList(BuildContext context, String query) {
    var playlists = widget.controller.libraryPlaylists;
    if (query.isNotEmpty) {
      playlists = playlists.where((p) {
        return p.title.toLowerCase().contains(query) ||
            p.subtitle.toLowerCase().contains(query);
      }).toList();
    }

    if (playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Text(
            query.isNotEmpty
                ? 'No playlists match "$query"'
                : 'No playlists yet',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textMutedOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return _buildPlaylistTile(context, playlist);
      },
    );
  }

  Widget _buildPlaylistTile(BuildContext context, MusicPlaylist playlist) {
    final isSelected = playlist.id == widget.selectedPlaylistId;
    final cleanSubtitle = playlist.subtitle.isNotEmpty
        ? playlist.subtitle
        : (playlist.songIds.isNotEmpty
              ? '${playlist.songIds.length} ${playlist.songIds.length == 1 ? 'song' : 'songs'}'
              : 'Playlist');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => widget.onPlaylistSelected?.call(playlist.id),
        hoverColor: AppTheme.primaryOf(context).withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? AppTheme.primaryOf(context).withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: playlist.imageUrl.isNotEmpty
                      ? Image.network(
                          playlist.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) =>
                              _buildPlaylistArtFallback(context, playlist),
                        )
                      : _buildPlaylistArtFallback(context, playlist),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primaryOf(context)
                            : AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Playlist • $cleanSubtitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryOf(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistArtFallback(
    BuildContext context,
    MusicPlaylist playlist,
  ) {
    final colors = playlist.gradient.isNotEmpty
        ? playlist.gradient
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
        child: Icon(Icons.music_note_rounded, size: 20, color: Colors.white),
      ),
    );
  }

  Widget _buildArtistsList(BuildContext context, String query) {
    var artists =
        widget.controller.allSongs
            .map((s) => s.artist)
            .where((a) => a.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (query.isNotEmpty) {
      artists = artists.where((a) => a.toLowerCase().contains(query)).toList();
    }

    if (artists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Text(
            query.isNotEmpty
                ? 'No artists match "$query"'
                : 'No artists in library',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textMutedOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => widget.onArtistSelected?.call(artist),
            hoverColor: AppTheme.primaryOf(context).withValues(alpha: 0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.cardSurfaceOf(context),
                    child: Text(
                      artist.isNotEmpty ? artist[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Artist',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textMutedOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumsList(BuildContext context, String query) {
    var albums =
        widget.controller.allSongs
            .map((s) => s.album)
            .where((a) => a.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (query.isNotEmpty) {
      albums = albums.where((a) => a.toLowerCase().contains(query)).toList();
    }

    if (albums.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Text(
            query.isNotEmpty
                ? 'No albums match "$query"'
                : 'No albums in library',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textMutedOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => widget.onAlbumSelected?.call(album),
            hoverColor: AppTheme.primaryOf(context).withValues(alpha: 0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: AppTheme.cardSurfaceOf(context),
                      child: Icon(
                        Icons.album_rounded,
                        size: 22,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Album',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textMutedOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onLibraryTap,
                hoverColor: AppTheme.primaryOf(context).withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.library_music_rounded,
                        size: 20,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your Library',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action Buttons: Import & Create
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Import" Icon Button (Spotify link + export ZIP)
              Tooltip(
                message: 'Import Spotify link or export ZIP',
                waitDuration: const Duration(milliseconds: 300),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        _selectedFilter = null;
                        _searchController.clear();
                      });
                      widget.onImportSpotify?.call();
                    },
                    hoverColor: AppTheme.primaryOf(
                      context,
                    ).withValues(alpha: 0.12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurfaceOf(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.borderOf(context),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        size: 15,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // "+ Create" Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      _selectedFilter = null;
                      _searchController.clear();
                    });
                    widget.onCreatePlaylist?.call();
                  },
                  hoverColor: AppTheme.primaryOf(
                    context,
                  ).withValues(alpha: 0.12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurfaceOf(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.borderOf(context),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 15,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filters = ['Playlists', 'Albums', 'Artists'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _onFilterTap(filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (AppTheme.isDark(context)
                                ? Colors.white
                                : AppTheme.primaryOf(context))
                          : AppTheme.cardSurfaceOf(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppTheme.borderOf(context),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? (AppTheme.isDark(context)
                                  ? Colors.black
                                  : Colors.white)
                            : AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchAndSortRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Search Icon or search input
          if (_isSearchOpen)
            Expanded(
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurfaceOf(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppTheme.textMutedOf(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search in library...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMutedOf(context),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppTheme.textMutedOf(context),
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
              ),
            )
          else
            IconButton(
              tooltip: 'Search in Your Library',
              icon: Icon(
                Icons.search_rounded,
                size: 18,
                color: AppTheme.textMutedOf(context),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _isSearchOpen = true;
                });
              },
            ),

          if (!_isSearchOpen)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Recents',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.sort_rounded,
                  size: 15,
                  color: AppTheme.textMutedOf(context),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
