import 'package:availchat/core/utils/auth_validators.dart';
import 'package:availchat/core/utils/geohash.dart';
import 'package:availchat/models/user_model.dart';

/// Public half of a profile (DEST-002). `public_profiles/{uid}` is written by
/// the `mirrorPublicProfile` Function (functions/profile_mirror.js); keep
/// [displayFields] in sync with PUBLIC_FIELDS there.
///
/// Private (never published): email, exact DOB, birth time/place, GPS
/// coordinates, push tokens, notification and other settings.
class PublicProfile {
  PublicProfile._();

  static const String collection = 'public_profiles';

  /// Profile content copied as-is when present.
  static const List<String> displayFields = [
    'username',
    'profileImage',
    'avatar',
    'avatarVersion',
    'bio',
    'interests',
    'zodiacSign',
    'sunSign',
    'location',
    'voiceIntroUrl',
    'voiceIntroDurationSeconds',
    'profession',
    'habits',
    'activityLevel',
    'relationshipGoal',
    'relationshipStatus',
    'hereFor',
    'height',
    'bodyType',
    'education',
    'lifestyle',
    'sleepSchedule',
    'foodPreference',
    'smokingHabits',
    'drinkingHabits',
    'exerciseFrequency',
    'pets',
    'wantsChildren',
    'partyingFrequency',
    'tattoos',
    'personalityType',
    'politicalViews',
    'religiousViews',
    'musicGenres',
    'movieGenres',
    'tvGenres',
    'preferredSigns',
    'personalityPriority',
    'believesInAstrology',
    'astrologyBeliefLevel',
    'relationshipPriority',
    'vibePreference',
    'idealDate',
    'online',
    'lastSeen',
  ];

  /// Builds the public map from a private `users/{uid}` map. Used for the
  /// interim fallback that still reads `users` before the mirror is deployed,
  /// so the UI only ever holds public fields of other users.
  static Map<String, dynamic> fromUserData(String uid, Map<String, dynamic> data) {
    final out = <String, dynamic>{'uid': uid};
    for (final key in displayFields) {
      if (data.containsKey(key) && data[key] != null) out[key] = data[key];
    }

    final gender = data['gender'];
    if (gender is String && gender.trim().isNotEmpty) {
      out['gender'] = gender.trim().toLowerCase();
    }

    final avatarUrl = (data['avatarProperties'] is Map)
        ? (data['avatarProperties'] as Map)['avatarImageUrl']
        : null;
    if (avatarUrl is String && avatarUrl.isNotEmpty) {
      out['avatarProperties'] = {'avatarImageUrl': avatarUrl};
    }

    final dob = UserModel.parseDob(data['dateOfBirth']) ??
        UserModel.parseDob(data['dob']);
    final age = dob == null ? null : AgePolicy.ageOn(dob);
    if (age != null) out['age'] = age;

    final hash = geohashFromUserData(data);
    if (hash != null) out['geohash'] = hash;

    out['discoveryEnabled'] =
        data['discoveryEnabled'] == true && age != null && age >= AgePolicy.minAge;
    return out;
  }

  /// Precision-5 geohash from a stored geohash or from legacy coordinates.
  static String? geohashFromUserData(Map<String, dynamic> data) {
    final stored = data['geohash'];
    if (stored is String && stored.length >= Geohash.publicPrecision) {
      return stored.substring(0, Geohash.publicPrecision);
    }
    final lat = data['userLatitude'];
    final lng = data['userLongitude'];
    if (lat is num && lng is num) {
      return Geohash.encode(lat.toDouble(), lng.toDouble());
    }
    return null;
  }
}
