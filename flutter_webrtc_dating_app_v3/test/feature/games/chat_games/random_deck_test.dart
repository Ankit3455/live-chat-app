import 'dart:math';

import 'package:availchat/feature/games/chat_games/build_our_date/date_questions.dart';
import 'package:availchat/feature/games/chat_games/chat_game.dart';
import 'package:availchat/feature/games/chat_games/chat_game_logic.dart';
import 'package:availchat/feature/games/chat_games/rate_it/rate_topic_pool.dart';
import 'package:availchat/feature/games/chat_games/rate_it/rate_topics.dart';
import 'package:flutter_test/flutter_test.dart';

bool _relative(DateQuestion q) =>
    q.options.contains(ChatGameLogic.dateMeOption) ||
    q.options.contains(ChatGameLogic.dateYouOption);

/// The first 10 questions without Me / You options.
final List<DateQuestion> _plain = DateQuestions.pool
    .where((q) => !_relative(q))
    .take(10)
    .toList();

ChatGame _date(
  List<Map<String, Object>> picks, {
  int? round,
  List<DateQuestion>? questions,
}) => ChatGame(
  kind: ChatGameKind.date,
  gameId: 'g1',
  players: const ['alice', 'bob'],
  createdBy: 'alice',
  cancelled: false,
  round: round ?? 10,
  deck: [
    for (var r = 0; r < 10; r++)
      [(questions ?? _plain)[r % (questions ?? _plain).length].id],
  ],
  picks: [
    for (var r = 0; r < 10; r++)
      r < picks.length ? picks[r] : const <String, Object>{},
  ],
);

