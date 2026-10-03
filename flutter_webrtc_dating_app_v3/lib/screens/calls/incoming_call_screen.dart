import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../services/call/call_service.dart';
import '../../services/call/webrtc/call_constants.dart';
import '../../services/call/webrtc/signaling_service.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';
import 'widgets/call_ui.dart';

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

  StreamSubscription<String?>? _roomSub;
  StreamSubscription<DatabaseEvent>? _inboxSub;

  /// Set once Accept, Decline, timeout or a remote cancel is being handled.
  bool _handled = false;
  bool _answering = false;

  /// Prefer the admitted call (names/avatars from the caller's profile).
  CallModel get _call {
    final ringing = _callService.ringingCall;
    return (ringing != null && ringing.id == widget.call.id)
        ? ringing
        : widget.call;
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playRingtone();
    _startTimeout();
    _listenForCancel();
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
      if (_handled || !mounted) return;
      await _audioPlayer.play(AssetSource('sounds/incoming_call.mp3'));
    } catch (e) {
      debugPrint('IncomingCallScreen: ringtone failed: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  void _startTimeout() {
    _timeoutTimer = Timer(CallConstants.incomingStaleAfter, _rejectCall);
  }

  /// Caller hung up / timed out: the room ends (or is deleted) and the
  /// inbox entry is closed or removed.
  void _listenForCancel() {
    final callId = widget.call.id;
    _roomSub = SignalingService().roomState(callId).listen((state) {
      if (state == null || state == CallConstants.roomStateEnded) {
        _dismissCancelled();
      }
    }, onError: (e) => debugPrint('IncomingCallScreen: room error: $e'));

    final uid = widget.call.receiverId;
    if (uid.isEmpty) return;
    _inboxSub = FirebaseDatabase.instance
        .ref('${CallConstants.pathIncomingCalls}/$uid/$callId')
        .onValue
        .listen((event) {
          final snap = event.snapshot;
          final status = snap.child('status').value;
          if (!snap.exists ||
              status == CallConstants.inboxEnded ||
              status == CallConstants.inboxMissed ||
              status == CallConstants.inboxFailed) {
            _dismissCancelled();
          }
        }, onError: (e) => debugPrint('IncomingCallScreen: inbox error: $e'));
  }

  Future<void> _cancelListeners() async {
    _timeoutTimer?.cancel();
    await _roomSub?.cancel();
    _roomSub = null;
    await _inboxSub?.cancel();
    _inboxSub = null;
  }

  Future<void> _dismissCancelled() async {
    if (_handled) return;
    _handled = true;
    await _cancelListeners();
    await _stopRingtone();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Call cancelled')));
    _close();
  }

  void _close() {
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final nav = Navigator.of(context);
    nav.popUntil((r) => r == route);
    nav.pop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    _roomSub?.cancel();
    _inboxSub?.cancel();
    // Route removed without an answer (e.g. sign-out): stop it ringing.
    if (!_handled) unawaited(_callService.rejectCall(widget.call.id));
    _audioPlayer.stop().catchError((_) {});
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _answerCall() async {
    if (_handled) return;
    final call = _call;
    setState(() {
      _handled = true;
      _answering = true;
    });
    await _cancelListeners();
    await _stopRingtone();

    try {
      await _callService.answerCall(call);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => call.type == CallType.video
              ? VideoCallScreen(callId: call.id, isOutgoing: false)
              : AudioCallScreen(callId: call.id, isOutgoing: false),
        ),
      );
    } catch (e) {
      debugPrint('IncomingCallScreen: answer failed: $e');
      if (!mounted) return;

      final message = e is CallPermissionDeniedException
          ? e.message
          : e is StateError
          ? 'This call is no longer available'
          : 'Failed to answer call';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.dangerRed),
      );
      _close();
    }
  }

  Future<void> _rejectCall() async {
    if (_handled) return;
    setState(() => _handled = true);
    await _cancelListeners();
    await _stopRingtone();

    try {
      await _callService.rejectCall(widget.call.id);
    } catch (_) {}

    if (!mounted) return;
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final call = _call;
    final callerName = call.otherNameFor(call.receiverId);
    final isVideo = call.type == CallType.video;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _rejectCall();
      },
      child: Scaffold(
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
                      style: TextStyle(
                        color: AppColors.hintPurple,
                        fontSize: 16,
                      ),
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
                                  color: AppColors.purplePrimary.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: CallAvatar(
                              name: callerName,
                              imageUrl: call.otherAvatarFor(call.receiverId),
                              radius: 60,
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
                child: _answering
                    ? CircularProgressIndicator(color: AppColors.purplePrimary)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            onTap: _handled ? null : _rejectCall,
                            backgroundColor: AppColors.dangerRed,
                            icon: Icons.call_end,
                            label: 'Decline',
                          ),
                          _buildActionButton(
                            onTap: _handled ? null : _answerCall,
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
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onTap,
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
