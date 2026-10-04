// lib/services/avatar_mapping.dart
//
// Maps questionnaire answers to avatar properties (the single props shape
// stored in users/{uid}.avatarProperties) and turns those properties into
// explicit DiceBear avataaars query params.

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

  static const List<String> _maleFacialHair = [
    'beardLight',
    'beardMedium',
    'moustacheFancy',
  ];

  static const List<String> _readingAccessories = [
    'prescription01',
    'prescription02',
    'round',
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

    final props = <String, dynamic>{
      'gender': gender,
      'habit': habits,
      'interests': interests,
      if (username.isNotEmpty) 'username': username,
      if (ageGroup.isNotEmpty) 'ageGroup': ageGroup,
      if (profession.isNotEmpty) 'profession': profession,
    };

    props['likesMusic'] = interests.any((i) => i.contains('music'));
    props['likesSports'] = interests.any(
        (i) => i.contains('sport') || i.contains('yoga') || i.contains('danc'));
    props['likesArt'] = interests.any(
        (i) => i.contains('art') || i.contains('photo'));
    props['likesReading'] = interests.any((i) => i.contains('reading'));

    props['bgTone'] = _bgToneFromHabits(habits);

    return props;
  }

  /// Explicit avataaars params derived from [props]. The seed only adds
  /// stable randomness inside these constraints.
  static Map<String, String> dicebearParams(Map<String, dynamic> props) {
    final gender = normalizeGender(props['gender']);
    final fromDob = ageGroupFromDob(props['dateOfBirth'] ?? props['dob']);
    final ageGroup =
        fromDob.isNotEmpty ? fromDob : (props['ageGroup'] ?? '').toString();
    final bgTone = (props['bgTone'] ??
            _bgToneFromHabits(
                (props['habit'] ?? props['habits'] ?? '').toString()))
        .toString();

    final params = <String, String>{
      'backgroundColor': _backgroundColors(bgTone).join(','),
    };

    switch (gender) {
      case 'male':
        params['top'] = _maleTops.join(',');
        params['topProbability'] = '100';
        params['facialHair'] = _maleFacialHair.join(',');
        params['facialHairProbability'] =
            ageGroup == 'adult' ? '60' : (ageGroup == 'young' ? '35' : '20');
        break;
      case 'female':
        params['top'] = _femaleTops.join(',');
        params['topProbability'] = '100';
        params['facialHairProbability'] = '0';
        break;
      default:
        params['topProbability'] = '100';
        params['facialHairProbability'] = '0';
    }

    if (props['likesReading'] == true) {
      params['accessories'] = _readingAccessories.join(',');
      params['accessoriesProbability'] = '70';
    } else {
      params['accessoriesProbability'] = '10';
    }

    if (props['likesSports'] == true) {
      params['clothing'] = 'hoodie,shirtCrewNeck,shirtVNeck';
    } else if (props['likesArt'] == true) {
      params['clothing'] = 'graphicShirt,overall,collarAndSweater';
    } else if (ageGroup == 'adult') {
      params['clothing'] = 'blazerAndShirt,blazerAndSweater,collarAndSweater';
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

  static List<String> _backgroundColors(String tone) {
    switch (tone) {
      case 'dark':
        return ['65c9ff', '5199e4', 'c0aede'];
      case 'light':
        return ['ffdfbf', 'ffd5dc', 'fff2b3'];
      default:
        return ['b6e3f4', 'd1d4f9', 'c0aede'];
    }
  }

  static String _bgToneFromHabits(String habits) {
    final h = habits.toLowerCase();
    if (h.contains('night')) return 'dark';
    if (h.contains('early') || h.contains('morning')) return 'light';
    return 'neutral';
  }
}
