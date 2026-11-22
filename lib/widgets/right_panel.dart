import 'package:material_ui/material_ui.dart';
import '../models/song_model.dart';
import '../theme/app_theme.dart';
import '../controllers/music_player_controller.dart';
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
    _maybeEnsureLyrics(widget.controller.currentSong);
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

  void _maybeEnsureLyrics(Song? song) {
    if (song != null && song.lyrics.isEmpty) {
      widget.controller.ensureLyricsFor(song);
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
    _maybeEnsureLyrics(widget.controller.currentSong);
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

            final totalDur = currentSong != null
                ? widget.controller.displayDurationFor(currentSong)
                : widget.controller.currentDuration;
            final maxMs = totalDur.inMilliseconds > 0
                ? totalDur.inMilliseconds.toDouble()
                : 1.0;
            final currentMs = widget.controller.currentPosition.inMilliseconds
                .toDouble()
                .clamp(0.0, maxMs);

            return Container(
              width: 320,
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                border: Border(
                  left: BorderSide(color: AppTheme.borderOf(context), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header aligned with desktop bar
                  Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.borderOf(context),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOf(
                              context,
                            ).withValues(alpha: 0.15),
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
                              const SizedBox(width: 5),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. CIRCLE ARTWORK WITH WHITE GLOW RING (circle yung music)
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glowing outer halo
                                Container(
                                  width: 182,
                                  height: 182,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: isPlaying ? 0.45 : 0.18,
                                        ),
                                        blurRadius: 28,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color:
                                            (currentSong
                                                        ?.gradientColors
                                                        .firstOrNull ??
                                                    AppTheme.primary)
                                                .withValues(
                                                  alpha: isPlaying
                                                      ? 0.35
                                                      : 0.10,
                                                ),
                                        blurRadius: 36,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),

                                // Circular Vinyl with clean white border ring
                                RotationTransition(
                                  turns: _rotationController,
                                  child: Container(
                                    width: 174,
                                    height: 174,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: isPlaying ? 0.95 : 0.60,
                                        ),
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: SongArtworkWidget(
                                        song: currentSong,
                                        size: 169,
                                        isCircle: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 2. SONG TITLE & ARTIST NAME (may title artist name)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentSong?.title ?? 'No Track Playing',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryOf(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentSong != null
                                          ? '${currentSong.artist} • ${currentSong.album}'
                                          : 'Select any track to start playing',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppTheme.textSecondaryOf(
                                          context,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  (currentSong?.isLiked ?? false)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 19,
                                  color: (currentSong?.isLiked ?? false)
                                      ? AppTheme.accentPink
                                      : AppTheme.textMutedOf(context),
                                ),
                                tooltip: (currentSong?.isLiked ?? false)
                                    ? 'In Favorites'
                                    : 'Add to Favorites',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: currentSong != null
                                    ? () => widget.controller.toggleLike(
                                        currentSong.id,
                                      )
                                    : null,
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Action Buttons: Lyrics, Save, Download
                          if (currentSong != null)
                            Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildActionButton(
                                  context: context,
                                  icon: Icons.lyrics_rounded,
                                  label: 'Lyrics',
                                  onTap: widget.onOpenLyrics,
                                ),
                                _buildActionButton(
                                  context: context,
                                  icon: currentSong.isLiked
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  label: currentSong.isLiked ? 'Saved' : 'Save',
                                  isActive: currentSong.isLiked,
                                  onTap: () => widget.controller.toggleLike(
                                    currentSong.id,
                                  ),
                                ),
                                Builder(
                                  builder: (btnCtx) {
                                    final isDownloaded = widget.controller
                                        .isSongDownloaded(currentSong.id);
                                    final isDownloading = widget.controller
                                        .isSongDownloading(currentSong.id);
                                    return _buildActionButton(
                                      context: btnCtx,
                                      icon: isDownloaded
                                          ? Icons.download_done_rounded
                                          : (isDownloading
                                              ? Icons.sync_rounded
                                              : Icons.download_rounded),
                                      label: isDownloaded
                                          ? 'Downloaded'
                                          : (isDownloading
                                              ? 'Saving…'
                                              : 'Download'),
                                      isActive: isDownloaded,
                                      onTap: () async {
                                        if (!isDownloaded && !isDownloading) {
                                          await widget.controller.downloadSong(
                                            currentSong,
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),

                          const SizedBox(height: 12),

                          // 3. PROGRESS SLIDER (progress slider)
                          Row(
                            children: [
                              Text(
                                Song.formatTime(
                                  widget.controller.currentPosition,
                                ),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMutedOf(context),
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3.0,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 4.5,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 9,
                                    ),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: currentMs,
                                    min: 0.0,
                                    max: maxMs,
                                    onChanged: currentSong != null
                                        ? (val) {
                                            widget.controller.seekTo(
                                              Duration(
                                                milliseconds: val.toInt(),
                                              ),
                                            );
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                              Text(
                                Song.formatTime(totalDur),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMutedOf(context),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // 4. CONTROLS: SHUFFLE, PREV, PLAY/PAUSE, NEXT, REPEAT
                          // (shuffle button, enable repeat button, saka play pause button na may < > button din)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Shuffle Button
                              IconButton(
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  size: 19,
                                  color: widget.controller.isShuffle
                                      ? AppTheme.accentGreen
                                      : AppTheme.textMutedOf(context),
                                ),
                                tooltip: 'Shuffle',
                                onPressed: currentSong != null
                                    ? widget.controller.toggleShuffle
                                    : null,
                              ),

                              // Previous Track < Button
                              IconButton(
                                icon: Icon(
                                  Icons.skip_previous_rounded,
                                  size: 26,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                                tooltip: 'Previous',
                                onPressed: currentSong != null
                                    ? widget.controller.previous
                                    : null,
                              ),

                              // Play / Pause Circular Button
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.black87,
                                    size: 24,
                                  ),
                                  onPressed: currentSong != null
                                      ? widget.controller.togglePlayPause
                                      : null,
                                ),
                              ),

                              // Next Track > Button
                              IconButton(
                                icon: Icon(
                                  Icons.skip_next_rounded,
                                  size: 26,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                                tooltip: 'Next',
                                onPressed: currentSong != null
                                    ? widget.controller.next
                                    : null,
                              ),

                              // Repeat Button
                              IconButton(
                                icon: Icon(
                                  widget.controller.repeatMode ==
                                          PlaybackRepeatMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  size: 19,
                                  color: widget.controller.repeatMode !=
                                          PlaybackRepeatMode.off
                                      ? AppTheme.accentGreen
                                      : AppTheme.textMutedOf(context),
                                ),
                                tooltip:
                                    'Repeat: ${widget.controller.repeatMode.name}',
                                onPressed: currentSong != null
                                    ? widget.controller.toggleRepeat
                                    : null,
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Secondary mini-toolbar: Visualizer bar + Volume Slider
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.cardSurfaceOf(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.borderOf(context),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.controller.isMuted
                                      ? Icons.volume_off_rounded
                                      : (widget.controller.volume > 0.5
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_down_rounded),
                                  size: 16,
                                  color: AppTheme.textMutedOf(context),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2.5,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 3.5,
                                      ),
                                      activeTrackColor: AppTheme.accentGreen,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: widget.controller.volume.clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (val) =>
                                          widget.controller.setVolume(val),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(widget.controller.volume * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textMutedOf(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // 5. SQUARE IMAGE SHOWCASE ("sa baba nito is may image din")
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.radio_rounded,
                                          size: 15,
                                          color: AppTheme.primaryOf(context),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          currentSong?.album.isNotEmpty == true
                                              ? currentSong!.album
                                              : 'Current Album & Radio',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            color: AppTheme.textPrimaryOf(
                                              context,
                                            ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.more_horiz_rounded,
                                      size: 16,
                                      color: AppTheme.textMutedOf(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // The square image artwork
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 1.0,
                                    child: SongArtworkWidget(
                                      song: currentSong,
                                      size: 260,
                                      borderRadius: 12,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // 6. TITLE & ARTIST NAME AGAIN
                                // ("saka sa baba ng image may title ulit saka artist name")
                                Text(
                                  currentSong?.title ?? 'No Track Selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryOf(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentSong?.artist ?? '',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondaryOf(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // 7. LYRICS SECTION ("sa baba nitong title saka artist name is may lyrics na")
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: widget.onOpenLyrics,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF281E0C),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.lyrics_rounded,
                                              size: 15,
                                              color: Color(0xFFFBBF24),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Lyrics preview',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.6,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Icon(
                                          Icons.open_in_full_rounded,
                                          size: 14,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (currentSong != null &&
                                        currentSong.lyrics.isNotEmpty) ...[
                                      Builder(
                                        builder: (context) {
                                          final total = widget.controller
                                              .displayDurationFor(currentSong);
                                          final active =
                                              Song.lyricsLineIndexForProgress(
                                                currentSong.lyrics,
                                                widget
                                                    .controller
                                                    .currentPosition,
                                                total,
                                              );
                                          final start = (active - 1)
                                              .clamp(
                                                0,
                                                currentSong.lyrics.length - 1,
                                              )
                                              .toInt();
                                          final end = (active + 4)
                                              .clamp(
                                                0,
                                                currentSong.lyrics.length,
                                              )
                                              .toInt();
                                          final window = currentSong.lyrics
                                              .sublist(start, end);
                                          var offset = start;
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: window.map((line) {
                                              final i = offset++;
                                              final isActive = i == active;
                                              final displayLine =
                                                  Song.stripTimestamp(line);
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                child: Text(
                                                  displayLine.isNotEmpty
                                                      ? displayLine
                                                      : line,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: isActive
                                                        ? 14.5
                                                        : 13,
                                                    height: 1.35,
                                                    fontWeight: isActive
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                    color: isActive
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFFD1B78B,
                                                          ),
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
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFFBBF24),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Flexible(
                                            child: Text(
                                              'Loading lyrics…',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFD1B78B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const Text(
                                        'No lyrics or active track loaded',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFD1B78B),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                size: 13,
                color: isActive ? activeColor : AppTheme.textPrimaryOf(context),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive
                      ? activeColor
                      : AppTheme.textPrimaryOf(context),
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
