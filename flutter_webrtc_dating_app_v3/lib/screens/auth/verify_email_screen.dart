import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/auth_validators.dart';
import '../../widgets/custom_button.dart';
import 'auth_router.dart';

/// Shown to new email/password accounts until the verification link is used.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _hint = Color(0xFFB39DDB);
  static const _resendCooldown = 30;

  bool _checking = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (!mounted) return;
      if (verified) {
        await AuthRouter.routeCurrentUser(context);
      } else {
        _showMessage('Your email is not verified yet.', error: true);
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(AuthValidators.messageFor(e), error: true);
    } catch (_) {
      _showMessage('Could not check. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      _showMessage('Verification email sent');
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      _showMessage(AuthValidators.messageFor(e), error: true);
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

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const Icon(
                Icons.mark_email_unread,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to $email. '
                'Open it, then come back and tap the button below.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _hint, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 40),
              CustomButton(
                text: "I've verified my email",
                isLoading: _checking,
                gradientColors: const [
                  AppColors.purplePrimary,
                  AppColors.purpleSecondary,
                ],
                onPressed: _checking ? null : _checkVerified,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _cooldown > 0 ? null : _resend,
                child: Text(
                  _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => AuthRouter.signOutToLogin(context),
                child: const Text('Sign out', style: TextStyle(color: _hint)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
