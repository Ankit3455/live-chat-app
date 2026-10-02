import 'package:availchat/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
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

  // Email/Password Login
  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final userId = _auth.currentUser?.uid;
      
      if (userId != null) {
        await _saveFcmToken(userId);
        await _initializeNotificationSettings(userId);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Google Sign-In
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final userId = userCredential.user?.uid;

      if (userId != null) {
        await _saveFcmToken(userId);
        await _initializeNotificationSettings(userId);
      }

      if (mounted) {
        _showSuccess('Welcome ${userCredential.user?.displayName}!');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      _showError('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Save FCM Token
  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        }).catchError((_) async {
          // Fallback if document doesn't exist
          await _db.collection('users').doc(userId).set({
            'fcmTokens': [token],
          }, SetOptions(merge: true));
        });
      }
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  // Initialize notification settings
  Future<void> _initializeNotificationSettings(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final existingSettings = doc.data()?['notificationSettings'];

      if (existingSettings == null) {
        await _db.collection('users').doc(userId).update({
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
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize notification settings: $e');
    }
  }

  // Forgot Password
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      _showError('Enter your email first');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSuccess('Reset link sent to your email');
    } catch (e) {
      _showError('Error: $e');
    }
  }

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
              
              // App Title
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
              
              // Tagline
              const Text(
                'Find your cosmic connection.',
                style: TextStyle(
                  color: Color(0xFFB39DDB),
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Email Field
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
              
              // Password Field
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
              
              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFFB39DDB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Progress Indicator
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFF7B2CBF))
              else ...[
                // Login Button
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
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // OR Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: const Color(0xFFB39DDB))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(color: Color(0xFFB39DDB)),
                      ),
                    ),
                    Expanded(child: Divider(color: const Color(0xFFB39DDB))),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Google Sign-In Button
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
              
              // Sign Up Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Color(0xFFB39DDB)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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