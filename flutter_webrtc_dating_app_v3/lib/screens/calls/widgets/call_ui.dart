import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../models/call_model.dart';
import '../../../services/call/call_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/user_avatar.dart' show BrokenImageUrls;

/// Circular avatar from a URL, falling back to the name's initial.
class CallAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  /// Greys the avatar out (call ended).
  final bool dimmed;

  const CallAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 60,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null &&
        url.startsWith('http') &&
        !BrokenImageUrls.contains(url);
    final initial = Text(
      name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: radius * 0.66,
        color: AppColors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    final avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      child: hasImage
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                memCacheWidth: (radius * 6).round(),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                useOldImageOnUrlChange: true,
                errorWidget: (_, __, ___) {
                  BrokenImageUrls.add(url);
                  return Center(child: initial);
                },
              ),
            )
          : Center(child: initial),
    );
    if (!dimmed) return avatar;
    return Opacity(opacity: 0.5, child: avatar);
  }
}

/// Avatar with a soft pink/violet glow and a ring; [pulse] (0..1, repeating)
/// adds expanding ripple rings for the incoming screen.
class CallHalo extends StatelessWidget {
  final Widget avatar;
  final Animation<double>? pulse;
  final bool muted;

  const CallHalo({
    super.key,
    required this.avatar,
    this.pulse,
    this.muted = false,
  });

  static const double _size = 220;
  static const double _ring = 140;

