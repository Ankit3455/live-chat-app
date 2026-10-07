import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/vibe_line.dart';
import '../../../managers/profile_completion_manager.dart';
import '../../../models/question_model.dart';
import '../../../models/question_type.dart';
import 'deck_models.dart';
import 'deck_widgets.dart';

/// One deck (Lifestyle or Personality): a card per question, each answer
/// saved to `users/{uid}` as soon as it is given, ending in a "reading".
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

class _DestinyDeckScreenState extends State<DestinyDeckScreen>
    with TickerProviderStateMixin {
  late final List<DeckCard> _cards = widget.section.cards;
  late int _i = widget.startIndex.clamp(0, _cards.length - 1);
  late final AnimationController _flip = AnimationController(vsync: this);
  late final AnimationController _away = AnimationController(vsync: this);
  late final AnimationController _enter =
      AnimationController(vsync: this, value: 1);

  bool _busy = false;
  bool _reading = false;
  int? _endPercent;
  String? _revealed;
  bool _toast = false;
  Timer? _toastTimer;

  Map<String, dynamic> get _answers => widget.answers;
  DeckCard get _card => _cards[_i];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _flip.duration = still ? Duration.zero : const Duration(milliseconds: 600);
    _away.duration = still ? Duration.zero : const Duration(milliseconds: 400);
    _enter.duration = still ? Duration.zero : const Duration(milliseconds: 450);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _flip.dispose();
    _away.dispose();
    _enter.dispose();
    super.dispose();
  }

  // ---------- Saving ----------

  void _save(String field, Object? value) {
    setState(() {
      if (isAnswered(value)) {
        _answers[field] = value;
      } else {
        _answers.remove(field);
      }
    });
    _showToast();
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

  void _showToast() {
    _toastTimer?.cancel();
    setState(() => _toast = true);
    _toastTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _toast = false);
    });
  }

  // ---------- Card flow ----------

  /// Single-choice answer: save, flip to reveal, fly away, next card.
  Future<void> _reveal(Question q, String value) async {
    if (_busy) return;
    _busy = true;
    Haptics.light();
    _save(q.fieldName, value);
    setState(() => _revealed = value);
    await _flip.forward(from: 0);
    await Future<void>.delayed(
      _flip.duration == Duration.zero
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 650),
    );
    if (!mounted) return;
    await _away.forward(from: 0);
    if (!mounted) return;
    _busy = false;
    _next();
  }

  void _toggle(Question q, String option) {
    final current = _answers[q.fieldName];
    var list = current is List
        ? current.map((e) => e.toString()).toList()
        : <String>[];
    if (list.contains(option)) {
      list.remove(option);
    } else if (q.exclusiveOptions.contains(option)) {
      list = [option];
    } else {
      list.removeWhere(q.exclusiveOptions.contains);
      if (q.maxSelections == null || list.length < q.maxSelections!) {
        list.add(option);
      }
    }
    Haptics.selection();
    _save(q.fieldName, list);
  }

  void _goTo(int index) {
    if (_busy) return;
    _flip.value = 0;
    _away.value = 0;
    setState(() {
      _i = index;
      _revealed = null;
    });
    _enter.forward(from: 0);
  }

  void _next() {
    if (_i < _cards.length - 1) {
      _goTo(_i + 1);
    } else {
      _openReading();
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
    setState(() => _reading = false);
    _goTo(index);
  }

  // ---------- Helpers ----------

  List<String> _listOf(String field) {
    final v = _answers[field];
    if (v is List) return v.map((e) => e.toString()).toList();
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

  String _hint(DeckCard card) {
    final q = card.lead;
    if (card.questions.length > 1) {
      return 'Collect up to ${q.maxSelections ?? 5} each';
    }
    switch (q.deckStyle) {
      case DeckStyle.scale:
        return 'Slide to your spot';
      case DeckStyle.stickers:
        return q.inputType == QuestionType.multiChoice
            ? 'Collect up to ${q.maxSelections ?? q.options.length}'
            : 'Tap one';
      case DeckStyle.fan:
        return 'Draw one card below';
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDarkest,
      body: DeckBackground(
        child: SafeArea(
          child: Stack(
            children: [
              _reading ? _buildReading() : _buildDeck(),
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _toast ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xF2160F25),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: AppColors.gold.withOpacity(.4)),
                        ),
                        child: const Text(
                          '✦ Saved to your profile',
                          style: TextStyle(
                              color: deckGoldLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar({required bool showSkip}) {
    final lit = _cards.where((c) => c.isDone(_answers)).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
      child: Row(
        children: [
          DeckIconButton(
            icon: Icons.close_rounded,
            label: 'Close',
            onTap: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: showSkip
                ? Column(
                    children: [
                      Text(
                        widget.section.title.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .5,
                        ),
                      ),
                      Text(
                        'Card ${_i + 1} of ${_cards.length} · $lit stars lit',
                        style: const TextStyle(
                            color: AppColors.textSubtle, fontSize: 11),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(
            width: 56,
            child: showSkip
                ? TextButton(
                    onPressed: _busy ? null : _next,
                    child: const Text('Skip',
                        style: TextStyle(color: AppColors.lavender)),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDeck() {
    return Column(
      children: [
        _topBar(showSkip: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Constellation(
            lit: [for (final c in _cards) c.isDone(_answers)],
            current: _i,
            onTap: _goTo,
          ),
        ),
        SizedBox(height: 300, child: _buildCardStack()),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: KeyedSubtree(
              key: ValueKey('zone-${widget.section.name}-$_i'),
              child: _buildZone(),
            ),
          ),
        ),
        _buildTray(),
      ],
    );
  }

  Widget _buildCardStack() {
    final q = _card.lead;
    Widget behind(double dy, double scale, double opacity) =>
        Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: const SizedBox(
                width: 232,
                height: 286,
                child: TarotFrame(child: SizedBox.expand()),
              ),
            ),
          ),
        );
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_i < _cards.length - 2) behind(-24, .92, .25),
        if (_i < _cards.length - 1) behind(-12, .96, .55),
        AnimatedBuilder(
          animation: Listenable.merge([_flip, _away, _enter]),
          builder: (context, _) {
            final f = Curves.easeInOutCubic.transform(_flip.value);
            final a = Curves.easeInCubic.transform(_away.value);
            final e = Curves.easeOutBack.transform(_enter.value);
            final showBack = f >= .5 && _revealed != null;
            final face = showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: CardBack(
                      answer: _revealed!,
                      emoji: q.emojiFor(_revealed!) ?? q.icon,
                      quip: q.quipFor(_revealed!),
                    ),
                  )
                : CardFront(index: _i, question: q, hint: _hint(_card));
            return Opacity(
              opacity: ((1 - a) * _enter.value).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -420 * a + (1 - e) * 60),
                child: Transform.scale(
                  scale: (1 - .65 * a) * (.9 + .1 * e),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0012)
                      ..rotateZ(-.14 * a)
                      ..rotateY(f * math.pi),
                    child: SizedBox(width: 232, height: 286, child: face),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildZone() {
    final card = _card;
    final q = card.lead;
    if (card.questions.length > 1) {
      return Column(
        children: [
          for (final g in card.questions)
            StickerPicker(
              question: g,
              label: g.deckLabel ?? g.text,
              selected: _listOf(g.fieldName),
              onTap: (o) => _toggle(g, o),
            ),
          const SizedBox(height: 14),
          DeckButton(
            label: card.isDone(_answers) ? 'Done ✦' : 'Pick at least one',
            onPressed: card.isDone(_answers) ? _next : null,
          ),
        ],
      );
    }
    final single = _answers[q.fieldName] is String
        ? _answers[q.fieldName] as String
        : null;
    switch (q.deckStyle) {
      case DeckStyle.fan:
        return OptionFan(
          question: q,
          selected: single,
          onPick: (v) => _reveal(q, v),
        );
      case DeckStyle.scale:
        return ScaleDial(
          key: ValueKey(q.fieldName),
          question: q,
          selected: single,
          onLock: (v) => _reveal(q, v),
        );
      case DeckStyle.stickers:
        if (q.inputType != QuestionType.multiChoice) {
          return StickerPicker(
            question: q,
            selected: _listOf(q.fieldName),
            onTap: (v) => _reveal(q, v),
          );
        }
        final picked = _listOf(q.fieldName);
        return Column(
          children: [
            StickerPicker(
              question: q,
              selected: picked,
              onTap: (o) => _toggle(q, o),
            ),
            const SizedBox(height: 8),
            Text(
              '${picked.length}${q.maxSelections != null ? '/${q.maxSelections}' : ''} collected',
              style:
                  const TextStyle(color: AppColors.textSubtle, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            DeckButton(
              label: picked.isEmpty ? 'Pick at least one' : 'Done ✦',
              onPressed: picked.isEmpty ? null : _next,
            ),
          ],
        );
    }
  }

  Widget _buildTray() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'YOUR SPREAD',
                style: TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _busy ? null : _openReading,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'See reading →',
                    style: TextStyle(
                      color: AppColors.brandPurpleLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, k) {
                final done = _cards[k].isDone(_answers);
                return Semantics(
                  button: true,
                  label: 'Card ${k + 1}, ${done ? 'answered' : 'not answered'}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => _goTo(k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: done
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF2E1F4D), Color(0xFF1B1132)],
                              )
                            : null,
                        color:
                            done ? null : AppColors.surfaceCard.withOpacity(.5),
                        border: Border.all(
                          color: k == _i
                              ? Colors.white
                              : done
                                  ? AppColors.gold.withOpacity(.55)
                                  : AppColors.brandPurpleLight.withOpacity(.2),
                          width: k == _i ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        done ? _cardEmoji(_cards[k]) : '·',
                        style: TextStyle(
                          fontSize: done ? 17 : 14,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
        _topBar(showSkip: false),
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
