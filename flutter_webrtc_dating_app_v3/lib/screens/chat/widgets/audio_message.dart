// lib/screens/chat/widgets/audio_message.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/chat_message_model.dart';
import '../../../services/media/media_url_policy.dart';

class AudioMessage extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const AudioMessage({Key? key, required this.message, required this.isMe})
    : super(key: key);

  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage> {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    // Duration from metadata
    final seconds = widget.message.mediaDuration ?? 0;
    _duration = Duration(seconds: seconds);

    _positionSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = false;
        });
      }
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() => _duration = dur);
      }
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AudioMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.message.id != widget.message.id ||
        oldWidget.message.mediaUrl != widget.message.mediaUrl;
    if (!changed) return;
    // A different (or deleted) recording: drop the old playback state.
    unawaited(_player.stop());
    setState(() {
      _isPlaying = false;
      _isLoading = false;
      _position = Duration.zero;
      _duration = Duration(seconds: widget.message.mediaDuration ?? 0);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = widget.message.mediaUrl;
    if (!MediaUrlPolicy.isAllowed(url)) return;

    setState(() => _isLoading = true);

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_position == Duration.zero) {
          await _player.play(UrlSource(url!));
        } else {
          await _player.resume();
        }
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static const int _barCount = 26;

  /// Stable pseudo-waveform per message (no amplitude data is stored).
  List<double> get _barHeights {
    final rng = math.Random(widget.message.id.hashCode);
    return List.generate(_barCount, (_) => 6 + rng.nextDouble() * 18);
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final playable = MediaUrlPolicy.isAllowed(widget.message.mediaUrl);
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final played = (progress * _barCount).round();

    final Color barOn = isMe ? AppColors.white : AppColors.brandPurpleLight;
    final Color barOff = isMe
        ? AppColors.white.withOpacity(0.4)
        : AppColors.lavender.withOpacity(0.35);
    final Color meta = isMe
        ? AppColors.white.withOpacity(0.85)
        : AppColors.lavender;
    final shown = _isPlaying || _position > Duration.zero
        ? _position
        : _duration;
    final heights = _barHeights;

    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: isMe ? null : AppColors.surface2,
        gradient: isMe ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            enabled: playable,
            label: !playable
                ? 'Voice message unavailable'
                : (_isPlaying ? 'Pause voice message' : 'Play voice message'),
            // excludeSemantics drops the inner tap action, so re-add it.
            onTap: playable ? _togglePlay : null,
            excludeSemantics: true,
            child: Tooltip(
              message: !playable
                  ? 'Voice message unavailable'
                  : (_isPlaying ? 'Pause' : 'Play'),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: playable ? _togglePlay : null,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.white : AppColors.brandPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Opacity(
                        opacity: playable ? 1 : 0.5,
                        child: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(11),
                                child: CircularProgressIndicator(
                                  color: isMe
                                      ? AppColors.brandPurple
                                      : AppColors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                !playable
                                    ? Icons.block
                                    : _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: isMe
                                    ? AppColors.brandPurple
                                    : AppColors.white,
                                size: 26,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ExcludeSemantics(
              child: SizedBox(
                height: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _barCount; i++)
                      Container(
                        width: 3,
                        height: heights[i],
                        decoration: BoxDecoration(
                          color: i < played ? barOn : barOff,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: 'Duration ${_formatDuration(shown)}',
            excludeSemantics: true,
            child: Text(
              _formatDuration(shown),
              style: TextStyle(
                color: meta,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
