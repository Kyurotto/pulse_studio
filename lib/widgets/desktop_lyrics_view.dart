import 'package:material_ui/material_ui.dart';
import '../models/song_model.dart';
import '../theme/app_theme.dart';
import '../controllers/music_player_controller.dart';
import 'lyrics_sync_dialog.dart';
import 'song_artwork_widget.dart';

class DesktopLyricsView extends StatefulWidget {
  final MusicPlayerController controller;
  final VoidCallback onClose;

  const DesktopLyricsView({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  State<DesktopLyricsView> createState() => _DesktopLyricsViewState();
}

class _DesktopLyricsViewState extends State<DesktopLyricsView> {
  final ScrollController _scrollController = ScrollController();
  int? _highlightedLineIndex;
  int? _lastSyncedIndex;
  bool _userPinned = false;

  /// Keyed to the active row so auto-scroll follows the real laid-out height
  /// instead of assuming every lyric line is exactly 56px tall.
  final GlobalKey _activeLineKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _maybeEnsureLyrics(widget.controller.currentSong);
  }

  void _maybeEnsureLyrics(Song? song) {
    if (song != null && song.lyrics.isEmpty) {
      widget.controller.ensureLyricsFor(song);
    }
  }

  @override
  void didUpdateWidget(DesktopLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.currentSong?.id != oldWidget.controller.currentSong?.id) {
      _userPinned = false;
      _highlightedLineIndex = null;
      _lastSyncedIndex = null;
      _maybeEnsureLyrics(widget.controller.currentSong);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onLineTapped(List<String> lyrics, int index) {
    if (index < 0 || index >= lyrics.length) return;
    final song = widget.controller.currentSong;
    if (song == null) return;
    final total = widget.controller.displayDurationFor(song);
    // Seek earlier by the tracker's lead so the tapped line becomes active
    // exactly when playback reaches it.
    final target =
        Song.positionForLyricsLine(lyrics, index, total) -
        widget.controller.lyricsLeadOffsetFor(song);
    widget.controller.seekTo(target < Duration.zero ? Duration.zero : target);
    setState(() {
      _userPinned = true;
      _highlightedLineIndex = index;
    });
  }

  /// Rough row height used only to reach rows outside the builder's cache
  /// (a long seek). The measured row takes over afterwards.
  static const double _estimatedLineExtent = 64.0;

  void _autoScrollTo(int activeIndex) {
    if (_userPinned) return;
    if (_lastSyncedIndex == activeIndex) return;
    _lastSyncedIndex = activeIndex;

    final lineContext = _activeLineKey.currentContext;
    if (lineContext != null) {
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.35,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutQuad,
      );
      return;
    }
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final estimate =
        (activeIndex * _estimatedLineExtent - position.viewportDimension * 0.35)
            .clamp(0.0, position.maxScrollExtent);
    _scrollController
        .animateTo(
          estimate,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutQuad,
        )
        .then((_) => _refineScroll());
  }

  void _refineScroll() {
    if (!mounted) return;
    final refined = _activeLineKey.currentContext;
    if (refined == null) return;
    Scrollable.ensureVisible(
      refined,
      alignment: 0.35,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutQuad,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = widget.controller.currentSong;
    if (currentSong == null) {
      return Container(
        color: AppTheme.backgroundOf(context),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_rounded, size: 56, color: AppTheme.textMutedOf(context)),
            const SizedBox(height: 16),
            Text(
              'No Track Playing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onClose,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      );
    }

    final topColor = (currentSong.gradientColors.firstOrNull ?? AppTheme.primary)
        .withValues(alpha: 0.45);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundOf(context),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            topColor,
            AppTheme.backgroundOf(context),
          ],
          stops: const [0.0, 0.45],
        ),
      ),
      child: Column(
        children: [
          // Top Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderOf(context).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Back Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Back to Dashboard',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Artwork Thumbnail
                SongArtworkWidget(
                  song: currentSong,
                  size: 42,
                  borderRadius: 8,
                ),

                const SizedBox(width: 12),

                // Song Title & Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentSong.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${currentSong.artist} • ${currentSong.album}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Per-song lyrics calibration
                IconButton(
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Lyrics sync',
                  onPressed: () => LyricsSyncDialog.show(
                    context,
                    song: currentSong,
                    controller: widget.controller,
                  ),
                ),

                // Like Button
                IconButton(
                  icon: Icon(
                    currentSong.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: currentSong.isLiked ? AppTheme.accentPink : Colors.white70,
                    size: 20,
                  ),
                  tooltip: currentSong.isLiked ? 'In Favorites' : 'Add to Favorites',
                  onPressed: () => widget.controller.toggleLike(currentSong.id),
                ),

                // Close Lyrics Icon
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  tooltip: 'Close lyrics view',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Main Lyrics Body
          Expanded(
            child: ValueListenableBuilder<Duration>(
              valueListenable: widget.controller.positionListenable,
              builder: (context, position, _) {
                final lyrics = currentSong.lyrics;
                final totalDur = widget.controller.displayDurationFor(currentSong);
                final hasSyncedLyrics = Song.hasSyncedLyrics(lyrics);
                // Untimed lyrics get no highlight: an evenly-spread fake
                // cursor always drifts out of sync with the vocal.
                final int? activeIndex = !hasSyncedLyrics
                    ? null
                    : (_userPinned && _highlightedLineIndex != null
                          ? _highlightedLineIndex
                          : Song.lyricsLineIndexForProgress(
                              lyrics,
                              position,
                              totalDur,
                              leadOffset: widget.controller
                                  .lyricsLeadOffsetFor(currentSong),
                            ));

                // Auto-scroll when activeIndex changes
                if (activeIndex != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _autoScrollTo(activeIndex);
                  });
                }

                if (lyrics.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lyrics_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            currentSong.isEnrichingLyrics
                                ? 'Fetching synchronized lyrics…'
                                : 'Lyrics are not available yet',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enjoy "${currentSong.title}" by ${currentSong.artist}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white30),
                            ),
                            onPressed: () =>
                                widget.controller.ensureLyricsFor(currentSong),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry lyrics lookup'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.06, 0.94, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 36,
                    ),
                    itemCount: lyrics.length,
                    itemBuilder: (context, index) {
                      final rawLine = lyrics[index];
                      final displayLine = Song.stripTimestamp(rawLine);
                      final isActive = index == activeIndex;

                      return InkWell(
                        key: isActive ? _activeLineKey : null,
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _onLineTapped(lyrics, index),
                        hoverColor: Colors.white.withValues(alpha: 0.08),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            displayLine.isNotEmpty ? displayLine : rawLine,
                            style: TextStyle(
                              fontSize: isActive ? 26 : 22,
                              height: 1.45,
                              fontWeight:
                                  isActive ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: -0.4,
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                              shadows: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
