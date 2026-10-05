// lib/feature/games/chat_games/chat_game_logic.dart
//
// Per-game rules on top of ChatGame: decks, valid picks, scores and the chat
// messages. Pure Dart so it can be unit tested.

import 'dart:math';

import 'build_our_date/date_cards.dart';
import 'chat_game.dart';
import 'flags/flag_statements.dart';
import 'rate_it/rate_topics.dart';
import 'telepathy/telepathy_prompts.dart';

class ChatGameMessage {
  final String text;
  final Map<String, Object> metadata;

  const ChatGameMessage(this.text, this.metadata);
}

class ChatGameLogic {
  ChatGameLogic._();

  static const String inviteStage = 'invite';
  static const String resultStage = 'result';

  /// [tagsA]/[tagsB] are questionnaire tags of players[0]/players[1]; only
  /// Build Our Date uses them.
  static List<List<String>> buildDeck(
    ChatGameKind kind, {
    Set<String> tagsA = const {},
    Set<String> tagsB = const {},
    required Random random,
  }) {
    switch (kind) {
      case ChatGameKind.date:
        return DateCards.buildDeck(tagsA: tagsA, tagsB: tagsB, random: random);
      case ChatGameKind.rate:
        return RateTopics.buildDeck(ChatGame.roundCount, random);
      case ChatGameKind.flags:
        return FlagStatements.buildDeck(ChatGame.roundCount, random);
      case ChatGameKind.telepathy:
        return TelepathyPrompts.buildDeck(ChatGame.roundCount, random);
    }
  }

  static bool isValidPick(ChatGame game, Object value) {
    if (!game.isActive) return false;
    switch (game.kind) {
      case ChatGameKind.date:
        return value is String && game.deck[game.round].contains(value);
      case ChatGameKind.rate:
        return RateTopics.isValidScore(value);
      case ChatGameKind.flags:
        return FlagStatements.isValidVote(value);
      case ChatGameKind.telepathy:
        return TelepathyPrompts.isValidPick(value, game.deck[game.round]);
    }
  }

  // ---------- Build Our Date ----------

  static Map<String, String> _stringPicks(ChatGame g, int r) => {
    for (final e in g.picksFor(r).entries)
      if (e.value is String) e.key: e.value as String,
  };

  static bool dateMatched(ChatGame g, int r) =>
      DateCards.isMatch(_stringPicks(g, r));

  /// The card chosen for round [r]: both picked = match or coin flip. Once
  /// the round is over (it timed out), a single pick wins, and with no picks
  /// a fixed card from the deck is used, so every finished round has a card.
  static String? dateResult(ChatGame g, int r) {
    final picks = _stringPicks(g, r);
    final decided = DateCards.decide(
      picks: picks,
      players: g.players,
      gameId: g.gameId,
      round: r,
    );
    if (decided != null || r >= g.round) return decided;
    if (picks.isNotEmpty) return picks.values.first;
    final deck = g.deck[r];
    if (deck.isEmpty) return null;
    return deck[DateCards.fallbackIndex(g.gameId, r, deck.length)];
  }

  static List<String> dateResults(ChatGame g) => [
    for (var r = 0; r < ChatGame.roundCount; r++)
      if (dateResult(g, r) != null) dateResult(g, r)!,
  ];

  static int dateScore(ChatGame g) => [
    for (var r = 0; r < ChatGame.roundCount; r++)
      if (dateMatched(g, r)) r,
  ].length;

  // ---------- Rate It ----------

  static int? rating(ChatGame g, int r, String uid) {
    final v = g.pickOf(r, uid);
    return RateTopics.isValidScore(v) ? v as int : null;
  }

  static int tasteMatch(ChatGame g) {
    final pairs = <(int, int)>[];
    for (var r = 0; r < ChatGame.roundCount; r++) {
      final a = rating(g, r, g.players[0]);
      final b = rating(g, r, g.players[1]);
      if (a != null && b != null) pairs.add((a, b));
    }
    return RateTopics.tasteMatch(pairs);
  }

