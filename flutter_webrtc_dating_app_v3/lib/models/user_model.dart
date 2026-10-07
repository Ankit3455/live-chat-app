// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:availchat/core/utils/auth_validators.dart';

class UserModel {
  final String? uid;
  final String? email;
  final String username;
  final String profileImage;
  final bool online;
  final List<String> interests;
  final String? habits;
  final String? profession;
  final String? activityLevel;
  final String? relationshipGoal;
  final dynamic avatar;

  /// Canonical DOB (Timestamp `dateOfBirth`, legacy `dob` string accepted).
  /// Only present on the user's own doc; public profiles carry [age].
  final DateTime? dateOfBirth;
  final String? zodiacSign;

  // ✅ NEW: Voice intro
  final String? voiceIntroUrl;
  final int? voiceIntroDurationSeconds;

  // ✅ Avatar system extension
  final int? avatarVersion;
  final Map<String, dynamic>? avatarProperties;

  // Astrology fields
  final List<String> preferredSigns;
  final String? personalityPriority;
  final bool believesInAstrology;
  final String? astrologyBeliefLevel;
  final String? relationshipPriority;
  final String? vibePreference;
  final String? lifestyle;
  final String? idealDate;

  // Basic info
  final String? gender;
  final int? _storedAge;
  final String? birthTime;
  final String? birthLocation;
  final String? location;
  final String? bio;

  // Discovery. Coordinates exist only on the user's own doc; other users are
  // known by a precision-5 [geohash].
  final double? userLatitude;
  final double? userLongitude;
  final String? geohash;
  final bool discoveryEnabled;

  // Mandatory fields
  final String? relationshipStatus;
  final List<String>? hereFor;
  final String? height;
  final String? bodyType;
  final String? education;

  // Lifestyle fields
  final String? foodPreference;
  final String? smokingHabits;
  final String? drinkingHabits;
  final String? exerciseFrequency;
  final List<String>? pets;
  final String? wantsChildren;
  final String? hasChildren;
  final String? partyingFrequency;
  final String? tattoos;

  // Personality fields
  final String? personalityType;
  final String? politicalViews;
  final String? religiousViews;
  final String? religion;
  final String? communicationStyle;
  final String? loveLanguage;
  final List<String>? languages;
  final List<String>? musicGenres;
  final List<String>? movieGenres;
  final List<String>? tvGenres;

  // Profile tracking (null when never computed)
  final int? profileCompletionPercentage;

  // FCM tokens
  final List<String>? fcmTokens;

  // Database-specific fields
  final DateTime? lastSeen;
  final String? sleepSchedule;
  final String? sunSign;
  final Map<String, dynamic>? notificationSettings;
  final int? lastLocationUpdate;
  final String? contactPreference;

  UserModel({
    this.uid,
    this.email,
    this.username = "Unknown",
    this.profileImage = "",
    this.online = false,
    this.interests = const [],
    this.habits,
    this.profession,
    this.activityLevel,
    this.relationshipGoal,
    this.avatar,
    this.dateOfBirth,
    this.zodiacSign,
    this.preferredSigns = const [],
    this.personalityPriority,
    this.believesInAstrology = false,
    this.astrologyBeliefLevel,
    this.relationshipPriority,
    this.vibePreference,
    this.lifestyle,
    this.idealDate,
    this.gender,
    int? age,
    this.birthTime,
    this.birthLocation,
    this.location,
    this.bio,
    this.userLatitude,
    this.userLongitude,
    this.geohash,
    this.discoveryEnabled = false,
    this.relationshipStatus,
    this.hereFor,
    this.height,
    this.bodyType,
    this.education,
    this.foodPreference,
    this.smokingHabits,
    this.drinkingHabits,
    this.exerciseFrequency,
    this.pets,
    this.wantsChildren,
    this.hasChildren,
    this.partyingFrequency,
    this.tattoos,
    this.personalityType,
    this.politicalViews,
    this.religiousViews,
    this.religion,
    this.communicationStyle,
    this.loveLanguage,
    this.languages,
    this.musicGenres,
    this.movieGenres,
    this.tvGenres,
    this.profileCompletionPercentage,
    this.fcmTokens,
    this.lastSeen,
    this.sleepSchedule,
    this.sunSign,
    this.notificationSettings,
    this.lastLocationUpdate,
    this.contactPreference,
    // ✅ NEW (optional)
    this.voiceIntroUrl,
    this.voiceIntroDurationSeconds,
    this.avatarVersion,
    this.avatarProperties,
  }) : _storedAge = age;

  /// Age from [dateOfBirth], else the age published on a public profile.
  int? get age =>
      dateOfBirth != null ? AgePolicy.ageOn(dateOfBirth!) : _storedAge;

