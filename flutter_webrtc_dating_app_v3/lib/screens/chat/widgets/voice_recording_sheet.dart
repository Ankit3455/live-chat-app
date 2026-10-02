// lib/screens/chat/widgets/voice_recording_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/media/chat_media_service.dart';

class VoiceRecordingSheet extends StatefulWidget {
  final Function(String path, int duration) onSend;
  final VoidCallback onCancel;

  const VoiceRecordingSheet({
    Key? key,
    required this.onSend,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<VoiceRecordingSheet> {
  bool _isRecording = false;
  String? _recordingPath;
  int _elapsed = 0;
  Timer? _timer;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await ChatMediaService.hasMicrophonePermission();
    if (!hasPermission) {
      setState(() => _hasError = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onCancel();
      });
      return;
    }

    final path = await ChatMediaService.startVoiceRecording();
    if (path == null) {
      setState(() => _hasError = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onCancel();
      });
      return;
    }

    setState(() {
      _recordingPath = path;
      _isRecording = true;
      _elapsed = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_elapsed >= ChatMediaService.kMaxVoiceDuration) {
        _stopAndSend();
        return;
      }
      if (mounted) setState(() => _elapsed++);
    });
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();

    if (_recordingPath == null || _elapsed < 1) {
      await ChatMediaService.cancelVoiceRecording();
      widget.onCancel();
      return;
    }

    final path = await ChatMediaService.stopVoiceRecording();
    if (path == null) {
      widget.onCancel();
      return;
    }

    widget.onSend(path, _elapsed);
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await ChatMediaService.cancelVoiceRecording();
    widget.onCancel();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_off, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Microphone permission required',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Please enable microphone access in settings',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recording indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RecordingDot(),
                const SizedBox(width: 10),
                const Text(
                  'Recording...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Timer
            Text(
              _formatDuration(_elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Max ${ChatMediaService.kMaxVoiceDuration} seconds',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 30),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                GestureDetector(
                  onTap: _cancel,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ),

                // Send button
                GestureDetector(
                  onTap: _elapsed >= 1 ? _stopAndSend : null,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _elapsed >= 1
                          ? AppColors.purplePrimary
                          : AppColors.purplePrimary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Animated recording dot
class _RecordingDot extends StatefulWidget {
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.5 + (_controller.value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}