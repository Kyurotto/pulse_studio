import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../controllers/music_player_controller.dart';

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
  final String? selectedPlaylistId;
  final double width;

  const DesktopLibrarySidebar({
    super.key,
    required this.controller,
    this.onPlaylistSelected,
    this.onArtistSelected,
    this.onAlbumSelected,
    this.onCreatePlaylist,
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
  void dispose() {
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
              right: BorderSide(
                color: AppTheme.borderOf(context),
                width: 1,
              ),
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

              // Items area kept empty per user request ("wag muna e balik yung mga music artist, albums, saka playlist")
              const Expanded(
                child: SizedBox(),
              ),
            ],
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.library_music_rounded,
                  size: 20,
                  color: AppTheme.textSecondaryOf(context),
                ),
                const SizedBox(width: 8),
                Flexible(
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
          const SizedBox(width: 8),
          // "+ Create" Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onCreatePlaylist,
              hoverColor: AppTheme.primaryOf(context).withValues(alpha: 0.12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
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