  /// Legacy dd/MM/yyyy view of [dateOfBirth] for older readers.
  String? get dob => dateOfBirth == null
      ? null
      : AgePolicy.legacyDobFormat.format(dateOfBirth!);

  // Helper to get avatar as string
  String? get avatarString {
    if (avatar is String) return avatar as String;
    if (avatar is num) return avatar.toString();
    return null;
  }

  // ===== HELPER METHODS =====

  static List<String> _safeListConversion(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static List<String>? _safeNullableListConversion(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final list = value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      return list.isEmpty ? null : list;
    }
    return null;
  }

  /// The single DOB parser for both `dateOfBirth` and legacy `dob`:
  /// Timestamp, DateTime, epoch s/ms, ISO, dd/MM/yyyy, d-M-yyyy, yyyy/MM/dd.
  static DateTime? parseDob(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is num) {
        final n = value.toInt();
        // Seconds stay below 1e10 until year 2286; anything larger is ms.
        return DateTime.fromMillisecondsSinceEpoch(
            n.abs() >= 10000000000 ? n : n * 1000);
      }
      if (value is Map && value['_seconds'] is num) {
        return DateTime.fromMillisecondsSinceEpoch(
            (value['_seconds'] as num).toInt() * 1000);
      }
      if (value is String) {
        final s = value.trim();
        if (s.isEmpty) return null;
        final parts = s.split(RegExp(r'[-/.]'));
        if (parts.length == 3) {
          final a = int.tryParse(parts[0]);
          final b = int.tryParse(parts[1]);
          final c = int.tryParse(parts[2]);
          if (a != null && b != null && c != null) {
            final d = a > 31 ? DateTime(a, b, c) : DateTime(c, b, a);
            return d.year > 1900 ? d : null;
          }
        }
        return DateTime.tryParse(s);
      }
    } catch (_) {}
    return null;
  }

  static String? _str(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return null;
  }

  static int? _int(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static bool _safeBoolConversion(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      final s = value.toLowerCase();
      return s == 'yes' || s == 'true' || s == '1';
    }
    if (value is num) return value != 0;
    return false;
  }

  static String? _parseAstrologyBeliefLevel(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _safeMapConversion(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  // ===== FROM MAP =====
  // Reads both private users/{uid} docs and public_profiles/{uid} docs.
  // No hard casts: a malformed field becomes null instead of dropping the user.
  factory UserModel.fromMap(Map<String, dynamic> map, {String? uid}) {
    final dobParsed = parseDob(map['dateOfBirth']) ?? parseDob(map['dob']);
    final hereFor = map['hereFor'];
    return UserModel(
      uid: uid ?? _str(map['uid']),
      email: _str(map['email']),
      username: _str(map['username']) ?? "Unknown",
      profileImage: _str(map['profileImage']) ?? "",
      online: _safeBoolConversion(map['online']),
      interests: _safeListConversion(map['interests']),
      habits: _str(map['habits']),
      profession: _str(map['profession']),
      activityLevel: _str(map['activityLevel']),
      relationshipGoal: _str(map['relationshipGoal']),
      avatar: map['avatar'],
      dateOfBirth: dobParsed,
      zodiacSign: _str(map['zodiacSign']) ?? _str(map['sunSign']),
      sunSign: _str(map['sunSign']),
      voiceIntroUrl: _str(map['voiceIntroUrl']),
      voiceIntroDurationSeconds: _int(map['voiceIntroDurationSeconds']),
      avatarVersion: _int(map['avatarVersion']) ?? 1,
      avatarProperties: _safeMapConversion(map['avatarProperties']),
      preferredSigns: _safeListConversion(map['preferredSigns']),
      personalityPriority: _str(map['personalityPriority']),
      believesInAstrology: _safeBoolConversion(map['believesInAstrology']),
      astrologyBeliefLevel: _parseAstrologyBeliefLevel(map['astrologyBeliefLevel']),
      relationshipPriority: _str(map['relationshipPriority']),
      vibePreference: _str(map['vibePreference']),
      lifestyle: _str(map['lifestyle']) ?? _str(map['sleepSchedule']),
      sleepSchedule: _str(map['sleepSchedule']),
      idealDate: _str(map['idealDate']),
      gender: _str(map['gender']),
      age: _int(map['age']),
      birthTime: _str(map['birthTime']),
      birthLocation: _str(map['birthLocation']) ?? _str(map['placeOfBirth']),
      location: _str(map['location']),
      bio: _str(map['bio']),
      userLatitude: _double(map['userLatitude']),
      userLongitude: _double(map['userLongitude']),
      geohash: _str(map['geohash']),
      discoveryEnabled: map['discoveryEnabled'] == true,
      relationshipStatus: _str(map['relationshipStatus']),
      // hereFor was written both as a string and as a list.
      hereFor: hereFor is String
          ? (hereFor.trim().isEmpty ? null : [hereFor.trim()])
          : _safeNullableListConversion(hereFor),
      height: _str(map['height']),
      bodyType: _str(map['bodyType']),
      education: _str(map['education']),
      foodPreference: _str(map['foodPreference']),
      smokingHabits: _str(map['smokingHabits']),
      drinkingHabits: _str(map['drinkingHabits']),
      exerciseFrequency: _str(map['exerciseFrequency']),
      pets: _safeNullableListConversion(map['pets']),
      wantsChildren: _str(map['wantsChildren']),
      hasChildren: _str(map['hasChildren']),
      partyingFrequency: _str(map['partyingFrequency']),
      tattoos: _str(map['tattoos']),
      personalityType: _str(map['personalityType']),
      politicalViews: _str(map['politicalViews']),
      religiousViews: _str(map['religiousViews']),
      religion: _str(map['religion']),
      communicationStyle: _str(map['communicationStyle']),
      loveLanguage: _str(map['loveLanguage']),
      languages: _safeNullableListConversion(map['languages']),
      musicGenres: _safeNullableListConversion(map['musicGenres']),
      movieGenres: _safeNullableListConversion(map['movieGenres']),
      tvGenres: _safeNullableListConversion(map['tvGenres']),
      profileCompletionPercentage: _int(map['profileCompletionPercentage']),
      fcmTokens: _safeNullableListConversion(map['fcmTokens']),
      lastSeen: _parseTimestamp(map['lastSeen']),
      notificationSettings: _safeMapConversion(map['notificationSettings']),
      lastLocationUpdate: _int(map['lastLocationUpdate']),
      contactPreference: _str(map['contactPreference']),
    );
  }

  // ===== FROM FIRESTORE =====
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data is! Map<String, dynamic>) return UserModel(uid: doc.id);
    return UserModel.fromMap(data, uid: doc.id);
  }

  // dietPreference getter implemented (was returning null earlier)
  String? get dietPreference => foodPreference;

  // ===== TO MAP =====
  // Own users/{uid} doc only. Age is derived, so it is not stored.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'profileImage': profileImage,
      'online': online,
      'interests': interests,
      'habits': habits,
      'profession': profession,
      'activityLevel': activityLevel,
      'relationshipGoal': relationshipGoal,
      'avatar': avatar,
      'dateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'dob': dob,
      'sunSign': zodiacSign ?? sunSign,
      'voiceIntroUrl': voiceIntroUrl,
      'voiceIntroDurationSeconds': voiceIntroDurationSeconds,
      'avatarVersion': avatarVersion,
      'avatarProperties': avatarProperties,
      'preferredSigns': preferredSigns,
      'personalityPriority': personalityPriority,
      'believesInAstrology': believesInAstrology,
      'astrologyBeliefLevel': astrologyBeliefLevel != null
          ? (int.tryParse(astrologyBeliefLevel!) ?? astrologyBeliefLevel)
          : null,
      'relationshipPriority': relationshipPriority,
      'vibePreference': vibePreference,
      'sleepSchedule': lifestyle ?? sleepSchedule,
      'idealDate': idealDate,
      'gender': gender,
      'birthTime': birthTime,
      'birthLocation': birthLocation,
      'location': location,
      'bio': bio,
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
      'geohash': geohash,
      'discoveryEnabled': discoveryEnabled,
      'relationshipStatus': relationshipStatus,
      'hereFor': hereFor,
      'height': height,
      'bodyType': bodyType,
      'education': education,
      'foodPreference': foodPreference,
      'smokingHabits': smokingHabits,
      'drinkingHabits': drinkingHabits,
      'exerciseFrequency': exerciseFrequency,
      'pets': pets,
      'wantsChildren': wantsChildren,
      'hasChildren': hasChildren,
      'partyingFrequency': partyingFrequency,
      'tattoos': tattoos,
      'personalityType': personalityType,
      'politicalViews': politicalViews,
      'religiousViews': religiousViews,
      'religion': religion,
      'communicationStyle': communicationStyle,
      'loveLanguage': loveLanguage,
      'languages': languages,
      'musicGenres': musicGenres,
      'movieGenres': movieGenres,
      'tvGenres': tvGenres,
      'profileCompletionPercentage': profileCompletionPercentage,
      'fcmTokens': fcmTokens,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'notificationSettings': notificationSettings,
      'lastLocationUpdate': lastLocationUpdate,
      'contactPreference': contactPreference,
    };
  }

  // ===== COPY WITH =====

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? profileImage,
    bool? online,
    List<String>? interests,
    String? habits,
    String? profession,
    String? activityLevel,
    String? relationshipGoal,
    dynamic avatar,
    DateTime? dateOfBirth,
    String? zodiacSign,
    String? voiceIntroUrl,
    int? voiceIntroDurationSeconds,
    int? avatarVersion,
    Map<String, dynamic>? avatarProperties,
    List<String>? preferredSigns,
    String? personalityPriority,
    bool? believesInAstrology,
    String? astrologyBeliefLevel,
    String? relationshipPriority,
    String? vibePreference,
    String? lifestyle,
    String? idealDate,
    String? gender,
    int? age,
    String? birthTime,
    String? birthLocation,
    String? location,
    String? bio,
    double? userLatitude,
    double? userLongitude,
    String? geohash,
    bool? discoveryEnabled,
    String? relationshipStatus,
    List<String>? hereFor,
    String? height,
    String? bodyType,
    String? education,
    String? foodPreference,
    String? smokingHabits,
    String? drinkingHabits,
    String? exerciseFrequency,
    List<String>? pets,
    String? wantsChildren,
    String? hasChildren,
    String? partyingFrequency,
    String? tattoos,
    String? personalityType,
    String? politicalViews,
    String? religiousViews,
    String? religion,
    String? communicationStyle,
    String? loveLanguage,
    List<String>? languages,
    List<String>? musicGenres,
    List<String>? movieGenres,
    List<String>? tvGenres,
    int? profileCompletionPercentage,
    List<String>? fcmTokens,
    DateTime? lastSeen,
    String? sleepSchedule,
    String? sunSign,
    Map<String, dynamic>? notificationSettings,
    int? lastLocationUpdate,
    String? contactPreference,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImage: profileImage ?? this.profileImage,
      online: online ?? this.online,
      interests: interests ?? this.interests,
      habits: habits ?? this.habits,
      profession: profession ?? this.profession,
      activityLevel: activityLevel ?? this.activityLevel,
      relationshipGoal: relationshipGoal ?? this.relationshipGoal,
      avatar: avatar ?? this.avatar,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      voiceIntroUrl: voiceIntroUrl ?? this.voiceIntroUrl,
      voiceIntroDurationSeconds:
      voiceIntroDurationSeconds ?? this.voiceIntroDurationSeconds,
      preferredSigns: preferredSigns ?? this.preferredSigns,
      personalityPriority: personalityPriority ?? this.personalityPriority,
      believesInAstrology: believesInAstrology ?? this.believesInAstrology,
      astrologyBeliefLevel: astrologyBeliefLevel ?? this.astrologyBeliefLevel,
      relationshipPriority: relationshipPriority ?? this.relationshipPriority,
      vibePreference: vibePreference ?? this.vibePreference,
      lifestyle: lifestyle ?? this.lifestyle,
      idealDate: idealDate ?? this.idealDate,
      gender: gender ?? this.gender,
      age: age ?? _storedAge,
      birthTime: birthTime ?? this.birthTime,
      birthLocation: birthLocation ?? this.birthLocation,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      geohash: geohash ?? this.geohash,
      discoveryEnabled: discoveryEnabled ?? this.discoveryEnabled,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      hereFor: hereFor ?? this.hereFor,
      height: height ?? this.height,
      bodyType: bodyType ?? this.bodyType,
      education: education ?? this.education,
      foodPreference: foodPreference ?? this.foodPreference,
      smokingHabits: smokingHabits ?? this.smokingHabits,
      drinkingHabits: drinkingHabits ?? this.drinkingHabits,
      exerciseFrequency: exerciseFrequency ?? this.exerciseFrequency,
      pets: pets ?? this.pets,
      wantsChildren: wantsChildren ?? this.wantsChildren,
      hasChildren: hasChildren ?? this.hasChildren,
      partyingFrequency: partyingFrequency ?? this.partyingFrequency,
      tattoos: tattoos ?? this.tattoos,
      personalityType: personalityType ?? this.personalityType,
      politicalViews: politicalViews ?? this.politicalViews,
      religiousViews: religiousViews ?? this.religiousViews,
      religion: religion ?? this.religion,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      loveLanguage: loveLanguage ?? this.loveLanguage,
      languages: languages ?? this.languages,
      musicGenres: musicGenres ?? this.musicGenres,
      movieGenres: movieGenres ?? this.movieGenres,
      tvGenres: tvGenres ?? this.tvGenres,
      profileCompletionPercentage: profileCompletionPercentage ?? this.profileCompletionPercentage,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      lastSeen: lastSeen ?? this.lastSeen,
      sleepSchedule: sleepSchedule ?? this.sleepSchedule,
      sunSign: sunSign ?? this.sunSign,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      contactPreference: contactPreference ?? this.contactPreference,
      avatarVersion: avatarVersion ?? this.avatarVersion,
      avatarProperties: avatarProperties ?? this.avatarProperties,
    );
  }
}
