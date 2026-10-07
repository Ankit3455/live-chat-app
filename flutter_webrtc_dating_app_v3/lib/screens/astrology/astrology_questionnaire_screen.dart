import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/core/utils/haptics.dart';
import 'package:availchat/models/question_model.dart';
import 'package:availchat/models/question_type.dart';
import 'package:availchat/screens/questionnaire/deck/deck_models.dart';
import 'package:availchat/screens/questionnaire/deck/deck_runner.dart';
import 'package:availchat/screens/questionnaire/deck/deck_widgets.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';

/// "Your Stars": the astrology deck. Sun sign from DOB, belief level and
/// preferred signs. Finishing saves and pops back to the caller with `true`.
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
  // Finishing shows a confirmation briefly before popping.
  bool _saved = false;

  // A stored 'unsure' stays untouched until the user picks one of these.
  static const _beliefValues = ['no', 'somewhat', 'yes'];

  // Deck-only field names; answers live in the view model.
  static const _sunField = '_sunSign';
  static const _beliefField = '_belief';

  static final List<DeckCard> _cards = [
    const DeckCard([
      Question(
        text: 'Your sun sign',
        inputType: QuestionType.text,
        fieldName: _sunField,
        isMandatory: false,
        icon: '☀️',
      ),
    ]),
    const DeckCard([
      Question(
        text: 'Do you believe in the stars?',
        options: ['Not really', 'A little', 'Completely'],
        optionEmojis: ['🙂', '✨', '🔮'],
        optionQuips: ['Just for fun', 'Curious soul', 'Written in the stars'],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.scale,
        fieldName: _beliefField,
        isMandatory: false,
        icon: '🔮',
      ),
    ]),
    const DeckCard([
      Question(
        text: 'Signs you vibe with',
        inputType: QuestionType.multiChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'preferredSigns',
        isMandatory: false,
        icon: '♈',
      ),
    ]),
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

  /// The view model's state in the shape the deck reads.
  Map<String, dynamic> get _answers {
    final belief = _beliefValues.indexOf(_vm.belief ?? '');
    return {
      if (_vm.ownSign != null) _sunField: _vm.ownSign,
      if (belief >= 0) _beliefField: _cards[1].lead.options[belief],
      'preferredSigns': _vm.preferredSigns,
    };
  }

  void _onAnswer(String field, Object? value) {
    if (field == _beliefField && value is String) {
      final i = _cards[1].lead.options.indexOf(value);
      if (i >= 0) _vm.setBelief(_beliefValues[i]);
    }
  }

  Future<void> _save() async {
    if (_vm.isSaving || _saved) return;
    final uid = _uid;
    if (uid == null) {
      Haptics.error();
      _showSnack('Please log in again to save your answers.');
      return;
    }
    final ok = await _vm.save(uid);
    if (!mounted) return;
    if (!ok) {
      Haptics.error();
      _showSnack(
        "We couldn't save your astrology profile. Check your connection and try again.",
      );
      return;
    }
    Haptics.success();
    setState(() => _saved = true);
    _showSnack('Astrology profile saved');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDarkest,
      body: DeckBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedBuilder(
                animation: _vm,
                builder: (context, _) => DeckRunner(
                  eyebrow: 'Your stars',
                  cards: _cards,
                  answers: _answers,
                  busy: _vm.isSaving || _saved,
                  onAnswer: _onAnswer,
                  onFinish: _save,
                  onClose: () => Navigator.maybePop(context),
                  hintFor: (card) => switch (card.lead.fieldName) {
                    _sunField => 'Read from your birth date',
                    'preferredSigns' => 'Tap the signs',
                    _ => 'Slide to your spot',
                  },
                  customZone: _customZone,
                  artBuilder: _art,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The sun-sign and zodiac cards keep the animations the old astrology
  /// screens had; the belief card uses its icon.
  Widget? _art(BuildContext context, DeckCard card) {
    final asset = switch (card.lead.fieldName) {
      _sunField => AppAssets.starAnimation,
      'preferredSigns' => AppAssets.zodiacAnimation,
      _ => null,
    };
    if (asset == null) return null;
    return Lottie.asset(
      asset,
      width: 92,
      height: 92,
      fit: BoxFit.contain,
      animate: !MediaQuery.disableAnimationsOf(context),
      errorBuilder: (context, error, stackTrace) =>
          Text(card.lead.icon ?? '✦', style: const TextStyle(fontSize: 48)),
    );
  }

  Widget? _customZone(
    BuildContext context,
    DeckCard card,
    DeckRunnerState runner,
  ) {
    switch (card.lead.fieldName) {
      case _sunField:
        final sign = _vm.ownSign;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withOpacity(.75),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                _vm.isLoading
                    ? 'Reading your birth date…'
                    : sign == null
                        ? 'Not set yet'
                        : 'From your birth date',
                style: const TextStyle(color: AppColors.lavender, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                sign == null
                    ? '✦'
                    : '${AstrologyUtils.zodiacEmoji[sign] ?? ''} $sign',
                style: deckSerif(30),
              ),
              const SizedBox(height: 6),
              Text(
                sign == null
                    ? 'Add your date of birth in Edit profile to get your sign and compatibility scores.'
                    : 'Wrong sign? Update your birth date in Edit profile.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 12),
              DeckButton(
                label: sign == null ? 'Continue' : "That's me ✦",
                onPressed: _vm.isLoading
                    ? null
                    : sign == null
                        ? runner.next
                        : () => runner.reveal(
                              _sunField,
                              sign,
                              save: false,
                              emoji: AstrologyUtils.zodiacEmoji[sign],
                              quip: 'Your stars are set',
                            ),
              ),
            ],
          ),
        );
      case 'preferredSigns':
        final picked = _vm.preferredSigns;
        return Column(
          children: [
            ZodiacWheel(
              signs: AstrologyUtils.zodiacSigns,
              glyphs: AstrologyUtils.zodiacEmoji,
              selected: picked,
              ownSign: _vm.ownSign,
              onToggle: _vm.toggleSign,
            ),
            const SizedBox(height: 12),
            DeckButton(
              label: _saved
                  ? 'Saved ✦'
                  : _vm.hasChanges || picked.isNotEmpty
                      ? 'Save my stars ✦'
                      : 'Done',
              onPressed: _vm.isSaving || _saved ? null : _save,
            ),
          ],
        );
    }
    return null;
  }
}
