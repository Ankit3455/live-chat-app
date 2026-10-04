// lib/services/avatar_mapping.dart
//
// Maps questionnaire answers to avatar properties (the single props shape
// stored in users/{uid}.avatarProperties) and turns those properties into
// explicit DiceBear avataaars query params.
//
// Every visual part is constrained to a hand-picked list so the seed only
// varies within "nice" options: no dizzy/crying eyes, no vomit or grimace
// mouths, no angry brows, no eyepatch, natural hair and skin colours.

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
  ];

  static const List<String> _facialHair = [
    'beardLight',
    'beardMedium',
    'beardMajestic',
    'moustacheFancy',
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

  /// Build avatar properties from questionnaire answers (or from a stored
  /// avatarProperties map merged with user-doc fields; the shape is the same).
  static Map<String, dynamic> buildFromAnswers(Map<String, dynamic> answers) {
    final gender = normalizeGender(answers['gender']);

    final rawHabits =
        (answers['habits'] ?? answers['habit'] ?? '').toString().trim();
    final habits = rawHabits.isNotEmpty ? rawHabits.toLowerCase() : 'balanced';

    final interests = (answers['interests'] is List)
        ? List<String>.from((answers['interests'] as List)
            .map((e) => e.toString().toLowerCase()))
        : <String>[];

    final username =
        (answers['username'] ?? answers['userName'] ?? '').toString().trim();

    // Only the derived age group is kept; exact DOB is private.
    final fromDob = ageGroupFromDob(answers['dateOfBirth'] ?? answers['dob']);
    final ageGroup =
        fromDob.isNotEmpty ? fromDob : (answers['ageGroup'] ?? '').toString();

    final profession = (answers['profession'] ?? '').toString().trim();

    bool likes(List<String> keys) =>
        interests.any((i) => keys.any((k) => i.contains(k)));

    return <String, dynamic>{
      'gender': gender,
      'habit': habits,
      'interests': interests,
      if (username.isNotEmpty) 'username': username,
      if (ageGroup.isNotEmpty) 'ageGroup': ageGroup,
      if (profession.isNotEmpty) 'profession': profession,
      'likesMusic': likes(['music']),
      'likesSports': likes(['sport', 'yoga', 'danc']),
      'likesArt': likes(['art', 'photo']),
      'likesReading': likes(['reading']),
      'likesTech': likes(['tech', 'gaming']),
      'likesTravel': likes(['travel']),
      'likesMystic': likes(['astrology', 'mystic', 'stargaz']),
      'likesRomance': likes(['romance']),
      'isCalm': likes(['meditation', 'yoga', 'deep conversation', 'reading']),
      'isEnergetic': likes(['sport', 'danc', 'travel', 'music']),
      'bgTone': _bgToneFromHabits(habits),
    };
  }

  /// Explicit avataaars params derived from [props]. The seed only adds
  /// stable randomness inside these constraints.
  static Map<String, String> dicebearParams(Map<String, dynamic> props) {
    final gender = normalizeGender(props['gender']);
    final fromDob = ageGroupFromDob(props['dateOfBirth'] ?? props['dob']);
    final ageGroup =
        fromDob.isNotEmpty ? fromDob : (props['ageGroup'] ?? '').toString();
    final adult = ageGroup == 'adult';
    final bgTone = (props['bgTone'] ??
            _bgToneFromHabits(
                (props['habit'] ?? props['habits'] ?? '').toString()))
        .toString();
    bool flag(String key) => props[key] == true;

    final params = <String, String>{
      'backgroundColor': _backgroundColors(bgTone).join(','),
      'backgroundType': 'gradientLinear',
      'skinColor': _skinColors.join(','),
      'hairColor': (adult ? _adultHairColors : _youngHairColors).join(','),
      'topProbability': '100',
      'clothesColor': _clothesColors(bgTone).join(','),
      'clothing': _clothing(
        (props['profession'] ?? '').toString(),
        sporty: flag('likesSports'),
        adult: adult,
      ),
    };

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

    // Expression comes from interests and habits only.
    final energetic = flag('isEnergetic') && !flag('isCalm');
    params['mouth'] = energetic ? 'smile,twinkle' : 'smile,default,twinkle';
    params['eyes'] = flag('likesRomance')
        ? 'hearts,happy'
        : energetic
            ? 'happy,wink,default'
            : bgTone == 'dark'
                ? 'squint,default,happy'
                : 'default,happy';
    params['eyebrows'] = energetic
        ? 'raisedExcited,raisedExcitedNatural,defaultNatural'
        : 'default,defaultNatural,upDownNatural';

    if (flag('likesReading')) {
      params['accessories'] = 'prescription01,prescription02';
      params['accessoriesProbability'] = '100';
    } else if (flag('likesTech')) {
      params['accessories'] = 'round,prescription02';
      params['accessoriesProbability'] = '80';
    } else if (flag('likesTravel')) {
      params['accessories'] = 'wayfarers,sunglasses';
      params['accessoriesProbability'] = '80';
    } else if (flag('likesMystic')) {
      params['accessories'] = 'kurt';
      params['accessoriesProbability'] = '50';
    } else {
      params['accessoriesProbability'] = '0';
    }

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
    DateTime? dob;
    try {
      if (raw is DateTime) {
        dob = raw;
      } else if (raw is String) {
        dob = DateTime.tryParse(raw);
      } else if (raw is int) {
        dob = raw > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(raw)
            : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      } else if (raw != null) {
        final dynamic d = (raw as dynamic).toDate();
        if (d is DateTime) dob = d;
      }
    } catch (_) {}
    if (dob == null) return '';

    final now = DateTime.now();
    final age = now.year -
        dob.year -
        ((now.month < dob.month ||
                (now.month == dob.month && now.day < dob.day))
            ? 1
            : 0);
    return age <= 35 ? 'young' : 'adult';
  }

  static String _clothing(String profession, {required bool sporty, required bool adult}) {
    switch (profession.toLowerCase()) {
      case 'engineer':
        return 'hoodie,graphicShirt';
      case 'doctor':
        return 'collarAndSweater,blazerAndShirt';
      case 'artist':
        return 'overall,graphicShirt';
      case 'student':
        return 'hoodie,shirtCrewNeck';
      case 'astrology consultant':
        return 'blazerAndSweater,collarAndSweater';
    }
    if (sporty) return 'shirtVNeck,hoodie';
    if (adult) return 'blazerAndShirt,collarAndSweater';
    return 'shirtCrewNeck,shirtScoopNeck,shirtVNeck';
  }

  // Night owls get the deep Destined violet; early risers a warm sunrise.
  static List<String> _backgroundColors(String tone) {
    switch (tone) {
      case 'dark':
        return ['3b2a6b', '4c2f7a'];
      case 'light':
        return ['ffd5dc', 'ffe3c2'];
      default:
        return ['d1d4f9', 'c0aede'];
    }
  }

  static List<String> _clothesColors(String tone) {
    switch (tone) {
      case 'dark':
        return ['262e33', '3c4f5c', '5199e4'];
      case 'light':
        return ['ff5c5c', 'ffafb9', 'ffdeb5'];
      default:
        return ['a7ffc4', 'b1e2ff', 'ffffb1'];
    }
  }

  static String _bgToneFromHabits(String habits) {
    final h = habits.toLowerCase();
    if (h.contains('night')) return 'dark';
    if (h.contains('early') || h.contains('morning')) return 'light';
    return 'neutral';
  }
}
