import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/call_model.dart';
import '../../services/call/call_service.dart';
import '../../core/constants/app_colors.dart';
import 'video_call_screen.dart';
import 'audio_call_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;

  const IncomingCallScreen({Key? key, required this.call}) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  final CallService _callService = CallService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timeoutTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playRingtone();
    _startTimeout();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _playRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
// If you have a file at assets/sounds/incoming_call.mp3:
// await audioPlayer.play(AssetSource('sounds/incoming_call.mp3'));
// Otherwise, do nothing (silent)
    } catch (e) {}
  }

  Future<void> _stopRingtone() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {}
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      _rejectCall();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    _stopRingtone();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _answerCall() async {
    await _stopRingtone();
    _timeoutTimer?.cancel();
    try {
      await _callService.answerCall(widget.call);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => widget.call.type == CallType.video
              ? VideoCallScreen(callId: widget.call.id, isOutgoing: false)
              : AudioCallScreen(callId: widget.call.id, isOutgoing: false),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to answer call: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _rejectCall() async {
    await _stopRingtone();
    _timeoutTimer?.cancel();

    try {
      await _callService.rejectCall(widget.call.id);
    } catch (_) {}

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.call.callerName;
    final isVideo = widget.call.type == CallType.video;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Incoming ${isVideo ? "Video" : "Voice"} Call',
                    style: TextStyle(color: AppColors.hintPurple, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.purplePrimary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.purplePrimary.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: AppColors.purpleSecondary,
                            child: Text(
                              callerName.isNotEmpty
                                  ? callerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 40,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Text(
                    callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'is calling you...',
                    style: TextStyle(
                      color: AppColors.hintPurple,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    onTap: _rejectCall,
                    backgroundColor: AppColors.dangerRed,
                    icon: Icons.call_end,
                    label: 'Decline',
                  ),
                  _buildActionButton(
                    onTap: _answerCall,
                    backgroundColor: AppColors.green500,
                    icon: isVideo ? Icons.videocam : Icons.call,
                    label: 'Accept',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required Color backgroundColor,
    required IconData icon,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 35),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(color: AppColors.hintPurple, fontSize: 14),
        ),
      ],
    );
  }
}