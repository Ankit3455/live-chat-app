// lib/screens/chat/widgets/audio_message.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/chat_message_model.dart';
import '../../../services/media/media_url_policy.dart';

class AudioMessage extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const AudioMessage({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

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
    final changed = oldWidget.message.id != widget.message.id ||
        oldWidget.message.mediaUrl != widget.message.mediaUrl;
    if (!changed) return;
    // A different (or deleted) recording: drop the old playback state.
    _player.stop();
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

  @override
  Widget build(BuildContext context) {
    final playable = MediaUrlPolicy.isAllowed(widget.message.mediaUrl);
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMe
            ? AppColors.purplePrimary.withOpacity(0.3)
            : AppColors.inputBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purplePrimary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Play/Pause Button
          GestureDetector(
            onTap: playable ? _togglePlay : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: playable
                    ? AppColors.purplePrimary
                    : AppColors.purplePrimary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Icon(
                !playable
                    ? Icons.block
                    : _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Progress & Duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.purplePrimary,
                    ),
                    minHeight: 4,
                  ),
                ),

                const SizedBox(height: 6),

                // Duration text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Mic icon
          Icon(
            Icons.mic_rounded,
            color: AppColors.purplePrimary.withOpacity(0.6),
            size: 18,
          ),
        ],
      ),
    );
  }
}