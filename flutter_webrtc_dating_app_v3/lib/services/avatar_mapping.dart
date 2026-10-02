// lib/services/avatar_mapping.dart
//
// Enhanced avatar mapping for DiceBear
// Maps questionnaire answers to avatar properties

class AvatarMapping {
  /// Build avatar properties from questionnaire answers
  static Map<String, dynamic> buildFromAnswers(Map<String, dynamic> answers) {
    // Normalize gender (critical for DiceBear)
    final rawGender = (answers['gender'] ?? '').toString().trim();
    final gender = _normalizeGender(rawGender);

    // Habits
    final rawHabits = (answers['habits'] ?? answers['habit'] ?? '').toString().trim();
    final habits = rawHabits.isNotEmpty ? rawHabits.toLowerCase() : 'balanced';

    // Interests
    final interests = (answers['interests'] is List)
        ? List<String>.from((answers['interests'] as List).map((e) => e.toString().toLowerCase()))
        : <String>[];

    // Username
    final username = (answers['username'] ?? answers['userName'] ?? '').toString().trim();

    // Date of birth
    final dob = answers['dateOfBirth'] ?? answers['dob'];

    // Bio
    final bio = (answers['bio'] ?? '').toString().trim();

    // Build properties map
    final props = <String, dynamic>{
      'gender': gender, // ✅ Normalized
      'habit': habits,
      'interests': interests,
      if (username.isNotEmpty) 'username': username,
      if (dob != null) 'dateOfBirth': dob,
      if (bio.isNotEmpty) 'bio': bio,
    };

    // Derived boolean flags
    props['likesMusic'] = interests.any((i) => i.contains('music'));
    props['likesSports'] = interests.any((i) => i.contains('sport'));
    props['likesArt'] = interests.any((i) => i.contains('art'));
    props['likesReading'] = interests.any((i) => i.contains('reading'));

    // Background tone from habits
    props['bgTone'] = _bgToneFromHabits(habits);

    return props;
  }

  /// Normalize gender to lowercase standard values
  static String _normalizeGender(String? gender) {
    if (gender == null || gender.isEmpty) return 'other';

    final g = gender.toLowerCase().trim();

    // Male variations
    if (g == 'male' || g == 'man' || g == 'm') return 'male';

    // Female variations
    if (g == 'female' || g == 'woman' || g == 'f') return 'female';

    // Everything else
    return 'other';
  }

  /// Background tone from habits
  static String _bgToneFromHabits(String habits) {
    if (habits.contains('night')) return 'dark';
    if (habits.contains('early') || habits.contains('morning')) return 'light';
    return 'neutral';
  }
}