// lib/services/avatar_mapping.dart
//
// Maps questionnaire answers to avatar properties (the single props shape
// stored in users/{uid}.avatarProperties) and turns those properties into
// explicit DiceBear avataaars query params.
//
// Every visual part is constrained to a hand-picked list so the seed only
// varies within "nice" options: no dizzy/crying eyes, no vomit or grimace
// mouths, no angry brows, no eyepatch, natural skin colours.
//
// What drives what:
//   gender            -> hair styles, facial hair
//   age (from DOB)    -> grey hair, beard likelihood, formal clothes
//   zodiac element    -> colour palette (background, clothes, glasses)
//   habits            -> day / night version of that palette, eye mood
//   personality       -> expression (falls back to interests)
//   interests         -> accessories, T-shirt print, expression
//   profession        -> outfit (falls back to exercise / music / age)
//   partying, music   -> party shades, print or collar
// Post-signup answers (personality, exercise, music, partying) only exist
// once the user has filled them, so they affect regenerated avatars.

import '../core/utils/astrology_utils.dart';

class AvatarMapping {
  static const List<String> _maleTops = [
    'shortFlat',
    'shortRound',
    'shortWaved',
    'shortCurly',
    'theCaesar',
    'theCaesarAndSidePart',
    'sides',
    'shavedSides',
    'frizzle',
    'dreads01',
    'shaggy',
    'curly',
  ];

  static const List<String> _femaleTops = [
    'bigHair',
    'bob',
    'bun',
    'curly',
    'curvy',
    'frida',
    'longButNotTooLong',
    'miaWallace',
    'straight01',
    'straight02',
    'straightAndStrand',
    'fro',
    'froBand',
  ];

  static const List<String> _neutralTops = [
    'bob',
    'bun',
    'curly',
    'frizzle',
    'shaggy',
    'shaggyMullet',
    'shortCurly',
    'shortWaved',
    'straight02',
    'fro',
  ];

  static const List<String> _facialHair = [
    'beardLight',
    'beardMedium',
    'beardMajestic',
    'moustacheFancy',
    'moustacheMagnum',
  ];

  static const List<String> _skinColors = [
    'ffdbb4',
    'edb98a',
    'fd9841',
    'd08b5b',
    'ae5d29',
    '614335',
  ];

  static const List<String> _youngHairColors = [
    '2c1b18',
    '4a312c',
    '724133',
    'a55728',
    'b58143',
    'c93305',
  ];

  static const List<String> _adultHairColors = [
    '2c1b18',
    '4a312c',
    '724133',
    'a55728',
    'b58143',
    'e8e1e1',
  ];

  // Creative profiles occasionally get pastel pink or platinum hair.
  static const List<String> _creativeHairColors = ['f59797', 'ecdcbf'];

