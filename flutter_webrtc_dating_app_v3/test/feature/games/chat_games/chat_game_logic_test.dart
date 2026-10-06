import 'dart:math';

import 'package:availchat/feature/games/chat_games/chat_game.dart';
import 'package:availchat/feature/games/chat_games/chat_game_logic.dart';
import 'package:availchat/feature/games/chat_games/flags/flag_statements.dart';
import 'package:availchat/feature/games/chat_games/rate_it/rate_topic_pool.dart';
import 'package:availchat/feature/games/chat_games/rate_it/rate_topics.dart';
import 'package:availchat/feature/games/chat_games/telepathy/telepathy_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

ChatGame _game(
  ChatGameKind kind, {
  required List<List<String>> deck,
  List<Map<String, Object>> picks = const [],
  int? round,
  bool cancelled = false,
}) => ChatGame(
  kind: kind,
  gameId: 'g1',
  players: const ['alice', 'bob'],
  createdBy: 'alice',
  cancelled: cancelled,
  round: round ?? kind.rounds,
  deck: deck,
  picks: [
    for (var r = 0; r < kind.rounds; r++)
      r < picks.length ? picks[r] : const <String, Object>{},
  ],
);

void main() {
  test('kinds round-trip through their names', () {
    for (final k in ChatGameKind.values) {
      expect(ChatGameKind.byName(k.name), k);
    }
    expect(ChatGameKind.byName('chess'), isNull);
  });

  test('date and rate have 10 rounds, flags and telepathy 5', () {
    expect(ChatGameKind.date.rounds, 10);
    expect(ChatGameKind.rate.rounds, 10);
    expect(ChatGameKind.flags.rounds, 5);
    expect(ChatGameKind.telepathy.rounds, 5);
  });

  test('every deck has one round per game round, of the right size', () {
    for (final kind in ChatGameKind.values) {
      final deck = ChatGameLogic.buildDeck(kind, random: Random(1));
      expect(deck.length, kind.rounds, reason: kind.name);
      for (final round in deck) {
        expect(round.length, kind == ChatGameKind.telepathy ? 10 : 1);
        expect(round.length, ChatGame.deckRoundSize(kind));
      }
    }
  });

  test('rate and flags decks never repeat a topic', () {
    for (var seed = 0; seed < 30; seed++) {
      final rate = ChatGameLogic.buildDeck(
        ChatGameKind.rate,
        random: Random(seed),
      ).map((r) => r.single);
      final flags = ChatGameLogic.buildDeck(
        ChatGameKind.flags,
        random: Random(seed),
      ).map((r) => r.single);
      expect(rate.toSet().length, ChatGameKind.rate.rounds);
      expect(flags.toSet().length, ChatGameKind.flags.rounds);
      expect(rate.every((id) => ChatGameLogic.rateTopic(id) != null), isTrue);
      expect(flags.every((id) => FlagStatements.byId(id) != null), isTrue);
    }
  });

  test('topic and statement ids are unique', () {
    expect(
      RateTopics.pool.map((t) => t.id).toSet().length,
      RateTopics.pool.length,
    );
    expect(
      RateTopicPool.pool.map((t) => t.id).toSet().length,
      RateTopicPool.pool.length,
    );
    expect(
      FlagStatements.pool.map((s) => s.id).toSet().length,
      FlagStatements.pool.length,
    );
  });

  test('valid picks depend on the game', () {
    final rate = _game(ChatGameKind.rate, deck: _one('t'), round: 0);
    expect(ChatGameLogic.isValidPick(rate, 1), isTrue);
    expect(ChatGameLogic.isValidPick(rate, 10), isTrue);
    expect(ChatGameLogic.isValidPick(rate, 0), isFalse);
    expect(ChatGameLogic.isValidPick(rate, 11), isFalse);
    expect(ChatGameLogic.isValidPick(rate, '5'), isFalse);

    final flags = _game(ChatGameKind.flags, deck: _one('s'), round: 0);
    expect(ChatGameLogic.isValidPick(flags, 'red'), isTrue);
    expect(ChatGameLogic.isValidPick(flags, 'green'), isTrue);
    expect(ChatGameLogic.isValidPick(flags, 'yellow'), isFalse);

    final date = _game(ChatGameKind.date, deck: _one('q', 10), round: 0);
    for (var i = 0; i < 4; i++) {
      expect(ChatGameLogic.isValidPick(date, i), isTrue);
    }
    expect(ChatGameLogic.isValidPick(date, -1), isFalse);
    expect(ChatGameLogic.isValidPick(date, 4), isFalse);
    expect(ChatGameLogic.isValidPick(date, '0'), isFalse);

    final ended = _game(
      ChatGameKind.rate,
      deck: _one('t'),
      round: 0,
      cancelled: true,
    );
    expect(ChatGameLogic.isValidPick(ended, 5), isFalse);
  });

  test('taste match: 100 for equal ratings, 0 for 1 vs 10', () {
    expect(RateTopics.tasteMatch([(5, 5), (8, 8)]), 100);
    expect(RateTopics.tasteMatch([(1, 10)]), 0);
    expect(RateTopics.tasteMatch([(1, 10), (7, 7)]), 50);
    expect(RateTopics.tasteMatch(const []), 0);
  });

  test('rate result message carries the taste match', () {
    final g = _game(
      ChatGameKind.rate,
      deck: _one('t', 10),
      picks: [
        for (var r = 0; r < 10; r++) {'alice': 6, 'bob': 6},
      ],
    );
    expect(ChatGameLogic.tasteMatch(g), 100);
    final msg = ChatGameLogic.result(g);
    expect(msg.metadata['game'], 'rate');
    expect(msg.metadata['stage'], ChatGameLogic.resultStage);
    expect(msg.metadata['percent'], 100);
    expect(msg.text, contains('100% taste match'));
    expect(
      ChatGameLogic.resultLine(ChatGameKind.rate, msg.metadata),
      '100% taste match',
    );
  });

  test('flags count rounds where both voted the same', () {
    final g = _game(
      ChatGameKind.flags,
      deck: _one('s'),
      picks: [
        {'alice': 'red', 'bob': 'red'},
        {'alice': 'green', 'bob': 'red'},
        {'alice': 'green', 'bob': 'green'},
        {'alice': 'red', 'bob': 'green'},
        {'alice': 'green', 'bob': 'green'},
      ],
    );
    expect(ChatGameLogic.flagsAgree(g, 0), isTrue);
    expect(ChatGameLogic.flagsAgree(g, 1), isFalse);
    expect(ChatGameLogic.flagMatches(g), 3);
    final msg = ChatGameLogic.result(g);
    expect(msg.metadata['matches'], 3);
    expect(
      ChatGameLogic.resultLine(ChatGameKind.flags, msg.metadata),
      '3/5 flags match',
    );
  });

  test('a half-answered round does not count as agreement', () {
    final g = _game(
      ChatGameKind.flags,
      deck: _one('s'),
      round: 0,
      picks: [
        {'alice': 'red'},
      ],
    );
    expect(ChatGameLogic.flagsAgree(g, 0), isFalse);
  });

  test('invites name the game in metadata', () {
    for (final k in ChatGameKind.values) {
      final m = ChatGameLogic.invite(k);
      expect(m.metadata, {'game': k.name, 'stage': ChatGameLogic.inviteStage});
      expect(m.text, isNotEmpty);
    }
  });

  test('fromMap reads deck maps and mixed pick values', () {
    final g = ChatGame.fromMap(ChatGameKind.rate, {
      'gameId': 'g9',
      'players': ['alice', 'bob'],
      'createdBy': 'bob',
      'status': 'playing',
      'round': 1,
      'deck': {
        for (var r = 0; r < 10; r++) 'r$r': ['t$r'],
      },
      'picks': {
        'r0': {'alice': 3, 'bob': 9, 'junk': 1.5},
      },
    })!;
    expect(g.round, 1);
    expect(g.deck[2], ['t2']);
    expect(g.picksFor(0), {'alice': 3, 'bob': 9});
    expect(g.isActive, isTrue);
    expect(g.otherOf('alice'), 'bob');
    expect(
      ChatGame.fromMap(ChatGameKind.rate, {
        'players': ['a'],
      }),
      isNull,
    );
    expect(ChatGame.fromMap(ChatGameKind.rate, null), isNull);
  });

  test('telepathy prompts have unique ids and 9 different emojis each', () {
    expect(
      TelepathyPrompts.pool.map((p) => p.id).toSet().length,
      TelepathyPrompts.pool.length,
    );
    for (final p in TelepathyPrompts.pool) {
      expect(p.emojis.length, TelepathyPrompts.choicesPerRound, reason: p.id);
      expect(p.emojis.toSet().length, p.emojis.length, reason: p.id);
    }
  });

  test('telepathy deck: prompt id first, then its 9 emojis', () {
    final deck = ChatGameLogic.buildDeck(
      ChatGameKind.telepathy,
      random: Random(3),
    );
    expect(
      deck.map((r) => r.first).toSet().length,
      ChatGameKind.telepathy.rounds,
    );
    for (final round in deck) {
      final prompt = TelepathyPrompts.byId(round.first)!;
      expect(round.skip(1).toSet(), prompt.emojis.toSet());
    }
  });

  test('a telepathy pick is 3 different emojis from the round', () {
    const round = [
      'sunday',
      '😴',
      '☕',
      '🎬',
      '🍕',
      '🏞️',
      '📚',
      '🎮',
      '🛍️',
      '🧘',
    ];
    expect(TelepathyPrompts.isValidPick(['😴', '☕', '🎬'], round), isTrue);
    expect(TelepathyPrompts.isValidPick(['😴', '☕'], round), isFalse);
    expect(TelepathyPrompts.isValidPick(['😴', '😴', '☕'], round), isFalse);
    expect(TelepathyPrompts.isValidPick(['😴', '☕', '🚀'], round), isFalse);
    expect(TelepathyPrompts.isValidPick(['😴', '☕', 'sunday'], round), isFalse);
    expect(TelepathyPrompts.isValidPick('😴', round), isFalse);
  });

  test('mind sync counts shared emojis across rounds', () {
    const round = [
      'sunday',
      '😴',
      '☕',
      '🎬',
      '🍕',
      '🏞️',
      '📚',
      '🎮',
      '🛍️',
      '🧘',
    ];
    final g = _game(
      ChatGameKind.telepathy,
      deck: List.filled(5, round),
      picks: [
        {
          'alice': ['😴', '☕', '🎬'],
          'bob': ['😴', '☕', '🎬'],
        },
        {
          'alice': ['😴', '☕', '🎬'],
          'bob': ['😴', '🍕', '📚'],
        },
        {
          'alice': ['😴', '☕', '🎬'],
          'bob': ['🧘', '🍕', '📚'],
        },
        {
          'alice': ['🎮', '☕', '🎬'],
          'bob': ['🎮', '☕', '📚'],
        },
        {
          'alice': ['😴', '☕', '🎬'],
          'bob': ['🎬', '😴', '🧘'],
        },
      ],
    );
    expect(ChatGameLogic.sharedEmojis(g, 0), {'😴', '☕', '🎬'});
    expect(ChatGameLogic.mindSync(g), 3 + 1 + 0 + 2 + 2);
    expect(ChatGameLogic.maxMindSync(), 15);
    final msg = ChatGameLogic.result(g);
    expect(msg.metadata['sync'], 8);
    expect(
      ChatGameLogic.resultLine(ChatGameKind.telepathy, msg.metadata),
      '8/15 mind sync',
    );
  });

  test('fromMap keeps telepathy list picks', () {
    final g = ChatGame.fromMap(ChatGameKind.telepathy, {
      'players': ['alice', 'bob'],
      'deck': {
        for (var r = 0; r < 5; r++) 'r$r': ['sunday', '😴'],
      },
      'picks': {
        'r0': {
          'alice': ['😴', '☕', '🎬'],
        },
      },
    })!;
    expect(g.pickOf(0, 'alice'), ['😴', '☕', '🎬']);
  });

  test('a game saved with an older round count reads as ended', () {
    Map<String, dynamic> doc(int rounds, int size) => {
      'players': ['alice', 'bob'],
      'status': 'playing',
      'round': 2,
      'deck': {
        for (var r = 0; r < rounds; r++) 'r$r': List.filled(size, 'x$r'),
      },
      'picks': {
        'r0': {'alice': 'vibe_chill', 'bob': 'vibe_chill'},
      },
    };
    final old = ChatGame.fromMap(ChatGameKind.date, doc(5, 4))!;
    expect(old.cancelled, isTrue);
    expect(old.isActive, isFalse);
    expect(old.isDone, isFalse);
    expect(ChatGameLogic.dateScore(old), 0, reason: 'old string picks');
    expect(ChatGame.fromMap(ChatGameKind.rate, doc(5, 1))!.isActive, isFalse);
    expect(ChatGame.fromMap(ChatGameKind.date, doc(10, 1))!.isActive, isTrue);
    expect(ChatGame.fromMap(ChatGameKind.flags, doc(5, 1))!.isActive, isTrue);
  });

  test('old date-plan result cards still show their plan', () {
    expect(
      ChatGameLogic.resultLine(ChatGameKind.date, {
        'cards': ['vibe_romantic', 'place_rooftop'],
        'score': 2,
      }),
      'at the Rooftop',
    );
  });

  test('missing flag votes show a clock', () {
    expect(FlagStatements.emojiOf(null), '⏱️');
    expect(FlagStatements.emojiOf('red'), '🚩');
    expect(FlagStatements.emojiOf('green'), '💚');
  });

  test('turn clock counts down and stops at zero', () {
    final start = DateTime(2026, 1, 1, 12);
    final deadline = start.add(const Duration(seconds: TurnClock.seconds));
    expect(TurnClock.secondsLeft(deadline, start), 30);
    expect(
      TurnClock.secondsLeft(
        deadline,
        start.add(const Duration(milliseconds: 29500)),
      ),
      1,
    );
    expect(
      TurnClock.secondsLeft(deadline, start.add(const Duration(seconds: 45))),
      0,
    );
    expect(TurnClock.secondsLeft(null, start), isNull);
  });

  test('fromMap reads joined players and the round clock', () {
    final started = DateTime(2026, 1, 1, 12);
    final g = ChatGame.fromMap(ChatGameKind.flags, {
      'players': ['alice', 'bob'],
      'joined': ['alice'],
      'roundStartedAt': null,
      'deck': {
        for (var r = 0; r < 5; r++) 'r$r': ['s$r'],
      },
    })!;
    expect(g.bothJoined, isFalse);
    expect(g.deadline, isNull);
    final h = ChatGame.fromMap(ChatGameKind.flags, {
      'players': ['alice', 'bob'],
      'joined': ['alice', 'bob'],
      'roundStartedAt': started,
      'deck': {
        for (var r = 0; r < 5; r++) 'r$r': ['s$r'],
      },
    })!;
    expect(h.bothJoined, isTrue);
    expect(h.deadline, started.add(const Duration(seconds: 30)));
  });
}

List<List<String>> _one(String prefix, [int rounds = 5]) => [
  for (var r = 0; r < rounds; r++) ['$prefix$r'],
];
