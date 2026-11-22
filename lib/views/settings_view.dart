import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import '../auth/auth_service.dart';
import '../controllers/music_player_controller.dart';
import '../data/local_database.dart';
import '../models/equalizer_preset.dart';
import '../services/audio_capabilities.dart';
import '../services/biometric_auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    this.controller,
    this.openProfileEdit = false,
  });

  final MusicPlayerController? controller;
  final bool openProfileEdit;

  static Future<void> show(
    BuildContext context, {
    MusicPlayerController? controller,
    bool openProfileEdit = false,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsView(
          controller: controller,
          openProfileEdit: openProfileEdit,
        ),
      ),
    );
  }

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Spotify-style Settings State
  double _crossfadeSeconds = 4.0;
  bool _gaplessPlayback = true;
  bool _automix = true;
  bool _normalizeVolume = true;
  bool _monoAudio = false;
  bool _autoplay = true;

  String _streamingQuality = 'Very High (320 kbps)';
  String _downloadQuality = 'High (160 kbps)';
  String _equalizerPreset = 'Bass Boost';

  bool _canvasAnimation = true;
  bool _autoLyrics = false;
  bool _allowExplicit = true;
  bool _downloadOnMobile = false;
  bool _autoCachePlayedSongs = true;
  bool _dataSaverMode = false;
  bool _reduceAnimations = false;
  String _themeModeSetting = 'dark';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  bool _biometricUnlockEnabled = false;
  bool _biometricSupported = false;
  bool _biometricEnrolled = false;

  int _cacheSizeBytes = -1;
  bool _clearingCache = false;
  bool _cacheRefreshInFlight = false;
  bool _cacheRefreshQueued = false;
  Timer? _cacheRefreshDebounce;

  final List<String> _qualityOptions = const [
    'Automatic',
    'Low (24 kbps)',
    'Normal (96 kbps)',
    'High (160 kbps)',
    'Very High (320 kbps)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _equalizerPreset = widget.controller!.equalizerPreset;
      _reduceAnimations = widget.controller!.reduceAnimations;
    }
    if (AppTheme.themeMode == ThemeMode.light) {
      _themeModeSetting = 'light';
    } else if (AppTheme.themeMode == ThemeMode.system) {
      _themeModeSetting = 'system';
    } else {
      _themeModeSetting = 'dark';
    }
    _loadSettings();
    _refreshCacheSize();
    LocalDatabase.audioCacheRevision.addListener(_onAudioCacheChanged);
    if (widget.openProfileEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showEditProfileDialog();
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await LocalDatabase.instance.getAllSettings();
      if (!mounted) return;
      setState(() {
        if (settings.containsKey('crossfade')) {
          _crossfadeSeconds =
              double.tryParse(settings['crossfade']!) ?? _crossfadeSeconds;
        }
        if (settings.containsKey('gapless_playback')) {
          _gaplessPlayback = settings['gapless_playback'] == 'true';
        }
        if (settings.containsKey('automix')) {
          _automix = settings['automix'] == 'true';
        }
        if (settings.containsKey('normalize_volume')) {
          _normalizeVolume = settings['normalize_volume'] == 'true';
        }
        if (settings.containsKey('mono_audio')) {
          _monoAudio = settings['mono_audio'] == 'true';
        }
        if (settings.containsKey('autoplay')) {
          _autoplay = settings['autoplay'] == 'true';
        }
        if (settings.containsKey('streaming_quality')) {
          _streamingQuality = settings['streaming_quality']!;
        }
        if (settings.containsKey('download_quality')) {
          _downloadQuality = settings['download_quality']!;
        }
        if (settings.containsKey('equalizer_preset')) {
          _equalizerPreset = settings['equalizer_preset']!;
        }
        if (settings.containsKey('canvas_animation')) {
          _canvasAnimation = settings['canvas_animation'] == 'true';
        }
        if (settings.containsKey('auto_lyrics')) {
          _autoLyrics = settings['auto_lyrics'] == 'true';
        }
        if (settings.containsKey('allow_explicit')) {
          _allowExplicit = settings['allow_explicit'] == 'true';
        }
        if (settings.containsKey('download_on_mobile_data')) {
          _downloadOnMobile = settings['download_on_mobile_data'] == 'true';
        }
        if (settings.containsKey('auto_cache_played_songs')) {
          _autoCachePlayedSongs = settings['auto_cache_played_songs'] != 'false';
        }
        if (settings.containsKey('data_saver_mode')) {
          _dataSaverMode = settings['data_saver_mode'] == 'true';
        }
        if (settings.containsKey('reduce_animations')) {
          _reduceAnimations = settings['reduce_animations'] == 'true';
        }
        if (settings.containsKey('theme_mode')) {
          _themeModeSetting = settings['theme_mode']!;
        }
      });

      final uid = AuthService.instance.currentUserId;
      final supported = BiometricAuthService.instance.isPlatformSupported;
      bool enrolled = false;
      bool unlockEnabled = false;
      if (supported) {
        enrolled = await BiometricAuthService.instance.isBiometricEnrolled();
        if (uid.isNotEmpty) {
          unlockEnabled = await BiometricAuthService.instance
              .isBiometricUnlockEnabled(uid);
        }
      }
      if (mounted) {
        setState(() {
          _biometricSupported = supported;
          _biometricEnrolled = enrolled;
          _biometricUnlockEnabled = unlockEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    try {
      await LocalDatabase.instance.saveSetting(key, value);
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

  void _onAudioCacheChanged() {
    _cacheRefreshDebounce?.cancel();
    _cacheRefreshDebounce = Timer(const Duration(milliseconds: 1200), () {
      _refreshCacheSize();
    });
  }

  Future<void> _refreshCacheSize() async {
    if (_cacheRefreshInFlight) {
      _cacheRefreshQueued = true;
      return;
    }
    _cacheRefreshInFlight = true;
    try {
      final bytes = await LocalDatabase.getLocalAudioCacheSizeBytes();
      if (!mounted || bytes == _cacheSizeBytes) return;
      setState(() => _cacheSizeBytes = bytes);
    } catch (e) {
      debugPrint('Error reading audio cache size: $e');
    } finally {
      _cacheRefreshInFlight = false;
      if (_cacheRefreshQueued) {
        _cacheRefreshQueued = false;
        unawaited(_refreshCacheSize());
      }
    }
  }

  String _formatCacheSize(int bytes) {
    if (bytes < 0) return 'Calculating…';
    if (bytes == 0) return '0 MB';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / kb).toStringAsFixed(0)} KB';
  }

  /// Visual share of a nominal 8 GB cache budget for the storage bar.
  int get _cacheBarFlex {
    if (_cacheSizeBytes <= 0) return 1;
    const referenceBytes = 8 * 1024 * 1024 * 1024;
    return ((_cacheSizeBytes / referenceBytes) * 100).clamp(1, 100).round();
  }

  Future<void> _showQualityPicker({required bool isStreaming}) async {
    final current = isStreaming ? _streamingQuality : _downloadQuality;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  isStreaming
                      ? 'Streaming Audio Quality'
                      : 'Download Audio Quality',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(sheetContext),
                  ),
                ),
              ),
              Divider(color: AppTheme.borderOf(sheetContext)),
              ..._qualityOptions.map(
                (opt) => ListTile(
                  title: Text(
                    opt,
                    style: TextStyle(
                      color: opt == current
                          ? AppTheme.primaryOf(sheetContext)
                          : AppTheme.textPrimaryOf(sheetContext),
                      fontWeight: opt == current
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: opt == current
                      ? Icon(
                          Icons.check_rounded,
                          color: AppTheme.primaryOf(sheetContext),
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(opt),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        if (isStreaming) {
          _streamingQuality = selected;
        } else {
          _downloadQuality = selected;
        }
      });
      _saveSetting(
        isStreaming ? 'streaming_quality' : 'download_quality',
        selected,
      );
      if (isStreaming) {
        widget.controller?.setStreamingQuality(selected, save: false);
      } else {
        widget.controller?.setDownloadQuality(selected, save: false);
      }
    }
  }

  Future<void> _showEqualizerPicker() async {
    final initialPreset =
        widget.controller?.currentEqualizer ??
        EqualizerPreset.getByName(_equalizerPreset);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String activePresetName = initialPreset.name;
        List<double> activeBands = List<double>.from(initialPreset.bands);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activePreset = EqualizerPreset.getByName(activePresetName);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(sheetContext),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.borderOf(sheetContext),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textMutedOf(
                            sheetContext,
                          ).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOf(
                                    sheetContext,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: AppTheme.primaryOf(sheetContext),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Audio Equalizer',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimaryOf(
                                        sheetContext,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    activePreset.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primaryOf(sheetContext),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppTheme.textMutedOf(sheetContext),
                            ),
                            onPressed: () => Navigator.of(
                              sheetContext,
                            ).pop(activePresetName),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5-Band Frequency Sliders / Visual Curve Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardSurfaceOf(sheetContext),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.borderOf(sheetContext),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'FREQUENCY RESPONSE (dB)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: AppTheme.textMutedOf(sheetContext),
                                  ),
                                ),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryOf(
                                        sheetContext,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activePreset.description,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondaryOf(
                                          sheetContext,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 5 Interactive / Animated Frequency Sliders
                            SizedBox(
                              height: 125,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(5, (index) {
                                  final db = activeBands[index];
                                  final label =
                                      EqualizerPreset.frequencyLabels[index];

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${db >= 0 ? '+' : ''}${db.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: db != 0
                                              ? AppTheme.primaryOf(sheetContext)
                                              : AppTheme.textMutedOf(
                                                  sheetContext,
                                                ),
                                        ),
                                      ),
                                      Expanded(
                                        child: RotatedBox(
                                          quarterTurns: -1,
                                          child: SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              trackHeight: 3,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                    enabledThumbRadius: 5,
                                                  ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                    overlayRadius: 10,
                                                  ),
                                              activeTrackColor:
                                                  AppTheme.primaryOf(
                                                    sheetContext,
                                                  ),
                                              inactiveTrackColor:
                                                  AppTheme.borderOf(
                                                    sheetContext,
                                                  ),
                                              thumbColor: AppTheme.primaryOf(
                                                sheetContext,
                                              ),
                                            ),
                                            child: Slider(
                                              value: db,
                                              min: -10.0,
                                              max: 10.0,
                                              onChanged: (newVal) {
                                                setSheetState(() {
                                                  activeBands[index] = newVal;
                                                  activePresetName =
                                                      EqualizerPreset
                                                          .custom
                                                          .name;
                                                });
                                                // Move the native equalizer
                                                // while dragging, but only
                                                // persist once the drag ends.
                                                widget.controller
                                                    ?.setCustomEqualizerBands(
                                                      activeBands,
                                                      save: false,
                                                    );
                                              },
                                              onChangeEnd: (_) {
                                                widget.controller
                                                    ?.setCustomEqualizerBands(
                                                      activeBands,
                                                    );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppTheme.textSecondaryOf(
                                            sheetContext,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: AppTheme.borderOf(sheetContext)),

                    // Scrollable Presets List (Fixes the 28px bottom overflow!)
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        itemCount: EqualizerPreset.all.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final preset = EqualizerPreset.all[index];
                          final isSelected = preset.name == activePresetName;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                final bands =
                                    preset.name == EqualizerPreset.custom.name
                                    ? List<double>.from(
                                        widget
                                                .controller
                                                ?.customEqualizerBands ??
                                            preset.bands,
                                      )
                                    : List<double>.from(preset.bands);
                                setSheetState(() {
                                  activePresetName = preset.name;
                                  activeBands = bands;
                                });
                                widget.controller?.setEqualizerPreset(
                                  preset.name,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryOf(
                                          sheetContext,
                                        ).withValues(alpha: 0.12)
                                      : AppTheme.cardSurfaceOf(
                                          sheetContext,
                                        ).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryOf(sheetContext)
                                        : AppTheme.borderOf(sheetContext),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryOf(sheetContext)
                                            : AppTheme.surfaceOf(sheetContext),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        preset.icon,
                                        color: isSelected
                                            ? (AppTheme.isDark(sheetContext)
                                                  ? Colors.black87
                                                  : Colors.white)
                                            : AppTheme.textMutedOf(
                                                sheetContext,
                                              ),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            preset.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? AppTheme.primaryOf(
                                                      sheetContext,
                                                    )
                                                  : AppTheme.textPrimaryOf(
                                                      sheetContext,
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            preset.description,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondaryOf(
                                                sheetContext,
                                              ),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.primaryOf(sheetContext),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Apply Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOf(sheetContext),
                            foregroundColor: AppTheme.isDark(sheetContext)
                                ? Colors.black87
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(activePresetName),
                          child: const Text(
                            'Apply Equalizer Preset',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _equalizerPreset = selected);
      widget.controller?.setEqualizerPreset(selected);
      _saveSetting('equalizer_preset', selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Equalizer set to "$selected"',
            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
          ),
          backgroundColor: AppTheme.surfaceOf(context),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceOf(dialogContext),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.borderOf(dialogContext)),
        ),
        title: Text(
          'Clear audio cache?',
          style: TextStyle(
            color: AppTheme.textPrimaryOf(dialogContext),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will free up storage space by clearing temporary streaming cache. Your permanently downloaded songs, playlists, library tracks, and account data will NOT be deleted.',
          style: TextStyle(
            color: AppTheme.textSecondaryOf(dialogContext),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryOf(dialogContext)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOf(dialogContext),
              foregroundColor: AppTheme.isDark(dialogContext)
                  ? Colors.black87
                  : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Clear',
              style: TextStyle(
                color: AppTheme.isDark(dialogContext)
                    ? Colors.black87
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _clearingCache = true);
      final freed = await LocalDatabase.clearLocalAudioCache();
      if (!mounted) return;
      await _refreshCacheSize();
      if (!mounted) return;
      setState(() => _clearingCache = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cache cleared! Freed ${_formatCacheSize(freed)} of storage. Offline downloads remain intact.',
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final displayName = AuthService.instance.userDisplayName;
    final email = AuthService.instance.userEmail;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceOf(dialogContext),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.borderOf(dialogContext)),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              'Log out?',
              style: TextStyle(
                color: AppTheme.textPrimaryOf(dialogContext),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of $displayName ($email)?\nYou will return to the sign-in screen.',
          style: TextStyle(
            color: AppTheme.textSecondaryOf(dialogContext),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryOf(dialogContext)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Perform sign out
      await AuthService.instance.signOut();

      if (!mounted) return;

      // Navigate back to AuthGate / AuthView cleanly
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have been logged out.')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    LocalDatabase.audioCacheRevision.removeListener(_onAudioCacheChanged);
    _cacheRefreshDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.backgroundOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final textMuted = AppTheme.textMutedOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search settings...',
                  hintStyle: TextStyle(color: textMuted, fontSize: 15),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: Icon(Icons.close_rounded, color: textSecondary),
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  _searchController.clear();
                  setState(() {});
                } else {
                  setState(() => _isSearching = false);
                }
              },
            )
          else
            IconButton(
              icon: Icon(Icons.search_rounded, color: textPrimary),
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: _isSearching ? _buildSearchResults() : _buildCategoryList(),
    );
  }

  Widget _buildCategoryList() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // 1. Account
            _buildCategoryRow(
              icon: Icons.person_outline_rounded,
              title: 'Account',
              subtitle: 'Username • Close account',
              onTap: () => _openCategory(
                'Account',
                (ctx, setSub) => _buildAccountCategory(setSub),
              ),
            ),

            // 2. Content and display
            _buildCategoryRow(
              icon: Icons.music_note_outlined,
              title: 'Content and display',
              subtitle: 'Reduce animations • Canvas • Allow explicit content',
              onTap: () => _openCategory(
                'Content and display',
                (ctx, setSub) => _buildContentAndDisplayCategory(setSub),
              ),
            ),

            // 3. Playback
            _buildCategoryRow(
              icon: Icons.volume_up_outlined,
              title: 'Playback',
              subtitle: 'Gapless playback • Autoplay • Equalizer',
              onTap: () => _openCategory(
                'Playback',
                (ctx, setSub) => _buildPlaybackCategory(setSub),
              ),
            ),

            // 4. Data-saving and offline
            _buildCategoryRow(
              icon: Icons.arrow_circle_down_outlined,
              title: 'Data-saving and offline',
              subtitle: 'Data saver mode • Downloads over cellular',
              onTap: () => _openCategory(
                'Data-saving and offline',
                (ctx, setSub) => _buildDataSavingCategory(setSub),
              ),
            ),

            // 5. Media quality
            _buildCategoryRow(
              icon: Icons.bar_chart_rounded,
              title: 'Media quality',
              subtitle: 'Wi-Fi streaming quality • Audio download quality',
              onTap: () => _openCategory(
                'Media quality',
                (ctx, setSub) => _buildMediaQualityCategory(setSub),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: (isDark ? Colors.white : Colors.black).withValues(
          alpha: 0.08,
        ),
        highlightColor: (isDark ? Colors.white : Colors.black).withValues(
          alpha: 0.04,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: textPrimary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCategory(
    String title,
    Widget Function(BuildContext, StateSetter) contentBuilder,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (subContext) => StatefulBuilder(
          builder: (ctx, setSubState) {
            final bgColor = AppTheme.backgroundOf(ctx);
            final textPrimary = AppTheme.textPrimaryOf(ctx);

            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                backgroundColor: bgColor,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                  onPressed: () => Navigator.of(subContext).pop(),
                ),
                centerTitle: true,
                title: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: contentBuilder(ctx, setSubState),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccountCategory(StateSetter setSubState) {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileCard(),
        const SizedBox(height: 24),
        _buildSectionHeader(Icons.security_rounded, 'Security & App Unlock'),
        _buildCard([
          if (_biometricSupported && _biometricEnrolled)
            _buildSwitchTile(
              title: isWindows ? 'Windows Hello Unlock' : 'Biometric Unlock',
              subtitle: isWindows
                  ? 'Unlock Pulse Studio using Windows Hello or device authentication'
                  : 'Unlock Pulse Studio with your device\'s biometric authentication',
              value: _biometricUnlockEnabled,
              onChanged: (val) async {
                final uid = AuthService.instance.currentUserId;
                if (uid.isEmpty) return;
                if (val) {
                  final ok = await BiometricAuthService.instance
                      .authenticateForUnlock();
                  if (ok) {
                    await BiometricAuthService.instance.enableBiometricUnlock(
                      uid,
                    );
                    setState(() => _biometricUnlockEnabled = true);
                    setSubState(() {});
                  }
                } else {
                  await BiometricAuthService.instance.disableBiometricUnlock();
                  setState(() => _biometricUnlockEnabled = false);
                  setSubState(() {});
                }
              },
            )
          else
            ListTile(
              leading: const Icon(
                Icons.fingerprint_rounded,
                color: Colors.grey,
              ),
              title: Text(
                isWindows ? 'Windows Hello Unlock' : 'Biometric Unlock',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                !_biometricSupported
                    ? 'Biometric unlock is not supported on this platform'
                    : 'No biometric credentials enrolled in device settings',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ),
        ]),
        const SizedBox(height: 24),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            label: const Text(
              'Log out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: Colors.redAccent.withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Pulse Studio • Crafted for audiophiles',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMutedOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentAndDisplayCategory(StateSetter setSubState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(Icons.palette_outlined, 'Display & Animations'),
        _buildCard([
          // Theme Selection (Dark mode / Light mode / Auto system)
          _buildThemeTile(setSubState),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Reduce animations (lag reduction)
          _buildSwitchTile(
            title: 'Reduce animations',
            subtitle:
                'Minimizes visual wave effects, disk rotations, and heavy animations to prevent app lag',
            value: _reduceAnimations,
            onChanged: (val) {
              setState(() => _reduceAnimations = val);
              setSubState(() {});
              widget.controller?.setReduceAnimations(val, save: false);
              _saveSetting('reduce_animations', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Canvas (Visualizer)
          _buildSwitchTile(
            title: 'Canvas',
            subtitle:
                'Display the decorative audio-wave animation in the player bar',
            value: _canvasAnimation,
            onChanged: (val) {
              setState(() => _canvasAnimation = val);
              setSubState(() {});
              widget.controller?.setVisualizerEnabled(val, save: false);
              _saveSetting('canvas_animation', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Allow explicit content
          _buildSwitchTile(
            title: 'Allow explicit content',
            subtitle: 'Turn on to play explicit-rated tracks',
            value: _allowExplicit,
            onChanged: (val) {
              setState(() => _allowExplicit = val);
              setSubState(() {});
              widget.controller?.setAllowExplicit(val, save: false);
              _saveSetting('allow_explicit', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Show Lyrics Automatically
          _buildSwitchTile(
            title: 'Show lyrics automatically',
            subtitle: 'Pop up the lyrics sheet when starting a song',
            value: _autoLyrics,
            onChanged: (val) {
              setState(() => _autoLyrics = val);
              setSubState(() {});
              widget.controller?.setAutoLyrics(val, save: false);
              _saveSetting('auto_lyrics', val.toString());
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildThemeTile(StateSetter setSubState) {
    String themeLabel;
    IconData themeIcon;
    switch (_themeModeSetting) {
      case 'light':
        themeLabel = 'Light mode';
        themeIcon = Icons.light_mode_outlined;
        break;
      case 'system':
        themeLabel = 'Auto (System)';
        themeIcon = Icons.brightness_auto_outlined;
        break;
      case 'dark':
      default:
        themeLabel = 'Dark mode';
        themeIcon = Icons.dark_mode_outlined;
        break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        themeIcon,
        color: AppTheme.textPrimaryOf(context),
        size: 22,
      ),
      title: Text(
        'Theme',
        style: TextStyle(
          color: AppTheme.textPrimaryOf(context),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        themeLabel,
        style: TextStyle(
          color: AppTheme.textSecondaryOf(context),
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textMutedOf(context),
      ),
      onTap: () => _showThemePickerDialog(setSubState),
    );
  }

  Future<void> _showThemePickerDialog(StateSetter setSubState) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Widget buildOption({
              required String id,
              required String title,
              required String subtitle,
              required IconData icon,
            }) {
              final isSelected = _themeModeSetting == id;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _themeModeSetting = id);
                  setSubState(() {});
                  setDialogState(() {});
                  ThemeMode mode;
                  if (id == 'light') {
                    mode = ThemeMode.light;
                  } else if (id == 'system') {
                    mode = ThemeMode.system;
                  } else {
                    mode = ThemeMode.dark;
                  }
                  AppTheme.setThemeMode(mode);
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: isSelected
                            ? AppTheme.primaryOf(dialogCtx)
                            : AppTheme.textSecondaryOf(dialogCtx),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.textPrimaryOf(dialogCtx)
                                    : AppTheme.textSecondaryOf(dialogCtx),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMutedOf(dialogCtx),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppTheme.primaryOf(dialogCtx),
                        ),
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: AppTheme.surfaceOf(dialogCtx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppTheme.borderOf(dialogCtx)),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOf(
                        dialogCtx,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      color: AppTheme.primaryOf(dialogCtx),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Choose theme',
                    style: TextStyle(
                      color: AppTheme.textPrimaryOf(dialogCtx),
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildOption(
                    id: 'dark',
                    title: 'Dark mode',
                    subtitle: 'Always use dark atmospheric theme',
                    icon: Icons.dark_mode_outlined,
                  ),
                  Divider(height: 1, color: AppTheme.borderOf(dialogCtx)),
                  buildOption(
                    id: 'light',
                    title: 'Light mode',
                    subtitle: 'Always use crisp light theme',
                    icon: Icons.light_mode_outlined,
                  ),
                  Divider(height: 1, color: AppTheme.borderOf(dialogCtx)),
                  buildOption(
                    id: 'system',
                    title: 'Auto (System)',
                    subtitle: 'Follow device system appearance',
                    icon: Icons.brightness_auto_outlined,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppTheme.textSecondaryOf(dialogCtx),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlaybackCategory(StateSetter setSubState) {
    final loudnessSupported = AudioCapabilities.supportsLoudnessNormalization;
    final monoSupported = AudioCapabilities.supportsMonoAudio;
    final eqSupported = AudioCapabilities.supportsEqualizer;
    final crossfadeEnabled = _automix;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          Icons.play_circle_outline_rounded,
          'Playback Settings',
        ),
        _buildCard([
          // Crossfade Slider
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Crossfade',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: crossfadeEnabled
                            ? AppTheme.textPrimaryOf(context)
                            : AppTheme.textMutedOf(context),
                      ),
                    ),
                    Text(
                      _crossfadeSeconds == 0
                          ? 'Off'
                          : '${_crossfadeSeconds.toInt()}s',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: crossfadeEnabled
                            ? AppTheme.primaryOf(context)
                            : AppTheme.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  crossfadeEnabled
                      ? 'Allows you to crossfade smoothly between songs'
                      : 'Turn on Automix to use crossfade',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryOf(context),
                    inactiveTrackColor: AppTheme.borderOf(context),
                    thumbColor: AppTheme.primaryOf(context),
                    disabledActiveTrackColor: AppTheme.borderOf(context),
                    disabledInactiveTrackColor: AppTheme.borderOf(
                      context,
                    ).withValues(alpha: 0.5),
                    disabledThumbColor: AppTheme.textMutedOf(context),
                    overlayColor: AppTheme.primaryOf(
                      context,
                    ).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _crossfadeSeconds,
                    min: 0,
                    max: 12,
                    divisions: 12,
                    onChanged: crossfadeEnabled
                        ? (val) {
                            setState(() => _crossfadeSeconds = val);
                            setSubState(() {});
                          }
                        : null,
                    onChangeEnd: crossfadeEnabled
                        ? (val) {
                            _saveSetting('crossfade', val.toString());
                            widget.controller?.setCrossfadeSeconds(
                              val,
                              save: false,
                            );
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Gapless Playback
          _buildSwitchTile(
            title: 'Gapless Playback',
            subtitle:
                'Advance immediately without an added silent gap; network tracks may still buffer',
            value: _gaplessPlayback,
            onChanged: (val) {
              setState(() => _gaplessPlayback = val);
              setSubState(() {});
              widget.controller?.setGaplessPlayback(val, save: false);
              _saveSetting('gapless_playback', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Automix
          _buildSwitchTile(
            title: 'Automix',
            subtitle: 'Allow smooth transitions between tracks',
            value: _automix,
            onChanged: (val) {
              setState(() => _automix = val);
              setSubState(() {});
              widget.controller?.setAutomix(val, save: false);
              _saveSetting('automix', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Normalize Volume
          _buildSwitchTile(
            title: 'Normalize Volume',
            subtitle: loudnessSupported
                ? (AudioCapabilities.isWindows
                      ? 'Evens out loud and quiet tracks with dynamic normalization'
                      : 'Applies a fixed loudness boost to playback')
                : 'Not supported on this platform',
            value: loudnessSupported && _normalizeVolume,
            enabled: loudnessSupported,
            onChanged: (val) {
              setState(() => _normalizeVolume = val);
              setSubState(() {});
              widget.controller?.setNormalizeVolume(val, save: false);
              _saveSetting('normalize_volume', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Mono Audio
          _buildSwitchTile(
            title: 'Mono Audio',
            subtitle: monoSupported
                ? 'Makes the left and right speakers play the same audio'
                : 'Not supported on this platform',
            value: monoSupported && _monoAudio,
            enabled: monoSupported,
            onChanged: (val) {
              setState(() => _monoAudio = val);
              setSubState(() {});
              widget.controller?.setMonoAudio(val, save: false);
              _saveSetting('mono_audio', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Autoplay
          _buildSwitchTile(
            title: 'Autoplay',
            subtitle: 'Keep listening to similar songs when your queue ends',
            value: _autoplay,
            onChanged: (val) {
              setState(() => _autoplay = val);
              setSubState(() {});
              widget.controller?.setAutoplay(val, save: false);
              _saveSetting('autoplay', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),

          // Equalizer Tile
          ListTile(
            enabled: eqSupported,
            title: Text(
              'Equalizer',
              style: TextStyle(
                fontSize: 15,
                color: eqSupported
                    ? AppTheme.textPrimaryOf(context)
                    : AppTheme.textMutedOf(context),
              ),
            ),
            subtitle: Text(
              eqSupported
                  ? _equalizerPreset
                  : '$_equalizerPreset · Not supported on this platform',
              style: TextStyle(
                fontSize: 13,
                color: eqSupported
                    ? AppTheme.primaryOf(context)
                    : AppTheme.textMutedOf(context),
              ),
            ),
            trailing: Icon(
              eqSupported ? Icons.tune_rounded : Icons.lock_outline_rounded,
              color: eqSupported
                  ? AppTheme.primaryOf(context)
                  : AppTheme.textMutedOf(context),
            ),
            onTap: eqSupported
                ? () async {
                    await _showEqualizerPicker();
                    if (mounted) {
                      setState(() {});
                      setSubState(() {});
                    }
                  }
                : null,
          ),
        ]),
      ],
    );
  }

  Widget _buildDataSavingCategory(StateSetter setSubState) {
    final cellularSupported = AudioCapabilities.supportsCellularDataPolicy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(Icons.data_saver_on_rounded, 'Data Saver'),
        _buildCard([
          _buildSwitchTile(
            title: 'Data Saver Mode',
            subtitle: cellularSupported
                ? 'Caps new streams and downloads at ~96 kbps, pauses automatic song caching, and blocks cache downloads on mobile data.'
                : 'Caps new streams where the source supports it and pauses automatic song caching.',
            value: _dataSaverMode,
            onChanged: (val) {
              setState(() => _dataSaverMode = val);
              setSubState(() {});
              widget.controller?.setDataSaverMode(val, save: false);
              _saveSetting('data_saver_mode', val.toString());
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),
          _buildSwitchTile(
            title: 'Downloads over cellular',
            subtitle: cellularSupported
                ? 'Off: songs are saved for offline use only on Wi-Fi'
                : 'Only applies on mobile devices with a cellular connection',
            value: cellularSupported && _downloadOnMobile,
            enabled: cellularSupported,
            onChanged: (val) {
              setState(() => _downloadOnMobile = val);
              setSubState(() {});
              _saveSetting('download_on_mobile_data', val.toString());
            },
          ),
          if (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)) ...[
            Divider(height: 1, color: AppTheme.borderOf(context)),
            _buildSwitchTile(
              title: 'Cache played songs',
              subtitle:
                  'Only save audio when you play it; imports no longer download automatically',
              value: _autoCachePlayedSongs,
              onChanged: (val) {
                setState(() => _autoCachePlayedSongs = val);
                setSubState(() {});
                if (widget.controller != null) {
                  widget.controller!.setAutoCachePlayedSongs(val);
                } else {
                  _saveSetting('auto_cache_played_songs', val.toString());
                }
              },
            ),
          ],
        ]),
        const SizedBox(height: 24),
        _buildSectionHeader(Icons.storage_rounded, 'Storage & Cache'),
        _buildCard([
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Local Audio Cache',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatCacheSize(_cacheSizeBytes),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (kIsWeb || defaultTargetPlatform == TargetPlatform.windows)
                      ? 'Played songs are automatically stored in cache for offline listening.'
                      : 'Temporary audio cached from streaming playback.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: _cacheBarFlex,
                        child: Container(
                          height: 8,
                          color: AppTheme.primaryOf(context),
                        ),
                      ),
                      Expanded(
                        flex: 20,
                        child: Container(height: 8, color: Colors.blueAccent),
                      ),
                      Expanded(
                        flex: 65,
                        child: Container(
                          height: 8,
                          color: AppTheme.borderOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _StorageLegend(
                      color: AppTheme.primaryOf(context),
                      label: 'Audio Cache',
                    ),
                    const _StorageLegend(
                      color: Colors.blueAccent,
                      label: 'Playlists & Tracks',
                    ),
                    _StorageLegend(
                      color: AppTheme.borderOf(context),
                      label: 'Free Space',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _cacheSizeBytes > 0 && !_clearingCache
                      ? () async {
                          await _clearCache();
                          if (mounted) {
                            setState(() {});
                            setSubState(() {});
                          }
                        }
                      : null,
                  icon: _clearingCache
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.textMutedOf(context),
                          ),
                        )
                      : const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(
                    _clearingCache
                        ? 'Clearing cache…'
                        : _cacheSizeBytes < 0
                        ? 'Calculating…'
                        : _cacheSizeBytes > 0
                        ? 'Clear Audio Cache'
                        : 'Cache is Clean (0 MB)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cacheSizeBytes > 0
                        ? AppTheme.textPrimaryOf(context)
                        : AppTheme.textMutedOf(context),
                    side: BorderSide(
                      color: _cacheSizeBytes > 0
                          ? AppTheme.borderOf(context)
                          : AppTheme.borderOf(context).withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildMediaQualityCategory(StateSetter setSubState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(Icons.equalizer_rounded, 'Media Quality'),
        _buildCard([
          ListTile(
            title: Text(
              'Wi-Fi streaming quality',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            subtitle: Text(
              _dataSaverMode
                  ? '$_streamingQuality · Data Saver caps at 96 kbps'
                  : _streamingQuality,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondaryOf(context),
            ),
            onTap: () async {
              await _showQualityPicker(isStreaming: true);
              if (mounted) {
                setState(() {});
                setSubState(() {});
              }
            },
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),
          ListTile(
            title: Text(
              'Audio download quality',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            subtitle: Text(
              _dataSaverMode
                  ? '$_downloadQuality · Data Saver caps at 96 kbps'
                  : _downloadQuality,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondaryOf(context),
            ),
            onTap: () async {
              await _showQualityPicker(isStreaming: false);
              if (mounted) {
                setState(() {});
                setSubState(() {});
              }
            },
          ),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Actual bitrate depends on the source. YouTube streams typically top out around 160 kbps.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMutedOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 48, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              Text(
                'Type to search settings',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'e.g. reduce animations, playback, equalizer, cache, quality',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedOf(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> results = [];

    // Check Theme
    if ('theme dark light auto system appearance mode'.contains(query)) {
      results.add(_buildThemeTile((fn) => fn()));
    }

    // Check Reduce Animations
    if ('reduce animations lag performance'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        _buildSwitchTile(
          title: 'Reduce animations',
          subtitle: 'Minimizes visual effects and visualizers to prevent lag',
          value: _reduceAnimations,
          onChanged: (val) {
            setState(() => _reduceAnimations = val);
            widget.controller?.setReduceAnimations(val, save: false);
            _saveSetting('reduce_animations', val.toString());
          },
        ),
      );
    }

    // Check Canvas
    if ('canvas visualizer wave'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        _buildSwitchTile(
          title: 'Canvas (Visualizer)',
          subtitle:
              'Display the decorative audio-wave animation in the player bar',
          value: _canvasAnimation,
          onChanged: (val) {
            setState(() => _canvasAnimation = val);
            widget.controller?.setVisualizerEnabled(val, save: false);
            _saveSetting('canvas_animation', val.toString());
          },
        ),
      );
    }

    // Check Explicit
    if ('explicit content rating filter'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        _buildSwitchTile(
          title: 'Allow explicit content',
          subtitle: 'Turn on to play explicit-rated tracks',
          value: _allowExplicit,
          onChanged: (val) {
            setState(() => _allowExplicit = val);
            widget.controller?.setAllowExplicit(val, save: false);
            _saveSetting('allow_explicit', val.toString());
          },
        ),
      );
    }

    // Check Lyrics
    if ('lyrics auto show'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        _buildSwitchTile(
          title: 'Show lyrics automatically',
          subtitle: 'Pop up lyrics sheet when starting a song',
          value: _autoLyrics,
          onChanged: (val) {
            setState(() => _autoLyrics = val);
            widget.controller?.setAutoLyrics(val, save: false);
            _saveSetting('auto_lyrics', val.toString());
          },
        ),
      );
    }

    // Check Gapless & Playback
    if ('gapless playback silence'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        _buildSwitchTile(
          title: 'Gapless Playback',
          subtitle:
              'Advance immediately without an added silent gap; network tracks may still buffer',
          value: _gaplessPlayback,
          onChanged: (val) {
            setState(() => _gaplessPlayback = val);
            widget.controller?.setGaplessPlayback(val, save: false);
            _saveSetting('gapless_playback', val.toString());
          },
        ),
      );
    }

    if ('crossfade fade'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        ListTile(
          title: Text(
            'Crossfade',
            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
          ),
          subtitle: Text(
            _automix
                ? 'Current: ${_crossfadeSeconds.toInt()}s'
                : 'Current: ${_crossfadeSeconds.toInt()}s · Requires Automix',
            style: TextStyle(color: AppTheme.primaryOf(context)),
          ),
          onTap: () => _openCategory(
            'Playback',
            (ctx, setSub) => _buildPlaybackCategory(setSub),
          ),
        ),
      );
    }

    if ('equalizer eq bass treble sound'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      final eqSupported = AudioCapabilities.supportsEqualizer;
      results.add(
        ListTile(
          enabled: eqSupported,
          title: Text(
            'Equalizer',
            style: TextStyle(
              color: eqSupported
                  ? AppTheme.textPrimaryOf(context)
                  : AppTheme.textMutedOf(context),
            ),
          ),
          subtitle: Text(
            eqSupported
                ? _equalizerPreset
                : '$_equalizerPreset · Not supported on this platform',
            style: TextStyle(
              color: eqSupported
                  ? AppTheme.primaryOf(context)
                  : AppTheme.textMutedOf(context),
            ),
          ),
          trailing: Icon(
            eqSupported ? Icons.tune_rounded : Icons.lock_outline_rounded,
            color: eqSupported
                ? AppTheme.primaryOf(context)
                : AppTheme.textMutedOf(context),
          ),
          onTap: eqSupported ? _showEqualizerPicker : null,
        ),
      );
    }

    if ('quality streaming bitrate audio download'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        ListTile(
          title: Text(
            'Wi-Fi streaming quality',
            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
          ),
          subtitle: Text(
            _streamingQuality,
            style: TextStyle(color: AppTheme.primaryOf(context)),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMutedOf(context),
          ),
          onTap: () => _showQualityPicker(isStreaming: true),
        ),
      );
      results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      results.add(
        ListTile(
          title: Text(
            'Audio download quality',
            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
          ),
          subtitle: Text(
            _downloadQuality,
            style: TextStyle(color: AppTheme.primaryOf(context)),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMutedOf(context),
          ),
          onTap: () => _showQualityPicker(isStreaming: false),
        ),
      );
    }

    if ('cache storage delete clear'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        ListTile(
          title: Text(
            'Storage & Cache',
            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
          ),
          subtitle: Text(
            'Audio cache: ${_formatCacheSize(_cacheSizeBytes)}',
            style: TextStyle(color: AppTheme.primaryOf(context)),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMutedOf(context),
          ),
          onTap: () => _openCategory(
            'Data-saving and offline',
            (ctx, setSub) => _buildDataSavingCategory(setSub),
          ),
        ),
      );
    }

    if ('data saver cellular mobile offline'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        _buildSwitchTile(
          title: 'Data Saver Mode',
          subtitle: AudioCapabilities.supportsCellularDataPolicy
              ? 'Caps streams at 96 kbps and saves data'
              : 'Caps streams where supported and pauses automatic caching',
          value: _dataSaverMode,
          onChanged: (val) {
            setState(() => _dataSaverMode = val);
            widget.controller?.setDataSaverMode(val, save: false);
            _saveSetting('data_saver_mode', val.toString());
          },
        ),
      );
    }

    if ('account profile username credentials email logout'.contains(query)) {
      if (results.isNotEmpty) {
        results.add(Divider(height: 1, color: AppTheme.borderOf(context)));
      }
      results.add(
        ListTile(
          title: Text(
            'Account Profile',
            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
          ),
          subtitle: Text(
            AuthService.instance.userDisplayName,
            style: TextStyle(color: AppTheme.primaryOf(context)),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMutedOf(context),
          ),
          onTap: () => _openCategory(
            'Account',
            (ctx, setSub) => _buildAccountCategory(setSub),
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'No settings found for "$query"',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [_buildCard(results)],
    );
  }

  Widget _buildProfileCard() {
    final displayName = AuthService.instance.userDisplayName;
    final email = AuthService.instance.userEmail;
    final initials = AuthService.instance.userInitials;
    final role = AuthService.instance.userRole;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showEditProfileDialog,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.isDark(context)
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: AppTheme.isDark(context)
                            ? [
                                AppTheme.primary,
                                AppTheme.primary.withValues(alpha: 0.6),
                              ]
                            : const [Color(0xFF6366F1), Color(0xFFA855F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryOf(
                            context,
                          ).withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurfaceOf(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.borderOf(context)),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: AppTheme.primaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: role == 'admin'
                                ? Colors.amber.withValues(alpha: 0.2)
                                : AppTheme.primaryOf(
                                    context,
                                  ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: role == 'admin'
                                  ? Colors.amber
                                  : AppTheme.primaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 13,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email.isNotEmpty ? email : 'No Gmail assigned',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurfaceOf(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: AppTheme.primaryOf(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.w600,
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
  }

  Future<void> _showEditProfileDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(
      text: AuthService.instance.userEmail,
    );
    final backupEmailController = TextEditingController(
      text: AuthService.instance.userBackupEmail,
    );
    final phoneController = TextEditingController(
      text: AuthService.instance.userPhoneNumber,
    );
    final nameController = TextEditingController(
      text: AuthService.instance.userDisplayName,
    );
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContentContext, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceOf(dialogContext),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppTheme.borderOf(dialogContext)),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOf(
                      dialogContext,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.manage_accounts_rounded,
                    color: AppTheme.primaryOf(dialogContext),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Profile Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(dialogContext),
                        ),
                      ),
                      Text(
                        'Update credentials & recovery details',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(dialogContext),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Display Name
                      TextFormField(
                        controller: nameController,
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(dialogContext),
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration(
                          context: dialogContext,
                          label: 'Full Name',
                          hint: 'e.g. John Laurence',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Gmail / Primary Email
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(dialogContext),
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration(
                          context: dialogContext,
                          label: 'Gmail / Primary Email',
                          hint: 'user@gmail.com',
                          icon: Icons.email_outlined,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Primary Gmail is required';
                          }
                          if (!val.contains('@') || !val.contains('.')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Backup Gmail
                      TextFormField(
                        controller: backupEmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(dialogContext),
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration(
                          context: dialogContext,
                          label: 'Back up Gmail (Recovery)',
                          hint: 'backup@gmail.com',
                          icon: Icons.mark_email_read_outlined,
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            if (!val.contains('@') || !val.contains('.')) {
                              return 'Enter a valid backup email address';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(dialogContext),
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration(
                          context: dialogContext,
                          label: 'Phone Number',
                          hint: '+1 555-0199 or 09123456789',
                          icon: Icons.phone_iphone_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password (Hash) Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardSurfaceOf(dialogContext),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.borderOf(dialogContext),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: AppTheme.secondaryOf(dialogContext),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PASSWORD',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: AppTheme.secondaryOf(dialogContext),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              style: TextStyle(
                                color: AppTheme.textPrimaryOf(dialogContext),
                                fontSize: 14,
                              ),
                              decoration: _inputDecoration(
                                context: dialogContext,
                                label: 'New Password',
                                hint: 'Leave blank to keep existing',
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: AppTheme.textMutedOf(dialogContext),
                                  ),
                                  onPressed: () => setDialogState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (val) {
                                if (val != null &&
                                    val.isNotEmpty &&
                                    val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: obscureConfirm,
                              style: TextStyle(
                                color: AppTheme.textPrimaryOf(dialogContext),
                                fontSize: 14,
                              ),
                              decoration: _inputDecoration(
                                context: dialogContext,
                                label: 'Confirm New Password',
                                hint: 'Re-enter password',
                                icon: Icons.lock_reset_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: AppTheme.textMutedOf(dialogContext),
                                  ),
                                  onPressed: () => setDialogState(
                                    () => obscureConfirm = !obscureConfirm,
                                  ),
                                ),
                              ),
                              validator: (val) {
                                if (passwordController.text.isNotEmpty &&
                                    val != passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.textSecondaryOf(dialogContext),
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOf(dialogContext),
                  foregroundColor: AppTheme.isDark(dialogContext)
                      ? Colors.black87
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          await AuthService.instance.updateProfileAccount(
                            newEmail: emailController.text.trim(),
                            backupEmail: backupEmailController.text.trim(),
                            phoneNumber: phoneController.text.trim(),
                            displayName: nameController.text.trim(),
                            newPassword: passwordController.text.isNotEmpty
                                ? passwordController.text
                                : null,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Profile account updated successfully!',
                                  style: TextStyle(
                                    color: AppTheme.isDark(context)
                                        ? Colors.black87
                                        : Colors.white,
                                  ),
                                ),
                                backgroundColor: AppTheme.primaryOf(context),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update account: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.isDark(dialogContext)
                              ? Colors.black87
                              : Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryOf(context)),
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(
        color: AppTheme.textSecondaryOf(context),
        fontSize: 13,
      ),
      hintStyle: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 12),
      filled: true,
      fillColor: AppTheme.cardSurfaceOf(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.borderOf(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.borderOf(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primaryOf(context), width: 1.5),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Material(
      color: AppTheme.surfaceOf(context),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile.adaptive(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: enabled
              ? AppTheme.textPrimaryOf(context)
              : AppTheme.textMutedOf(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context)),
      ),
      value: value,
      activeTrackColor: AppTheme.primaryOf(context).withValues(alpha: 0.5),
      activeThumbColor: AppTheme.primaryOf(context),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _StorageLegend extends StatelessWidget {
  const _StorageLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}
