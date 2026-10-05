// lib/feature/games/chat_games/chat_game_views.dart
//
// The per-game parts of ChatGameScreen: the round question, the picker, the
// reveal line and the result body. The screen draws everything around them.

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

import 'build_our_date/date_cards.dart';
import 'build_our_date/widgets/date_card_tile.dart';
import 'chat_game.dart';
import 'chat_game_logic.dart';
import 'flags/flag_statements.dart';
import 'rate_it/rate_topics.dart';
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

  /// Questionnaire tags of the current user ("Made for you" badges).
  final Set<String> myTags;
  final ValueChanged<Object> onPick;

  const ChatGameView({
    required this.game,
    required this.myUid,
    required this.otherName,
    required this.busy,
    required this.myTags,
    required this.onPick,
  });

  String get otherUid => game.otherOf(myUid);
  int get round => game.round;
  Object? get myPick => game.pickOf(round, myUid);
  bool get canPick =>
      myPick == null && !busy && game.isActive && game.bothJoined;

  String _possessive(String uid) => uid == myUid ? 'your' : "$otherName's";

  GameTheme get theme => GameTheme.of(game.kind.name);

  // ---------- round ----------

  String question() {
    switch (game.kind) {
      case ChatGameKind.date:
        return DateCards.rounds[round].question;
      case ChatGameKind.rate:
        final t = RateTopics.byId(_item(round));
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
        return null;
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
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: [
        for (final id in game.deck[round])
          if (DateCards.byId(id) != null)
            DateCardTile(
              card: DateCards.byId(id)!,
              selected: pick == id,
              dimmed: pick != null && pick != id,
              badge: DateCards.byId(id)!.tags.any(myTags.contains)
                  ? 'Made for you'
                  : null,
              onTap: canPick ? () => onPick(id) : null,
            ),
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
    String show(Object? v) {
      if (v == null) return '⏱️';
      switch (game.kind) {
        case ChatGameKind.date:
          final c = DateCards.byId(v as String?);
          return c == null ? '?' : '${c.emoji} ${c.label}';
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
    return (show(mine), show(theirs), same);
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
        final card = DateCards.byId(ChatGameLogic.dateResult(game, r));
        if (card == null) return '';
        if (timedOut != null) {
          return '$timedOut. ${card.emoji} ${card.label} it is.';
        }
        if (ChatGameLogic.dateMatched(game, r)) {
          return '✨ Match! You both picked ${card.emoji} ${card.label}';
        }
        final winner = game.players[DateCards.coinWinner(game.gameId, r)];
        return '🪙 Different picks. Coin flip: ${_possessive(winner)} pick '
            '${card.emoji} ${card.label}';
      case ChatGameKind.rate:
        final mine = ChatGameLogic.rating(game, r, myUid);
        final theirs = ChatGameLogic.rating(game, r, otherUid);
        final t = RateTopics.byId(_item(r));
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
        return 'Our date plan';
      case ChatGameKind.rate:
        return 'Your tastes';
      case ChatGameKind.flags:
        return 'Your flags';
      case ChatGameKind.telepathy:
        return 'Your mind sync';
    }
  }

  String resultHeadline() {
    const total = ChatGame.roundCount;
    switch (game.kind) {
      case ChatGameKind.date:
        return '${ChatGameLogic.dateScore(game)}/$total in sync';
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
        final cards = [
          for (final id in ChatGameLogic.dateResults(game))
            if (DateCards.byId(id) != null) DateCards.byId(id)!,
        ];
        return Column(
          children: [
            Text(
              DateCards.title([for (final c in cards) c.id]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in cards) DateCardChip(card: c)],
            ),
          ],
        );
      case ChatGameKind.rate:
        return Column(
          children: [
            _legend(),
            for (var r = 0; r < ChatGame.roundCount; r++)
              if (RateTopics.byId(_item(r)) != null)
                ResultRow(
                  label:
                      '${RateTopics.byId(_item(r))!.emoji} ${RateTopics.byId(_item(r))!.label}',
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
            for (var r = 0; r < ChatGame.roundCount; r++)
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
            for (var r = 0; r < ChatGame.roundCount; r++)
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