void main() {
  test('pools: 1000 unique ids; every date question has 4 options', () {
    expect(DateQuestions.pool.length, 1000);
    expect(DateQuestions.pool.map((q) => q.id).toSet().length, 1000);
    for (final q in DateQuestions.pool) {
      expect(q.options.length, ChatGameLogic.dateOptionCount, reason: q.id);
    }
    expect(RateTopicPool.pool.length, 1000);
    expect(RateTopicPool.pool.map((t) => t.id).toSet().length, 1000);
  });

  test('date and rate decks: 10 distinct ids from the 1000 pool', () {
    final dateIds = DateQuestions.pool.map((q) => q.id).toSet();
    final rateIds = RateTopicPool.pool.map((t) => t.id).toSet();
    for (var seed = 0; seed < 50; seed++) {
      final date = ChatGameLogic.buildDeck(
        ChatGameKind.date,
        random: Random(seed),
      );
      final rate = ChatGameLogic.buildDeck(
        ChatGameKind.rate,
        random: Random(seed),
      );
      for (final (deck, pool) in [(date, dateIds), (rate, rateIds)]) {
        expect(deck.length, 10);
        expect(deck.every((r) => r.length == 1), isTrue);
        final ids = deck.map((r) => r.single).toSet();
        expect(ids.length, 10);
        expect(pool.containsAll(ids), isTrue);
      }
    }
  });

  test('a new game skips the ids of the game it replaces', () {
    final random = Random(7);
    for (final kind in [ChatGameKind.date, ChatGameKind.rate]) {
      var previous = ChatGameLogic.buildDeck(kind, random: random);
      for (var i = 0; i < 100; i++) {
        final exclude = previous.map((r) => r.single).toSet();
        final next = ChatGameLogic.buildDeck(
          kind,
          random: random,
          exclude: exclude,
        );
        final ids = next.map((r) => r.single).toSet();
        expect(ids.length, 10);
        expect(ids.intersection(exclude), isEmpty, reason: kind.name);
        previous = next;
      }
    }
  });

  test('deckIds reads the question id of every round', () {
    final g = _date(const []);
    expect(ChatGameLogic.deckIds(g), {for (final q in _plain) q.id});
    expect(ChatGameLogic.deckIds(null), isEmpty);
  });

  test('sampleIds is uniform-ish and falls back to excluded ids', () {
    final ids = [for (var i = 0; i < 20; i++) 'id$i'];
    final counts = <String, int>{};
    final random = Random(42);
    const draws = 4000;
    for (var i = 0; i < draws; i++) {
      final picked = ChatGameLogic.sampleIds(ids, 5, random);
      expect(picked.toSet().length, 5);
      for (final id in picked) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    // Each id is expected draws * 5 / 20 = 1000 times.
    for (final id in ids) {
      expect(counts[id], inInclusiveRange(850, 1150), reason: id);
    }

    final few = ChatGameLogic.sampleIds(
      ids.take(12).toList(),
      10,
      Random(1),
      ids.take(8).toSet(),
    );
    expect(few.length, 10);
    expect(few.toSet().length, 10);
    expect(few.take(4).toSet(), {'id8', 'id9', 'id10', 'id11'});
  });

  test('date score: same option index = match; percent and answers', () {
    final g = _date([
      {'alice': 0, 'bob': 0},
      {'alice': 1, 'bob': 2},
      {'alice': 3, 'bob': 3},
      {'alice': 2},
      {},
      {'alice': 1, 'bob': 1},
      {'alice': 'x', 'bob': 'x'},
    ]);
    expect(ChatGameLogic.dateMatched(g, 0), isTrue);
    expect(ChatGameLogic.dateMatched(g, 1), isFalse);
    expect(ChatGameLogic.dateMatched(g, 3), isFalse, reason: 'one pick');
    expect(ChatGameLogic.dateMatched(g, 4), isFalse, reason: 'no picks');
    expect(ChatGameLogic.dateMatched(g, 6), isFalse, reason: 'not an index');
    expect(ChatGameLogic.dateScore(g), 3);
    expect(ChatGameLogic.datePercent(g), 30);

    final q = _plain;
    final matches = ChatGameLogic.dateMatches(g);
    expect(matches, [
      (emoji: q[0].emoji, text: q[0].options[0], who: null),
      (emoji: q[2].emoji, text: q[2].options[3], who: null),
      (emoji: q[5].emoji, text: q[5].options[1], who: null),
    ]);
    expect(
      ChatGameLogic.dateMatchLabel(
        matches.first,
        viewer: 'alice',
        otherName: 'Bob',
      ),
      '${q[0].emoji} ${q[0].options[0]}',
    );
  });

  test('Me / You questions match when both name the same person', () {
    final relative = DateQuestions.pool.where(_relative).toList();
    expect(relative, isNotEmpty);
    for (final q in relative) {
      expect(q.options, contains(ChatGameLogic.dateMeOption), reason: q.id);
      expect(q.options, contains(ChatGameLogic.dateYouOption), reason: q.id);
    }
    final q = relative.first;
    final me = q.options.indexOf(ChatGameLogic.dateMeOption);
    final you = q.options.indexOf(ChatGameLogic.dateYouOption);
    final other = [0, 1, 2, 3].firstWhere((i) => i != me && i != you);
    final g = _date(
      [
        {'alice': me, 'bob': you}, // both say alice
        {'alice': you, 'bob': me}, // both say bob
        {'alice': me, 'bob': me}, // each says themselves
        {'alice': you, 'bob': you}, // each says the other
        {'alice': other, 'bob': other}, // "Both" / "Neither"
        {'alice': me, 'bob': other},
      ],
      questions: [q],
    );
    expect(ChatGameLogic.dateMatched(g, 0), isTrue);
    expect(ChatGameLogic.dateAgreedWho(g, 0), 'alice');
    expect(ChatGameLogic.dateMatched(g, 1), isTrue);
    expect(ChatGameLogic.dateAgreedWho(g, 1), 'bob');
    expect(ChatGameLogic.dateMatched(g, 2), isFalse);
    expect(ChatGameLogic.dateMatched(g, 3), isFalse);
    expect(ChatGameLogic.dateMatched(g, 4), isTrue);
    expect(ChatGameLogic.dateAgreedWho(g, 4), isNull);
    expect(ChatGameLogic.dateMatched(g, 5), isFalse);
    expect(ChatGameLogic.dateScore(g), 3);

    final matches = ChatGameLogic.dateMatches(g);
    expect(matches.first, (emoji: q.emoji, text: q.prompt, who: 'alice'));
    String label(String viewer) => ChatGameLogic.dateMatchLabel(
      matches.first,
      viewer: viewer,
      otherName: viewer == 'alice' ? 'Bob' : 'Alice',
    );
    expect(label('alice'), '${q.emoji} ${q.prompt} You');
    expect(label('bob'), '${q.emoji} ${q.prompt} Alice');

    final msg = ChatGameLogic.result(g);
    expect(msg.text, isNot(contains(q.prompt)), reason: 'no "who" in text');
    expect(
      ChatGameLogic.resultAnswers(
        msg.metadata,
        viewer: 'bob',
        otherName: 'Alice',
      ).take(2),
      ['${q.emoji} ${q.prompt} Alice', '${q.emoji} ${q.prompt} You'],
    );
  });

  test('date result card: "Date match 4/10" plus up to 3 answers', () {
    final g = _date([
      for (var r = 0; r < 10; r++)
        r < 4 ? {'alice': r % 4, 'bob': r % 4} : {'alice': 0, 'bob': 1},
    ]);
    final msg = ChatGameLogic.result(g);
    expect(msg.metadata['game'], 'date');
    expect(msg.metadata['stage'], ChatGameLogic.resultStage);
    expect(msg.metadata['score'], 4);
    expect(msg.metadata['total'], 10);
    final answers = ChatGameLogic.resultAnswers(
      msg.metadata,
      viewer: 'alice',
      otherName: 'Bob',
    );
    expect(answers.length, 3);
    final q = _plain[1];
    expect(answers[1], '${q.emoji} ${q.options[1]}');
    expect(msg.text, startsWith('💌 Date match 4/10: '));
    expect(
      ChatGameLogic.resultLine(ChatGameKind.date, msg.metadata),
      'Date match 4/10 💌',
    );
    expect(msg.text, '💌 Date match 4/10: ${answers.join(', ')}');

    final none = ChatGameLogic.result(_date(const []));
    expect(none.text, '💌 Date match 0/10');
    expect(none.metadata['answers'], isEmpty);
  });

  test('rate topics: new pool first, old ids still readable', () {
    final first = RateTopicPool.pool.first;
    expect(ChatGameLogic.rateTopic(first.id), (
      emoji: first.emoji,
      label: first.label,
    ));
    for (final old in RateTopics.pool) {
      expect(ChatGameLogic.rateTopic(old.id), isNotNull, reason: old.id);
    }
    expect(ChatGameLogic.rateTopic('nope'), isNull);
    expect(ChatGameLogic.rateTopic(null), isNull);
  });

  test('a date game is active for 10 rounds', () {
    expect(_date(const [], round: 9).isActive, isTrue);
    expect(_date(const [], round: 10).isDone, isTrue);
  });
}
