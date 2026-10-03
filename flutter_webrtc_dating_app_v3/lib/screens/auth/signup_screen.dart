import 'package:availchat/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/astrology_utils.dart';
import '../../core/utils/auth_validators.dart';
import '../../services/auth_service.dart';
import 'auth_router.dart';

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
  final _birthDateController = TextEditingController();
  final _birthTimeController = TextEditingController();
  final _birthLocationController = TextEditingController();

  DateTime? _dob;
  bool _confirmedAdult = false;
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
    final latest = AgePolicy.latestAllowedDob();
    final fallback = DateTime(2000);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? (fallback.isAfter(latest) ? latest : fallback),
      firstDate: DateTime(1920),
      lastDate: latest,
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
      _dob = picked;
      _birthDateController.text = AgePolicy.legacyDobFormat.format(picked);
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

  String? _validateDob(String? _) {
    final dob = _dob;
    if (dob == null) return 'Birth date is required';
    if (!AgePolicy.isAdult(dob)) {
      return 'You must be 18 or older to use Destined';
    }
    return null;
  }

  // Handle Signup
  Future<void> _handleSignup() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_confirmedAdult) {
      _showError('Please confirm you are 18 or older');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final dob = _dob!;
    final time = _birthTimeController.text.trim();
    final birthLocation = _birthLocationController.text.trim();
    final zodiac = AstrologyUtils.zodiacFromDob(
      AgePolicy.legacyDobFormat.format(dob),
    );

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().signUp(
        email: email,
        password: password,
        profile: {
          ...AgePolicy.dobFields(dob, zodiac),
          if (time.isNotEmpty) 'birthTime': time,
          'birthLocation': birthLocation,
          'termsAcceptedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;

      _showSuccess('Account created! Check your inbox to verify your email.');
      await AuthRouter.routeCurrentUser(context);
    } on FirebaseAuthException catch (e) {
      _showError(
        e.code == 'profile-write-failed'
            ? (e.message ?? 'Signup failed')
            : AuthValidators.messageFor(e),
      );
    } catch (_) {
      _showError('Signup failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                child: Form(
                  key: _formKey,
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
                      autofillHints: const [AutofillHints.email],
                      validator: AuthValidators.email,
                    ),

                    const SizedBox(height: 16),

                    // Password
                    _buildLabel('Password'),
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'At least 8 characters, letters and numbers',
                      icon: Icons.lock,
                      isPassword: true,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: AuthValidators.newPassword,
                    ),

                    const SizedBox(height: 16),

                    // Confirm Password
                    _buildLabel('Confirm Password'),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hint: 'Confirm your password',
                      icon: Icons.lock,
                      isPassword: true,
                      validator: (v) => AuthValidators.confirmPassword(
                        v,
                        _passwordController.text,
                      ),
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
                      validator: _validateDob,
                    ),

                    const SizedBox(height: 16),

                    // Birth Time & Location Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Birth Time (optional)'),
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
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    CheckboxListTile(
                      value: _confirmedAdult,
                      onChanged: _isLoading
                          ? null
                          : (v) => setState(() => _confirmedAdult = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF7B2CBF),
                      title: const Text(
                        'I confirm I am 18 or older',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 8),

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
                        'By signing up, you agree to our Terms of Service and Privacy Policy.',
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
    Iterable<String>? autofillHints,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB39DDB)),
        errorMaxLines: 2,
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
