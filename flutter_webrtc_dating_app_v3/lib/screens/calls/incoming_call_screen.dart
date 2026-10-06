import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/call_model.dart';
import '../../services/call/call_intent_channel.dart';
import '../../services/call/call_service.dart';
import '../../services/call/webrtc/call_constants.dart';
import '../../services/call/webrtc/signaling_service.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';
import 'widgets/call_controls.dart';
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
    _startTimeout();
    _listenForCancel();
    // This screen rings from here on; stop the Android notification ringing.
    unawaited(CallIntentChannel.cancelNotification(widget.call.id));
    if (CallIntentChannel.takeAutoAnswer(widget.call.id)) {
      // Accepted from the notification.
      WidgetsBinding.instance.addPostFrameCallback((_) => _answerCall());
    } else {
      _playRingtone();
      CallIntentChannel.autoAnswerCallId.addListener(_onAutoAnswer);
    }
  }

  /// Accept tapped on the notification while this screen was already open.
  void _onAutoAnswer() {
    if (!mounted || _handled) return;
    if (CallIntentChannel.takeAutoAnswer(widget.call.id)) _answerCall();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );
  }

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: no ripple rings.
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat();
    }
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
    unawaited(CallIntentChannel.releaseLockScreen());
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('The caller hung up.')));
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
    CallIntentChannel.autoAnswerCallId.removeListener(_onAutoAnswer);
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
    Haptics.medium();
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
      unawaited(CallIntentChannel.releaseLockScreen());
      if (!mounted) return;

      final message = e is CallPermissionDeniedException
          ? e.message
          : e is StateError
              ? 'This call has already ended.'
              : "Couldn't answer the call. Check your connection and try again.";
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
      _close();
    }
  }

  Future<void> _rejectCall() async {
    if (_handled) return;
    Haptics.warning();
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
    final kind = isVideo ? 'video' : 'voice';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _rejectCall();
      },
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
                          const SizedBox(
                            height: 56,
                            child: Center(
                              child: Text(
                                'DESTINED',
                                style: TextStyle(
                                  color: AppColors.textSubtle,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            label: 'Incoming $kind call from $callerName',
                            excludeSemantics: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.call_rounded,
                                  size: 16,
                                  color: AppColors.lavender,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Incoming $kind call',
                                  style: const TextStyle(
                                    color: AppColors.lavender,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          CallHalo(
                            pulse: _reduceMotion ? null : _pulseController,
                            avatar: CallAvatar(
                              name: callerName,
                              imageUrl: call.otherAvatarFor(call.receiverId),
                              radius: 70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            callerName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: callNameStyle(),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'is calling you on Destined',
                            style: TextStyle(
                              color: AppColors.lavender,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          if (_answering)
                            const SizedBox(
                              height: 104,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.brandPurpleLight,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  CallAnswerButton(
                                    icon: Icons.call_end_rounded,
                                    label: 'Decline',
                                    semanticLabel: 'Decline call',
                                    color: AppColors.error,
                                    iconColor: AppColors.white,
                                    onPressed: _handled ? null : _rejectCall,
                                  ),
                                  CallAnswerButton(
                                    icon: isVideo
                                        ? Icons.videocam_rounded
                                        : Icons.call_rounded,
                                    label: 'Accept',
                                    semanticLabel: 'Accept call',
                                    color: AppColors.success,
                                    iconColor: AppColors.backgroundDeep,
                                    onPressed: _handled ? null : _answerCall,
                                  ),
                                ],
                              ),
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
