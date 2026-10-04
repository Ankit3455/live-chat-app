import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../widgets/app_states.dart';
import 'widgets/call_controls.dart';
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

  // toggleSpeaker is async; repaint once the route has switched.
  Future<void> _toggleSpeaker() async {
    await callService.toggleSpeaker();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ended = buildEndedView(isVideo: true);
    if (ended != null) return callPopScope(child: ended);

    final status = phaseLabel;
    final linked = phase == CallPhase.active || phase == CallPhase.reconnecting;
    final showRemote = _renderersReady && (!_isConnecting || linked);
    final reconnecting = phase == CallPhase.reconnecting;

    return callPopScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Remote video (full screen); blurred while reconnecting.
            if (showRemote)
              ImageFiltered(
                enabled: reconnecting,
                imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              CallBackdrop(child: _buildWaiting(status)),

            // Top and bottom scrims keep the overlays readable.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0),
                      Colors.black.withOpacity(0),
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0, 0.26, 0.62, 1],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(status),
                        if (reconnecting)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              _previewSize.width + 32,
                              0,
                            ),
                            child: _buildReconnectingBanner(),
                          ),
                      ],
                    ),
                  ),
                  Positioned(top: 64, right: 16, child: _buildLocalPreview()),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 24,
                    child: _buildCallControls(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiting(String? status) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CallHalo(
            muted: true,
            avatar: CallAvatar(
              name: otherName,
              imageUrl: otherAvatar,
              radius: 70,
            ),
          ),
          const SizedBox(height: 16),
          CallStatusChip(
            label: status ?? 'Connecting…',
            tone: CallStatusTone.pending,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(String? status) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Material(
            color: AppColors.backgroundDeep.withOpacity(0.45),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Back (asks to end the call)',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: callNameStyle(size: 17),
                ),
                Text(
                  status ?? _formatDuration(callService.callDuration),
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildReconnectingBanner() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const AppBanner(
        tone: AppBannerTone.warning,
        icon: Icons.wifi_off_rounded,
        message: 'Reconnecting… Weak connection.',
      ),
    );
  }

  // Landscape uses a landscape-shaped preview so it clears the controls.
  Size get _previewSize =>
      MediaQuery.orientationOf(context) == Orientation.landscape
      ? const Size(148, 104)
      : const Size(104, 148);

  Widget _buildLocalPreview() {
    final previewSize = _previewSize;
    final hasLocal = _renderersReady && _localRenderer.srcObject != null;
    final cameraOn = callService.isVideoEnabled;
    return Semantics(
      label: 'Your camera preview',
      child: Container(
        width: previewSize.width,
        height: previewSize.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.white.withOpacity(0.35),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasLocal && cameraOn)
                RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                const Center(
                  child: Icon(
                    Icons.videocam_off_rounded,
                    color: AppColors.lavender,
                    size: 28,
                  ),
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDeep.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    final cameraOn = callService.isVideoEnabled;
    final muted = callService.isMuted;
    final speakerOn = callService.isSpeakerOn;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withOpacity(0.62),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.white.withOpacity(0.12)),
      ),
      child: CallControlRow(
        children: [
          CallControlButton(
            icon: cameraOn
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: 'Camera',
            tooltip: cameraOn ? 'Turn camera off' : 'Turn camera on',
            toggled: !cameraOn,
            onPressed: () {
              setState(() => callService.toggleVideo());
            },
          ),
          CallControlButton(
            icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: muted ? 'Muted' : 'Mute',
            tooltip: muted ? 'Unmute' : 'Mute',
            toggled: muted,
            onPressed: () {
              setState(() => callService.toggleMute());
            },
          ),
          CallControlButton.end(onPressed: hangUp),
          CallControlButton(
            icon: Icons.cameraswitch_rounded,
            label: 'Flip',
            tooltip: 'Flip camera',
            onPressed: () async => callService.switchCamera(),
          ),
          CallControlButton(
            icon: speakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            label: 'Speaker',
            tooltip: speakerOn ? 'Turn speaker off' : 'Turn speaker on',
            toggled: speakerOn,
            onPressed: _toggleSpeaker,
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
