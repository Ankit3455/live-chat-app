import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/screens/astrology/widgets/zodiac_sign_selector.dart';
import 'package:availchat/widgets/app_states.dart';
import 'package:availchat/widgets/custom_button.dart';
import '../../core/constants/app_colors.dart';

/// Astrology profile on one screen (DEST-100): sun sign from DOB, belief
/// level and preferred signs. Save pops back to the caller with `true`.
class AstrologyQuestionnaireScreen extends StatefulWidget {
  const AstrologyQuestionnaireScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyQuestionnaireScreen> createState() =>
      _AstrologyQuestionnaireScreenState();
}

class _AstrologyQuestionnaireScreenState
    extends State<AstrologyQuestionnaireScreen> {
  final _vm = AstrologyViewModel();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // A stored 'unsure' stays untouched until the user picks one of these.
  static const _beliefChoices = [
    (value: 'no', label: 'Not really', emoji: '🙂'),
    (value: 'somewhat', label: 'A little', emoji: '✨'),
    (value: 'yes', label: 'Completely', emoji: '🔮'),
  ];

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null) _vm.load(uid);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_vm.isSaving) return;
    final uid = _uid;
    if (uid == null) {
      _showSnack('Please sign in again to save your answers.');
      return;
    }
    final ok = await _vm.save(uid);
    if (!mounted) return;
    if (!ok) {
      _showSnack('Could not save. Check your connection and try again.');
      return;
    }
    _showSnack('Astrology profile saved');
    Navigator.of(context).pop(true);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _vm,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.white,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your cosmic profile',
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Used for the compatibility score on profile cards.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sunSignCard(textTheme),
                      if (_vm.ownSign != null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Wrong sign? Update your birth date in Edit profile.',
                          style: TextStyle(
                            color: AppColors.textSubtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'How much do you believe in astrology?',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < _beliefChoices.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _beliefCard(
                                label: _beliefChoices[i].label,
                                emoji: _beliefChoices[i].emoji,
                                selected: _vm.belief == _beliefChoices[i].value,
                                onTap: () =>
                                    _vm.setBelief(_beliefChoices[i].value),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Signs you vibe with',
                              style: textTheme.titleLarge,
                            ),
                          ),
                          Text(
                            '${_vm.preferredSigns.length} selected',
                            style: const TextStyle(
                              color: AppColors.textSubtle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ZodiacSignSelector(
                        selectedSigns: _vm.preferredSigns,
                        onToggle: _vm.toggleSign,
                      ),
                      const SizedBox(height: 20),
                      const AppBanner(message: CompatibilityService.tooltip),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: CustomButton(
                  text: 'Save',
                  onPressed: _vm.isLoading || _vm.isSaving ? null : _save,
                  isLoading: _vm.isSaving,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sunSignCard(TextTheme textTheme) {
    final sign = _vm.ownSign;
    final String title;
    final String caption;
    if (_vm.isLoading) {
      title = 'Loading…';
      caption = 'Reading your birth date';
    } else if (sign != null) {
      title = sign;
      caption = 'From your birth date';
    } else {
      title = 'Not set yet';
      caption =
          'Add your date of birth to your profile to get your zodiac '
          'sign and compatibility scores.';
    }
    final glyph = sign == null ? null : AstrologyUtils.zodiacEmoji[sign];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withOpacity(0.16),
            AppColors.brandPurple.withOpacity(0.10),
          ],
          stops: const [0.0, 0.7],
        ),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withOpacity(0.45)),
            ),
            child: glyph != null
                ? Text(
                    glyph,
                    style: const TextStyle(fontSize: 34, color: AppColors.gold),
                  )
                : const Icon(
                    Icons.auto_awesome,
                    size: 30,
                    color: AppColors.gold,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUN SIGN',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(title, style: textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _beliefCard({
    required String label,
    required String emoji,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(14);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.brandPurpleMid.withOpacity(0.14)
            : AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.brandPurpleMid : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.brandPurple : null,
                      border: Border.all(
                        color: selected
                            ? AppColors.brandPurpleMid
                            : AppColors.borderStrong,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: AppColors.white,
                          )
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
