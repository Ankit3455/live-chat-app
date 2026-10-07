import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/vibe_line.dart';
import '../../../managers/profile_completion_manager.dart';
import 'deck_models.dart';
import 'deck_runner.dart';
import 'deck_widgets.dart';

/// One profile deck (Lifestyle or Personality): each answer is saved to
/// `users/{uid}` as soon as it is given, ending in a "reading".
/// [answers] is the caller's copy of the user doc and is updated in place.
class DestinyDeckScreen extends StatefulWidget {
  final DeckSection section;
  final Map<String, dynamic> answers;
  final int startIndex;
  final int startPercent;

  const DestinyDeckScreen({
    super.key,
    required this.section,
    required this.answers,
    required this.startPercent,
    this.startIndex = 0,
  });

  /// First card without an answer, or 0 when all are answered.
  static int firstOpen(DeckSection section, Map<String, dynamic> answers) {
    final i = section.cards.indexWhere((c) => !c.isDone(answers));
    return i < 0 ? 0 : i;
  }

  @override
  State<DestinyDeckScreen> createState() => _DestinyDeckScreenState();
}

class _DestinyDeckScreenState extends State<DestinyDeckScreen> {
  late final List<DeckCard> _cards = widget.section.cards;
  final _runner = GlobalKey<DeckRunnerState>();
  bool _reading = false;
  int? _endPercent;
  int _resumeAt = 0;

  Map<String, dynamic> get _answers => widget.answers;

  @override
  void initState() {
    super.initState();
    _resumeAt = widget.startIndex;
  }

  void _save(String field, Object? value) {
    setState(() {
      if (isAnswered(value)) {
        _answers[field] = value;
      } else {
        _answers.remove(field);
      }
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).set(
        {field: answerWriteValue(value)},
        SetOptions(merge: true)).catchError((Object e) {
      debugPrint('Deck save failed: $e');
      if (!mounted) return;
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "We couldn't save that answer. Check your connection and try again.",
          ),
          backgroundColor: AppColors.error,
        ),
      );
    });

    final section = widget.section;
    if (_answers[section.completedFlag] != true &&
        section.answeredCount(_answers) >= section.threshold) {
      _answers[section.completedFlag] = true;
      section.markComplete().catchError(
            (Object e) => debugPrint('Mark section complete failed: $e'),
          );
    }
  }

  Future<void> _openReading() async {
    setState(() => _reading = true);
    if (widget.section.isComplete(_answers)) Haptics.success();
    try {
      final pct = await ProfileCompletionManager().getCompletionPercentage();
      if (mounted) setState(() => _endPercent = pct);
    } catch (e) {
      debugPrint('Completion % failed: $e');
    }
  }

  void _editFromReading(int index) {
    setState(() {
      _resumeAt = index;
      _reading = false;
    });
  }

  List<String> _listOf(String field) {
    final v = _answers[field];
    if (v is List)
      return v.whereType<Object>().map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  String _cardEmoji(DeckCard card) {
    final q = card.lead;
    final v = _answers[q.fieldName];
    if (card.questions.length == 1 && v is String) {
      return q.emojiFor(v) ?? q.icon ?? '✦';
    }
    return q.icon ?? '✦';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDarkest,
      body: DeckBackground(
        child: SafeArea(
          child: _reading
              ? _buildReading()
              : DeckRunner(
                  key: _runner,
                  eyebrow: widget.section.title,
                  cards: _cards,
                  answers: _answers,
                  startIndex: _resumeAt,
                  onAnswer: _save,
                  onFinish: _openReading,
                  onClose: () => Navigator.of(context).pop(),
                  trayAction: 'See reading →',
                  savedToast: '✦ Saved to your profile',
                ),
        ),
      ),
    );
  }

  // ---------- Reading ----------

  String _readingLabel(DeckCard card) {
    final all = [for (final q in card.questions) ..._listOf(q.fieldName)];
    if (all.isEmpty) return 'Skipped';
    if (card.questions.length == 1 && _answers[card.lead.fieldName] is String) {
      return all.first;
    }
    return all.take(2).join(', ') +
        (all.length > 2 ? ' +${all.length - 2}' : '');
  }

  Widget _buildReading() {
    final section = widget.section;
    final complete = section.isComplete(_answers);
    final vibe = VibeLine.from(_answers);
    final otherDone = section.other.isComplete(_answers);
    final end = _endPercent;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: DeckIconButton(
              icon: Icons.close_rounded,
              label: 'Close',
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              children: [
                Text(
                  '${section.roman} · YOUR READING',
                  style: deckSerif(14, color: AppColors.gold, italic: true)
                      .copyWith(letterSpacing: 2.5),
                ),
                const SizedBox(height: 4),
                Text(
                  complete
                      ? 'The ${section.title} constellation'
                      : 'Half a constellation…',
                  textAlign: TextAlign.center,
                  style: deckSerif(32),
                ),
                Constellation(
                  lit: [for (final c in _cards) c.isDone(_answers)],
                  height: 140,
                  swing: 38,
                ),
                if (vibe != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '“$vibe”',
                      textAlign: TextAlign.center,
                      style: deckSerif(20, color: deckGoldLight, italic: true)
                          .copyWith(height: 1.35),
                    ),
                  ),
                if (!complete)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Answer ${section.threshold - section.answeredCount(_answers)} more to complete this deck. Your answers so far are saved.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.lavender, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withOpacity(.85),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${widget.startPercent}%  →  ',
                        style: const TextStyle(color: AppColors.textSubtle),
                      ),
                      TextSpan(
                        text: end == null ? '…' : '$end%',
                        style: const TextStyle(color: AppColors.success),
                      ),
                      const TextSpan(text: '  profile strength'),
                    ]),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: .92,
                  children: [
                    for (var k = 0; k < _cards.length; k++) _readingCard(k),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap any card to change it.',
                  style: TextStyle(color: AppColors.textSubtle, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
          child: otherDone
              ? DeckButton(
                  label: 'Back to profile',
                  height: 52,
                  onPressed: () => Navigator.of(context).pop(),
                )
              : Row(
                  children: [
                    DeckButton(
                      label: 'Later',
                      ghost: true,
                      height: 52,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DeckButton(
                        label: 'Draw ${section.other.roman} →',
                        height: 52,
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => DestinyDeckScreen(
                              section: section.other,
                              answers: _answers,
                              startPercent: end ?? widget.startPercent,
                              startIndex: DestinyDeckScreen.firstOpen(
                                  section.other, _answers),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _readingCard(int k) {
    final card = _cards[k];
    final label = _readingLabel(card);
    final skipped = label == 'Skipped';
    final q = card.lead;
    return Semantics(
      button: true,
      label: '${q.text}: $label. Edit',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _editFromReading(k),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: skipped
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A1B47), Color(0xFF160D2A)],
                  ),
            color: skipped ? AppColors.surfaceCard.withOpacity(.45) : null,
            border: Border.all(
              color: skipped
                  ? AppColors.brandPurpleLight.withOpacity(.18)
                  : AppColors.gold.withOpacity(.3),
            ),
          ),
          child: Opacity(
            opacity: skipped ? .6 : 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_cardEmoji(card), style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: deckSerif(
                    skipped ? 13 : 15,
                    color: skipped ? AppColors.textSubtle : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  q.text.replaceAll('?', '').toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 8.5,
                    letterSpacing: .4,
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
