import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import 'widgets/call_ui.dart';

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

class _VideoCallScreenState extends State<VideoCallScreen>
    with ActiveCallScreenMixin {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isConnecting = true;
  bool _renderersReady = false;

  StreamSubscription<MediaStream?>? _localSub;
  StreamSubscription<MediaStream?>? _remoteSub;
  Timer? _durationTimer;

  @override
  String get callId => widget.callId;

  @override
  bool get isOutgoingCall => widget.isOutgoing;

  @override
  void initState() {
    super.initState();
    initCallScreen();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;
    _renderersReady = true;

    // Attaches already-produced streams immediately.
    await callService.webrtc.setRenderers(_localRenderer, _remoteRenderer);
    if (!mounted) return;
    _markConnectedIfRendered();

    _localSub = callService.localStream.listen((stream) {
      if (!mounted) return;
      setState(() {}); // repaint the mini preview
    });

    _remoteSub = callService.remoteStream.listen((stream) {
      if (!mounted) return;
      if (stream != null) {
        setState(() => _isConnecting = false);
      }
    });

    // Covers srcObject arriving between the steps above.
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      if (_remoteRenderer.srcObject != null) {
        setState(() => _isConnecting = false);
        break;
      }
    }
  }

  /// If the engine attached streams before we subscribed, srcObject is set.
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

  @override
  void dispose() {
    _durationTimer?.cancel();
    _localSub?.cancel();
    _remoteSub?.cancel();
    disposeCallScreen();
    if (_renderersReady) {
      try {
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
      } catch (_) {}
    }
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = phaseLabel;
    final linked = phase == CallPhase.active || phase == CallPhase.reconnecting;
    final showRemote = _renderersReady && (!_isConnecting || linked);

    return callPopScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Remote video (full screen)
            Center(
              child: !showRemote
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CallAvatar(
                          name: otherName,
                          imageUrl: otherAvatar,
                          radius: 50,
                        ),
                        const SizedBox(height: 20),
                        CircularProgressIndicator(
                          color: AppColors.purplePrimary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          status ?? 'Connecting...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    )
                  : RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                  child: !_renderersReady || _localRenderer.srcObject == null
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
              child: _buildCallInfo(status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallInfo(String? status) {
    return SafeArea(
      child: Column(
        children: [
          Text(
            otherName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status ?? _formatDuration(callService.callDuration),
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
          icon: callService.isVideoEnabled
              ? Icons.videocam
              : Icons.videocam_off,
          tooltip: callService.isVideoEnabled
              ? 'Turn camera off'
              : 'Turn camera on',
          onPressed: () {
            setState(() => callService.toggleVideo());
          },
          backgroundColor: Colors.white24,
        ),

        // Mute
        _buildControlButton(
          icon: callService.isMuted ? Icons.mic_off : Icons.mic,
          tooltip: callService.isMuted ? 'Unmute' : 'Mute',
          onPressed: () {
            setState(() => callService.toggleMute());
          },
          backgroundColor: Colors.white24,
        ),

        // End call
        _buildControlButton(
          icon: Icons.call_end,
          tooltip: 'End call',
          onPressed: hangUp,
          backgroundColor: Colors.red,
          size: 70,
        ),

        // Switch camera
        _buildControlButton(
          icon: Icons.cameraswitch,
          tooltip: 'Switch camera',
          onPressed: () async => callService.switchCamera(),
          backgroundColor: Colors.white24,
        ),

        // Speaker
        _buildControlButton(
          icon: callService.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          tooltip: callService.isSpeakerOn
              ? 'Turn speaker off'
              : 'Turn speaker on',
          onPressed: () {
            setState(() => callService.toggleSpeaker());
          },
          backgroundColor: Colors.white24,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
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
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
