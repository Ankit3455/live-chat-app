// lib/feature/games/chat_games/chat_game_views.dart
//
// The per-game parts of ChatGameScreen: the round question, the picker, the
// reveal line and the result body. The screen draws everything around them.

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

import 'build_our_date/widgets/date_card_tile.dart';
import 'chat_game.dart';
import 'chat_game_logic.dart';
import 'flags/flag_statements.dart';
import 'telepathy/telepathy_picker.dart';
import 'telepathy/telepathy_prompts.dart';
import 'ui/game_ui.dart';
import 'widgets/choice_button.dart';
import 'widgets/premium_pickers.dart';

class ChatGameView {
  final ChatGame game;
  final String myUid;
  final String otherName;
  final bool busy;
  final ValueChanged<Object> onPick;

  const ChatGameView({
    required this.game,
    required this.myUid,
    required this.otherName,
    required this.busy,
    required this.onPick,
  });

  String get otherUid => game.otherOf(myUid);
  int get round => game.round;
  Object? get myPick => game.pickOf(round, myUid);
  bool get canPick =>
      myPick == null && !busy && game.isActive && game.bothJoined;

  GameTheme get theme => GameTheme.of(game.kind.name);

  // ---------- round ----------

  String question() {
    switch (game.kind) {
      case ChatGameKind.date:
        final q = ChatGameLogic.dateQuestionAt(game, round);
        return q == null ? '' : '${q.emoji} ${q.prompt}';
      case ChatGameKind.rate:
        final t = ChatGameLogic.rateTopicAt(game, round);
        return t == null ? '' : '${t.emoji} ${t.label}';
      case ChatGameKind.flags:
        return 'Red flag or green flag?';
      case ChatGameKind.telepathy:
        final p = TelepathyPrompts.byId(_item(round));
        return p == null ? '' : '"${p.label}"';
    }
  }

  String? hint() {
    switch (game.kind) {
      case ChatGameKind.date:
        return 'Pick one in secret. Same answer as $otherName = match!';
      case ChatGameKind.rate:
        return 'Slide to rate, then lock it in.';
      case ChatGameKind.flags:
        return 'Swipe the card, or tap a button.';
      case ChatGameKind.telepathy:
        return 'Pick the 3 emojis you think $otherName will pick.';
    }
  }

  Widget picker() {
    switch (game.kind) {
      case ChatGameKind.date:
        return _datePicker();
      case ChatGameKind.rate:
        return _ratePicker();
      case ChatGameKind.flags:
        return _flagPicker();
      case ChatGameKind.telepathy:
        final pick = myPick;
        return TelepathyPicker(
          choices: game.deck[round].skip(1).toList(),
          locked: pick == null ? null : TelepathyPrompts.asPick(pick),
          enabled: canPick,
          theme: theme,
          onSubmit: onPick,
        );
    }
  }

  String? _item(int r) => r < game.deck.length && game.deck[r].isNotEmpty
      ? game.deck[r].first
      : null;

