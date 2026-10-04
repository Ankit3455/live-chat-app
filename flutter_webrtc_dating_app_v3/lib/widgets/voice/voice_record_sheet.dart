// lib/widgets/voice/voice_record_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/voice_intro_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';

class VoiceRecordSheet extends StatefulWidget {
  const VoiceRecordSheet({super.key});

  @override
  State<VoiceRecordSheet> createState() => _VoiceRecordSheetState();
}

class _VoiceRecordSheetState extends State<VoiceRecordSheet> {
  String? _tempPath;
  int _elapsed = 0;
  Timer? _timer;
  bool _recording = false;
  bool _saving = false;

  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await VoiceIntroService.hasMicPermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Allow microphone access in Settings to record a voice intro.')),
        );
      }
      return;
    }
    final p = await VoiceIntroService.startRecording();
    if (p == null) return;

    setState(() {
      _tempPath = p;
      _elapsed = 0;
      _recording = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_elapsed >= VoiceIntroService.kMaxSeconds) {
        await _stop();
        return;
      }
      setState(() => _elapsed++);
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await VoiceIntroService.stopRecording(tempPath: _tempPath!);
    setState(() => _recording = false);
  }

  Future<void> _playPreview() async {
    if (_tempPath == null) return;
    await _player.stop();
    await _player.play(DeviceFileSource(_tempPath!));
  }

  Future<void> _save() async {
    if (_tempPath == null) return;
    setState(() => _saving = true);
    try {
      final res = await VoiceIntroService.uploadAndSave(
        localPath: _tempPath!,
        durationSeconds: _elapsed,
      );
      if (res != null && mounted) {
        Haptics.success();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice intro saved')),
        );
      }
    } catch (_) {
      if (mounted) {
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't save your voice intro. Check your connection and try again.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    _timer?.cancel();
    setState(() {
      _tempPath = null;
      _elapsed = 0;
      _recording = false;
    });
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.borderStrong, width: 0.5),
      ),
      child: SafeArea(
        top: false,
        // Scrolls in landscape / large text.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: const Text(
                  "Add a short voice intro",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "A voice intro lets people hear your tone and energy before you chat.\nKeep it friendly and real — up to 20 seconds.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
              const SizedBox(height: 16),

              // Timer
              Text(
                _fmt(
                    _recording ? _elapsed : (_tempPath != null ? _elapsed : 0)),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              // Big button area
              if (_recording) ...[
                ElevatedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error),
                ),
              ] else if (_tempPath == null) ...[
                ElevatedButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Start recording'),
                ),
              ] else ...[
                // Wrap so large text never overflows.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _playPreview,
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white),
                      label: const Text('Preview',
                          style: TextStyle(color: Colors.white)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _discard,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                      label: const Text('Re-record',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
              ],

              const SizedBox(height: 8),
              const Text(
                "Tip: speak clearly, smile while you talk, and share one or two things you love.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSubtle, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
