import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/auth_validators.dart';
import '../../core/constants/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtl = TextEditingController();
  final _newCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtl.dispose();
    _newCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  String? _validateNew(String? v) => AuthValidators.newPassword(v);

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final current = _currentCtl.text;
    final newPass = _newCtl.text;
    final confirm = _confirmCtl.text;

    if (newPass == current) {
      _showSnackBar(AppStrings.newPasswordMustDiffer);
      return;
    }

    if (newPass != confirm) {
      _showSnackBar(AppStrings.passwordsDoNotMatch);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().changePassword(
        currentPassword: current,
        newPassword: newPass,
      );

      if (!mounted) return;
      _showSnackBar(
        '${AppStrings.passwordChangedSuccess}. Other devices will be signed out.',
        isError: false,
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      final message =
          (e.code == 'wrong-password' || e.code == 'invalid-credential')
              ? AppStrings.currentPasswordWrong
              : AuthValidators.messageFor(e);
      _showSnackBar(message);
    } catch (_) {
      _showSnackBar(AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((p) => p.providerId).toList() ?? const <String>[];
    final usesEmailPassword = providers.contains('password');

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: _buildAppBar(),
      body: usesEmailPassword
          ? _buildPasswordForm()
          : _ProviderBanner(providers: providers),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Change Password',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildPasswordForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandViolet.withOpacity(0.2),
                        AppColors.brandPink.withOpacity(0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: AppColors.brandViolet,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              Center(
                child: Text(
                  'Create a strong password to\nkeep your account secure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Current Password
              CustomTextField(
                controller: _currentCtl,
                hintText: 'Enter current password',
                icon: Icons.lock_outline,  // ✅ Fixed
                obscureText: _obscureCurrent,
                suffixIcon: IconButton(
                  tooltip: _obscureCurrent ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                validator: (v) => (v == null || v.isEmpty) ? AppStrings.passwordRequired : null,
              ),

// New Password
              CustomTextField(
                controller: _newCtl,
                hintText: 'Enter new password',
                icon: Icons.lock_reset,  // ✅ Fixed
                obscureText: _obscureNew,
                suffixIcon: IconButton(
                  tooltip: _obscureNew ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                validator: _validateNew,
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _newCtl,
                builder: (_, __, ___) => _buildPasswordHints(),
              ),

// Confirm Password
              CustomTextField(
                controller: _confirmCtl,
                hintText: 'Confirm new password',
                icon: Icons.lock_outline,  // ✅ Fixed
                obscureText: _obscureConfirm,
                suffixIcon: IconButton(
                  tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (v) => (v == null || v.isEmpty) ? AppStrings.passwordRequired : null,
              ),

              // Submit Button
              CustomButton(
                text: 'Update Password',
                leftIcon: Icons.security,
                isLoading: _isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),

              // Cancel Button
              CustomButton(
                text: 'Cancel',
                type: ButtonType.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordHints() {
    final password = _newCtl.text;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildHintRow(
            'At least ${AuthValidators.minPasswordLength} characters',
            password.length >= AuthValidators.minPasswordLength,
          ),
          const SizedBox(height: 6),
          _buildHintRow('Contains a letter', RegExp(r'[A-Za-z]').hasMatch(password)),
          const SizedBox(height: 6),
          _buildHintRow('Contains a number', RegExp(r'\d').hasMatch(password)),
        ],
      ),
    );
  }

  Widget _buildHintRow(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.circle_outlined,
          size: 16,
          color: isValid ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isValid ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _ProviderBanner extends StatelessWidget {
  const _ProviderBanner({required this.providers});
  final List<String> providers;

  String _name(String id) {
    switch (id) {
      case 'google.com':
        return 'Google';
      case 'apple.com':
        return 'Apple';
      case 'phone':
        return 'Phone';
      default:
        return id;
    }
  }

  IconData _icon(String id) {
    switch (id) {
      case 'google.com':
        return Icons.g_mobiledata;
      case 'apple.com':
        return Icons.apple;
      case 'phone':
        return Icons.phone;
      default:
        return Icons.account_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerId = providers.isNotEmpty ? providers.first : '';
    final providerName = providers.isEmpty ? 'your provider' : _name(providerId);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brandViolet.withOpacity(0.1),
                AppColors.brandPink.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.brandViolet.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandViolet.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon(providerId),
                  color: AppColors.brandViolet,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Password Managed by $providerName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your account uses $providerName for authentication. To change your password, please visit $providerName account settings.',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Go Back',
                type: ButtonType.outline,
                leftIcon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}