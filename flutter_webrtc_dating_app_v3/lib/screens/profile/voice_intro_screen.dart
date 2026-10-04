import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../services/voice_intro_service.dart';
import '../../widgets/custom_button.dart';
import '../questionnaire/widgets/progress_header.dart';

/// Last onboarding step: record, preview and save a short voice intro.
/// Pops `true` when a voice intro is saved, `false` on skip/back.
class VoiceIntroScreen extends StatefulWidget {
  const VoiceIntroScreen({super.key});

  @override
  State<VoiceIntroScreen> createState() => _VoiceIntroScreenState();
}

class _VoiceIntroScreenState extends State<VoiceIntroScreen>
    with SingleTickerProviderStateMixin {
  static const _prompts = [
    '😂 What makes you laugh?',
    '☀️ Your perfect Sunday',
    '🔮 Why astrology?',
  ];

  final AudioPlayer _player = AudioPlayer();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  String? _tempPath;
  String? _prompt;
  int _elapsed = 0;
  Timer? _timer;
  bool _recording = false;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _timer?.cancel();
    final path = _tempPath;
    if (_recording && path != null) {
      unawaited(VoiceIntroService.stopRecording(tempPath: path));
    }
    _pulse.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await VoiceIntroService.hasMicPermission();
    if (!ok) {
      Haptics.error();
      _snack('Allow microphone access in your phone settings to record.');
      return;
    }
    final p = await VoiceIntroService.startRecording();
    if (p == null || !mounted) return;

    Haptics.light();
    setState(() {
      _tempPath = p;
      _elapsed = 0;
      _recording = true;
    });
    if (!MediaQuery.of(context).disableAnimations) {
      unawaited(_pulse.repeat());
    }

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
    _pulse.stop();
    final path = _tempPath;
    if (path != null) await VoiceIntroService.stopRecording(tempPath: path);
    if (!mounted) return;
    Haptics.light();
    setState(() => _recording = false);
  }

  Future<void> _playPreview() async {
    final path = _tempPath;
    if (path == null) return;
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  Future<void> _save() async {
    final path = _tempPath;
    if (path == null || _saving || _saved) return;
    setState(() => _saving = true);
    try {
      final res = await VoiceIntroService.uploadAndSave(
        localPath: path,
        durationSeconds: _elapsed,
      );
      if (!mounted) return;
      if (res == null) {
        Haptics.error();
        _snack(
          'We couldn\'t save your voice intro. Check your connection and try again.',
        );
        return;
      }
      Haptics.success();
      _snack('Voice intro saved');
      // Brief success state on the button before going back.
      setState(() {
        _saving = false;
        _saved = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Voice intro save failed: $e');
      Haptics.error();
      _snack(
        'We couldn\'t save your voice intro. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    _timer?.cancel();
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _tempPath = null;
      _elapsed = 0;
      _recording = false;
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static String _fmt(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasClip = _tempPath != null && !_recording;

    return PopScope(
      canPop: !_saving && !_saved,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  ProgressHeader(
                    currentStep: 1,
                    totalSteps: 1,
                    stepLabel: 'Last step',
                    onBack: _saving || _saved
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LAST STEP',
                            style: TextStyle(
                              color: AppColors.pinkLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            header: true,
                            child: Text(
                              'Add a voice intro',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Say hi in up to ${VoiceIntroService.kMaxSeconds} '
                            'seconds. People hear it on your profile.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Need an idea? Pick a prompt',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final p in _prompts) _promptChip(p),
                            ],
                          ),
                          const SizedBox(height: 32),
                          AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            child: hasClip
                                ? KeyedSubtree(
                                    key: const ValueKey('voice-preview'),
                                    child: _previewCard(),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('voice-recorder'),
                                    child: _recorder(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasClip) ...[
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: 'Re-record',
                                  type: ButtonType.outline,
                                  leftIcon: Icons.mic_rounded,
                                  onPressed:
                                      _saving || _saved ? null : _discard,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomButton(
                                  text: 'Save',
                                  onPressed: _save,
                                  isLoading: _saving,
                                  isSuccess: _saved,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        CustomButton(
                          text: 'Skip for now',
                          type: ButtonType.text,
                          onPressed: _saving || _saved || _recording
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _togglePrompt(String text) {
    Haptics.selection();
    setState(() => _prompt = _prompt == text ? null : text);
  }

  // Visual suggestion only; selecting one just highlights it.
  Widget _promptChip(String text) {
    final selected = _prompt == text;
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      excludeSemantics: true,
      onTap: () => _togglePrompt(text),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _togglePrompt(text),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.brandPurpleMid.withOpacity(0.18)
                  : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.brandPurpleMid : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: selected
                          ? AppColors.brandPurpleLight
                          : AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recorder() {
    return Center(
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_recording) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  _fmt(_elapsed),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Up to ${_fmt(VoiceIntroService.kMaxSeconds)}',
            style: const TextStyle(color: AppColors.textSubtle, fontSize: 12),
          ),
          const SizedBox(height: 24),
          _recordButton(),
          const SizedBox(height: 20),
          Text(
            _recording ? 'Recording… tap to stop' : 'Tap to record',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordButton() {
    final recording = _recording;
    final button = Tooltip(
      message: recording ? 'Stop recording' : 'Start recording',
      child: Semantics(
        button: true,
        label: recording ? 'Recording. Tap to stop' : 'Start recording',
        excludeSemantics: true,
        onTap: recording ? _stop : _start,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPink.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: recording ? _stop : _start,
                child: Icon(
                  recording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 40,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Pulse ring only while recording.
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (recording)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value;
                return Transform.scale(
                  scale: 1 + 0.3 * t,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brandPink.withOpacity(0.45 * (1 - t)),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
          button,
        ],
      ),
    );
  }

  Widget _previewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            child: Tooltip(
              message: 'Play preview',
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _playPreview,
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 28,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your voice intro',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(_elapsed)} · Have a listen before you save',
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
