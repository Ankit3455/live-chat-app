import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/call_model.dart';
import '../../../services/call/call_service.dart';

/// Circular avatar from a URL, falling back to the name's initial.
class CallAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const CallAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 60,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.startsWith('http');
    final initial = Text(
      name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: radius * 0.66,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.purpleSecondary,
      child: hasImage
          ? ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Center(child: initial),
              ),
            )
          : initial,
    );
  }
}

Future<bool> confirmEndCall(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.inputBackground,
      title: const Text('End call?', style: TextStyle(color: Colors.white)),
      content: Text(
        'Leaving this screen will end the call.',
        style: TextStyle(color: AppColors.hintPurple),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('End call', style: TextStyle(color: AppColors.dangerRed)),
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
        return 'Ringing...';
      case CallPhase.connecting:
        return 'Connecting...';
      case CallPhase.reconnecting:
        return 'Reconnecting...';
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
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _closing) return;
        if (await confirmEndCall(context)) await hangUp();
      },
      child: child,
    );
  }

  Future<void> hangUp() async {
    _hungUpLocally = true;
    await callService.endCall();
    closeCallScreen();
  }

  void closeCallScreen() {
    if (_closing || !mounted) return;
    _closing = true;

    final reason = callService.lastEndReason;
    if (!_hungUpLocally && reason != null && reason != CallEndReason.hangup) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(CallService.endReasonMessage(reason))),
      );
    }

    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    if (route == null || !route.isActive) return;
    // Close anything stacked on top (e.g. the confirm dialog) first.
    nav.popUntil((r) => r == route);
    nav.pop();
  }
}
