import 'package:material_ui/material_ui.dart';
import '../models/song_model.dart';
import '../theme/app_theme.dart';
import '../controllers/music_player_controller.dart';
import 'animated_visualizer.dart';
import 'song_artwork_widget.dart';

class RightActivityPanel extends StatefulWidget {
  final MusicPlayerController controller;
  final VoidCallback? onOpenLyrics;
  final ValueChanged<Song>? onPlaySong;

  const RightActivityPanel({
    super.key,
    required this.controller,
    this.onOpenLyrics,
    this.onPlaySong,
  });

  @override
  State<RightActivityPanel> createState() => _RightActivityPanelState();
}

class _RightActivityPanelState extends State<RightActivityPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    widget.controller.addListener(_syncRotation);
    _syncRotation();
  }

  void _syncRotation() {
    if (!mounted) return;
    final shouldRotate =
        widget.controller.isPlaying && !widget.controller.reduceAnimations;
    if (shouldRotate) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }
  }

  @override
  void didUpdateWidget(RightActivityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncRotation);
      widget.controller.addListener(_syncRotation);
    }
    _syncRotation();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncRotation);
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: widget.controller.positionListenable,
          builder: (context, _, child) {
            final currentSong = widget.controller.currentSong;
            final isPlaying = widget.controller.isPlaying;

            return Container(
          width: 300,
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            border: Border(left: BorderSide(color: AppTheme.borderOf(context), width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header aligned with top bar
              Container(
                height: 66,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.borderOf(context), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOf(context).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPlaying
                                  ? AppTheme.accentGreen
                                  : AppTheme.textMutedOf(context),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPlaying ? 'LIVE' : 'IDLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPlaying
                                  ? AppTheme.accentGreen
                                  : AppTheme.textMutedOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Spinning Vinyl / Album Showcase
                      const SizedBox(height: 10),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow
                          Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (currentSong?.gradientColors.first ??
                                              AppTheme.primary)
                                          .withValues(
                                            alpha: isPlaying ? 0.35 : 0.05,
                                          ),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),

                          // Vinyl Disc
                          RotationTransition(
                            turns: _rotationController,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFF1E293B),
                                    Color(0xFF0F172A),
                                    Color(0xFF090D16),
                                  ],
                                  stops: [0.3, 0.7, 1.0],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: SongArtworkWidget(
                                  song: currentSong,
                                  size: 80,
                                  isCircle: true,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Track Info
                      Text(
                        currentSong?.title ?? 'No Track Playing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentSong != null
                            ? '${currentSong.artist} • ${currentSong.album}'
                            : 'Select any track to start playing',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Action Buttons: Lyrics, Save, Download
                      if (currentSong != null) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // Lyrics Button
                            _buildActionButton(
                              context: context,
                              icon: Icons.lyrics_rounded,
                              label: 'Lyrics',
                              onTap: widget.onOpenLyrics,
                            ),

                            // Save Button
                            _buildActionButton(
                              context: context,
                              icon: currentSong.isLiked
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              label: currentSong.isLiked ? 'Saved' : 'Save',
                              isActive: currentSong.isLiked,
                              onTap: () => widget.controller.toggleLike(currentSong.id),
                            ),

                            // Download Button
                            Builder(
                              builder: (btnCtx) {
                                final isDownloaded = widget.controller.isSongDownloaded(currentSong.id);
                                final isDownloading = widget.controller.isSongDownloading(currentSong.id);
                                return _buildActionButton(
                                  context: btnCtx,
                                  icon: isDownloaded
                                      ? Icons.download_done_rounded
                                      : (isDownloading
                                          ? Icons.sync_rounded
                                          : Icons.download_rounded),
                                  label: isDownloaded
                                      ? 'Downloaded'
                                      : (isDownloading ? 'Saving…' : 'Download'),
                                  isActive: isDownloaded,
                                  onTap: () async {
                                    if (!isDownloaded && !isDownloading) {
                                      await widget.controller.downloadSong(currentSong);
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ],

                      if (widget.controller.visualizerEnabled)
                        const SizedBox(height: 16),

                      // Live Animated Equalizer
                      if (widget.controller.visualizerEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cardSurfaceOf(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.borderOf(context),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'AUDIO FREQUENCY',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        color: AppTheme.textMutedOf(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryOf(context).withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.primaryOf(context).withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          widget.controller.equalizerPreset,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: AppTheme.primaryOf(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(widget.controller.volume * 100).toInt()}% Vol',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppTheme.secondaryOf(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 38,
                                child: Center(
                                  child: AnimatedVisualizer(
                                    isPlaying: isPlaying,
                                    barCount: 24,
                                    maxHeight: 34,
                                    barWidth: 4.5,
                                    gradientColors: currentSong?.gradientColors,
                                    equalizerBands: widget
                                        .controller
                                        .currentEqualizer
                                        .bands,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Synchronized Lyrics snippet (Tappable for full lyrics)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: widget.onOpenLyrics,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardSurfaceOf(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.borderOf(context),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lyrics_rounded,
                                      size: 16,
                                      color: AppTheme.primaryOf(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'LYRICS PREVIEW',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        color: AppTheme.textMutedOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (currentSong != null &&
                                    currentSong.lyrics.isNotEmpty) ...[
                                  // Window of lines around the active one so the
                                  // panel tracks playback instead of showing a
                                  // frozen first-four preview.
                                  Builder(
                                    builder: (context) {
                                      final total = widget.controller
                                          .displayDurationFor(currentSong);
                                      final active =
                                          Song.lyricsLineIndexForProgress(
                                            currentSong.lyrics,
                                            widget.controller.currentPosition,
                                            total,
                                          );
                                      final start = (active - 1)
                                          .clamp(
                                            0,
                                            currentSong.lyrics.length - 1,
                                          )
                                          .toInt();
                                      final end = (active + 3)
                                          .clamp(0, currentSong.lyrics.length)
                                          .toInt();
                                      final window = currentSong.lyrics.sublist(
                                        start,
                                        end,
                                      );
                                      var offset = start;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: window.map((line) {
                                          final i = offset++;
                                          final isActive = i == active;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Text(
                                              line,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: isActive ? 14 : 13,
                                                height: 1.3,
                                                fontWeight: isActive
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: Colors.white,
                                                shadows: const [
                                                  BoxShadow(
                                                    color: Colors.black54,
                                                    blurRadius: 6,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ] else if (currentSong != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.textPrimaryOf(context),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Loading lyrics…',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textMutedOf(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    'No lyrics or active track loaded',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMutedOf(context),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Up Next Section Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${widget.controller.queue.length} Tracks',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'UP NEXT IN QUEUE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppTheme.textMutedOf(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Up Next queue list
                      if (widget.controller.queue.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          child: Text(
                            'Queue is empty',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedOf(context),
                            ),
                          ),
                        )
                      else
                        ...widget.controller.queue.asMap().entries.take(5).map((
                          entry,
                        ) {
                          final idx = entry.key;
                          final song = entry.value;
                          final isCurrent =
                              idx == widget.controller.currentIndex;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  if (widget.onPlaySong != null) {
                                    widget.onPlaySong!(song);
                                  } else {
                                    widget.controller.playSong(song);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          gradient: LinearGradient(
                                            colors: song.gradientColors,
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isCurrent
                                                ? Icons.volume_up_rounded
                                                : Icons.music_note_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              song.title,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isCurrent
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isCurrent
                                                    ? AppTheme.accentGreen
                                                    : AppTheme.textPrimaryOf(context),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              song.artist,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMutedOf(context),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        song.formattedDuration,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMutedOf(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  },
);
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isActive = false,
  }) {
    final activeColor = AppTheme.accentGreen;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.22)
                : AppTheme.cardSurfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.6)
                  : AppTheme.borderOf(context),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? activeColor : AppTheme.textPrimaryOf(context),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? activeColor : AppTheme.textPrimaryOf(context),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
