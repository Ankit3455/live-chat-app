// lib/feature/games/chat_games/telepathy/telepathy_prompts.dart
//
// Telepathy: a co-op game. Each round shows a word and 9 emojis; both pick
// the 3 they think the OTHER person will pick. Matching emojis = points.

import 'dart:math';

class TelepathyPrompt {
  final String id;
  final String label;
  final List<String> emojis;

  const TelepathyPrompt(this.id, this.label, this.emojis);
}

class TelepathyPrompts {
  TelepathyPrompts._();

  static const int picksPerRound = 3;
  static const int choicesPerRound = 9;

  static const List<TelepathyPrompt> pool = [
    TelepathyPrompt('sunday', 'Perfect Sunday', [
      '😴',
      '☕',
      '🎬',
      '🍕',
      '🏞️',
      '📚',
      '🎮',
      '🛍️',
      '🧘',
    ]),
    TelepathyPrompt('first_date', 'First date', [
      '☕',
      '🍝',
      '🎳',
      '🎤',
      '🌃',
      '🎡',
      '🍦',
      '🎨',
      '🚶',
    ]),
    TelepathyPrompt('rainy_day', 'A rainy day', [
      '☔',
      '🍜',
      '🛋️',
      '🎬',
      '🫖',
      '📚',
      '😴',
      '🎮',
      '💃',
    ]),
    TelepathyPrompt('road_trip', 'Road trip', [
      '🚗',
      '🗺️',
      '🎶',
      '🍔',
      '⛰️',
      '🏖️',
      '📸',
      '⛺',
      '🌅',
    ]),
    TelepathyPrompt('monday', 'Monday morning', [
      '😩',
      '☕',
      '⏰',
      '🏃',
      '📱',
      '🥱',
      '🚿',
      '🍳',
      '💼',
    ]),
    TelepathyPrompt('celebration', 'Celebration', [
      '🎉',
      '🍰',
      '🥂',
      '💃',
      '🎁',
      '🎆',
      '🍕',
      '🎤',
      '🥳',
    ]),
    TelepathyPrompt('late_night', 'Late night', [
      '🌙',
      '🍜',
      '📺',
      '💬',
      '🌌',
      '🎧',
      '🍿',
      '😴',
      '🚗',
    ]),
    TelepathyPrompt('beach', 'Beach day', [
      '🏖️',
      '🌊',
      '🍹',
      '😎',
      '🏐',
      '🐚',
      '🍦',
      '📸',
      '🌅',
    ]),
    TelepathyPrompt('winter', 'Winter', [
      '❄️',
      '🧣',
      '☕',
      '🍲',
      '🛋️',
      '🎄',
      '🔥',
      '⛷️',
      '🍫',
    ]),
    TelepathyPrompt('comfort_food', 'Comfort food', [
      '🍕',
      '🍜',
      '🍔',
      '🥟',
      '🍫',
      '🍦',
      '🍛',
      '🧁',
      '🥘',
    ]),
    TelepathyPrompt('dream_holiday', 'Dream holiday', [
      '🏝️',
      '🏔️',
      '🗼',
      '🏯',
      '🏜️',
      '🚢',
      '✈️',
      '🏰',
      '🌋',
    ]),
    TelepathyPrompt('lazy_day', 'Lazy day', [
      '🛌',
      '📺',
      '🍕',
      '😴',
      '🐱',
      '🎮',
      '📱',
      '🍿',
      '🧸',
    ]),
    TelepathyPrompt('party', 'Party', [
      '🎉',
      '💃',
      '🎶',
      '🍕',
      '🥤',
      '🎤',
      '🕺',
      '🎈',
      '🪩',
    ]),
    TelepathyPrompt('love', 'Love', [
      '❤️',
      '🌹',
      '💌',
      '💍',
      '🫶',
      '🥰',
      '😘',
      '🍫',
      '🌙',
    ]),
    TelepathyPrompt('adventure', 'Adventure', [
      '🧗',
      '🪂',
      '🏕️',
      '🗺️',
      '🚴',
      '🏄',
      '🌋',
      '🦁',
      '🧭',
    ]),
    TelepathyPrompt('childhood', 'Childhood', [
      '🧸',
      '🍭',
      '🚲',
      '🎈',
      '📺',
      '🏏',
      '🪁',
      '🍬',
      '🎠',
    ]),
    TelepathyPrompt('stress', 'Stress buster', [
      '🧘',
      '🎧',
      '🍫',
      '🚶',
      '😴',
      '🛁',
      '🎮',
      '🐶',
      '📞',
    ]),
    TelepathyPrompt('festival', 'Festival', [
      '🪔',
      '🎆',
      '🍬',
      '👗',
      '🎊',
      '🥳',
      '🪁',
      '🎶',
      '🏮',
    ]),
    TelepathyPrompt('summer', 'Summer', [
      '☀️',
      '🍉',
      '🏊',
      '🍦',
      '🥭',
      '😎',
      '🌴',
      '💦',
      '🩴',
    ]),
    TelepathyPrompt('movie_night', 'Movie night', [
      '🍿',
      '🎬',
      '🛋️',
      '😱',
      '😂',
      '😭',
      '🍕',
      '🥤',
      '🌙',
    ]),
    TelepathyPrompt('morning', 'Good morning', [
      '🌅',
      '☕',
      '🫖',
      '🏃',
      '🧘',
      '🍳',
      '📰',
      '🐦',
      '🚿',
    ]),
    TelepathyPrompt('pets', 'Pets', [
      '🐶',
      '🐱',
      '🐰',
      '🐠',
      '🦜',
      '🐢',
      '🐹',
      '🐴',
      '🦊',
    ]),
  ];

  static final Map<String, TelepathyPrompt> _byId = {
    for (final p in pool) p.id: p,
  };

  static TelepathyPrompt? byId(String? id) => id == null ? null : _byId[id];

  /// deck[r] = [promptId, 9 emojis in a random order].
  static List<List<String>> buildDeck(int rounds, Random random) {
    final shuffled = List.of(pool)..shuffle(random);
    return [
      for (final p in shuffled.take(rounds))
        [p.id, ...(List.of(p.emojis)..shuffle(random))],
    ];
  }

  /// 3 different emojis, all from this round's choices (deck[r] minus the
  /// prompt id at index 0).
  static bool isValidPick(Object? value, List<String> roundDeck) {
    if (value is! List || value.length != picksPerRound) return false;
    final picks = value.whereType<String>().toSet();
    final choices = roundDeck.skip(1).toSet();
    return picks.length == picksPerRound && choices.containsAll(picks);
  }

  static List<String> asPick(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  static Set<String> overlap(Object? a, Object? b) =>
      asPick(a).toSet().intersection(asPick(b).toSet());
}