  /// Build avatar properties from questionnaire answers (or from a stored
  /// avatarProperties map merged with user-doc fields; the shape is the same).
  static Map<String, dynamic> buildFromAnswers(Map<String, dynamic> answers) {
    final gender = normalizeGender(answers['gender']);

    final rawHabits =
        (answers['habits'] ?? answers['habit'] ?? '').toString().trim();
    final habits = rawHabits.isNotEmpty ? rawHabits.toLowerCase() : 'balanced';

    final interests = _lowerList(answers['interests']);
    final music = _lowerList(answers['musicGenres']);

    final username =
        (answers['username'] ?? answers['userName'] ?? '').toString().trim();

    // Only derived values are kept; exact DOB is private.
    final dob = _parseDob(answers['dateOfBirth'] ?? answers['dob']);
    final ageGroup = dob != null
        ? _ageGroup(dob)
        : (answers['ageGroup'] ?? '').toString();
    final sign = AstrologyUtils.normalizeSign(
          (answers['zodiacSign'] ?? answers['sunSign'])?.toString(),
        ) ??
        (dob != null ? AstrologyUtils.zodiacFromDate(dob) : null);
    final element = (AstrologyUtils.elementOf(sign) ??
            (answers['element'] ?? '').toString())
        .toLowerCase();

    final profession = (answers['profession'] ?? '').toString().trim();
    final personality =
        (answers['personalityType'] ?? answers['personality'] ?? '')
            .toString()
            .toLowerCase();
    final exercise =
        (answers['exerciseFrequency'] ?? '').toString().toLowerCase();
    final partying =
        (answers['partyingFrequency'] ?? '').toString().toLowerCase();

    bool likes(List<String> keys) =>
        interests.any((i) => keys.any((k) => i.contains(k)));
    bool listens(List<String> keys) =>
        music.any((m) => keys.any((k) => m.contains(k)));

    return <String, dynamic>{
      'gender': gender,
      'habit': habits,
      'interests': interests,
      if (username.isNotEmpty) 'username': username,
      if (ageGroup.isNotEmpty) 'ageGroup': ageGroup,
      if (element.isNotEmpty) 'element': element,
      if (profession.isNotEmpty) 'profession': profession,
      if (personality.isNotEmpty) 'personality': personality,
      'likesMusic': likes(['music']),
      'likesSports': likes(['sport', 'yoga', 'danc']),
      'likesArt': likes(['art', 'photo']),
      'likesReading': likes(['reading']),
      'likesTech': likes(['tech', 'gaming']),
      'likesTravel': likes(['travel']),
      'likesMystic': likes(['astrology', 'mystic', 'stargaz']),
      'likesRomance': likes(['romance']),
      'likesCooking': likes(['cook']),
      'isCalm': likes(['meditation', 'yoga', 'deep conversation', 'reading']),
      'isEnergetic': likes(['sport', 'danc', 'travel', 'music']),
      'isActive': exercise.contains('daily') || exercise.contains('3-4'),
      'isPartyGoer': partying.contains('love') || partying.contains('often'),
      'likesLoudMusic': listens(['rock', 'edm', 'hip-hop', 'hip hop']),
      'likesClassical': listens(['classical', 'jazz']),
      'bgTone': _bgToneFromHabits(habits),
    };
  }

  /// Explicit avataaars params derived from [props]. The seed only adds
  /// stable randomness inside these constraints.
  static Map<String, String> dicebearParams(Map<String, dynamic> props) {
    final gender = normalizeGender(props['gender']);
    final dob = _parseDob(props['dateOfBirth'] ?? props['dob']);
    final ageGroup =
        dob != null ? _ageGroup(dob) : (props['ageGroup'] ?? '').toString();
    final adult = ageGroup == 'adult';
    final bgTone = (props['bgTone'] ??
            _bgToneFromHabits(
                (props['habit'] ?? props['habits'] ?? '').toString()))
        .toString();
    final night = bgTone == 'dark';
    final palette = _Palette.of((props['element'] ?? '').toString(), night: night);
    final profession = (props['profession'] ?? '').toString().toLowerCase();
    bool flag(String key) => props[key] == true;
    final creative = profession == 'artist' || flag('likesArt');

    final params = <String, String>{
      'backgroundColor': palette.background.join(','),
      'backgroundType': 'gradientLinear',
      'skinColor': _skinColors.join(','),
      'hairColor': [
        ...(adult ? _adultHairColors : _youngHairColors),
        if (creative) ..._creativeHairColors,
      ].join(','),
      'topProbability': '100',
      'clothesColor': palette.clothes.join(','),
      'accessoriesColor': palette.accessories.join(','),
    };

    final clothing = _clothing(profession, props, adult: adult);
    params['clothing'] = clothing.join(',');
    if (clothing.contains('graphicShirt')) {
      params['clothingGraphic'] = _graphics(props).join(',');
    }

    switch (gender) {
      case 'male':
        params['top'] = _maleTops.join(',');
        params['facialHair'] = _facialHair.join(',');
        params['facialHairProbability'] = adult ? '70' : '30';
        break;
      case 'female':
        params['top'] = _femaleTops.join(',');
        params['facialHairProbability'] = '0';
        break;
      default:
        params['top'] = _neutralTops.join(',');
        params['facialHairProbability'] = '0';
    }

    _applyExpression(params, props, night: night);
    _applyAccessories(params, props);

    return params;
  }

