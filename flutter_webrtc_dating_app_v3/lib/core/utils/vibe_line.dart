/// One-line summary of lifestyle/personality answers, e.g. "An active,
/// veggie-loving ambivert who parties occasionally." Derived on the fly from
/// stored answers, so nothing extra is saved.
class VibeLine {
  VibeLine._();

  static const Map<String, String> _food = {
    'Vegetarian': 'veggie-loving',
    'Vegan': 'plant-powered',
    'Eggetarian': 'egg-loving',
    'Non-vegetarian': 'foodie',
  };
  static const Map<String, String> _move = {
    'Daily': 'gym-every-day',
    '3-4 times/week': 'active',
  };
  static const Map<String, String> _personality = {
    'Introvert': 'introvert',
    'Ambivert': 'ambivert',
    'Extrovert': 'extrovert',
  };
  static const Map<String, String> _party = {
    'Love it, often': "who's always on the dance floor",
    'Occasionally': 'who parties occasionally',
    'Rarely': 'who loves cosy nights in',
    'Never': 'who prefers books to bars',
  };

  /// Null until food, personality or party energy is answered.
  static String? from(Map<String, dynamic> answers) {
    String? pick(Map<String, String> m, String field) {
      final v = answers[field];
      return v is String ? m[v] : null;
    }

    final food = pick(_food, 'foodPreference');
    final move = pick(_move, 'exerciseFrequency');
    final personality = pick(_personality, 'personalityType');
    final party = pick(_party, 'partyingFrequency');
    if (food == null && personality == null && party == null) return null;

    final adjectives = [move, food].whereType<String>().join(', ');
    final head = [
      if (adjectives.isNotEmpty) adjectives,
      personality ?? 'soul',
    ].join(' ');
    final article =
        RegExp('^[aeiou]', caseSensitive: false).hasMatch(head) ? 'An' : 'A';
    final love = answers['loveLanguage'];
    return [
      '$article $head',
      if (party != null) ' $party',
      if (love is String && love.isNotEmpty)
        ', who feels loved through ${love.toLowerCase()}',
      '.',
    ].join();
  }
}
