import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../models/question_model.dart';
import '../../../models/question_type.dart';
import 'deck_models.dart';
import 'deck_widgets.dart';

enum DeckLeading { close, back }

/// The card deck engine shared by every questionnaire: a tarot card per
/// [DeckCard], a constellation of progress, the answer controls under the
/// card and the "spread" tray. Storage stays with the caller: every answer
/// goes through [onAnswer] and the caller updates [answers].
///
/// Cards whose questions are mandatory have no Skip and block moving past
/// them until answered.
class DeckRunner extends StatefulWidget {
  final String eyebrow;
  final List<DeckCard> cards;
  final Map<String, dynamic> answers;
  final void Function(String field, Object? value) onAnswer;

  /// After the last card, or from the tray action.
  final VoidCallback onFinish;

  /// ✕ (close) or back on the first card.
  final VoidCallback? onClose;
  final DeckLeading leading;
  final int startIndex;

  /// Tray link that finishes early (e.g. "See reading →"); null hides it.
  final String? trayAction;

  /// Shown briefly after each answer; null shows nothing.
  final String? savedToast;

  /// Caller is saving: input is disabled.
  final bool busy;

  /// Art in the card's circle; defaults to the question icon.
  final Widget Function(BuildContext context, DeckCard card)? artBuilder;

  /// Controls for cards that are not plain questions (e.g. a zodiac wheel).
  /// Return null to use the standard controls.
  final Widget? Function(
    BuildContext context,
    DeckCard card,
    DeckRunnerState runner,
  )? customZone;

  /// Hint on the card front; defaults by deck style.
  final String Function(DeckCard card)? hintFor;

  const DeckRunner({
    super.key,
    required this.eyebrow,
    required this.cards,
    required this.answers,
    required this.onAnswer,
    required this.onFinish,
    this.onClose,
    this.leading = DeckLeading.close,
    this.startIndex = 0,
    this.trayAction,
    this.savedToast,
    this.busy = false,
    this.artBuilder,
    this.customZone,
    this.hintFor,
  });

  @override
  State<DeckRunner> createState() => DeckRunnerState();
}

class DeckRunnerState extends State<DeckRunner> with TickerProviderStateMixin {
  late int _i = widget.startIndex.clamp(0, widget.cards.length - 1);
  late final AnimationController _flip = AnimationController(vsync: this);
  late final AnimationController _away = AnimationController(vsync: this);
  late final AnimationController _enter =
      AnimationController(vsync: this, value: 1);

  bool _busy = false;
  ({String answer, String? emoji, String? quip})? _revealed;
  bool _toast = false;
  Timer? _toastTimer;

  List<DeckCard> get _cards => widget.cards;
  Map<String, dynamic> get _answers => widget.answers;
  DeckCard get _card => _cards[_i];
  int get index => _i;

  static bool isRequired(DeckCard card) =>
      card.questions.any((q) => q.isMandatory);

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

  // ---------- Answers ----------

