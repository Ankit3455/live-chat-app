// lib/services/avatar_traits.dart
//
// Explains a generated avatar in plain language ("Reading -> Glasses").
// Rows are built from the params that were actually used to draw the face
// (avatarProperties.avatarParams), so the explanation is always true.

class AvatarTrait {
  final String emoji;

  /// The user's answer, e.g. "Reading".
  final String answer;

  /// Where the answer came from, e.g. "your interest".
  final String source;

  /// What it changed on the avatar, e.g. "Glasses".
  final String effect;

  const AvatarTrait(this.emoji, this.answer, this.source, this.effect);
}

class AvatarTraits {
  AvatarTraits._();

  static const Map<String, String> _signEmoji = {
    'Aries': '♈︎',
    'Taurus': '♉︎',
    'Gemini': '♊︎',
    'Cancer': '♋︎',
    'Leo': '♌︎',
    'Virgo': '♍︎',
    'Libra': '♎︎',
    'Scorpio': '♏︎',
    'Sagittarius': '♐︎',
    'Capricorn': '♑︎',
    'Aquarius': '♒︎',
    'Pisces': '♓︎',
  };

  static const Map<String, String> _palette = {
    'fire': 'Warm coral colours',
    'earth': 'Sage & olive colours',
    'air': 'Sky & lavender colours',
    'water': 'Ocean colours',
  };

  static const Map<String, String> _clothing = {
    'hoodie': 'Hoodie',
    'graphicShirt': 'Graphic tee',
    'collarAndSweater': 'Collar & sweater',
    'blazerAndShirt': 'Blazer',
    'blazerAndSweater': 'Blazer & sweater',
    'overall': 'Overalls',
    'shirtCrewNeck': 'T-shirt',
    'shirtVNeck': 'V-neck tee',
    'shirtScoopNeck': 'Scoop-neck tee',
  };

  // Graphic print -> (emoji, interest that produces it).
  static const Map<String, (String, String)> _graphics = {
    'pizza': ('🍳', 'Cooking'),
    'deer': ('✈️', 'Travel'),
    'diamond': ('🔮', 'Astrology'),
    'cumbia': ('🎵', 'Music'),
    'skullOutline': ('💻', 'Tech'),
    'bat': ('🎸', 'Rock & EDM'),
    'hola': ('❤️', 'Romance'),
    'bear': ('🎨', 'Art'),
  };

  static const Map<String, String> _graphicName = {
    'pizza': 'Pizza print',
    'deer': 'Deer print',
    'diamond': 'Diamond print',
    'cumbia': 'Music print',
    'skullOutline': 'Tech print',
    'bat': 'Bat print',
    'hola': '"Hola" print',
    'bear': 'Bear print',
  };

