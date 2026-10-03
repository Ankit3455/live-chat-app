// lib/widgets/voice/voice_record_sheet.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/voice_intro_service.dart';
import '../../core/constants/app_colors.dart';

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
          const SnackBar(content: Text('Microphone permission required')),
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
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice intro saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
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
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            const Text(
              "Add a short voice intro",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              "Why voice? It helps others feel your vibe quickly — tone, energy, confidence.\nKeep it friendly and real. Max 20 seconds.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            const SizedBox(height: 16),

            // Timer
            Text(
              _fmt(_recording ? _elapsed : (_tempPath != null ? _elapsed : 0)),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            // Big button area
            if (_recording) ...[
              ElevatedButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ] else if (_tempPath == null) ...[
              ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Start Recording'),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _playPreview,
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    label: const Text('Preview', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _discard,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: const Text('Re-record', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('Save'),
              ),
            ],

            const SizedBox(height: 8),
            const Text(
              "Tips: Speak clearly, smile while you talk. Share 1–2 things you love.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
