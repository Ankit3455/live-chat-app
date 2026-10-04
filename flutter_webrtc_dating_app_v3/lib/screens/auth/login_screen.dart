import 'package:availchat/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/auth_validators.dart';
import '../../widgets/app_states.dart';
import '../../widgets/custom_button.dart';
import 'auth_router.dart';
import 'signup_screen.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _db = FirebaseFirestore.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _googleBusy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // Email/Password Login
  // ----------------------------------------------------------
  Future<void> _handleEmailLogin() async {
    if (_isLoading) return;
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      final cred = await auth.signIn(email, password);

      final uid = cred.user?.uid;
      if (uid != null) await _initializeNotificationSettings(uid);

      if (mounted) await AuthRouter.routeCurrentUser(context);
    } on FirebaseAuthException catch (e) {
      _showError(AuthValidators.messageFor(e));
    } catch (e) {
      _showError(AppStrings.genericAuthError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------
  // Google Login
  // ----------------------------------------------------------
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() {
      _error = null;
      _isLoading = true;
      _googleBusy = true;
    });

    try {
      final auth = context.read<AuthService>();
      final cred = await auth.signInWithGoogle();

      // Picker cancelled.
      if (cred == null) return;

      final uid = cred.user?.uid;
      if (uid != null) await _initializeNotificationSettings(uid);

      if (mounted) await AuthRouter.routeCurrentUser(context);
    } on FirebaseAuthException catch (e) {
      _showError(AuthValidators.messageFor(e));
    } catch (e) {
      _showError('Google Sign-In failed');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _googleBusy = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // Firestore notification settings
  // ----------------------------------------------------------
  Future<void> _initializeNotificationSettings(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final existing = doc.data()?['notificationSettings'];

      if (existing == null) {
        await _db.collection('users').doc(userId).set({
          'notificationSettings': {
            'pushEnabled': true,
            'messageNotifications': true,
            'soundEnabled': true,
            'vibrationEnabled': true,
            'quietHoursEnabled': false,
            'quietHoursStart': null,
            'quietHoursEnd': null,
            'whoCanMessageDirectly': 'everyone',
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to init notification settings: $e');
    }
  }

  // ----------------------------------------------------------
  // Forgot password
  // ----------------------------------------------------------
  Future<void> _handleForgotPassword() async {
    setState(() => _error = null);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError(AppStrings.enterEmailForReset);
      return;
    }
    final emailError = AuthValidators.email(email);
    if (emailError != null) {
      _showError(emailError);
      return;
    }

    try {
      await context.read<AuthService>().sendResetLink(email);
      _showSuccess(AppStrings.resetEmailSent);
    } on FirebaseAuthException catch (e) {
      _showError(AuthValidators.messageFor(e));
    } catch (e) {
      _showError(AppStrings.genericAuthError);
    }
  }

  // ----------------------------------------------------------
  // UI Helpers
  // ----------------------------------------------------------

  // Errors show inline above the fields.
  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openSignup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: Starfield()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(),
                      const SizedBox(height: 36),
                      if (error != null) ...[
                        AppBanner(message: error, tone: AppBannerTone.error),
                        const SizedBox(height: 16),
                      ],
                      _buildForm(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _handleForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brandPurpleLight,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text(AppStrings.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomButton(
                        text: 'Log in',
                        isLoading: _isLoading && !_googleBusy,
                        onPressed: _isLoading ? null : _handleEmailLogin,
                      ),
                      const SizedBox(height: 20),
                      const AuthOrDivider(),
                      const SizedBox(height: 20),
                      _buildGoogleButton(),
                      const SizedBox(height: 20),
                      _buildSignupLink(),
                      const SizedBox(height: 24),
                      const LegalText(
                        prefix: 'By continuing you agree to our ',
                        termsLabel: 'Terms',
                        suffix: '. Destined is for adults 18+.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthLabel('Email'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              validator: AuthValidators.email,
              style: const TextStyle(color: AppColors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            const AuthLabel('Password'),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _handleEmailLogin(),
              validator: AuthValidators.loginPassword,
              style: const TextStyle(color: AppColors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Your password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // White Google button so it sits well with the purple brand.
  Widget _buildGoogleButton() {
    final disabled = _isLoading;
    return Opacity(
      opacity: disabled && !_googleBusy ? 0.5 : 1,
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: 'Continue with Google',
        excludeSemantics: true,
        child: Material(
          color: AppColors.white,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled ? null : _handleGoogleSignIn,
            child: SizedBox(
              height: 52,
              child: Center(
                child: _googleBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.brandPurple,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            AppAssets.googleIcon,
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: AppColors.backgroundDeep,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'New to Destined? ',
          style: TextStyle(color: AppColors.lavender, fontSize: 14),
        ),
        TextButton(
          onPressed: _isLoading ? null : _openSignup,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandPurpleLight,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: const Text(
            'Create an account',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
