import 'package:availchat/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/auth_validators.dart';
import '../../core/utils/haptics.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_states.dart';
import '../../widgets/custom_button.dart';
import 'auth_router.dart';
import 'widgets/auth_widgets.dart';
import '../../core/config/auth_config.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Handle Signup
  Future<void> _handleSignup() async {
    if (_isLoading) return;
    setState(() => _error = null);
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      Haptics.error();
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().signUp(
        email: email,
        password: password,
        // Birth date and the 18+ check come next, on the same birth card
        // Google sign-ups see (AuthRouter routes there while DOB is missing).
        profile: {'termsAcceptedAt': FieldValue.serverTimestamp()},
      );

      if (!mounted) return;

      Haptics.success();
      _showSuccess(
        AuthConfig.requireEmailVerification
            ? 'Account created! Check your inbox to verify your email.'
            : 'Account created!',
      );
      await AuthRouter.routeCurrentUser(context);
    } on FirebaseAuthException catch (e) {
      _showError(
        e.code == 'profile-write-failed'
            ? (e.message ??
                "We couldn't create your account. Please try again.")
            : AuthValidators.messageFor(e),
      );
    } catch (_) {
      _showError("We couldn't create your account. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Submit errors show inline above the Create account button.
  void _showError(String message) {
    if (!mounted) return;
    Haptics.error();
    setState(() => _error = message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _visibilityToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to log in',
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Create account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                // Cap line length on tablets.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Your login details. Next, your birth card: the same '
                            'quick start as signing up with Google.',
                            style: TextStyle(
                              color: AppColors.lavender,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const AuthLabel('Email'),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'you@example.com',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: AuthValidators.email,
                          ),
                          const SizedBox(height: 16),
                          const AuthLabel('Password'),
                          _buildTextField(
                            controller: _passwordController,
                            hint: 'At least 8 characters, letters and numbers',
                            icon: Icons.lock_outline,
                            obscure: _obscurePassword,
                            suffix: _visibilityToggle(
                              _obscurePassword,
                              () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            autofillHints: const [AutofillHints.newPassword],
                            validator: AuthValidators.newPassword,
                          ),
                          const SizedBox(height: 16),
                          const AuthLabel('Confirm password'),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hint: 'Type it again',
                            icon: Icons.lock_outline,
                            obscure: _obscureConfirm,
                            suffix: _visibilityToggle(
                              _obscureConfirm,
                              () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                            validator: (v) => AuthValidators.confirmPassword(
                              v,
                              _passwordController.text,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: AppColors.lavender,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.maybePop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.brandPurpleLight,
                                  minimumSize: const Size(48, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Sticky footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceRaised,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: error == null
                            ? const SizedBox.shrink()
                            : Padding(
                                key: ValueKey(error),
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppBanner(
                                  message: error,
                                  tone: AppBannerTone.error,
                                ),
                              ),
                      ),
                      CustomButton(
                        text: 'Create account',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleSignup,
                      ),
                      const SizedBox(height: 10),
                      const LegalText(
                        prefix: 'By signing up, you agree to our ',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    bool readOnly = false,
    VoidCallback? onTap,
    String? helper,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      validator: validator,
      style: const TextStyle(color: AppColors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        errorMaxLines: 2,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}
