import 'package:availchat/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/astrology_utils.dart';
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
  final _birthDateController = TextEditingController();
  final _birthTimeController = TextEditingController();
  final _birthLocationController = TextEditingController();

  DateTime? _dob;
  bool _confirmedAdult = false;
  bool _adultError = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

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
              primary: AppColors.brandPurple,
              surface: AppColors.surfaceCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _dob = picked;
        _birthDateController.text = AgePolicy.legacyDobFormat.format(picked);
      });
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
              primary: AppColors.brandPurple,
              surface: AppColors.surfaceCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      _birthTimeController.text = picked.format(context);
    }
  }

  String? _validateDob(String? _) {
    final dob = _dob;
    if (dob == null) return 'Please choose your birth date';
    if (!AgePolicy.isAdult(dob)) {
      return 'You must be 18 or older to use Destined';
    }
    return null;
  }

  // Handle Signup
  Future<void> _handleSignup() async {
    if (_isLoading) return;
    setState(() {
      _error = null;
      _adultError = !_confirmedAdult;
    });
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || !_confirmedAdult) {
      Haptics.error();
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
    final dob = _dob;
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
                            'Two quick parts: your login details, then the birth details '
                            'we use to read your chart.',
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
                          const SizedBox(height: 28),
                          _buildSectionHeader(),
                          const SizedBox(height: 16),
                          const AuthLabel('Birth date', required: true),
                          _buildTextField(
                            controller: _birthDateController,
                            hint: 'DD/MM/YYYY',
                            icon: Icons.calendar_today_outlined,
                            readOnly: true,
                            onTap: _isLoading ? null : _pickBirthDate,
                            validator: _validateDob,
                          ),
                          if (dob != null) ZodiacHelper(dob: dob),
                          const SizedBox(height: 16),
                          const AuthLabel('Birth time', optional: true),
                          _buildTextField(
                            controller: _birthTimeController,
                            hint: 'HH:MM',
                            icon: Icons.access_time,
                            readOnly: true,
                            onTap: _isLoading ? null : _pickBirthTime,
                            helper: "Makes your chart more precise. Skip it if "
                                "you're not sure.",
                          ),
                          const SizedBox(height: 16),
                          const AuthLabel('Birth location', required: true),
                          _buildTextField(
                            controller: _birthLocationController,
                            hint: 'City, Country',
                            icon: Icons.location_on_outlined,
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Please enter the city where you were born'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AuthCheckRow(
                            value: _confirmedAdult,
                            onChanged: _isLoading
                                ? null
                                : (v) => setState(() {
                                      Haptics.selection();
                                      _confirmedAdult = v;
                                      if (v) _adultError = false;
                                    }),
                            errorText: _adultError
                                ? 'Please confirm you are 18 or older'
                                : null,
                            label: const Text(
                              'I confirm I am 18 or older',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
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

  Widget _buildSectionHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandPurple.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_awesome,
            size: 18,
            color: AppColors.brandPurpleLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Your natal chart details',
                  style: GoogleFonts.montserrat(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'This helps us find your destined match.',
                style: TextStyle(color: AppColors.lavender, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
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