  // ---------- Red Flag, Green Flag ----------

  static bool flagsAgree(ChatGame g, int r) =>
      g.bothPicked(r) && g.picksFor(r).values.toSet().length == 1;

  static int flagMatches(ChatGame g) => [
    for (var r = 0; r < ChatGame.roundCount; r++)
      if (flagsAgree(g, r)) r,
  ].length;

  // ---------- Telepathy ----------

  static int maxMindSync() =>
      ChatGame.roundCount * TelepathyPrompts.picksPerRound;

  static Set<String> sharedEmojis(ChatGame g, int r) =>
      TelepathyPrompts.overlap(
        g.pickOf(r, g.players[0]),
        g.pickOf(r, g.players[1]),
      );

  static int mindSync(ChatGame g) => [
    for (var r = 0; r < ChatGame.roundCount; r++) sharedEmojis(g, r).length,
  ].fold(0, (a, b) => a + b);

  // ---------- chat messages ----------

  static ChatGameMessage invite(ChatGameKind kind) {
    final String text;
    switch (kind) {
      case ChatGameKind.date:
        text = "💌 Let's plan a date! Open Build Our Date to play.";
        break;
      case ChatGameKind.rate:
        text = "🔢 Let's play Rate It! Rate 5 things from 1 to 10 and compare.";
        break;
      case ChatGameKind.flags:
        text = "🚩💚 Let's play Red Flag, Green Flag!";
        break;
      case ChatGameKind.telepathy:
        text = "🧠 Let's play Telepathy! Can you guess which emojis I'll pick?";
        break;
    }
    return ChatGameMessage(text, {'game': kind.name, 'stage': inviteStage});
  }

  /// [invite] tagged with the game it invites to, so the chat card can tell
  /// a pending invite from an old one.
  static ChatGameMessage withGameId(ChatGameMessage invite, String gameId) =>
      ChatGameMessage(invite.text, {...invite.metadata, 'gameId': gameId});

  static ChatGameMessage result(ChatGame g) {
    const total = ChatGame.roundCount;
    switch (g.kind) {
      case ChatGameKind.date:
        final cards = dateResults(g);
        final score = dateScore(g);
        return ChatGameMessage(
          '💌 Our date plan: ${DateCards.title(cards)} ($score/$total in sync)',
          {
            'game': g.kind.name,
            'stage': resultStage,
            'cards': cards,
            'score': score,
          },
        );
      case ChatGameKind.rate:
        final percent = tasteMatch(g);
        return ChatGameMessage('🔢 Rate It: $percent% taste match', {
          'game': g.kind.name,
          'stage': resultStage,
          'percent': percent,
        });
      case ChatGameKind.flags:
        final matches = flagMatches(g);
        return ChatGameMessage(
          '🚩💚 Red Flag, Green Flag: $matches/$total flags match',
          {'game': g.kind.name, 'stage': resultStage, 'matches': matches},
        );
      case ChatGameKind.telepathy:
        final sync = mindSync(g);
        return ChatGameMessage(
          '🧠 Telepathy: $sync/${maxMindSync()} mind sync',
          {'game': g.kind.name, 'stage': resultStage, 'sync': sync},
        );
    }
  }

  /// One line for the result card in the chat, from the message metadata.
  static String resultLine(ChatGameKind kind, Map<String, dynamic> meta) {
    const total = ChatGame.roundCount;
    switch (kind) {
      case ChatGameKind.date:
        final cards = [
          for (final id in (meta['cards'] as List?) ?? const [])
            if (id is String) id,
        ];
        return DateCards.title(cards);
      case ChatGameKind.rate:
        final p = (meta['percent'] as num?)?.toInt();
        return p == null ? '' : '$p% taste match';
      case ChatGameKind.flags:
        final m = (meta['matches'] as num?)?.toInt();
        return m == null ? '' : '$m/$total flags match';
      case ChatGameKind.telepathy:
        final s = (meta['sync'] as num?)?.toInt();
        return s == null ? '' : '$s/${maxMindSync()} mind sync';
    }
  }
}
