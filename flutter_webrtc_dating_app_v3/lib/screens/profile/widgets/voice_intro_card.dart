import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/haptics.dart';
import 'package:availchat/services/audio_manager_service.dart';

/// Voice intro player card: play/pause, waveform-style progress, duration.
/// Player logic mirrors the quick sheet's mini player.
class VoiceIntroCard extends StatefulWidget {
  const VoiceIntroCard({super.key, required this.url, this.totalSeconds});

  final String url;
  final int? totalSeconds;

  @override
  State<VoiceIntroCard> createState() => _VoiceIntroCardState();
}

class _VoiceIntroCardState extends State<VoiceIntroCard> {
  // Fixed bar heights (fractions) for the decorative waveform.
  static const List<double> _bars = [
    0.40, 0.70, 0.55, 0.90, 0.60, 0.35, 0.75, 0.50, 0.85, //
    0.40, 0.65, 0.30, 0.55, 0.80, 0.45, 0.60, 0.35, 0.70,
  ];

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final seconds = widget.totalSeconds;
    if (seconds != null && seconds > 0) {
      _duration = Duration(seconds: seconds);
    }
    _subs.add(
      _player.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _duration = d);
      }),
    );
    _subs.add(
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
    );
    _subs.add(
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playing = s == PlayerState.playing);
      }),
    );
    _subs.add(
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _position = Duration.zero;
            _playing = false;
          });
        }
        unawaited(AudioManagerService.setSpeakerphone(false));
      }),
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_player.stop());
    unawaited(_player.dispose());
    unawaited(AudioManagerService.setSpeakerphone(false));
    super.dispose();
  }

  Future<void> _toggle() async {
    Haptics.light();
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      if (_player.state == PlayerState.playing) {
        await _player.pause();
        await AudioManagerService.setSpeakerphone(false);
      } else {
        await AudioManagerService.setCallAudioMode(false);
        await AudioManagerService.setSpeakerphone(true);
        await _player.play(UrlSource(widget.url));
      }
    } catch (_) {
      Haptics.error();
      if (mounted) setState(() => _hasError = true);
      await AudioManagerService.setSpeakerphone(false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final litBars = (progress * _bars.length).round();
    final shown = _playing || _position > Duration.zero ? _position : _duration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Tooltip(
                message: _playing ? 'Pause voice intro' : 'Play voice intro',
                child: Semantics(
                  button: true,
                  label: _playing ? 'Pause voice intro' : 'Play voice intro',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: _isLoading ? null : _toggle,
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Icon(
                              _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.white,
                              size: 26,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 28,
                    child: Row(
                      children: [
                        for (var i = 0; i < _bars.length; i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          Expanded(
                            child: FractionallySizedBox(
                              heightFactor: _bars[i],
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: i < litBars
                                      ? AppColors.pinkLight
                                      : AppColors.brandPurpleLight.withValues(
                                          alpha: 0.45,
                                        ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _fmt(shown),
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          child: _hasError
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    "We couldn't play this voice intro. Tap play to try again.",
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
