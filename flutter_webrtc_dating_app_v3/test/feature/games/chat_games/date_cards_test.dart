import 'dart:math';

import 'package:availchat/feature/games/chat_games/build_our_date/date_cards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('card ids are unique and every round has at least 4 cards', () {
    final ids = <String>{};
    for (final round in DateCards.rounds) {
      expect(round.pool.length, greaterThanOrEqualTo(DateCards.cardsPerRound));
      for (final c in round.pool) {
        expect(ids.add(c.id), isTrue, reason: 'duplicate ${c.id}');
        expect(DateCards.byId(c.id), same(c));
      }
    }
  });

  test('deck has 5 rounds of 4 distinct cards from that round', () {
    for (var seed = 0; seed < 50; seed++) {
      final deck = DateCards.buildDeck(
        tagsA: const {},
        tagsB: const {},
        random: Random(seed),
      );
      expect(deck.length, DateCards.rounds.length);
      for (var r = 0; r < deck.length; r++) {
        final pool = DateCards.rounds[r].pool.map((c) => c.id).toSet();
        expect(deck[r].length, DateCards.cardsPerRound);
        expect(deck[r].toSet().length, DateCards.cardsPerRound);
        expect(pool.containsAll(deck[r]), isTrue);
      }
    }
  });

  test("each player's answers put a card of theirs in the round", () {
    final night = DateCards.tagsFrom(habits: 'Night Owl');
    final reader = DateCards.tagsFrom(interests: ['Reading']);
    for (var seed = 0; seed < 50; seed++) {
      final deck = DateCards.buildDeck(
        tagsA: night,
        tagsB: reader,
        random: Random(seed),
      );
      expect(deck[4], contains('time_night'));
      expect(deck[1], contains('place_bookstore'));
    }
  });

  test('tagsFrom lower-cases and skips empty answers', () {
    expect(
      DateCards.tagsFrom(
        interests: ['Travel', ' ', null],
        habits: 'Early Riser',
      ),
      {'travel', 'early riser'},
    );
    expect(DateCards.tagsFrom(), isEmpty);
  });

  test('a round is decided only after both picks', () {
    const players = ['alice', 'bob'];
    expect(
      DateCards.decide(
        picks: {'alice': 'vibe_chill'},
        players: players,
        gameId: 'g',
        round: 0,
      ),
      isNull,
    );
    expect(
      DateCards.decide(
        picks: {'alice': 'vibe_chill', 'bob': 'vibe_chill'},
        players: players,
        gameId: 'g',
        round: 0,
      ),
      'vibe_chill',
    );
  });

  test('a split round goes to the coin winner, the same on every call', () {
    const players = ['alice', 'bob'];
    const picks = {'alice': 'vibe_chill', 'bob': 'vibe_foodie'};
    for (var r = 0; r < 5; r++) {
      final winner = players[DateCards.coinWinner('game42', r)];
      final chosen = DateCards.decide(
        picks: picks,
        players: players,
        gameId: 'game42',
        round: r,
      );
      expect(chosen, picks[winner]);
      expect(
        DateCards.coinWinner('game42', r),
        DateCards.coinWinner('game42', r),
      );
    }
  });

  test('the coin is not always the same player', () {
    final winners = {
      for (var i = 0; i < 40; i++) DateCards.coinWinner('game$i', 0),
    };
    expect(winners, {0, 1});
  });

  test('title reads like a plan', () {
    expect(
      DateCards.title([
        'vibe_romantic',
        'place_rooftop',
        'food_chai',
        'act_karaoke',
        'time_sunset',
      ]),
      'Sunset at the Rooftop: Chai & pakode + Karaoke',
    );
    expect(DateCards.title(const []), '');
  });
}
