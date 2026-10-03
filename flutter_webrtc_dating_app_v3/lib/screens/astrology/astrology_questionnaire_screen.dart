import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/widgets/zodiac_sign_selector.dart';

const _bg = Color(0xFF1A0E2E);
const _card = Color(0xFF2D1B4E);
const _accent = Color(0xFF7B2CBF);
const _muted = Color(0xFFB39DDB);

/// Astrology profile: intro + 2 questions in one PageView (DEST-100).
/// Skip saves what was answered and closes; Save pops back to the caller
/// with `true`.
class AstrologyQuestionnaireScreen extends StatefulWidget {
  const AstrologyQuestionnaireScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyQuestionnaireScreen> createState() =>
      _AstrologyQuestionnaireScreenState();
}

class _AstrologyQuestionnaireScreenState
    extends State<AstrologyQuestionnaireScreen> {
  static const _questionCount = 2;

  final _pageController = PageController();
  final _vm = AstrologyViewModel();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  int _page = 0;

  static const _beliefChoices = [
    (value: 'yes', label: 'Yes, absolutely!', icon: Icons.star),
    (value: 'somewhat', label: 'Somewhat', icon: Icons.star_half),
    (value: 'no', label: 'Not really', icon: Icons.star_border),
    (value: 'unsure', label: 'Not sure', icon: Icons.help_outline),
  ];

  @override
  void initState() {
    super.initState();
    if (_uid != null) _vm.load(_uid!);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_page > 0) {
      _goTo(_page - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Saves answered fields, then closes. Used by Skip and Save.
  Future<void> _finish({required bool fromSave}) async {
    if (_vm.isSaving) return;
    final uid = _uid;
    if (uid == null) {
      _showSnack('Please sign in again to save your answers.');
      return;
    }
    final changed = _vm.hasChanges;
    final ok = await _vm.save(uid);
    if (!mounted) return;
    if (!ok) {
      _showSnack('Could not save. Check your connection and try again.');
      return;
    }
    if (fromSave || changed) {
      _showSnack(
        fromSave ? 'Astrology profile saved' : 'Your answers so far are saved',
      );
    }
    Navigator.of(context).pop(fromSave);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _vm,
            builder: (context, _) => PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                _buildIntro(),
                _buildQuestion(
                  step: 1,
                  title: 'Which zodiac signs attract you the most?',
                  subtitle:
                      'Select all that apply. These signs get a small boost '
                      'in your compatibility scores.',
                  body: ZodiacSignSelector(
                    selectedSigns: _vm.preferredSigns,
                    onToggle: _vm.toggleSign,
                  ),
                  buttonText: 'Continue',
                  onPressed: () => _goTo(2),
                ),
                _buildQuestion(
                  step: 2,
                  title: 'How much do you believe in astrology?',
                  body: Column(
                    children: [
                      for (final c in _beliefChoices)
                        _choiceTile(
                          label: c.label,
                          icon: c.icon,
                          selected: _vm.belief == c.value,
                          onTap: () => _vm.setBelief(c.value),
                        ),
                    ],
                  ),
                  buttonText: 'Save',
                  onPressed: () => _finish(fromSave: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    final theme = Theme.of(context).textTheme;
    final sign = _vm.ownSign;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Lottie.asset(
            'assets/animations/star_animation.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            animate: !MediaQuery.of(context).disableAnimations,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.auto_awesome, size: 120, color: _accent),
          ),
          const SizedBox(height: 24),
          Text(
            'Discover Your Cosmic Match',
            style: theme.headlineMedium?.copyWith(
              color: _accent,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ownSignCard(sign),
          const SizedBox(height: 16),
          Text(
            '${CompatibilityService.tooltip} Answer $_questionCount quick '
            'questions to complete your astrology profile.',
            style: theme.bodyLarge?.copyWith(color: _muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _primaryButton(
            text: 'Start',
            onPressed: _vm.isLoading ? null : () => _goTo(1),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: _muted, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownSignCard(String? sign) {
    final String text;
    if (_vm.isLoading) {
      text = 'Loading your sign...';
    } else if (sign != null) {
      text = 'Your sign: ${AstrologyUtils.zodiacEmoji[sign] ?? ''} $sign\n'
          '(from your date of birth)';
    } else {
      text = 'Add your date of birth to your profile to get your zodiac sign '
          'and compatibility scores.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuestion({
    required int step,
    required String title,
    String? subtitle,
    required Widget body,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        AstrologyProgressHeader(
          currentStep: step,
          totalSteps: _questionCount,
          onBack: _back,
          onSkip: _vm.isSaving ? null : () => _finish(fromSave: false),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 16),
                  ),
                ],
                const SizedBox(height: 24),
                body,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _primaryButton(
            text: buttonText,
            onPressed: _vm.isSaving ? null : onPressed,
            loading: _vm.isSaving && step == _questionCount,
          ),
        ),
      ],
    );
  }

  Widget _choiceTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selected ? _accent.withOpacity(0.15) : _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? _accent : _card, width: 2),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? _accent : _muted, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? _accent : Colors.white,
                      fontSize: 18,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (selected) const Icon(Icons.check_circle, color: _accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String text,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
