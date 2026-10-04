import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/auth_validators.dart';
import '../../core/utils/haptics.dart';
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
  bool _isSuccess = false;
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
    if (isError) Haptics.error();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: AppColors.backgroundDeep,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.backgroundDeep),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSuccess) return;
    if (!_formKey.currentState!.validate()) {
      Haptics.error();
      return;
    }

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
      Haptics.success();
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      _showSnackBar(
        '${AppStrings.passwordChangedSuccess}. Other devices will be signed out.',
        isError: false,
      );
      // Brief check-mark state before leaving.
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
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
    final providers = user?.providerData.map((p) => p.providerId).toList() ??
        const <String>[];
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
    return AppBar(title: const Text('Change password'));
  }

  Widget _buildPasswordForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      // Cap width on tablets so the form stays readable.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                          AppColors.brandPurple.withOpacity(0.22),
                          AppColors.brandPink.withOpacity(0.14),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.brandPurpleLight,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle
                const Center(
                  child: Text(
                    'Create a strong password to\nkeep your account secure',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.lavender,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                const _FieldLabel('Current password'),
                CustomTextField(
                  controller: _currentCtl,
                  hintText: 'Enter current password',
                  icon: Icons.lock_outline,
                  obscureText: _obscureCurrent,
                  suffixIcon: IconButton(
                    tooltip:
                        _obscureCurrent ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textSubtle,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AppStrings.passwordRequired
                      : null,
                ),
                const SizedBox(height: 20),

                const _FieldLabel('New password'),
                CustomTextField(
                  controller: _newCtl,
                  hintText: 'Enter new password',
                  icon: Icons.lock_reset,
                  obscureText: _obscureNew,
                  suffixIcon: IconButton(
                    tooltip: _obscureNew ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textSubtle,
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
                const SizedBox(height: 20),

                const _FieldLabel('Confirm new password'),
                CustomTextField(
                  controller: _confirmCtl,
                  hintText: 'Confirm new password',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    tooltip:
                        _obscureConfirm ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textSubtle,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AppStrings.passwordRequired
                      : null,
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Update password',
                  leftIcon: Icons.security,
                  isLoading: _isLoading,
                  isSuccess: _isSuccess,
                  onPressed: _submit,
                ),
                const SizedBox(height: 8),

                CustomButton(
                  text: 'Cancel',
                  type: ButtonType.text,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
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
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildHintRow(
            'At least ${AuthValidators.minPasswordLength} characters',
            password.length >= AuthValidators.minPasswordLength,
          ),
          const SizedBox(height: 6),
          _buildHintRow(
            'Contains a letter',
            RegExp(r'[A-Za-z]').hasMatch(password),
          ),
          const SizedBox(height: 6),
          _buildHintRow('Contains a number', RegExp(r'\d').hasMatch(password)),
        ],
      ),
    );
  }

  Widget _buildHintRow(String text, bool isValid) {
    // Icon state is spoken as part of the label.
    return Semantics(
      label: '$text, ${isValid ? 'done' : 'not yet'}',
      excludeSemantics: true,
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Icon(
              isValid ? Icons.check_circle : Icons.circle_outlined,
              key: ValueKey(isValid),
              size: 16,
              color: isValid ? AppColors.success : AppColors.textSubtle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isValid ? AppColors.success : AppColors.lavender,
              ),
            ),
          ),
        ],
      ),
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
    final providerName =
        providers.isEmpty ? 'your provider' : _name(providerId);

    // Scrolls in landscape; width capped on tablets.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brandPurple.withOpacity(0.14),
                AppColors.brandPink.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandPurpleMid.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon(providerId),
                  color: AppColors.brandPurpleLight,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Password managed by $providerName',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You log in with $providerName, so your password is managed there. To change it, go to your $providerName account settings.',
                style: const TextStyle(
                  color: AppColors.lavender,
                  fontSize: 14,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Go back',
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.lavender,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
