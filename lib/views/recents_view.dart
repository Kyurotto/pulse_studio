import 'package:material_ui/material_ui.dart';

import '../auth/auth_service.dart';
import '../controllers/music_player_controller.dart';
import '../data/local_database.dart';
import '../models/listening_history.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork_widget.dart';

/// Recently played tracks, newest first, one row per song.
class RecentsView extends StatefulWidget {
  const RecentsView({super.key, this.controller});

  final MusicPlayerController? controller;

  static Route<void> route({MusicPlayerController? controller}) {
    return MaterialPageRoute<void>(
      builder: (_) => RecentsView(controller: controller),
    );
  }

  @override
  State<RecentsView> createState() => _RecentsViewState();
}

class _RecentsViewState extends State<RecentsView> {
  List<ListeningHistoryEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = AuthService.instance.currentUserId;
    final entries = userId.isEmpty
        ? const <ListeningHistoryEntry>[]
        : await LocalDatabase.instance.getRecentListening(userId: userId);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  void _play(ListeningHistoryEntry entry) {
    final controller = widget.controller;
    if (controller == null) return;
    final song = controller.songById(entry.songId);
    if (song == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This song is no longer in your library.'),
        ),
      );
      return;
    }
    controller.playSong(song);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceOf(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimaryOf(context),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Recents',
          style: TextStyle(
            color: AppTheme.textPrimaryOf(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              color: AppTheme.textSecondaryOf(context),
            ),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.borderOf(context)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryOf(context),
              backgroundColor: AppTheme.cardSurfaceOf(context),
              child: _entries.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        const SizedBox(height: 90),
                        Icon(
                          Icons.history_rounded,
                          size: 54,
                          color: AppTheme.textMutedOf(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nothing played yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Songs you play will show up here so you can jump '
                          'back into them quickly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: _entries.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 2, bottom: 8),
                            child: Text(
                              '${_entries.length} recently played '
                              '${_entries.length == 1 ? 'song' : 'songs'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: AppTheme.textMutedOf(context),
                              ),
                            ),
                          );
                        }
                        final entry = _entries[index - 1];
                        final previous = index > 1 ? _entries[index - 2] : null;
                        final showDayDivider =
                            previous == null ||
                            !_isSameDay(previous.startedAt, entry.startedAt);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDayDivider)
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 2,
                                  top: previous == null ? 0 : 12,
                                  bottom: 6,
                                ),
                                child: Text(
                                  _dayLabel(entry.startedAt),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: AppTheme.textSecondaryOf(context),
                                  ),
                                ),
                              ),
                            _RecentTile(
                              entry: entry,
                              onTap: widget.controller == null
                                  ? null
                                  : () => _play(entry),
                            ),
                            const SizedBox(height: 5),
                          ],
                        );
                      },
                    ),
            ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime value) {
    final now = DateTime.now();
    if (_isSameDay(now, value)) return 'TODAY';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(yesterday, value)) return 'YESTERDAY';
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.entry, this.onTap});

  final ListeningHistoryEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = _timeLabel(entry.startedAt);
    final listened = entry.listenedSeconds > 0
        ? ' · ${_shortDuration(entry.listenedSeconds)}'
        : '';
    final subtitle = entry.artist.isNotEmpty
        ? '${entry.artist} · $time$listened'
        : '$time$listened';

    return Material(
      color: AppTheme.surfaceOf(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Row(
            children: [
              SongArtworkWidget(
                imageUrl: entry.imageUrl,
                title: entry.title,
                artist: entry.artist,
                size: 36,
                borderRadius: 7,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (entry.completed)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppTheme.accentGreen,
                  ),
                ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 19,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeLabel(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static String _shortDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder > 0 ? '${hours}h ${remainder}m' : '${hours}h';
  }
}