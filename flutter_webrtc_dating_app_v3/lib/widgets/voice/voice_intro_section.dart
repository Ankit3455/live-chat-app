//Settings → Edit Profile me dikhne wala section.
// Shows current status, play/re-record/delete.
//lib/widgets/voice/voice_intro_section.dart

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/voice_intro_service.dart';
import 'voice_record_sheet.dart';

class VoiceIntroSection extends StatefulWidget {
  const VoiceIntroSection({super.key, required this.user});
  final UserModel user;

  @override
  State<VoiceIntroSection> createState() => _VoiceIntroSectionState();
}

class _VoiceIntroSectionState extends State<VoiceIntroSection> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _openRecorder() async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const VoiceRecordSheet(),
    );
    if (res == true && mounted) {
      setState(() {}); // parent screen should refresh user model after save
    }
  }

  Future<void> _play() async {
    final url = widget.user.voiceIntroUrl;
    if (url == null || url.trim().isEmpty) return;
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  Future<void> _delete() async {
    await VoiceIntroService.deleteVoice();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Voice intro removed')));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = (widget.user.voiceIntroUrl != null &&
        widget.user.voiceIntroUrl!.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text("Voice intro",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Text(
          "Let people hear you. A 10–20 second voice intro helps them get to know you faster.",
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
        ),
        const SizedBox(height: 10),
        if (!has)
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _openRecorder,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Record intro'),
              ),
            ],
          )
        else
          // Wrap so the three actions never overflow narrow screens.
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _play,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label:
                    const Text('Play', style: TextStyle(color: Colors.white)),
              ),
              OutlinedButton.icon(
                onPressed: _openRecorder,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Re-record',
                    style: TextStyle(color: Colors.white)),
              ),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                label: const Text('Remove',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
      ],
    );
  }
}