  /// Rows for "Why you look like this". [avatarProperties] is the stored
  /// users/{uid}.avatarProperties map (props + avatarParams).
  static List<AvatarTrait> explain(Map<String, dynamic> avatarProperties) {
    final props = avatarProperties;
    final rawParams = props['avatarParams'];
    if (rawParams is! Map) return const [];
    final params = rawParams.map((k, v) => MapEntry(k.toString(), v.toString()));
    bool flag(String key) => props[key] == true;
    final rows = <AvatarTrait>[];

    final sign = props['zodiacSign']?.toString();
    final element = (props['element'] ?? '').toString();
    if (sign != null && _palette.containsKey(element)) {
      rows.add(AvatarTrait(_signEmoji[sign] ?? '✨', sign,
          'from your birth date', _palette[element]!));
    }

    final habit = (props['habit'] ?? '').toString();
    if (habit.contains('night')) {
      rows.add(const AvatarTrait('🌙', 'Night owl', 'your habit', 'Night-sky shades'));
    } else if (habit.contains('early')) {
      rows.add(const AvatarTrait('🌅', 'Early riser', 'your habit', 'Bright day shades'));
    }

    final personality = (props['personality'] ?? '').toString();
    if (personality.contains('extro')) {
      rows.add(const AvatarTrait('🥳', 'Extrovert', 'your personality', 'Big smile'));
    } else if (personality.contains('intro')) {
      rows.add(const AvatarTrait('🌿', 'Introvert', 'your personality', 'Calm expression'));
    } else if (personality.contains('ambi')) {
      rows.add(const AvatarTrait('😊', 'Ambivert', 'your personality', 'Warm smile'));
    }

    if (params['eyes'] == 'hearts') {
      rows.add(const AvatarTrait('❤️', 'Romance', 'your interest', 'Heart eyes'));
    }

    final accessory = params['accessoriesProbability'] == '100'
        ? params['accessories']
        : null;
    if (accessory != null) {
      if (accessory.startsWith('prescription') && flag('likesReading')) {
        rows.add(const AvatarTrait('📚', 'Reading', 'your interest', 'Glasses'));
      } else if (flag('likesTech') &&
          (accessory == 'round' || accessory == 'prescription02')) {
        rows.add(const AvatarTrait('💻', 'Tech & gaming', 'your interest', 'Round glasses'));
      } else if (accessory == 'wayfarers' || accessory == 'sunglasses') {
        rows.add(flag('isPartyGoer')
            ? const AvatarTrait('🎉', 'Loves parties', 'your lifestyle', 'Sunglasses')
            : const AvatarTrait('✈️', 'Travel', 'your interest', 'Sunglasses'));
      } else if (flag('likesMystic')) {
        rows.add(const AvatarTrait('🔮', 'Astrology', 'your interest', 'Round shades'));
      }
    }

    final clothing = params['clothing'];
    final profession = (props['profession'] ?? '').toString();
    if (clothing != null && _clothing.containsKey(clothing)) {
      final outfit = _clothing[clothing]!;
      if (profession.isNotEmpty && profession.toLowerCase() != 'other') {
        rows.add(AvatarTrait('💼', profession, 'your profession', outfit));
      } else if (flag('isActive') || flag('likesSports')) {
        rows.add(AvatarTrait('🏃', 'Active lifestyle', 'your answers', outfit));
      }
    }

    final graphic = params['clothingGraphic'];
    if (clothing == 'graphicShirt' && graphic != null && _graphics.containsKey(graphic)) {
      final (emoji, interest) = _graphics[graphic]!;
      rows.add(AvatarTrait(emoji, interest, 'your interest', _graphicName[graphic]!));
    }

    final hair = params['hairColor'];
    if (hair == 'f59797' || hair == 'ecdcbf') {
      rows.add(AvatarTrait('🎨', 'Creative', 'your answers',
          hair == 'f59797' ? 'Pastel pink hair' : 'Platinum hair'));
    }

    return rows;
  }

  /// Short hint for the live preview after an answer changed the face, e.g.
  /// "📚 Reading → glasses added". Null when nothing visible changed.
  static String? changeHint({
    required Map<String, String>? before,
    required Map<String, String> after,
    required String answerLabel,
  }) {
    if (before == null) return null;
    String? change;
    final hadAcc = before['accessoriesProbability'] == '100';
    final hasAcc = after['accessoriesProbability'] == '100';
    if (!hadAcc && hasAcc) {
      final a = after['accessories'] ?? '';
      change = a.startsWith('prescription') || a == 'round'
          ? 'glasses added'
          : 'shades added';
    } else if (after['eyes'] == 'hearts' && before['eyes'] != 'hearts') {
      change = 'heart eyes';
    } else if (after['clothingGraphic'] != null &&
        after['clothingGraphic'] != before['clothingGraphic']) {
      change = 'new T-shirt print';
    } else if (after['clothing'] != before['clothing']) {
      change = 'new outfit';
    } else if (after['top'] != before['top']) {
      change = 'new hairstyle';
    } else if (after['backgroundColor'] != before['backgroundColor']) {
      change = 'new colours';
    } else if (after['eyes'] != before['eyes'] ||
        after['mouth'] != before['mouth']) {
      change = 'new expression';
    }
    if (change == null) return null;
    return answerLabel.isEmpty ? change : '$answerLabel → $change';
  }
}
