import 'package:availchat/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ Notification imports
import 'package:availchat/services/notification/push_token_service.dart';
import 'package:availchat/services/notification/onesignal_helper.dart';

import '../../services/auth_service.dart';
import '../../core/constants/app_strings.dart';
import '../home/home_screen.dart';
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
  bool _isLoading = false;

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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError(AppStrings.passwordRequired);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      await auth.signIn(email, password);

      // ✅ Firebase FCM token sync
      await PushTokenService.syncToken();

      // ✅ Save tokens
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        await _saveFcmToken(uid);
        await _initializeNotificationSettings(uid);

        // ✅ OneSignal user link
        await OneSignalHelper.setUser(uid);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? AppStrings.genericAuthError);
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
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      final cred = await auth.signInWithGoogle();

      if (cred == null) return;

      // ✅ Firebase token sync
      await PushTokenService.syncToken();

      final uid = cred.user?.uid ?? auth.currentUser?.uid;
      if (uid != null) {
        await _saveFcmToken(uid);
        await _initializeNotificationSettings(uid);

        // ✅ OneSignal bind user
        await OneSignalHelper.setUser(uid);
      }

      if (mounted) {
        _showSuccess('Welcome ${cred.user?.displayName ?? ''}!');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? AppStrings.genericAuthError);
    } catch (e) {
      _showError('Google Sign-In failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------
  // Save FCM token
  // ----------------------------------------------------------
  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _db.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
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

    try {
      await context.read<AuthService>().sendResetLink(email);
      _showSuccess(AppStrings.resetEmailSent);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? AppStrings.genericAuthError);
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
                  fontFamily: 'Montserrat',
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Find your cosmic connection.',
                style: TextStyle(
                  color: Color(0xFFB39DDB),
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                ),
              ),

              const SizedBox(height: 32),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email or username',
                  hintStyle: const TextStyle(color: Color(0xFFB39DDB)),
                  filled: true,
                  fillColor: const Color(0xFF2D1B4E),
                  prefixIcon: const Icon(Icons.mail, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Color(0xFFB39DDB)),
                  filled: true,
                  fillColor: const Color(0xFF2D1B4E),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                const CircularProgressIndicator(color: Color(0xFF7B2CBF))
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _handleEmailLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Login',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
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
                      backgroundColor: const Color(0xFF4285F4),
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
                      style: TextStyle(color: Color(0xFFB39DDB))),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
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
