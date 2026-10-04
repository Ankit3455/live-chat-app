import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import 'widgets/call_controls.dart';
import 'widgets/call_ui.dart';

class AudioCallScreen extends StatefulWidget {
  final String callId;
  final bool isOutgoing;

  const AudioCallScreen({
    Key? key,
    required this.callId,
    required this.isOutgoing,
  }) : super(key: key);

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen>
    with ActiveCallScreenMixin {
  Timer? _durationTimer;
  String _callDuration = '00:00';

  bool _hasRemoteAudio = false;
  bool _isConnecting = true;

  StreamSubscription<MediaStream?>? _remoteSub;

  @override
  String get callId => widget.callId;

  @override
  bool get isOutgoingCall => widget.isOutgoing;

  @override
  void initState() {
    super.initState();
    _startDurationTimer();
    _setupAudioStreamListeners();
    initCallScreen();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _callDuration = _formatDuration(callService.callDuration);
      });
    });
  }

  void _setupAudioStreamListeners() {
    _remoteSub = callService.remoteStream.listen((stream) {
      if (!mounted || stream == null) return;
      final audioTracks = stream.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        for (var t in audioTracks) {
          if (!t.enabled) t.enabled = true;
        }
        setState(() {
          _hasRemoteAudio = true;
          _isConnecting = false;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // toggleSpeaker is async; repaint once the route has switched.
  Future<void> _toggleSpeaker() async {
    await callService.toggleSpeaker();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _remoteSub?.cancel();
    disposeCallScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ended = buildEndedView(isVideo: false);
    if (ended != null) return callPopScope(child: ended);

    final displayName = otherName;
    final status = phaseLabel;
    // The remote stream may have arrived before this screen subscribed.
    final linked = phase == CallPhase.active || phase == CallPhase.reconnecting;
    final isConnecting = _isConnecting && !linked;
    final hasRemoteAudio = _hasRemoteAudio || linked;

    final String chipLabel;
    final CallStatusTone chipTone;
    if (phase == CallPhase.reconnecting) {
      chipLabel = status ?? 'Reconnecting…';
      chipTone = CallStatusTone.warning;
    } else if (status != null || isConnecting) {
      chipLabel = status ?? 'Connecting…';
      chipTone = CallStatusTone.pending;
    } else if (hasRemoteAudio) {
      chipLabel = 'Connected';
      chipTone = CallStatusTone.ok;
    } else {
      chipLabel = 'Waiting for audio…';
      chipTone = CallStatusTone.warning;
    }

    final muted = callService.isMuted;
    final speakerOn = callService.isSpeakerOn;

    return callPopScope(
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: CallBackdrop(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 56,
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Back (asks to end the call)',
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: AppColors.white,
                                  ),
                                ),
                                Expanded(
                                  child: Semantics(
                                    header: true,
                                    child: const Text(
                                      'Voice call',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.lavender,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          CallHalo(
                            muted: !hasRemoteAudio,
                            avatar: CallAvatar(
                              name: displayName,
                              imageUrl: otherAvatar,
                              radius: 70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: callNameStyle(),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            label: 'Call duration $_callDuration',
                            excludeSemantics: true,
                            child: Text(
                              _callDuration,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CallStatusChip(label: chipLabel, tone: chipTone),
                          const Spacer(),
                          CallControlRow(
                            children: [
                              CallControlButton(
                                icon: muted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                label: muted ? 'Muted' : 'Mute',
                                tooltip: muted ? 'Unmute' : 'Mute',
                                toggled: muted,
                                onPressed: () {
                                  setState(() => callService.toggleMute());
                                },
                              ),
                              CallControlButton.end(onPressed: hangUp),
                              CallControlButton(
                                icon: speakerOn
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_down_rounded,
                                label: 'Speaker',
                                tooltip: speakerOn
                                    ? 'Turn speaker off'
                                    : 'Turn speaker on',
                                toggled: speakerOn,
                                onPressed: _toggleSpeaker,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
