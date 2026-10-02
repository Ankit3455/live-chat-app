import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/screens/questionnaire/questionnaire_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../questionnaire/post_signup_questions_screen.dart'; // ✅ ADD THIS
// ✅ ADD this import
import '../../features/onboarding/tour_prefs.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _birthTimeController = TextEditingController();
  final _birthLocationController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _birthLocationController.dispose();
    super.dispose();
  }

  // Pick Birth Date
  Future<void> _pickBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7B2CBF),
              surface: Color(0xFF2D1B4E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  // Pick Birth Time
  Future<void> _pickBirthTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7B2CBF),
              surface: Color(0xFF2D1B4E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _birthTimeController.text = picked.format(context);
    }
  }

  // Calculate Zodiac Sign from DOB
  String _calculateZodiacSign(String dob) {
    try {
      final parts = dob.split('/');
      if (parts.length != 3) return 'Unknown';

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      if ((month == 3 && day >= 21) || (month == 4 && day <= 19))
        return 'Aries';
      if ((month == 4 && day >= 20) || (month == 5 && day <= 20))
        return 'Taurus';
      if ((month == 5 && day >= 21) || (month == 6 && day <= 20))
        return 'Gemini';
      if ((month == 6 && day >= 21) || (month == 7 && day <= 22))
        return 'Cancer';
      if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'Leo';
      if ((month == 8 && day >= 23) || (month == 9 && day <= 22))
        return 'Virgo';
      if ((month == 9 && day >= 23) || (month == 10 && day <= 22))
        return 'Libra';
      if ((month == 10 && day >= 23) || (month == 11 && day <= 21))
        return 'Scorpio';
      if ((month == 11 && day >= 22) || (month == 12 && day <= 21))
        return 'Sagittarius';
      if ((month == 12 && day >= 22) || (month == 1 && day <= 19))
        return 'Capricorn';
      if ((month == 1 && day >= 20) || (month == 2 && day <= 18))
        return 'Aquarius';
      if ((month == 2 && day >= 19) || (month == 3 && day <= 20))
        return 'Pisces';

      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Handle Signup
  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final dob = _birthDateController.text.trim();
    final time = _birthTimeController.text.trim();
    final location = _birthLocationController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        dob.isEmpty ||
        time.isEmpty ||
        location.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw Exception('User creation failed: No UID');
      }

      // ✅ AUTO-CALCULATE ZODIAC SIGN
      final sunSign = _calculateZodiacSign(dob);

      // ✅ SAVE TO FIRESTORE
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'username': email.split('@')[0],
        'dob': dob,
        'birthTime': time,
        'location': location,
        'sunSign': sunSign,
        'zodiacSign': sunSign,
        'discoveryEnabled': true,
        'online': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoading = false);

        // ✅ SET FLAG to show onboarding after questionnaire
        await TourPrefs.setForceShowAfterSignup(true);

        _showSuccess('Signup Successful! Complete your profile...');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const QuestionnaireScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError(e.message ?? 'Signup failed');
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('Failed to save details: $e');
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
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email
                    _buildLabel('Email Address'),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'you@example.com',
                      icon: Icons.mail,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16),

                    // Password
                    _buildLabel('Password'),
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Create a password',
                      icon: Icons.lock,
                      isPassword: true,
                    ),

                    const SizedBox(height: 16),

                    // Confirm Password
                    _buildLabel('Confirm Password'),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hint: 'Confirm your password',
                      icon: Icons.lock,
                      isPassword: true,
                    ),

                    const SizedBox(height: 32),

                    // Centered Section
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            'Your Natal Chart Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'This helps us find your destined match.',
                            style: TextStyle(
                              color: Color(0xFFB39DDB),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Birth Date
                    _buildLabel('Birth Date'),
                    _buildTextField(
                      controller: _birthDateController,
                      hint: 'DD / MM / YYYY',
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: _pickBirthDate,
                    ),

                    const SizedBox(height: 16),

                    // Birth Time & Location Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Birth Time'),
                              _buildTextField(
                                controller: _birthTimeController,
                                hint: 'e.g. 4:30 PM',
                                icon: Icons.access_time,
                                readOnly: true,
                                onTap: _pickBirthTime,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Birth Location'),
                              _buildTextField(
                                controller: _birthLocationController,
                                hint: 'City, Country',
                                icon: Icons.location_on,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Progress Indicator
                    if (_isLoading)
                      const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF7B2CBF)),
                      )
                    else
                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _handleSignup,
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
                                'Sign Up',
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

                    // Terms
                    const Center(
                      child: Text(
                        'By signing up, you agree to our Terms and Conditions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB39DDB),
                          fontSize: 12,
                        ),
                      ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB39DDB),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB39DDB)),
        filled: true,
        fillColor: const Color(0xFF2D1B4E),
        prefixIcon: Icon(icon, color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}