  /// Normalize gender to 'male' / 'female' / 'other'.
  static String normalizeGender(dynamic gender) {
    if (gender == null) return 'other';
    final g = gender.toString().toLowerCase().trim();
    if (g == 'male' || g == 'man' || g == 'm') return 'male';
    if (g == 'female' || g == 'woman' || g == 'f') return 'female';
    return 'other';
  }

  /// 'young' (<=35), 'adult' (>35) or '' when DOB is unknown.
  /// Accepts DateTime, ISO string, epoch int, or a Firestore Timestamp
  /// (duck-typed via toDate()).
  static String ageGroupFromDob(dynamic raw) {
    final dob = _parseDob(raw);
    return dob == null ? '' : _ageGroup(dob);
  }

  // ---------------------------------------------------------------------------

  static DateTime? _parseDob(dynamic raw) {
    try {
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      if (raw is int) {
        return raw > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(raw)
            : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      }
      if (raw != null) {
        final dynamic d = (raw as dynamic).toDate();
        if (d is DateTime) return d;
      }
    } catch (_) {}
    return null;
  }

  static String _ageGroup(DateTime dob) {
    final now = DateTime.now();
    final age = now.year -
        dob.year -
        ((now.month < dob.month ||
                (now.month == dob.month && now.day < dob.day))
            ? 1
            : 0);
    return age <= 35 ? 'young' : 'adult';
  }

  static List<String> _lowerList(dynamic raw) => raw is List
      ? raw.map((e) => e.toString().toLowerCase()).toList()
      : <String>[];

  static void _applyExpression(
    Map<String, String> params,
    Map<String, dynamic> props, {
    required bool night,
  }) {
    bool flag(String key) => props[key] == true;
    final personality = (props['personality'] ?? '').toString();

    // Personality (post-signup) wins; otherwise infer from interests.
    final String mood;
    if (personality.contains('extro')) {
      mood = 'bright';
    } else if (personality.contains('intro')) {
      mood = 'calm';
    } else if (personality.contains('ambi')) {
      mood = 'warm';
    } else if (flag('isEnergetic') && !flag('isCalm')) {
      mood = 'bright';
    } else if (flag('isCalm') && !flag('isEnergetic')) {
      mood = 'calm';
    } else {
      mood = 'warm';
    }

    switch (mood) {
      case 'bright':
        params['mouth'] = 'smile,twinkle';
        params['eyes'] = 'happy,wink,default';
        params['eyebrows'] = 'raisedExcited,raisedExcitedNatural,defaultNatural';
        break;
      case 'calm':
        params['mouth'] = 'default,smile';
        params['eyes'] = night ? 'squint,default' : 'default,squint,happy';
        params['eyebrows'] = 'defaultNatural,default,flatNatural';
        break;
      default:
        params['mouth'] = 'smile,default,twinkle';
        params['eyes'] = night ? 'squint,default,happy' : 'default,happy,wink';
        params['eyebrows'] = 'default,defaultNatural,upDownNatural';
    }

    if (flag('likesRomance')) params['eyes'] = 'hearts,happy';
    if (flag('isPartyGoer')) params['mouth'] = 'twinkle,smile';
  }

  static void _applyAccessories(
    Map<String, String> params,
    Map<String, dynamic> props,
  ) {
    bool flag(String key) => props[key] == true;
    if (flag('likesReading')) {
      params['accessories'] = 'prescription01,prescription02';
      params['accessoriesProbability'] = '100';
    } else if (flag('likesTech')) {
      params['accessories'] = 'round,prescription02';
      params['accessoriesProbability'] = '80';
    } else if (flag('isPartyGoer') || flag('likesTravel')) {
      params['accessories'] = 'wayfarers,sunglasses';
      params['accessoriesProbability'] = '80';
    } else if (flag('likesMystic')) {
      params['accessories'] = 'kurt,round';
      params['accessoriesProbability'] = '50';
    } else {
      params['accessoriesProbability'] = '0';
    }
  }

