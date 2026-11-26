import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../controllers/music_player_controller.dart';
import '../models/song_model.dart';

/// Per-song lyrics calibration.
///
/// LRC timestamps are authored against the studio master; the audio actually
/// reaching the speakers is delayed by the output buffer, which differs per
/// device (Windows, Android, browser). This dialog lets the listener nudge the
/// highlight in 50 ms steps and persists the value per track.
class LyricsSyncDialog extends StatefulWidget {
  final Song song;
  final MusicPlayerController controller;

  const LyricsSyncDialog({
    super.key,
    required this.song,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required Song song,
    required MusicPlayerController controller,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => LyricsSyncDialog(song: song, controller: controller),
    );
  }

  @override
  State<LyricsSyncDialog> createState() => _LyricsSyncDialogState();
}

class _LyricsSyncDialogState extends State<LyricsSyncDialog> {
  /// Follows the controller's persisted clamp so the dialog can never offer a
  /// range the player refuses to store.
  static final double _maxMs =
      MusicPlayerController.lyricsOffsetLimit.inMilliseconds.toDouble();
  static const double _stepMs = 50;

  late double _offsetMs;

  @override
  void initState() {
    super.initState();
    _offsetMs =
        widget.controller.lyricsOffsetMsFor(widget.song).toDouble();
  }

  void _apply(double valueMs) {
    final clamped = valueMs.clamp(-_maxMs, _maxMs).toDouble();
    setState(() => _offsetMs = clamped);
    unawaited(
      widget.controller.setLyricsOffset(
        widget.song,
        Duration(milliseconds: clamped.round()),
      ),
    );
  }

  void _nudge(double deltaMs) {
    final next = ((_offsetMs + deltaMs) / _stepMs).round() * _stepMs;
    _apply(next);
  }

  String get _label {
    if (_offsetMs == 0) return 'Automatic';
    final sign = _offsetMs > 0 ? '+' : '−';
    final seconds = (_offsetMs.abs() / 1000).toStringAsFixed(2);
    return '$sign${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF16181F);
    const muted = Color(0xFF9CA3AF);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Lyrics sync',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _offsetMs == 0
                        ? muted
                        : const Color(0xFF6EE7B7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.song.title} · ${widget.song.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 18),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14,
                ),
              ),
              child: Slider(
                value: _offsetMs,
                min: -_maxMs,
                max: _maxMs,
                divisions: (_maxMs * 2 / _stepMs).round(),
                onChanged: _apply,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Lyrics later',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  Text(
                    'Lyrics earlier',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _NudgeButton(
                  label: '−0.5s',
                  onTap: () => _nudge(-500),
                ),
                const SizedBox(width: 8),
                _NudgeButton(label: '−50ms', onTap: () => _nudge(-_stepMs)),
                const Spacer(),
                _NudgeButton(
                  label: 'Reset',
                  onTap: () => _apply(0),
                  emphasized: _offsetMs != 0,
                ),
                const Spacer(),
                _NudgeButton(label: '+50ms', onTap: () => _nudge(_stepMs)),
                const SizedBox(width: 8),
                _NudgeButton(label: '+0.5s', onTap: () => _nudge(500)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  const _NudgeButton({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: emphasized
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
