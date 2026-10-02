import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/call/call_service.dart';
import '../../core/constants/app_colors.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final bool isOutgoing;

  const VideoCallScreen({
    Key? key,
    required this.callId,
    required this.isOutgoing,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // Listen to streams
    _callService.localStream.listen((stream) {
      if (stream != null) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      }
    });

    _callService.remoteStream.listen((stream) {
      if (stream != null) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isConnecting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          Center(
            child: _isConnecting
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppColors.purplePrimary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Connecting...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            )
                : RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // Local video (small window)
          Positioned(
            top: 100,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

          // Call controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildCallControls(),
          ),

          // Call info
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: _buildCallInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallInfo() {
    return SafeArea(
      child: Column(
        children: [
          Text(
            _callService.currentCall?.receiverName ?? 'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_callService.callDuration),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Toggle camera
        _buildControlButton(
          icon: _callService.isVideoEnabled
              ? Icons.videocam
              : Icons.videocam_off,
          onPressed: () {
            setState(() {
              _callService.toggleVideo();
            });
          },
          backgroundColor: Colors.white24,
        ),

        // Toggle mute
        _buildControlButton(
          icon: _callService.isMuted ? Icons.mic_off : Icons.mic,
          onPressed: () {
            setState(() {
              _callService.toggleMute();
            });
          },
          backgroundColor: Colors.white24,
        ),

        // End call
        _buildControlButton(
          icon: Icons.call_end,
          onPressed: _endCall,
          backgroundColor: Colors.red,
          size: 70,
        ),

        // Switch camera
        _buildControlButton(
          icon: Icons.cameraswitch,
          onPressed: () async {
            await _callService.switchCamera();
          },
          backgroundColor: Colors.white24,
        ),

        // Toggle speaker
        _buildControlButton(
          icon: _callService.isSpeakerOn
              ? Icons.volume_up
              : Icons.volume_off,
          onPressed: () {
            setState(() {
              _callService.toggleSpeaker();
            });
          },
          backgroundColor: Colors.white24,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 60,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _endCall() async {
    await _callService.endCall();
    Navigator.pop(context);
  }
}