// lib/feature/games/chat_games/rate_it/rate_topics.dart
//
// Rate It: both rate the same 5 things from 1 to 10, then compare.

import 'dart:math';

class RateTopic {
  final String id;
  final String emoji;
  final String label;

  const RateTopic(this.id, this.emoji, this.label);
}

class RateTopics {
  RateTopics._();

  static const int minScore = 1;
  static const int maxScore = 10;

  static const List<RateTopic> pool = [
    RateTopic('pineapple_pizza', '🍍', 'Pineapple on pizza'),
    RateTopic('horror', '👻', 'Horror movies'),
    RateTopic('six_am', '⏰', 'Waking up at 6 AM'),
    RateTopic('road_trips', '🚗', 'Long road trips'),
    RateTopic('spicy', '🌶️', 'Very spicy food'),
    RateTopic('public_dance', '💃', 'Dancing in public'),
    RateTopic('rain', '🌧️', 'Rainy days'),
    RateTopic('cats', '🐱', 'Cats'),
    RateTopic('dogs', '🐶', 'Dogs'),
    RateTopic('bollywood', '🎶', 'Old Bollywood songs'),
    RateTopic('gym', '🏋️', 'Going to the gym'),
    RateTopic('shopping', '🛍️', 'Shopping'),
    RateTopic('camping', '⛺', 'Camping'),
    RateTopic('street_food', '🌮', 'Street food'),
    RateTopic('cricket', '🏏', 'Watching cricket'),
    RateTopic('surprise_party', '🎉', 'Surprise parties'),
    RateTopic('reality_tv', '📺', 'Reality shows'),
    RateTopic('sleep_in', '😴', 'Sleeping in on Sunday'),
    RateTopic('coffee', '☕', 'Coffee'),
    RateTopic('chai', '🫖', 'Chai'),
    RateTopic('mountains', '🏔️', 'Mountain trips'),
    RateTopic('beaches', '🏖️', 'Beach holidays'),
    RateTopic('video_games', '🎮', 'Video games'),
    RateTopic('cooking', '👩‍🍳', 'Cooking at home'),
    RateTopic('karaoke', '🎤', 'Karaoke nights'),
    RateTopic('astrology', '✨', 'Astrology'),
    RateTopic('selfies', '🤳', 'Taking selfies'),
    RateTopic('voice_notes', '🎙️', 'Voice notes'),
    RateTopic('books', '📚', 'Reading books'),
    RateTopic('weddings', '💒', 'Big fat weddings'),
  ];

  static final Map<String, RateTopic> _byId = {for (final t in pool) t.id: t};

  static RateTopic? byId(String? id) => id == null ? null : _byId[id];

  /// [rounds] different topics, one per round.
  static List<List<String>> buildDeck(int rounds, Random random) {
    final shuffled = List.of(pool)..shuffle(random);
    return [
      for (final t in shuffled.take(rounds)) [t.id],
    ];
  }

  static bool isValidScore(Object? v) =>
      v is int && v >= minScore && v <= maxScore;

  /// 100 when every rating matched, 0 when every pair was 1 vs 10.
  static int tasteMatch(List<(int, int)> ratings) {
    if (ratings.isEmpty) return 0;
    const span = maxScore - minScore;
    final total = ratings.fold<double>(
      0,
      (sum, r) => sum + (1 - (r.$1 - r.$2).abs() / span),
    );
    return (total / ratings.length * 100).round();
  }
}
