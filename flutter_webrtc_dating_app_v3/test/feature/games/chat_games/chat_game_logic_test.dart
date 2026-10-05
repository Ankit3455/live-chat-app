import 'dart:math';

import 'package:availchat/feature/games/chat_games/chat_game.dart';
import 'package:availchat/feature/games/chat_games/chat_game_logic.dart';
import 'package:availchat/feature/games/chat_games/flags/flag_statements.dart';
import 'package:availchat/feature/games/chat_games/rate_it/rate_topics.dart';
import 'package:availchat/feature/games/chat_games/telepathy/telepathy_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

ChatGame _game(
  ChatGameKind kind, {
  required List<List<String>> deck,
  List<Map<String, Object>> picks = const [],
  int round = ChatGame.roundCount,
  bool cancelled = false,
}) => ChatGame(
  kind: kind,
  gameId: 'g1',
  players: const ['alice', 'bob'],
  createdBy: 'alice',
  cancelled: cancelled,
  round: round,
  deck: deck,
  picks: [
    for (var r = 0; r < ChatGame.roundCount; r++)
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

  test('every deck has 5 rounds of the right size', () {
    for (final kind in ChatGameKind.values) {
      final deck = ChatGameLogic.buildDeck(kind, random: Random(1));
      expect(deck.length, ChatGame.roundCount, reason: kind.name);
      for (final round in deck) {
        expect(round.length, switch (kind) {
          ChatGameKind.date => 4,
          ChatGameKind.telepathy => 10,
          _ => 1,
        });
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
      expect(rate.toSet().length, ChatGame.roundCount);
      expect(flags.toSet().length, ChatGame.roundCount);
      expect(rate.every((id) => RateTopics.byId(id) != null), isTrue);
      expect(flags.every((id) => FlagStatements.byId(id) != null), isTrue);
    }
  });

  test('topic and statement ids are unique', () {
    expect(
      RateTopics.pool.map((t) => t.id).toSet().length,
      RateTopics.pool.length,
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

    final date = _game(
      ChatGameKind.date,
      deck: List.filled(5, [
        'vibe_chill',
        'vibe_foodie',
        'vibe_creative',
        'vibe_playful',
      ]),
      round: 0,
    );
    expect(ChatGameLogic.isValidPick(date, 'vibe_chill'), isTrue);
    expect(ChatGameLogic.isValidPick(date, 'place_cafe'), isFalse);

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
      deck: _one('t'),
      picks: [
        for (var r = 0; r < 5; r++) {'alice': 6, 'bob': 6},
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

  test('date result lists the chosen cards and the score', () {
    final g = _game(
      ChatGameKind.date,
      deck: const [
        ['vibe_romantic', 'vibe_chill', 'vibe_foodie', 'vibe_playful'],
        ['place_rooftop', 'place_cafe', 'place_beach', 'place_park'],
        ['food_chai', 'food_pizza', 'food_momos', 'food_dosa'],
        ['act_karaoke', 'act_movie', 'act_walk', 'act_pottery'],
        ['time_sunset', 'time_night', 'time_sunrise', 'time_afternoon'],
      ],
      picks: [
        {'alice': 'vibe_romantic', 'bob': 'vibe_romantic'},
        {'alice': 'place_rooftop', 'bob': 'place_rooftop'},
        {'alice': 'food_chai', 'bob': 'food_chai'},
        {'alice': 'act_karaoke', 'bob': 'act_karaoke'},
        {'alice': 'time_sunset', 'bob': 'time_sunset'},
      ],
    );
    expect(ChatGameLogic.dateScore(g), 5);
    final msg = ChatGameLogic.result(g);
    expect(msg.metadata['cards'], [
      'vibe_romantic',
      'place_rooftop',
      'food_chai',
      'act_karaoke',
      'time_sunset',
    ]);
    expect(msg.text, contains('Sunset at the Rooftop'));
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
        for (var r = 0; r < 5; r++) 'r$r': ['t$r'],
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
    expect(deck.map((r) => r.first).toSet().length, ChatGame.roundCount);
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

  test('a timed-out date round still gets a card', () {
    const deck = [
      ['vibe_romantic', 'vibe_chill', 'vibe_foodie', 'vibe_playful'],
      ['place_rooftop', 'place_cafe', 'place_beach', 'place_park'],
      ['food_chai', 'food_pizza', 'food_momos', 'food_dosa'],
      ['act_karaoke', 'act_movie', 'act_walk', 'act_pottery'],
      ['time_sunset', 'time_night', 'time_sunrise', 'time_afternoon'],
    ];
    final g = _game(
      ChatGameKind.date,
      deck: deck,
      round: 2,
      picks: [
        {'alice': 'vibe_chill'},
        {},
        {'alice': 'food_chai'},
      ],
    );
    expect(ChatGameLogic.dateResult(g, 0), 'vibe_chill');
    expect(deck[1], contains(ChatGameLogic.dateResult(g, 1)));
    expect(ChatGameLogic.dateResult(g, 1), ChatGameLogic.dateResult(g, 1));
    expect(ChatGameLogic.dateResult(g, 2), isNull, reason: 'round still open');
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

List<List<String>> _one(String prefix) => [
  for (var r = 0; r < ChatGame.roundCount; r++) ['$prefix$r'],
];
