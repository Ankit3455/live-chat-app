// 📁 lib/screens/calls/audio_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
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
    with TickerProviderStateMixin, ActiveCallScreenMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    _setupAnimations();
    _startDurationTimer();
    _setupAudioStreamListeners();
    initCallScreen();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    _remoteSub?.cancel();
    disposeCallScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = otherName;
    final avatarUrl = otherAvatar;
    final status = phaseLabel;
    // The remote stream may have arrived before this screen subscribed.
    final linked = phase == CallPhase.active || phase == CallPhase.reconnecting;
    final isConnecting = _isConnecting && !linked;
    final hasRemoteAudio = _hasRemoteAudio || linked;

    return callPopScope(
      child: Scaffold(
        backgroundColor: AppColors.appBackground,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.appBackground, AppColors.inputBackground],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 50),

                // Call status
                Text(
                  status ??
                      (isConnecting
                          ? 'Connecting...'
                          : (hasRemoteAudio
                                ? 'Voice Call'
                                : 'Waiting for audio...')),
                  style: TextStyle(
                    color: hasRemoteAudio
                        ? AppColors.brandPurpleLight
                        : AppColors.hintPurple,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 20),

                // Duration
                Text(
                  _callDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                // Animated avatar / connection indicator
                if (isConnecting)
                  Column(
                    children: [
                      CallAvatar(
                        name: displayName,
                        imageUrl: avatarUrl,
                        radius: 50,
                      ),
                      const SizedBox(height: 20),
                      CircularProgressIndicator(color: AppColors.purplePrimary),
                      const SizedBox(height: 20),
                      Text(
                        status ?? 'Establishing connection...',
                        style: TextStyle(
                          color: AppColors.hintPurple,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                else
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasRemoteAudio
                                  ? AppColors.purplePrimary
                                  : AppColors.hintPurple,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (hasRemoteAudio
                                            ? AppColors.purplePrimary
                                            : AppColors.hintPurple)
                                        .withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: CallAvatar(
                            name: displayName,
                            imageUrl: avatarUrl,
                            radius: 75,
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 30),

                // User name
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Audio status indicator
                if (!isConnecting)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: hasRemoteAudio
                                ? Colors.greenAccent
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasRemoteAudio ? 'Audio Connected' : 'No Audio',
                          style: TextStyle(
                            color: hasRemoteAudio
                                ? Colors.greenAccent
                                : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute
                      _buildControlButton(
                        icon: callService.isMuted ? Icons.mic_off : Icons.mic,
                        label: callService.isMuted ? 'Unmute' : 'Mute',
                        onPressed: () {
                          setState(() => callService.toggleMute());
                        },
                        backgroundColor: callService.isMuted
                            ? Colors.white24
                            : Colors.white12,
                      ),

                      // End call
                      _buildControlButton(
                        icon: Icons.call_end,
                        label: 'End call',
                        onPressed: hangUp,
                        backgroundColor: AppColors.dangerRed,
                        size: 70,
                      ),

                      // Speaker
                      _buildControlButton(
                        icon: callService.isSpeakerOn
                            ? Icons.volume_up
                            : Icons.volume_off,
                        label: callService.isSpeakerOn
                            ? 'Turn speaker off'
                            : 'Turn speaker on',
                        onPressed: () {
                          setState(() => callService.toggleSpeaker());
                        },
                        backgroundColor: callService.isSpeakerOn
                            ? Colors.white24
                            : Colors.white12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 60,
  }) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}