  Widget _ripple(double t, Color color) {
    return Transform.scale(
      scale: 1 + 0.55 * t,
      child: Opacity(
        opacity: (1 - t) * 0.9,
        child: Container(
          width: _ring,
          height: _ring,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = muted
        ? AppColors.brandPurpleLight.withOpacity(0.2)
        : AppColors.brandPink.withOpacity(0.7);
    final anim = pulse;
    return ExcludeSemantics(
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!muted)
              Container(
                width: _size - 40,
                height: _size - 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.brandPink.withOpacity(0.35),
                      AppColors.brandPurple.withOpacity(0.18),
                      AppColors.brandPurple.withOpacity(0),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            if (anim != null)
              // Own layer: otherwise every ripple frame also repaints the
              // glow and the avatar's 48px blurred shadow.
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: anim,
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        _ripple(
                          (anim.value + i / 3) % 1,
                          i == 1
                              ? AppColors.brandPurpleLight.withOpacity(0.5)
                              : AppColors.brandPink.withOpacity(0.55),
                        ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.backgroundDeep,
                border: Border.all(color: ringColor, width: 2),
                boxShadow: muted
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.brandPink.withOpacity(0.35),
                          blurRadius: 48,
                          offset: const Offset(0, 16),
                        ),
                      ],
              ),
              child: avatar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Immersive call background: deep violet radial with a pink/violet glow.
class CallBackdrop extends StatelessWidget {
  final Widget child;

  const CallBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.44),
          radius: 1.2,
          colors: [
            AppColors.surface2,
            AppColors.surfaceRaised,
            AppColors.backgroundDarkest,
          ],
          stops: [0, 0.48, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 0.7,
            colors: [
              AppColors.brandPink.withOpacity(0.2),
              AppColors.brandPurple.withOpacity(0.12),
              AppColors.brandPurple.withOpacity(0),
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Display-font heading used for the other person's name.
TextStyle callNameStyle({double size = 30}) => GoogleFonts.montserrat(
      color: AppColors.white,
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );

/// Shown instead of a SnackBar when an outgoing call was not picked up.
class CallEndedView extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final CallEndReason reason;
  final bool isVideo;
  final VoidCallback onClose;

  const CallEndedView({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.reason,
    required this.isVideo,
    required this.onClose,
  });

  String get _headline {
    switch (reason) {
      case CallEndReason.declined:
        return '$name declined the call';
      case CallEndReason.busy:
        return '$name is busy';
      default:
        return "$name didn't answer";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: CallBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 56,
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Close and go back to chat',
                                onPressed: onClose,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: AppColors.white,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  isVideo ? 'Video call' : 'Voice call',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.lavender,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        CallHalo(
                          muted: true,
                          avatar: CallAvatar(
                            name: name,
                            imageUrl: avatarUrl,
                            radius: 70,
                            dimmed: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _headline,
                            textAlign: TextAlign.center,
                            style: callNameStyle(size: 28),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try again later or send a message.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.lavender,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          constraints: const BoxConstraints(minHeight: 30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.32),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVideo
                                    ? Icons.videocam_off_rounded
                                    : Icons.phone_missed_rounded,
                                size: 14,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  CallService.endReasonMessage(reason),
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        CustomButton(
                          text: 'Send a message',
                          leftIcon: Icons.chat_bubble_outline_rounded,
                          size: ButtonSize.large,
                          onPressed: onClose,
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
    );
  }
}

Future<bool> confirmEndCall(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text('End call?', style: TextStyle(color: AppColors.white)),
      content: const Text(
        'Leaving this screen will end the call.',
        style: TextStyle(color: AppColors.lavender),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'End call',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Ties an in-call screen to the call: keeps the screen awake, follows
/// [CallService.phaseListenable], closes the route (with the end reason) when
/// the call ends, confirms before back, and ends the call if the route is
/// removed while the call is still live.
mixin ActiveCallScreenMixin<T extends StatefulWidget> on State<T> {
  final CallService callService = CallService();
  bool _closing = false;
  bool _hungUpLocally = false;

  // Set when an outgoing call ends unanswered; shows [CallEndedView].
  CallEndReason? _endedReason;
  String _endedName = '';
  String? _endedAvatar;

  String get callId;

  /// Fallback for the direction when the user is signed out mid-call.
  bool get isOutgoingCall;

  CallPhase get phase => callService.phase;

  CallModel? get call {
    final c = callService.currentCall;
    return (c != null && c.id == callId) ? c : null;
  }

  String get _myUid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) return uid;
    final c = call;
    if (c == null) return '';
    return isOutgoingCall ? c.callerId : c.receiverId;
  }

  String get otherName => call?.otherNameFor(_myUid) ?? 'User';

  String? get otherAvatar => call?.otherAvatarFor(_myUid);

  /// Short status line for the current phase, or null when connected.
  String? get phaseLabel {
    switch (phase) {
      case CallPhase.outgoingRinging:
        return 'Ringing…';
      case CallPhase.connecting:
        return 'Connecting…';
      case CallPhase.reconnecting:
        return 'Reconnecting…';
      default:
        return null;
    }
  }

  void initCallScreen() {
    unawaited(WakelockPlus.enable().catchError((_) {}));
    callService.phaseListenable.addListener(_onPhaseChanged);
    // The call may already have ended before this route was built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPhaseChanged());
  }

  void disposeCallScreen() {
    callService.phaseListenable.removeListener(_onPhaseChanged);
    unawaited(WakelockPlus.disable().catchError((_) {}));
    if (call != null && callService.isInCall) {
      unawaited(callService.endCall());
    }
  }

  void _onPhaseChanged() {
    if (!mounted || _closing) return;
    if (call == null || phase == CallPhase.ended || phase == CallPhase.idle) {
      closeCallScreen();
    } else {
      setState(() {});
    }
  }

  /// Wrap the screen body so system back asks before ending the call.
  Widget callPopScope({required Widget child}) {
    return PopScope(
      // Once closing (end state shown), back just leaves.
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _closing) return;
        if (await confirmEndCall(context)) await hangUp();
      },
      child: child,
    );
  }

  Future<void> hangUp() async {
    Haptics.warning();
    _hungUpLocally = true;
    await callService.endCall();
    closeCallScreen();
  }

  void closeCallScreen() {
    if (_closing || !mounted) return;
    _closing = true;

    final reason = callService.lastEndReason;
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    final routeActive = route != null && route.isActive;

    if (!_hungUpLocally &&
        isOutgoingCall &&
        (reason == CallEndReason.declined ||
            reason == CallEndReason.busy ||
            reason == CallEndReason.noAnswer)) {
      // Close anything stacked on top (e.g. the confirm dialog) first.
      if (routeActive) nav.popUntil((r) => r == route);
      setState(() {
        _endedName = otherName;
        _endedAvatar = otherAvatar;
        _endedReason = reason;
      });
      return;
    }

    if (!_hungUpLocally && reason != null && reason != CallEndReason.hangup) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceCard,
          behavior: SnackBarBehavior.floating,
          content: Text(
            CallService.endReasonMessage(reason),
            style: const TextStyle(color: AppColors.white),
          ),
        ),
      );
    }

    if (!routeActive) return;
    nav.popUntil((r) => r == route);
    nav.pop();
  }

  /// The end state for an unanswered outgoing call, or null while live.
  Widget? buildEndedView({required bool isVideo}) {
    final reason = _endedReason;
    if (reason == null) return null;
    return CallEndedView(
      name: _endedName,
      avatarUrl: _endedAvatar,
      reason: reason,
      isVideo: isVideo,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
