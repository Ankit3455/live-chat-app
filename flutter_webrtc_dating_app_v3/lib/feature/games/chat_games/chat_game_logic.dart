// lib/feature/games/chat_games/chat_game_logic.dart
//
// Per-game rules on top of ChatGame: decks, valid picks, scores and the chat
// messages. Pure Dart so it can be unit tested.

import 'dart:math';

import 'build_our_date/date_cards.dart';
import 'build_our_date/date_questions.dart';
import 'chat_game.dart';
import 'flags/flag_statements.dart';
import 'rate_it/rate_topic_pool.dart';
import 'rate_it/rate_topics.dart';
import 'telepathy/telepathy_prompts.dart';

class ChatGameMessage {
  final String text;
  final Map<String, Object> metadata;

  const ChatGameMessage(this.text, this.metadata);
}

/// Something to show for a deck entry: "🍕 Pizza".
typedef GameItem = ({String emoji, String label});

/// A Build Our Date answer both players agreed on. [who] is set when they
/// agreed on a person ("Who's funnier?"); [text] is then the question.
typedef DateMatch = ({String emoji, String text, String? who});

class ChatGameLogic {
  ChatGameLogic._();

  static const String inviteStage = 'invite';
  static const String resultStage = 'result';

  /// Matched answers shown on the chat result card.
  static const int maxCardAnswers = 3;

  static final List<String> _dateIds = [
    for (final q in DateQuestions.pool) q.id,
  ];
  static final Map<String, DateQuestion> _dateById = {
    for (final q in DateQuestions.pool) q.id: q,
  };
  static final List<String> _rateIds = [
    for (final t in RateTopicPool.pool) t.id,
  ];
  static final Map<String, RateTopicData> _rateById = {
    for (final t in RateTopicPool.pool) t.id: t,
  };

  /// [exclude]: ids of the game this one replaces, so a new game of Build
  /// Our Date or Rate It brings a fresh set.
  static List<List<String>> buildDeck(
    ChatGameKind kind, {
    required Random random,
    Set<String> exclude = const {},
  }) {
    switch (kind) {
      case ChatGameKind.date:
        return [
          for (final id in sampleIds(_dateIds, kind.rounds, random, exclude))
            [id],
        ];
      case ChatGameKind.rate:
        return [
          for (final id in sampleIds(_rateIds, kind.rounds, random, exclude))
            [id],
        ];
      case ChatGameKind.flags:
        return FlagStatements.buildDeck(kind.rounds, random);
      case ChatGameKind.telepathy:
        return TelepathyPrompts.buildDeck(kind.rounds, random);
    }
  }

  /// [count] distinct ids from [ids], uniformly at random. Ids in [exclude]
  /// are used only when there are not enough others.
  static List<String> sampleIds(
    List<String> ids,
    int count,
    Random random, [
    Set<String> exclude = const {},
  ]) {
    final fresh = [
      for (final id in ids.toSet())
        if (!exclude.contains(id)) id,
    ];
    final picked = _sample(fresh, count, random);
    if (picked.length < count) {
      final used = [
        for (final id in ids.toSet())
          if (exclude.contains(id)) id,
      ];
      picked.addAll(_sample(used, count - picked.length, random));
    }
    return picked;
  }