  void _answer(String field, Object? value) {
    widget.onAnswer(field, value);
    setState(() {});
    final text = widget.savedToast;
    if (text == null) return;
    _toastTimer?.cancel();
    setState(() => _toast = true);
    _toastTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _toast = false);
    });
  }

  /// Saves [value] for [field] (unless [save] is false), flips the card to
  /// show [answer], then moves on.
  Future<void> reveal(
    String field,
    String answer, {
    Object? value,
    String? emoji,
    String? quip,
    bool save = true,
    Duration hold = const Duration(milliseconds: 650),
  }) async {
    if (_busy || widget.busy) return;
    _busy = true;
    Haptics.light();
    if (save) _answer(field, value ?? answer);
    setState(() => _revealed = (answer: answer, emoji: emoji, quip: quip));
    await _flip.forward(from: 0);
    await Future<void>.delayed(
      _flip.duration == Duration.zero
          ? const Duration(milliseconds: 400)
          : hold,
    );
    if (!mounted) return;
    await _away.forward(from: 0);
    if (!mounted) return;
    _busy = false;
    next();
  }

  void _revealOption(Question q, String option) => reveal(
        q.fieldName,
        option,
        emoji: q.emojiFor(option) ?? q.icon,
        quip: q.quipFor(option),
      );

  void _toggle(Question q, String option) {
    var list = [...listOf(q.fieldName)];
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
    _answer(q.fieldName, list);
  }

  // ---------- Navigation ----------

  /// Index of the first unanswered required card, or the deck length.
  int get _firstBlocked {
    final i = _cards.indexWhere((c) => isRequired(c) && !c.isDone(_answers));
    return i < 0 ? _cards.length : i;
  }

  void goTo(int target) {
    if (_busy) return;
    if (target > _firstBlocked) {
      Haptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer the required card first.')),
      );
      target = _firstBlocked;
    }
    _flip.value = 0;
    _away.value = 0;
    setState(() {
      _i = target;
      _revealed = null;
    });
    _enter.forward(from: 0);
  }

  void next() {
    if (_i < _cards.length - 1) {
      goTo(_i + 1);
    } else {
      widget.onFinish();
    }
  }

  bool get canGoBack => _i > 0;

  void back() {
    if (_i > 0) {
      goTo(_i - 1);
    } else {
      widget.onClose?.call();
    }
  }

  // ---------- Helpers ----------

  List<String> listOf(String field) {
    final v = _answers[field];
    if (v is List)
      return v.whereType<Object>().map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  String cardEmoji(DeckCard card) {
    final q = card.lead;
    final v = _answers[q.fieldName];
    if (card.questions.length == 1 &&
        v is String &&
        q.deckStyle != DeckStyle.write) {
      return q.emojiFor(v) ?? q.icon ?? '✦';
    }
    return q.icon ?? '✦';
  }

  String _hint(DeckCard card) {
    final custom = widget.hintFor;
    if (custom != null) return custom(card);
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
      case DeckStyle.write:
        return (q.maxLength ?? 0) > 120 ? 'Write a few lines' : 'Type it in';
      case DeckStyle.fan:
        return 'Draw one card below';
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final required = isRequired(_card);
    return Stack(
      children: [
        Column(
          children: [
            _topBar(showSkip: !required),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Constellation(
                lit: [for (final c in _cards) c.isDone(_answers)],
                current: _i,
                onTap: goTo,
              ),
            ),
            SizedBox(height: 300, child: _buildCardStack(required)),
            Expanded(
              child: AbsorbPointer(
                absorbing: widget.busy,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: KeyedSubtree(
                    key: ValueKey('zone-$_i'),
                    child: widget.customZone?.call(context, _card, this) ??
                        _buildZone(),
                  ),
                ),
              ),
            ),
            _buildTray(),
          ],
        ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xF2160F25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.gold.withOpacity(.4)),
                  ),
                  child: Text(
                    widget.savedToast ?? '',
                    style: const TextStyle(
                      color: deckGoldLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar({required bool showSkip}) {
    final lit = _cards.where((c) => c.isDone(_answers)).length;
    final back = widget.leading == DeckLeading.back;
    final showLeading = !back || _i > 0 || widget.onClose != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: showLeading
                ? DeckIconButton(
                    icon: back
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.close_rounded,
                    label: back ? 'Back' : 'Close',
                    onTap: back ? this.back : () => widget.onClose?.call(),
                  )
                : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.eyebrow.toUpperCase(),
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
                    color: AppColors.textSubtle,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: showSkip
                ? TextButton(
                    onPressed: _busy || widget.busy ? null : next,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: AppColors.lavender),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack(bool required) {
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
            final revealed = _revealed;
            final face = f >= .5 && revealed != null
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: CardBack(
                      answer: revealed.answer,
                      emoji: revealed.emoji,
                      quip: revealed.quip,
                    ),
                  )
                : CardFront(
                    index: _i,
                    question: q,
                    hint: _hint(_card),
                    required: required,
                    art: widget.artBuilder?.call(context, _card),
                  );
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
              selected: listOf(g.fieldName),
              onTap: (o) => _toggle(g, o),
            ),
          const SizedBox(height: 14),
          _doneButton(card.isDone(_answers), required: isRequired(card)),
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
          onPick: (v) => _revealOption(q, v),
        );
      case DeckStyle.scale:
        return ScaleDial(
          key: ValueKey(q.fieldName),
          question: q,
          selected: single,
          onLock: (v) => _revealOption(q, v),
        );
      case DeckStyle.write:
        return DeckWriteField(
          key: ValueKey(q.fieldName),
          question: q,
          initial: single ?? '',
          submitLabel: _i == _cards.length - 1 ? 'Finish ✦' : 'Continue ✦',
          onSubmit: (text) {
            _answer(q.fieldName, text.isEmpty ? null : text);
            next();
          },
        );
      case DeckStyle.stickers:
        if (q.inputType != QuestionType.multiChoice) {
          return StickerPicker(
            question: q,
            selected: listOf(q.fieldName),
            onTap: (v) => _revealOption(q, v),
          );
        }
        final picked = listOf(q.fieldName);
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
            _doneButton(picked.isNotEmpty, required: q.isMandatory),
          ],
        );
    }
  }

  Widget _doneButton(bool answered, {required bool required}) {
    final last = _i == _cards.length - 1;
    if (!answered && required) {
      return const DeckButton(label: 'Pick at least one', onPressed: null);
    }
    return DeckButton(
      label: !answered
          ? 'Skip for now'
          : last
              ? 'Finish ✦'
              : 'Done ✦',
      onPressed: widget.busy ? null : next,
    );
  }

  Widget _buildTray() {
    final action = widget.trayAction;
    return Padding(
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
              if (action != null)
                GestureDetector(
                  onTap: _busy || widget.busy ? null : widget.onFinish,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      action,
                      style: const TextStyle(
                        color: AppColors.brandPurpleLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${_cards.where((c) => c.isDone(_answers)).length}/${_cards.length}',
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                    onTap: () => goTo(k),
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
                        done ? cardEmoji(_cards[k]) : '·',
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
}