  static List<String> _clothing(
    String profession,
    Map<String, dynamic> props, {
    required bool adult,
  }) {
    bool flag(String key) => props[key] == true;
    switch (profession) {
      case 'engineer':
        return ['hoodie', 'graphicShirt'];
      case 'doctor':
        return ['collarAndSweater', 'blazerAndShirt'];
      case 'artist':
        return ['overall', 'graphicShirt'];
      case 'student':
        return ['hoodie', 'shirtCrewNeck', 'graphicShirt'];
      case 'astrology consultant':
        return ['blazerAndSweater', 'collarAndSweater'];
    }
    if (flag('isActive') || flag('likesSports')) return ['shirtVNeck', 'hoodie'];
    if (flag('likesClassical')) return ['collarAndSweater', 'blazerAndSweater'];
    if (flag('likesLoudMusic')) return ['graphicShirt', 'hoodie'];
    if (adult) return ['blazerAndShirt', 'collarAndSweater'];
    return ['shirtCrewNeck', 'shirtScoopNeck', 'shirtVNeck', 'graphicShirt'];
  }

  static List<String> _graphics(Map<String, dynamic> props) {
    bool flag(String key) => props[key] == true;
    final g = <String>[
      if (flag('likesCooking')) 'pizza',
      if (flag('likesTravel')) 'deer',
      if (flag('likesMystic')) 'diamond',
      if (flag('likesMusic')) 'cumbia',
      if (flag('likesTech')) 'skullOutline',
      if (flag('likesLoudMusic')) 'bat',
      if (flag('likesRomance')) 'hola',
      if (flag('likesArt')) 'bear',
    ];
    return g.isNotEmpty ? g : const ['bear', 'deer', 'diamond', 'hola'];
  }

  static String _bgToneFromHabits(String habits) {
    final h = habits.toLowerCase();
    if (h.contains('night')) return 'dark';
    if (h.contains('early') || h.contains('morning')) return 'light';
    return 'neutral';
  }
}

/// Colour set per zodiac element, in a day and a night (night owl) version.
class _Palette {
  final List<String> background;
  final List<String> clothes;
  final List<String> accessories;

  const _Palette(this.background, this.clothes, this.accessories);

  static _Palette of(String element, {required bool night}) {
    switch (element) {
      case 'fire':
        return night
            ? const _Palette(['5a1f3d', '7a2a3a'], ['ff5c5c', '262e33', 'ff488e'], ['ff5c5c', 'ffffff'])
            : const _Palette(['ffd1c1', 'ffb3a7'], ['ff5c5c', 'ff488e', 'ffafb9'], ['ff5c5c', '262e33']);
      case 'earth':
        return night
            ? const _Palette(['2f3d2a', '3e4a2d'], ['3c4f5c', '929598', '25557c'], ['929598', 'ffdeb5'])
            : const _Palette(['dfe8c8', 'c9dbb2'], ['a7ffc4', 'ffdeb5', '929598'], ['3c4f5c', '929598']);
      case 'air':
        return night
            ? const _Palette(['2a3566', '3a2f6b'], ['5199e4', 'e6e6e6', '262e33'], ['65c9ff', 'ffffff'])
            : const _Palette(['d6ecff', 'e3dcff'], ['b1e2ff', 'e6e6e6', '65c9ff'], ['5199e4', '262e33']);
      case 'water':
        return night
            ? const _Palette(['1f2f5c', '3b2a6b'], ['25557c', '5199e4', '262e33'], ['65c9ff', 'ffffff'])
            : const _Palette(['c9e7f2', 'd1d4f9'], ['65c9ff', '25557c', 'b1e2ff'], ['25557c', '3c4f5c']);
      default:
        return night
            ? const _Palette(['3b2a6b', '4c2f7a'], ['262e33', '3c4f5c', '5199e4'], ['65c9ff', 'ffffff'])
            : const _Palette(['d1d4f9', 'c0aede'], ['a7ffc4', 'b1e2ff', 'ffffb1'], ['3c4f5c', '262e33']);
    }
  }
}
