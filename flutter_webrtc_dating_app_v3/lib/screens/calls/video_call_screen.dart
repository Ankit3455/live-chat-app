import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

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

  StreamSubscription<MediaStream?>? _localSub;
  StreamSubscription<MediaStream?>? _remoteSub;
  StreamSubscription<DatabaseEvent>? _stateSub;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _listenRoomState();
  }

  Future<void> _initializeRenderers() async {
    // 1) Init renderers
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // 2) Give them to the WebRTC engine (this may attach cached streams immediately)
    await _callService.webrtc.setRenderers(_localRenderer, _remoteRenderer);

    // 3) If WebRTC had already produced streams before this screen opened,
    //    the engine may have just set srcObject. Clear the loader in that case.
    _markConnectedIfRendered();

    // 4) Normal listeners for future updates
    _localSub = _callService.localStream.listen((stream) {
      if (!mounted) return;
      // renderer is already hooked inside the engine; no UI action needed
      setState(() {}); // force mini preview repaint if needed
    });

    _remoteSub = _callService.remoteStream.listen((stream) {
      if (!mounted) return;
      if (stream != null) {
        setState(() => _isConnecting = false);
      }
    });

    // 5) Small retry loop to handle any race where srcObject arrives between steps
    //    (no-ops if already attached)
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      if (_remoteRenderer.srcObject != null) {
        setState(() => _isConnecting = false);
        break;
      }
    }
  }

  /// If the engine attached streams before we subscribed, srcObject will be non-null.
  void _markConnectedIfRendered() {
    try {
      if (_remoteRenderer.srcObject != null) {
        _isConnecting = false;
      }
    } catch (_) {
      // renderer may be in an intermediate state; ignore
    }
    setState(() {});
  }

  void _listenRoomState() {
    // Prefer current call's roomId if available
    final roomId = _callService.currentCall?.roomId ?? widget.callId;
    _stateSub = FirebaseDatabase.instance
        .ref('rooms/$roomId/state')
        .onValue
        .listen((event) async {
      if (event.snapshot.value == 'ended') {
        await _endCall(silent: true);
      }
    }, onError: (e) {
      // Avoid crashes on RTDB permission blips during teardown
      debugPrint('⚠️ room state listener error: $e');
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _localSub?.cancel();
    _remoteSub?.cancel();
    // Only dispose renderers. Call teardown is driven by the red button / remote state.
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
                CircularProgressIndicator(color: AppColors.purplePrimary),
                const SizedBox(height: 20),
                const Text(
                  'Connecting...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            )
                : RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // Local video (PIP)
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
                child: _localRenderer.srcObject == null
                    ? const ColoredBox(color: Colors.black)
                    : RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit:
                  RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
            _callService.currentCall?.receiverName ??
                _callService.currentCall?.callerName ??
                'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_callService.callDuration),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
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
          icon:
          _callService.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
          onPressed: () {
            setState(() => _callService.toggleVideo());
          },
          backgroundColor: Colors.white24,
        ),

        // Mute
        _buildControlButton(
          icon: _callService.isMuted ? Icons.mic_off : Icons.mic,
          onPressed: () {
            setState(() => _callService.toggleMute());
          },
          backgroundColor: Colors.white24,
        ),

        // End call
        _buildControlButton(
          icon: Icons.call_end,
          onPressed: () => _endCall(),
          backgroundColor: Colors.red,
          size: 70,
        ),

        // Switch camera
        _buildControlButton(
          icon: Icons.cameraswitch,
          onPressed: () async => _callService.switchCamera(),
          backgroundColor: Colors.white24,
        ),

        // Speaker
        _buildControlButton(
          icon: _callService.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          onPressed: () {
            setState(() => _callService.toggleSpeaker());
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
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _endCall({bool silent = false}) async {
    // Cancel state listener first (prevents races / permission errors on teardown)
    await _stateSub?.cancel();
    _stateSub = null;

    await _callService.endCall();

    if (!mounted) return;

    if (silent) {
      if (Navigator.canPop(context)) Navigator.pop(context);
    } else {
      Navigator.pop(context);
    }
  }
}