  Widget _datePicker() {
    final pick = myPick;
    final options =
        ChatGameLogic.dateQuestionAt(game, round)?.options ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          ChoiceButton(
            label: options[i],
            fontSize: 17,
            accent: theme.a,
            selected: pick == i,
            dimmed: pick != null && pick != i,
            onTap: canPick ? () => onPick(i) : null,
          ),
        ],
      ],
    );
  }

  Widget _ratePicker() {
    final pick = myPick;
    return RateDial(
      key: ValueKey('rate$round'),
      theme: theme,
      locked: pick is int ? pick : null,
      enabled: canPick,
      onSubmit: onPick,
    );
  }

  Widget _flagPicker() {
    final pick = myPick;
    final s = FlagStatements.byId(_item(round));
    return SwipeVote(
      key: ValueKey('flag$round'),
      text: s?.text ?? '',
      locked: pick is String ? pick : null,
      enabled: canPick,
      onVote: onPick,
    );
  }

  /// Both answers of a finished round for the flip cards, and whether they
  /// match.
  (String, String, bool) revealPair(int r) {
    final mine = game.pickOf(r, myUid);
    final theirs = game.pickOf(r, otherUid);
    String show(String uid) {
      final v = game.pickOf(r, uid);
      if (v == null) return '⏱️';
      switch (game.kind) {
        case ChatGameKind.date:
          return _dateAnswer(r, uid);
        case ChatGameKind.rate:
          return v is int ? '${RateDial.faceFor(v)} $v' : '?';
        case ChatGameKind.flags:
          return FlagStatements.emojiOf(v);
        case ChatGameKind.telepathy:
          return TelepathyPrompts.asPick(v).join(' ');
      }
    }

    final same = switch (game.kind) {
      ChatGameKind.date => ChatGameLogic.dateMatched(game, r),
      ChatGameKind.rate => mine != null && mine == theirs,
      ChatGameKind.flags => ChatGameLogic.flagsAgree(game, r),
      ChatGameKind.telepathy =>
        ChatGameLogic.sharedEmojis(game, r).length ==
            TelepathyPrompts.picksPerRound,
    };
    return (show(myUid), show(otherUid), same);
  }

  /// [uid]'s date answer as I read it: their "Me" / "You" become names.
  String _dateAnswer(int r, String uid) {
    final who = ChatGameLogic.dateWho(game, r, uid);
    if (who != null && uid != myUid) {
      return who == myUid ? ChatGameLogic.dateYouOption : '🙋 $otherName';
    }
    final choice = ChatGameLogic.dateChoice(game, r, uid);
    return ChatGameLogic.dateOption(game, r, choice) ?? '?';
  }

  // ---------- reveal (round that just finished) ----------

  /// "⏱️ Bob didn't pick in time" for a round that timed out; null if both
  /// picked.
  String? _timedOut(int r) {
    final mine = game.pickOf(r, myUid) != null;
    final theirs = game.pickOf(r, otherUid) != null;
    if (mine && theirs) return null;
    if (!mine && !theirs) return "⏱️ Time's up! Nobody picked";
    return mine
        ? "⏱️ $otherName didn't pick in time"
        : "⏱️ You didn't pick in time";
  }

  String reveal(int r) {
    final timedOut = _timedOut(r);
    switch (game.kind) {
      case ChatGameKind.date:
        if (timedOut != null) return '$timedOut. No match this round.';
        final emoji = ChatGameLogic.dateQuestionAt(game, r)?.emoji ?? '';
        final who = ChatGameLogic.dateAgreedWho(game, r);
        if (who != null) {
          return '✨ Match! You both said: ${who == myUid ? 'you' : otherName}';
        }
        if (ChatGameLogic.dateMatched(game, r)) {
          final answer = ChatGameLogic.dateOption(
            game,
            r,
            ChatGameLogic.dateChoice(game, r, myUid),
          );
          return '✨ Match! You both picked $emoji ${answer ?? ''}'.trim();
        }
        return '$emoji Different picks this time. Next one!'.trim();
      case ChatGameKind.rate:
        final mine = ChatGameLogic.rating(game, r, myUid);
        final theirs = ChatGameLogic.rating(game, r, otherUid);
        final t = ChatGameLogic.rateTopicAt(game, r);
        if (t == null) return '';
        if (mine == null || theirs == null) return '$timedOut ${t.emoji}';
        if (mine == theirs) {
          return '✨ ${t.emoji} Both gave $mine. Perfect sync!';
        }
        final gap = (mine - theirs).abs();
        return '${t.emoji} You: $mine · $otherName: $theirs '
            '(${gap == 1 ? 'just 1 apart' : '$gap apart'})';
      case ChatGameKind.flags:
        final mine = game.pickOf(r, myUid);
        final theirs = game.pickOf(r, otherUid);
        if (timedOut != null) return timedOut;
        if (mine == theirs) {
          return '✨ You both said ${FlagStatements.emojiOf(mine)} '
              '${mine == FlagStatements.red ? 'red flag' : 'green flag'}';
        }
        return 'You: ${FlagStatements.emojiOf(mine)} · '
            '$otherName: ${FlagStatements.emojiOf(theirs)}. Talk it out 😄';
      case ChatGameKind.telepathy:
        if (timedOut != null) return '$timedOut. No points this round.';
        final shared = ChatGameLogic.sharedEmojis(game, r);
        final mine = TelepathyPrompts.asPick(game.pickOf(r, myUid)).join(' ');
        final theirs = TelepathyPrompts.asPick(
          game.pickOf(r, otherUid),
        ).join(' ');
        if (shared.length == TelepathyPrompts.picksPerRound) {
          return '🧠 Mind meld! You both picked ${shared.join(' ')}';
        }
        if (shared.isEmpty) {
          return '🙈 No match. You: $mine · $otherName: $theirs';
        }
        return '🧠 ${shared.length}/${TelepathyPrompts.picksPerRound} '
            'match: ${shared.join(' ')}  (You: $mine · $otherName: $theirs)';
    }
  }

  // ---------- result ----------

  String resultTitle() {
    switch (game.kind) {
      case ChatGameKind.date:
        return 'Your date match';
      case ChatGameKind.rate:
        return 'Your tastes';
      case ChatGameKind.flags:
        return 'Your flags';
      case ChatGameKind.telepathy:
        return 'Your mind sync';
    }
  }

  String resultHeadline() {
    final total = game.rounds;
    switch (game.kind) {
      case ChatGameKind.date:
        return '${ChatGameLogic.datePercent(game)}% match · '
            '${ChatGameLogic.dateScore(game)}/$total answers';
      case ChatGameKind.rate:
        return '${ChatGameLogic.tasteMatch(game)}% taste match';
      case ChatGameKind.flags:
        return '${ChatGameLogic.flagMatches(game)}/$total flags match';
      case ChatGameKind.telepathy:
        return '${ChatGameLogic.mindSync(game)}/'
            '${ChatGameLogic.maxMindSync()} mind sync';
    }
  }

  Widget resultBody() {
    switch (game.kind) {
      case ChatGameKind.date:
        final matches = ChatGameLogic.dateMatches(game);
        return Column(
          children: [
            Text(
              matches.isEmpty
                  ? 'No matching answers this time. Play again for new '
                        'questions!'
                  : 'Your date:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in matches)
                    DateCardChip(
                      text: ChatGameLogic.dateMatchLabel(
                        m,
                        viewer: myUid,
                        otherName: otherName,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      case ChatGameKind.rate:
        return Column(
          children: [
            _legend(),
            for (var r = 0; r < game.rounds; r++)
              if (ChatGameLogic.rateTopicAt(game, r) case final t?)
                ResultRow(
                  label: '${t.emoji} ${t.label}',
                  mine: '${ChatGameLogic.rating(game, r, myUid) ?? '-'}',
                  theirs: '${ChatGameLogic.rating(game, r, otherUid) ?? '-'}',
                  same:
                      ChatGameLogic.rating(game, r, myUid) ==
                      ChatGameLogic.rating(game, r, otherUid),
                ),
          ],
        );
      case ChatGameKind.flags:
        return Column(
          children: [
            _legend(),
            for (var r = 0; r < game.rounds; r++)
              if (FlagStatements.byId(_item(r)) != null)
                ResultRow(
                  label: FlagStatements.byId(_item(r))!.text,
                  mine: FlagStatements.emojiOf(game.pickOf(r, myUid)),
                  theirs: FlagStatements.emojiOf(game.pickOf(r, otherUid)),
                  same: ChatGameLogic.flagsAgree(game, r),
                ),
          ],
        );
      case ChatGameKind.telepathy:
        return Column(
          children: [
            _legend(),
            for (var r = 0; r < game.rounds; r++)
              if (TelepathyPrompts.byId(_item(r)) != null)
                ResultRow(
                  label: TelepathyPrompts.byId(_item(r))!.label,
                  mine: TelepathyPrompts.asPick(game.pickOf(r, myUid)).join(''),
                  theirs: TelepathyPrompts.asPick(
                    game.pickOf(r, otherUid),
                  ).join(''),
                  same: ChatGameLogic.sharedEmojis(game, r).length >= 2,
                ),
          ],
        );
    }
  }

  Widget _legend() => Align(
    alignment: Alignment.centerRight,
    child: Text(
      'You · $otherName',
      style: const TextStyle(color: AppColors.lavender, fontSize: 12),
    ),
  );
}
