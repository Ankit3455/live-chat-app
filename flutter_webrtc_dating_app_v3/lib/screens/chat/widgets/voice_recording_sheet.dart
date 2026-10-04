// lib/screens/chat/widgets/voice_recording_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/media/chat_media_service.dart';
import '../../../services/media/media_validator.dart';

/// Result of [VoiceRecordingSheet]: a finished local recording.
class VoiceRecordingResult {
  final String path;
  final int durationSeconds;

  const VoiceRecordingResult(this.path, this.durationSeconds);
}

/// Records a voice note. Pops itself with a [VoiceRecordingResult] on send,
/// or null when cancelled. The recorder never outlives the sheet.
///
///   final result = await showModalBottomSheet<VoiceRecordingResult>(
///       context: context, builder: (_) => const VoiceRecordingSheet());
class VoiceRecordingSheet extends StatefulWidget {
  const VoiceRecordingSheet({Key? key}) : super(key: key);

  @override
  State<VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<VoiceRecordingSheet> {
  static const int _maxSeconds = MediaValidator.maxVoiceSeconds;

  bool _isRecording = false;
  String? _recordingPath;
  int _elapsed = 0;
  Timer? _timer;
  bool _hasError = false;
  bool _permissionDenied = false;

  /// Set once stop/send or cancel starts, so a double tap does nothing.
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Closed by the system (route removed) while still recording.
    if (_isRecording && !_finishing) {
      ChatMediaService.cancelVoiceRecording();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await ChatMediaService.hasMicrophonePermission();
    if (!mounted) return;
    if (!hasPermission) {
      setState(() {
        _hasError = true;
        _permissionDenied = true;
      });
      return;
    }

    final path = await ChatMediaService.startVoiceRecording();
    if (!mounted || _finishing) {
      // The sheet closed while the recorder was starting.
      if (path != null) await ChatMediaService.cancelVoiceRecording();
      return;
    }
    if (path == null) {
      setState(() => _hasError = true);
      return;
    }

    setState(() {
      _recordingPath = path;
      _isRecording = true;
      _elapsed = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_elapsed + 1 >= _maxSeconds) {
        setState(() => _elapsed = _maxSeconds);
        _stopAndSend();
        return;
      }
      setState(() => _elapsed++);
    });
  }

  void _close([VoiceRecordingResult? result]) {
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _stopAndSend() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();

    if (_recordingPath == null || _elapsed < 1) {
      await ChatMediaService.cancelVoiceRecording();
      _isRecording = false;
      _close();
      return;
    }

    final duration = _elapsed;
    final path = await ChatMediaService.stopVoiceRecording();
    _isRecording = false;
    _close(path == null ? null : VoiceRecordingResult(path, duration));
  }

  Future<void> _cancel() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    if (_isRecording) {
      await ChatMediaService.cancelVoiceRecording();
      _isRecording = false;
    }
    _close();
  }

  Future<void> _confirmDiscard() async {
    if (_finishing) return;
    if (!_isRecording) {
      await _cancel();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: const Text(
          'Discard voice message?',
          style: TextStyle(color: AppColors.inputTextWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Keep recording',
              style: TextStyle(color: AppColors.hintPurple),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );
    if (discard == true) await _cancel();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: _hasError ? _buildError() : _buildRecorder(),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        // Scrolls in landscape, where the sheet is short.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_off, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _permissionDenied
                    ? 'Microphone permission required'
                    : 'Could not start recording',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _permissionDenied
                    ? 'Please enable microphone access in settings'
                    : 'Please try again',
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: _cancel,
                    child: const Text(
                      'Close',
                      style: TextStyle(color: AppColors.hintPurple),
                    ),
                  ),
                  if (_permissionDenied)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purplePrimary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await openAppSettings();
                        await _cancel();
                      },
                      child: const Text('Open Settings'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecorder() {
    final canSend = _isRecording && _elapsed >= 1 && !_finishing;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        // Scrolls in landscape, where the sheet is short.
        child: SingleChildScrollView(
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
                'Max ${_formatDuration(_maxSeconds)}',
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 30),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  Semantics(
                    button: true,
                    enabled: !_finishing,
                    label: 'Cancel recording',
                    child: GestureDetector(
                      onTap: _finishing ? null : _cancel,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.error, width: 2),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.error,
                          size: 30,
                        ),
                      ),
                    ),
                  ),

                  // Send button
                  Semantics(
                    button: true,
                    enabled: canSend,
                    label: 'Send voice message',
                    child: GestureDetector(
                      onTap: canSend ? _stopAndSend : null,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: canSend
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
                  ),
                ],
              ),
            ],
          ),
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
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: solid dot, no pulse.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1.0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
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
            color: AppColors.error.withOpacity(0.5 + (_controller.value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
