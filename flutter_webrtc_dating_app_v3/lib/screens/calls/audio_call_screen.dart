// 📁 lib/screens/calls/audio_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../services/call/call_service.dart';
import '../../core/constants/app_colors.dart';

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
    with TickerProviderStateMixin {
  final CallService _callService = CallService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _durationTimer;
  String _callDuration = '00:00';

  bool _hasRemoteAudio = false;
  bool _isConnecting = true;

  StreamSubscription<DatabaseEvent>? _stateSub;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startDurationTimer();
    _setupAudioStreamListeners();
    _listenRoomState();
  }

  void _listenRoomState() {
    final roomId = _callService.currentCall?.roomId ?? widget.callId;
    _stateSub = FirebaseDatabase.instance
        .ref('rooms/$roomId/state')
        .onValue
        .listen((event) async {
      if (event.snapshot.value == 'ended') {
        await _endCall(silent: true);
      }
    });
  }

  void _setupAnimations() {
    _pulseController =
    AnimationController(duration: const Duration(seconds: 2), vsync: this)
      ..repeat();
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _callDuration = _formatDuration(_callService.callDuration);
      });
    });
  }

  void _setupAudioStreamListeners() {
    _callService.localStream.listen((stream) {
      if (stream != null) {
        final tracks = stream.getAudioTracks();
        if (tracks.isNotEmpty) {
          // mic active
        }
      }
    });

    _callService.remoteStream.listen((stream) {
      if (!mounted) return;
      if (stream != null) {
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
    _stateSub?.cancel();
    // Do not endCall() here (only on red button or remote ended)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = _callService.currentCall;
    final displayName =
    widget.isOutgoing ? (call?.receiverName ?? 'User') : (call?.callerName ?? 'User');
    final avatarUrl = widget.isOutgoing ? call?.receiverAvatar : call?.callerAvatar;

    return Scaffold(
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
                _isConnecting
                    ? 'Connecting...'
                    : (_hasRemoteAudio ? 'Voice Call' : 'Waiting for audio...'),
                style: TextStyle(
                  color:
                  _hasRemoteAudio ? AppColors.purplePrimary : AppColors.hintPurple,
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
              if (_isConnecting)
                Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.purplePrimary),
                    const SizedBox(height: 20),
                    Text(
                      'Establishing connection...',
                      style: TextStyle(color: AppColors.hintPurple, fontSize: 14),
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
                            color: _hasRemoteAudio
                                ? AppColors.purplePrimary
                                : AppColors.hintPurple,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_hasRemoteAudio
                                  ? AppColors.purplePrimary
                                  : AppColors.hintPurple)
                                  .withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 75,
                          backgroundImage:
                          (avatarUrl != null) ? NetworkImage(avatarUrl) : null,
                          backgroundColor: AppColors.purpleSecondary,
                          child: (avatarUrl == null)
                              ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 50,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                              : null,
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
              if (!_isConnecting)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                          _hasRemoteAudio ? Colors.greenAccent : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hasRemoteAudio ? 'Audio Connected' : 'No Audio',
                        style: TextStyle(
                          color: _hasRemoteAudio ? Colors.greenAccent : Colors.orange,
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
                      icon: _callService.isMuted ? Icons.mic_off : Icons.mic,
                      onPressed: () {
                        setState(() => _callService.toggleMute());
                      },
                      backgroundColor:
                      _callService.isMuted ? Colors.white24 : Colors.white12,
                    ),

                    // End call
                    _buildControlButton(
                      icon: Icons.call_end,
                      onPressed: () => _endCall(),
                      backgroundColor: AppColors.dangerRed,
                      size: 70,
                    ),

                    // Speaker
                    _buildControlButton(
                      icon: _callService.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.volume_off,
                      onPressed: () {
                        setState(() => _callService.toggleSpeaker());
                      },
                      backgroundColor:
                      _callService.isSpeakerOn ? Colors.white24 : Colors.white12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 60,
  }) {
    return GestureDetector(
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
    );
  }

  Future<void> _endCall({bool silent = false}) async {
    // ✅ Stop listening before updating DB
    await _stateSub?.cancel();
    _stateSub = null;

    await _callService.endCall();

    if (!mounted) return;

    if (silent) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

}
