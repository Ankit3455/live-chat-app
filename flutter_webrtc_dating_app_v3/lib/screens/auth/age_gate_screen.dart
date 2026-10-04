import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/astrology_utils.dart';
import '../../core/utils/auth_validators.dart';
import '../../widgets/app_states.dart';
import '../../widgets/custom_button.dart';
import 'auth_router.dart';
import 'widgets/auth_widgets.dart';

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
  DateTime? _dob;
  bool _confirmedAdult = false;
  bool _saving = false;
  String? _error;
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
            primary: AppColors.brandPurple,
            surface: AppColors.surfaceCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _dob = picked;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
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

  // Errors show inline above Continue.
  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  String _formatDob(DateTime d) => AgePolicy.legacyDobFormat.format(d);

  TextStyle get _titleStyle => GoogleFonts.montserrat(
    color: AppColors.white,
    fontSize: 26,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: _blocked ? _buildBlocked() : _buildForm(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // Calm blocked state: moon art, one sentence, one way out.
  Widget _buildBlocked() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.brandPurple.withOpacity(0.35),
                  AppColors.brandPurple.withOpacity(0.0),
                ],
              ),
            ),
            child: const Icon(
              Icons.nightlight_round,
              size: 56,
              color: AppColors.lavenderLight,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Destined is only for adults',
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 12),
        const Text(
          'You must be 18 or older to use Destined.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.lavender, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final dob = _dob;
    final summary = dob == null ? null : ZodiacHelper.summary(dob);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceCard,
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Text(
            '18+',
            style: GoogleFonts.montserrat(
              color: AppColors.pinkLight,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Confirm your age', style: _titleStyle),
        const SizedBox(height: 8),
        const Text(
          'Destined is for adults 18 and over. Your date of birth is private; '
          'others only see your age and zodiac sign.',
          style: TextStyle(
            color: AppColors.lavender,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 32),
        const AuthLabel('Date of birth'),
        AuthPickerField(
          value: dob == null ? null : _formatDob(dob),
          placeholder: 'DD/MM/YYYY',
          icon: Icons.calendar_today_outlined,
          semanticLabel: 'Date of birth',
          onTap: _saving ? null : _pickDob,
        ),
        if (dob != null) ZodiacHelper(dob: dob),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppColors.lavender,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: summary == null
                        ? const [
                            TextSpan(
                              text:
                                  'Others only see your age and sign. '
                                  'Never the full date.',
                            ),
                          ]
                        : [
                            const TextSpan(text: 'On your profile: '),
                            TextSpan(
                              text: summary,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: '. Never the full date.'),
                          ],
                  ),
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AuthCheckRow(
          value: _confirmedAdult,
          onChanged: _saving
              ? null
              : (v) => setState(() => _confirmedAdult = v),
          label: const LegalText(
            prefix: 'I confirm I am 18 or older and agree to the ',
            suffix: '',
            textAlign: TextAlign.start,
            style: TextStyle(color: AppColors.white, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final error = _error;
    final email = FirebaseAuth.instance.currentUser?.email;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocked
            ? [
                CustomButton(
                  text: 'Sign out',
                  type: ButtonType.outline,
                  onPressed: () => AuthRouter.signOutToLogin(context),
                ),
                if (email != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Signed in as $email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 12,
                    ),
                  ),
                ],
              ]
            : [
                if (error != null) ...[
                  AppBanner(message: error, tone: AppBannerTone.error),
                  const SizedBox(height: 12),
                ],
                CustomButton(
                  text: 'Continue',
                  isLoading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
                const SizedBox(height: 4),
                CustomButton(
                  text: 'Sign out',
                  type: ButtonType.text,
                  onPressed: _saving
                      ? null
                      : () => AuthRouter.signOutToLogin(context),
                ),
              ],
      ),
    );
  }
}
