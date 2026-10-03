import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/astrology_utils.dart';
import '../../core/utils/auth_validators.dart';
import '../../widgets/custom_button.dart';
import 'auth_router.dart';

/// DOB + 18+ confirmation for accounts that have no DOB yet (Google first
/// login, older accounts) or no profile doc. With [blocked] it only explains
/// that the app is 18+ and offers sign-out.
class AgeGateScreen extends StatefulWidget {
  final bool blocked;

  const AgeGateScreen({super.key, this.blocked = false});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  static const _fieldFill = Color(0xFF2D1B4E);
  static const _hint = Color(0xFFB39DDB);

  DateTime? _dob;
  bool _confirmedAdult = false;
  bool _saving = false;
  late bool _blocked = widget.blocked;

  Future<void> _pickDob() async {
    final latest = AgePolicy.latestAllowedDob();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(latest.year - 7, latest.month, latest.day),
      firstDate: DateTime(1920),
      lastDate: latest,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7B2CBF),
            surface: _fieldFill,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    final dob = _dob;
    if (dob == null) {
      _showError('Please select your date of birth');
      return;
    }
    if (!AgePolicy.isAdult(dob)) {
      setState(() => _blocked = true);
      return;
    }
    if (!_confirmedAdult) {
      _showError('Please confirm you are 18 or older');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await AuthRouter.signOutToLogin(context);
      return;
    }

    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      // Presence may have created a bare doc; createdAt marks a real profile.
      final exists = (await ref.get()).data()?['createdAt'] != null;
      final zodiac = AstrologyUtils.zodiacFromDob(
        AgePolicy.legacyDobFormat.format(dob),
      );
      await ref
          .set({
            if (!exists) ...{
              'uid': user.uid,
              'email': user.email,
              'createdAt': FieldValue.serverTimestamp(),
              'signupCompleted': false,
              'mandatoryCompleted': false,
              'discoveryEnabled': false,
              'discoveryPendingOnboarding': true,
            },
            ...AgePolicy.dobFields(dob, zodiac),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      await AuthRouter.routeCurrentUser(context);
    } catch (_) {
      _showError('Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDob(DateTime d) => AgePolicy.legacyDobFormat.format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _blocked ? _buildBlocked() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildBlocked() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.block, color: Colors.white, size: 64),
        const SizedBox(height: 24),
        const Text(
          'Destined is only for adults',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'You must be 18 or older to use Destined.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _hint, fontSize: 15),
        ),
        const SizedBox(height: 40),
        CustomButton(
          text: 'Sign out',
          gradientColors: const [
            AppColors.purplePrimary,
            AppColors.purpleSecondary,
          ],
          onPressed: () => AuthRouter.signOutToLogin(context),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text(
          'Confirm your age',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Destined is for adults 18 and over. Your date of birth is private; '
          'others only see your age and zodiac sign.',
          style: TextStyle(color: _hint, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 32),
        const Text('Date of birth', style: TextStyle(color: _hint)),
        const SizedBox(height: 4),
        InkWell(
          onTap: _saving ? null : _pickDob,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  _dob == null ? 'DD / MM / YYYY' : _formatDob(_dob!),
                  style: TextStyle(
                    color: _dob == null ? _hint : Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _confirmedAdult,
          onChanged: _saving
              ? null
              : (v) => setState(() => _confirmedAdult = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.purplePrimary,
          title: const Text(
            'I confirm I am 18 or older',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'and agree to the Terms of Service and Privacy Policy.',
            style: TextStyle(color: _hint, fontSize: 12),
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: 'Continue',
          isLoading: _saving,
          gradientColors: const [
            AppColors.purplePrimary,
            AppColors.purpleSecondary,
          ],
          onPressed: _saving ? null : _submit,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _saving
                ? null
                : () => AuthRouter.signOutToLogin(context),
            child: const Text('Sign out', style: TextStyle(color: _hint)),
          ),
        ),
      ],
    );
  }
}
