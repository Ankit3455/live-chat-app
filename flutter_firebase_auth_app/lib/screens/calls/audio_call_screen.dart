import 'package:flutter/material.dart';
import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startDurationTimer();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration = _formatDuration(_callService.callDuration);
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = _callService.currentCall;
    final displayName = widget.isOutgoing
        ? call?.receiverName ?? 'User'
        : call?.callerName ?? 'User';
    final avatarUrl = widget.isOutgoing
        ? call?.receiverAvatar
        : call?.callerAvatar;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.appBackground,
              AppColors.inputBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 50),

              // Call status
              Text(
                widget.isOutgoing && _callService.callDuration == 0
                    ? 'Calling...'
                    : 'Voice Call',
                style: TextStyle(
                  color: AppColors.hintPurple,
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

              // Animated avatar
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
                          color: AppColors.purplePrimary,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purplePrimary.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 75,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        backgroundColor: AppColors.purpleSecondary,
                        child: avatarUrl == null
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

              const Spacer(),

              // Call controls
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    _buildControlButton(
                      icon: _callService.isMuted ? Icons.mic_off : Icons.mic,
                      onPressed: () {
                        setState(() {
                          _callService.toggleMute();
                        });
                      },
                      backgroundColor: _callService.isMuted
                          ? Colors.white24
                          : Colors.white12,
                    ),

                    // End call button
                    _buildControlButton(
                      icon: Icons.call_end,
                      onPressed: _endCall,
                      backgroundColor: AppColors.dangerRed,
                      size: 70,
                    ),

                    // Speaker button
                    _buildControlButton(
                      icon: _callService.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.volume_off,
                      onPressed: () {
                        setState(() {
                          _callService.toggleSpeaker();
                        });
                      },
                      backgroundColor: _callService.isSpeakerOn
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
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }

  Future<void> _endCall() async {
    await _callService.endCall();
    if (!mounted) return;
    Navigator.pop(context);
  }
}