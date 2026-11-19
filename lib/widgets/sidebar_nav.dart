import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../controllers/music_player_controller.dart';
import '../auth/auth_service.dart';
import '../views/accounts_view.dart';
import '../views/listening_stats_view.dart';
import '../views/profile_view.dart';
import '../views/recents_view.dart';
import '../views/settings_view.dart';

class SidebarNav extends StatelessWidget {
  final MusicPlayerController controller;
  final ValueChanged<String>? onPlaylistSelected;
  final ValueChanged<String>? onArtistSelected;
  final VoidCallback? onCreatePlaylist;
  final VoidCallback? onImportSpotify;
  final String? selectedPlaylistId;
  final bool isDrawer;

  const SidebarNav({
    super.key,
    required this.controller,
    this.onPlaylistSelected,
    this.onArtistSelected,
    this.onCreatePlaylist,
    this.onImportSpotify,
    this.selectedPlaylistId,
    this.isDrawer = false,
  });

  /// Pushes an account screen from either the desktop sidebar or the mobile
  /// drawer. Closing the drawer first keeps the navigation stack tidy.
  void _openPage(BuildContext context, Widget page) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openSettings(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    }
    SettingsView.show(context, controller: controller);
  }

  void _showUpdatesSheet(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMutedOf(ctx).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      color: Color(0xFF1DB954),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your Updates',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(ctx),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textMutedOf(ctx)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildUpdateTile(
                  context: ctx,
                  title: 'Now Playing Artwork & Action Buttons',
                  description:
                      'Tap any song to view high-resolution cover art with Lyrics, Save, and Download actions.',
                  date: 'Just now',
                ),
                _buildUpdateTile(
                  context: ctx,
                  title: 'Spotify & YouTube Fast Import',
                  description:
                      'Import playlists and songs with automatic full-track audio matching and offline caching.',
                  date: 'Recent',
                ),
                _buildUpdateTile(
                  context: ctx,
                  title: '10-Band Graphic Equalizer',
                  description:
                      'Custom presets, dynamic visualizer, and acoustic tuning in Settings.',
                  date: 'Recent',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpdateTile({
    required BuildContext context,
    required String title,
    required String description,
    required String date,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardSurfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderOf(context),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimaryOf(context),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    color: AppTheme.textMutedOf(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getUserDisplayName() {
    final name = AuthService.instance.userDisplayName.trim();
    if (name.isNotEmpty && name != 'Guest') {
      return name;
    }
    final email = AuthService.instance.userEmail.trim();
    if (email.isNotEmpty && email != 'guest@pulsemusic.app') {
      return email.split('@').first;
    }
    return 'johnlaurencenovicio';
  }

  String _getUserInitial(String displayName) {
    if (displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    return 'J';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getUserDisplayName();
    final initial = _getUserInitial(displayName);

    return Container(
      width: isDrawer ? double.infinity : 240,
      decoration: BoxDecoration(
        color: isDrawer
            ? (AppTheme.isDark(context)
                ? const Color(0xFF121212)
                : AppTheme.lightSurface)
            : AppTheme.surfaceOf(context),
        border: isDrawer
            ? null
            : Border(
                right: BorderSide(color: AppTheme.borderOf(context), width: 1),
              ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Profile Card (Spotify Style)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.isDark(context)
                      ? const Color(0xFF242424)
                      : AppTheme.lightCardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.borderOf(context),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Profile Header: Green circular Avatar + Username + View profile
                    InkWell(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      onTap: () => _openPage(context, const ProfileView()),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1DB954),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimaryOf(context),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'View profile',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
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

                    // Divider line
                    Divider(
                      color: AppTheme.borderOf(context),
                      height: 1,
                      thickness: 1,
                    ),

                    // Bottom: + Add account
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      onTap: () => _openPage(context, const AccountsView()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.isDark(context)
                                    ? const Color(0xFF333333)
                                    : AppTheme.borderOf(context),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.add,
                                color: AppTheme.textPrimaryOf(context),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Add account',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Menu Items List
              _buildMenuItem(
                context: context,
                iconWidget: _ListeningStatsIcon(
                  size: 26,
                  color: AppTheme.textPrimaryOf(context),
                ),
                label: 'Listening stats',
                onTap: () => _openPage(
                  context,
                  ListeningStatsView(controller: controller),
                ),
              ),

              _buildMenuItem(
                context: context,
                icon: Icons.history_rounded,
                label: 'Recents',
                onTap: () => _openPage(
                  context,
                  RecentsView(controller: controller),
                ),
              ),

              _buildMenuItem(
                context: context,
                icon: Icons.campaign_outlined,
                label: 'Your Updates',
                onTap: () => _showUpdatesSheet(context),
              ),

              _buildMenuItem(
                context: context,
                icon: Icons.settings_outlined,
                label: 'Settings and privacy',
                onTap: () => _openSettings(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    final textColor = AppTheme.textPrimaryOf(context);
    final isDark = AppTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        splashColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        highlightColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 30,
                alignment: Alignment.centerLeft,
                child: iconWidget ??
                    Icon(
                      icon,
                      size: 26,
                      color: textColor,
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListeningStatsIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _ListeningStatsIcon({this.size = 26, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ListeningStatsPainter(color: color),
    );
  }
}

class _ListeningStatsPainter extends CustomPainter {
  final Color color;

  _ListeningStatsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // L-shaped axis: left vertical and bottom horizontal line
    final axisPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.12)
      ..lineTo(size.width * 0.08, size.height * 0.88)
      ..lineTo(size.width * 0.92, size.height * 0.88);
    canvas.drawPath(axisPath, paint);

    // Rising trend line (jagged waveform curve like Spotify)
    final linePath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.72)
      ..lineTo(size.width * 0.36, size.height * 0.72)
      ..lineTo(size.width * 0.58, size.height * 0.28)
      ..lineTo(size.width * 0.76, size.height * 0.52)
      ..lineTo(size.width * 0.90, size.height * 0.22);
    canvas.drawPath(linePath, paint);
  }

  @override
  bool shouldRepaint(covariant _ListeningStatsPainter oldDelegate) =>
      oldDelegate.color != color;
}
