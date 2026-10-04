import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/auth_validators.dart';
import '../../widgets/app_states.dart';
import '../../widgets/custom_button.dart';
import 'auth_router.dart';

/// Shown to new email/password accounts until the verification link is used.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _resendCooldown = 30;

  bool _checking = false;
  bool _sending = false;
  bool _sent = false;
  int _cooldown = 0;
  String? _error;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (!mounted) return;
      if (verified) {
        // Refresh the ID token so the email_verified claim is current.
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        if (!mounted) return;
        await AuthRouter.routeCurrentUser(context);
      } else {
        _showError('Your email is not verified yet.');
      }
    } on FirebaseAuthException catch (e) {
      _showError(AuthValidators.messageFor(e));
    } catch (_) {
      _showError('Could not check. Try again.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      _showError(AuthValidators.messageFor(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown--);
    });
  }

  // Errors show inline above the actions.
  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    final error = _error;
    final coolingDown = _cooldown > 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: _constrained(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.brandPurple.withOpacity(0.16),
                            border: Border.all(color: AppColors.borderStrong),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            size: 44,
                            color: AppColors.pinkLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          'Check your inbox',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: AppColors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'We sent a verification link to',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.lavender,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Own line; honours text scaling, wraps only if too long.
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _tip(1, 'Open the email from Destined and tap the link.'),
                      _tip(2, "Come back here and tap \"I've verified\"."),
                      _tip(3, 'Nothing yet? Check Spam or Promotions.'),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _constrained(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      AppBanner(message: error, tone: AppBannerTone.error),
                      const SizedBox(height: 12),
                    ],
                    CustomButton(
                      text: "I've verified",
                      isLoading: _checking,
                      onPressed: _checking ? null : _checkVerified,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: CustomButton(
                        text: coolingDown
                            ? 'Resend in ${_clock(_cooldown)}'
                            : 'Resend email',
                        type: ButtonType.outline,
                        leftIcon: coolingDown ? Icons.schedule : Icons.refresh,
                        isLoading: _sending,
                        onPressed: coolingDown || _sending ? null : _resend,
                      ),
                    ),
                    if (_sent && coolingDown)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Email sent',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    CustomButton(
                      text: 'Use a different email',
                      type: ButtonType.text,
                      onPressed: () => AuthRouter.signOutToLogin(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Caps line length on tablets.
  Widget _constrained(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }

  Widget _tip(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface2,
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                color: AppColors.brandPurpleLight,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.lavender,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
