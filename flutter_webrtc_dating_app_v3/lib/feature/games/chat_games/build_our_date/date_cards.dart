// lib/feature/games/chat_games/build_our_date/date_cards.dart
//
// The original 5-round Build Our Date cards. The game now uses
// DateQuestions; these stay so date-plan result cards already in chats
// still read (DateCards.title). No Flutter or Firebase imports.

import 'dart:math';

class DateCard {
  final String id;
  final String emoji;
  final String label;

  /// Lower-case questionnaire answers (interests, habits) that make this card
  /// the "made for you" card of its round.
  final List<String> tags;

  const DateCard(this.id, this.emoji, this.label, [this.tags = const []]);
}

class DateRound {
  final String question;
  final List<DateCard> pool;

  const DateRound(this.question, this.pool);
}

class DateCards {
  DateCards._();

  static const int cardsPerRound = 4;

  static const List<DateRound> rounds = [
    DateRound('What kind of date?', [
      DateCard('vibe_chill', '😌', 'Chill', [
        'yoga',
        'reading',
        'balanced',
        'introvert',
      ]),
      DateCard('vibe_adventure', '🧗', 'Adventure', ['travel', 'sports']),
      DateCard('vibe_foodie', '🍜', 'Foodie', ['cooking']),
      DateCard('vibe_creative', '🎨', 'Creative', [
        'art',
        'photography',
        'music',
        'dancing',
      ]),
      DateCard('vibe_romantic', '🌹', 'Romantic', [
        'romance',
        'stargazing',
        'astrology',
        'mysticism',
      ]),
      DateCard('vibe_playful', '🎮', 'Playful', ['gaming', 'tech']),
    ]),
    DateRound('Where do we go?', [
      DateCard('place_cafe', '☕', 'Café', ['deep conversations']),
      DateCard('place_beach', '🏖️', 'Beach', ['travel']),
      DateCard('place_rooftop', '🌃', 'Rooftop', ['stargazing', 'romance']),
      DateCard('place_bookstore', '📚', 'Bookstore', ['reading']),
      DateCard('place_park', '🌳', 'Park', ['yoga', 'sports', 'photography']),
      DateCard('place_gallery', '🖼️', 'Art gallery', ['art']),
      DateCard('place_arcade', '🕹️', 'Arcade', ['gaming', 'tech']),
    ]),
    DateRound('What do we eat?', [
      DateCard('food_street', '🌮', 'Street food', ['travel']),
      DateCard('food_pizza', '🍕', 'Pizza', ['gaming']),
      DateCard('food_chai', '🫖', 'Chai & pakode', [
        'deep conversations',
        'reading',
      ]),
      DateCard('food_dessert', '🍰', 'Dessert crawl', ['romance']),
      DateCard('food_cook', '👩‍🍳', 'Cook together', ['cooking']),
      DateCard('food_momos', '🥟', 'Momos'),
      DateCard('food_dosa', '🥞', 'Dosa'),
    ]),
    DateRound('What do we do?', [
      DateCard('act_boardgames', '🎲', 'Board games', ['gaming', 'tech']),
      DateCard('act_walk', '🚶', 'Long walk', ['deep conversations', 'yoga']),
      DateCard('act_movie', '🎬', 'Movie'),
      DateCard('act_karaoke', '🎤', 'Karaoke', ['music']),
      DateCard('act_dance', '💃', 'Dance class', ['dancing']),
      DateCard('act_photowalk', '📸', 'Photo walk', ['photography', 'travel']),
      DateCard('act_pottery', '🏺', 'Pottery', ['art']),
      DateCard('act_stars', '🔭', 'Stargazing', [
        'stargazing',
        'astrology',
        'mysticism',
      ]),
    ]),
    DateRound('When?', [
      DateCard('time_sunrise', '🌅', 'Sunrise', ['early riser']),
      DateCard('time_afternoon', '☀️', 'Afternoon', ['balanced']),
      DateCard('time_sunset', '🌇', 'Sunset', ['romance', 'photography']),
      DateCard('time_night', '🌙', 'Late night', ['night owl']),
    ]),
  ];

  static final Map<String, DateCard> _byId = {
    for (final r in rounds)
      for (final c in r.pool) c.id: c,
  };

  static DateCard? byId(String? id) => id == null ? null : _byId[id];

  static String roundKey(int round) => 'r$round';

  /// Lower-case tags from questionnaire answers.
  static Set<String> tagsFrom({Iterable<Object?>? interests, Object? habits}) {
    return {
      for (final i in interests ?? const <Object?>[])
        if (i != null && i.toString().trim().isNotEmpty)
          i.toString().trim().toLowerCase(),
      if (habits != null && habits.toString().trim().isNotEmpty)
        habits.toString().trim().toLowerCase(),
    };
  }

  /// Four card ids per round. Each player's tags can put one card of theirs
  /// in the round; the rest are random. Display order is shuffled.
  static List<List<String>> buildDeck({
    required Set<String> tagsA,
    required Set<String> tagsB,
    required Random random,
  }) {
    return [
      for (final round in rounds) _roundDeck(round.pool, tagsA, tagsB, random),
    ];
  }

  static List<String> _roundDeck(
    List<DateCard> pool,
    Set<String> tagsA,
    Set<String> tagsB,
    Random random,
  ) {
    final shuffled = List.of(pool)..shuffle(random);
    final picked = <DateCard>[];
    for (final tags in [tagsA, tagsB]) {
      final match = shuffled.where(
        (c) => !picked.contains(c) && c.tags.any(tags.contains),
      );
      if (match.isNotEmpty && picked.length < cardsPerRound) {
        picked.add(match.first);
      }
    }
    for (final c in shuffled) {
      if (picked.length >= cardsPerRound) break;
      if (!picked.contains(c)) picked.add(c);
    }
    picked.shuffle(random);
    return [for (final c in picked) c.id];
  }

  /// FNV-1a; String.hashCode is not guaranteed to match across platforms,
  /// and both phones must agree on the coin flip.
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Index into the players list whose card wins a split round.
  static int coinWinner(String gameId, int round) =>
      _stableHash('$gameId#$round') % 2;

  /// Card index used when nobody picked before the round timed out.
  static int fallbackIndex(String gameId, int round, int count) =>
      _stableHash('$gameId#skip#$round') % count;

  static bool isMatch(Map<String, String> picks) =>
      picks.length == 2 && picks.values.toSet().length == 1;

  /// The card chosen for a round once both players picked, else null.
  static String? decide({
    required Map<String, String> picks,
    required List<String> players,
    required String gameId,
    required int round,
  }) {
    if (players.length != 2 || !players.every(picks.containsKey)) return null;
    if (isMatch(picks)) return picks.values.first;
    return picks[players[coinWinner(gameId, round)]];
  }

  /// "Sunset at the Rooftop: Chai & pakode + Karaoke".
  static String title(List<String> cardIds) {
    String label(int i) =>
        i < cardIds.length ? (byId(cardIds[i])?.label ?? '') : '';
    final time = label(4);
    final place = label(1);
    final food = label(2);
    final activity = label(3);
    final head = [
      if (time.isNotEmpty) time,
      if (place.isNotEmpty) 'at the $place',
    ].join(' ');
    final tail = [
      if (food.isNotEmpty) food,
      if (activity.isNotEmpty) activity,
    ].join(' + ');
    if (head.isEmpty) return tail;
    if (tail.isEmpty) return head;
    return '$head: $tail';
  }
}