  /// Partial Fisher-Yates: the first [count] of a shuffled copy.
  static List<String> _sample(List<String> from, int count, Random random) {
    final list = List.of(from);
    final n = min(count, list.length);
    for (var i = 0; i < n; i++) {
      final j = i + random.nextInt(list.length - i);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
    return list.sublist(0, n);
  }

  /// First entry of every round of [game]: its question / topic / prompt ids.
  static Set<String> deckIds(ChatGame? game) => {
    for (final round in game?.deck ?? const <List<String>>[])
      if (round.isNotEmpty) round.first,
  };

  static bool isValidPick(ChatGame game, Object value) {
    if (!game.isActive) return false;
    switch (game.kind) {
      case ChatGameKind.date:
        return value is int && value >= 0 && value < dateOptionCount;
      case ChatGameKind.rate:
        return RateTopics.isValidScore(value);
      case ChatGameKind.flags:
        return FlagStatements.isValidVote(value);
      case ChatGameKind.telepathy:
        return TelepathyPrompts.isValidPick(value, game.deck[game.round]);
    }
  }

  static String? _item(ChatGame g, int r) =>
      r >= 0 && r < g.deck.length && g.deck[r].isNotEmpty
      ? g.deck[r].first
      : null;

  // ---------- Build Our Date ----------

  /// Every date question has this many options; firestore.rules expects a
  /// pick of 0..3.
  static const int dateOptionCount = 4;

  static DateQuestion? dateQuestion(String? id) =>
      id == null ? null : _dateById[id];

  static DateQuestion? dateQuestionAt(ChatGame g, int r) =>
      dateQuestion(_item(g, r));

  /// The option index [uid] picked in round [r], if any.
  static int? dateChoice(ChatGame g, int r, String uid) {
    final v = g.pickOf(r, uid);
    return v is int && v >= 0 && v < dateOptionCount ? v : null;
  }

  /// The text of option [index] of round [r]'s question.
  static String? dateOption(ChatGame g, int r, int? index) {
    final options = dateQuestionAt(g, r)?.options;
    if (options == null ||
        index == null ||
        index < 0 ||
        index >= options.length) {
      return null;
    }
    return options[index];
  }

  /// Options each player reads from their own side: "Me" from one player
  /// and "You" from the other point at the same person.
  static const String dateMeOption = '🙋 Me';
  static const String dateYouOption = '👉 You';

  /// The player [uid]'s pick points at when it is a Me / You option.
  static String? dateWho(ChatGame g, int r, String uid) {
    final option = dateOption(g, r, dateChoice(g, r, uid));
    if (option == dateMeOption) return uid;
    if (option == dateYouOption) return g.otherOf(uid);
    return null;
  }

  /// Same option, or Me / You answers that name the same person.
  static bool dateMatched(ChatGame g, int r) {
    final a = dateChoice(g, r, g.players[0]);
    final b = dateChoice(g, r, g.players[1]);
    if (a == null || b == null) return false;
    final whoA = dateWho(g, r, g.players[0]);
    final whoB = dateWho(g, r, g.players[1]);
    if (whoA != null || whoB != null) return whoA == whoB;
    return a == b;
  }

  /// The person both named in round [r], if they matched on Me / You.
  static String? dateAgreedWho(ChatGame g, int r) =>
      dateMatched(g, r) ? dateWho(g, r, g.players[0]) : null;

  static int dateScore(ChatGame g) => [
    for (var r = 0; r < g.rounds; r++)
      if (dateMatched(g, r)) r,
  ].length;

  static int datePercent(ChatGame g) =>
      g.rounds == 0 ? 0 : (dateScore(g) * 100 / g.rounds).round();

  /// The answers both picked, in round order.
  static List<DateMatch> dateMatches(ChatGame g) => [
    for (var r = 0; r < g.rounds; r++)
      if (dateMatched(g, r))
        if (dateAgreedWho(g, r) case final who?)
          (
            emoji: dateQuestionAt(g, r)!.emoji,
            text: dateQuestionAt(g, r)!.prompt,
            who: who,
          )
        else if (dateOption(g, r, dateChoice(g, r, g.players[0]))
            case final text?)
          (emoji: dateQuestionAt(g, r)!.emoji, text: text, who: null),
  ];

  /// "🍕 Pizza", or "😂 Who's funnier? You" as [viewer] sees it.
  static String dateMatchLabel(
    DateMatch m, {
    required String viewer,
    required String otherName,
  }) {
    final who = m.who;
    final head = '${m.emoji} ${m.text}';
    if (who == null) return head;
    return '$head ${who == viewer ? 'You' : otherName}';
  }

  // ---------- Rate It ----------

  /// Rate It topics come from [RateTopicPool]; games started before it
  /// existed may hold ids only [RateTopics] knows.
  static GameItem? rateTopic(String? id) {
    if (id == null) return null;
    final t = _rateById[id];
    if (t != null) return (emoji: t.emoji, label: t.label);
    final old = RateTopics.byId(id);
    return old == null ? null : (emoji: old.emoji, label: old.label);
  }

  static GameItem? rateTopicAt(ChatGame g, int r) => rateTopic(_item(g, r));

  static int? rating(ChatGame g, int r, String uid) {
    final v = g.pickOf(r, uid);
    return RateTopics.isValidScore(v) ? v as int : null;
  }

  static int tasteMatch(ChatGame g) {
    final pairs = <(int, int)>[];
    for (var r = 0; r < g.rounds; r++) {
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
    for (var r = 0; r < g.rounds; r++)
      if (flagsAgree(g, r)) r,
  ].length;

  // ---------- Telepathy ----------

  static int maxMindSync() =>
      ChatGameKind.telepathy.rounds * TelepathyPrompts.picksPerRound;

  static Set<String> sharedEmojis(ChatGame g, int r) =>
      TelepathyPrompts.overlap(
        g.pickOf(r, g.players[0]),
        g.pickOf(r, g.players[1]),
      );

  static int mindSync(ChatGame g) => [
    for (var r = 0; r < g.rounds; r++) sharedEmojis(g, r).length,
  ].fold(0, (a, b) => a + b);

  // ---------- chat messages ----------

  static ChatGameMessage invite(ChatGameKind kind) {
    final String text;
    switch (kind) {
      case ChatGameKind.date:
        text = "💌 Let's plan a date! Open Build Our Date to play.";
        break;
      case ChatGameKind.rate:
        text =
            "🔢 Let's play Rate It! Rate 10 things from 1 to 10 and compare.";
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
    final total = g.rounds;
    switch (g.kind) {
      case ChatGameKind.date:
        final score = dateScore(g);
        final matches = dateMatches(g).take(maxCardAnswers).toList();
        // The text is read by both players, so it leaves out "who" answers.
        final plain = [
          for (final m in matches)
            if (m.who == null) '${m.emoji} ${m.text}',
        ];
        return ChatGameMessage(
          [
            '💌 Date match $score/$total',
            if (plain.isNotEmpty) plain.join(', '),
          ].join(': '),
          {
            'game': g.kind.name,
            'stage': resultStage,
            'score': score,
            'total': total,
            'answers': [
              for (final m in matches)
                {
                  'emoji': m.emoji,
                  'text': m.text,
                  if (m.who case final who?) 'who': who,
                },
            ],
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

  /// Matched answers a date result card lists, as [viewer] sees them.
  static List<String> resultAnswers(
    Map<String, dynamic> meta, {
    required String viewer,
    required String otherName,
  }) => [
    for (final a in (meta['answers'] as List?) ?? const [])
      if (a is Map && a['emoji'] is String && a['text'] is String)
        dateMatchLabel(
          (
            emoji: a['emoji'] as String,
            text: a['text'] as String,
            who: a['who'] is String ? a['who'] as String : null,
          ),
          viewer: viewer,
          otherName: otherName,
        ),
  ].take(maxCardAnswers).toList();

  /// One line for the result card in the chat, from the message metadata.
  static String resultLine(ChatGameKind kind, Map<String, dynamic> meta) {
    final total = kind.rounds;
    switch (kind) {
      case ChatGameKind.date:
        final score = (meta['score'] as num?)?.toInt();
        // Results of the old 5-card date plan carry card ids instead.
        if (meta['cards'] is List) {
          return DateCards.title(
            (meta['cards'] as List).whereType<String>().toList(),
          );
        }
        if (score == null) return '';
        final of = (meta['total'] as num?)?.toInt() ?? total;
        return 'Date match $score/$of 💌';
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
