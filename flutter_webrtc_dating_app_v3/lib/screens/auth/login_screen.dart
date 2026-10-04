import 'package:availchat/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/auth_validators.dart';
import '../../widgets/custom_button.dart';
import 'auth_router.dart';
import 'signup_screen.dart';

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
  bool _obscurePassword = true;

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
    setState(() => _isLoading = true);

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
      if (mounted) setState(() => _isLoading = false);
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
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.lavender),
      filled: true,
      fillColor: AppColors.surfaceCard,
      prefixIcon: Icon(icon, color: Colors.white),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              const Text(
                'Destined',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Find your cosmic connection.',
                style: TextStyle(
                  color: AppColors.lavender,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    children: [
                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        validator: AuthValidators.email,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hint: 'Email',
                          icon: Icons.mail,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _handleEmailLogin(),
                        validator: AuthValidators.loginPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hint: 'Password',
                          icon: Icons.lock,
                          suffix: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.lavender,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  child: Text(AppStrings.forgotPassword),
                ),
              ),

              const SizedBox(height: 20),

              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.brandPurple)
              else ...[
                CustomButton(
                  text: 'Login',
                  gradientColors: const [
                    AppColors.purplePrimary,
                    AppColors.purpleSecondary,
                  ],
                  onPressed: _handleEmailLogin,
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _handleGoogleSignIn,
                    icon: Image.asset(
                      'assets/images/google_icon.png',
                      height: 24,
                      width: 24,
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.googleBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: AppColors.lavender)),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
