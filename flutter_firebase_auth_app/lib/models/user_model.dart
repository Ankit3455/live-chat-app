import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? uid;
  final String? email;
  final String username;
  final String profileImage;
  final String? lastMessage;
  final String? timeAgo;
  final bool online;
  final List<String> interests;
  final String? habits;
  final String? profession;
  final String? activityLevel;
  final String? relationshipGoal;
  final dynamic avatar;
  final DateTime? dateOfBirth;
  final String? zodiacSign;

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
  final int? age;
  final String? dob;
  final String? birthTime;
  final String? location;
  final String? bio;

  // Compatibility
  final String? compatibilityText;
  final int? matchPercentage;

  // Discovery
  final double? userLatitude;
  final double? userLongitude;
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
  final String? partyingFrequency;
  final String? tattoos;

  // Personality fields
  final String? personalityType;
  final String? politicalViews;
  final String? religiousViews;
  final List<String>? musicGenres;
  final List<String>? movieGenres;
  final List<String>? tvGenres;

  // Profile tracking
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
    this.lastMessage,
    this.timeAgo,
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
    this.age,
    this.dob,
    this.birthTime,
    this.location,
    this.bio,
    this.compatibilityText,
    this.matchPercentage,
    this.userLatitude,
    this.userLongitude,
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
    this.partyingFrequency,
    this.tattoos,
    this.personalityType,
    this.politicalViews,
    this.religiousViews,
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
  });

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

  static DateTime? _parseDobString(String? dobString) {
    if (dobString == null || dobString.isEmpty) return null;
    
    try {
      final parts = dobString.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      print('Error parsing DOB: $e');
    }
    return null;
  }

  static bool _safeBoolConversion(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'yes' || 
             value.toLowerCase() == 'true' || 
             value == '1';
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
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _safeMapConversion(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  // ===== FROM MAP =====

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String?,
      email: map['email'] as String?,
      username: map['username'] as String? ?? "Unknown",
      profileImage: map['profileImage'] as String? ?? "",
      lastMessage: map['lastMessage'] as String?,
      timeAgo: map['timeAgo'] as String?,
      online: map['online'] as bool? ?? false,
      interests: _safeListConversion(map['interests']),
      habits: map['habits'] as String?,
      profession: map['profession'] as String?,
      activityLevel: map['activityLevel'] as String?,
      relationshipGoal: map['relationshipGoal'] as String?,
      avatar: map['avatar'],
      
      dateOfBirth: map['dateOfBirth'] is String
          ? DateTime.tryParse(map['dateOfBirth'] as String)
          : _parseDobString(map['dob'] as String?),
      
      zodiacSign: map['zodiacSign'] as String? ?? map['sunSign'] as String?,
      sunSign: map['sunSign'] as String?,
      
      preferredSigns: _safeListConversion(map['preferredSigns']),
      personalityPriority: map['personalityPriority'] as String?,
      believesInAstrology: _safeBoolConversion(map['believesInAstrology']),
      astrologyBeliefLevel: _parseAstrologyBeliefLevel(map['astrologyBeliefLevel']),
      relationshipPriority: map['relationshipPriority'] as String?,
      vibePreference: map['vibePreference'] as String?,
      lifestyle: map['lifestyle'] as String? ?? map['sleepSchedule'] as String?,
      sleepSchedule: map['sleepSchedule'] as String?,
      idealDate: map['idealDate'] as String?,
      gender: map['gender'] as String?,
      age: (map['age'] as num?)?.toInt(),
      dob: map['dob'] as String?,
      birthTime: map['birthTime'] as String?,
      location: map['location'] as String?,
      bio: map['bio'] as String?,
      compatibilityText: map['compatibilityText'] as String?,
      matchPercentage: (map['matchPercentage'] as num?)?.toInt(),
      userLatitude: (map['userLatitude'] as num?)?.toDouble(),
      userLongitude: (map['userLongitude'] as num?)?.toDouble(),
      discoveryEnabled: map['discoveryEnabled'] as bool? ?? false,
      relationshipStatus: map['relationshipStatus'] as String?,
      hereFor: _safeNullableListConversion(map['hereFor']),
      height: map['height'] as String?,
      bodyType: map['bodyType'] as String?,
      education: map['education'] as String?,
      foodPreference: map['foodPreference'] as String?,
      smokingHabits: map['smokingHabits'] as String?,
      drinkingHabits: map['drinkingHabits'] as String?,
      exerciseFrequency: map['exerciseFrequency'] as String?,
      pets: _safeNullableListConversion(map['pets']),
      wantsChildren: map['wantsChildren'] as String?,
      partyingFrequency: map['partyingFrequency'] as String?,
      tattoos: map['tattoos'] as String?,
      personalityType: map['personalityType'] as String?,
      politicalViews: map['politicalViews'] as String?,
      religiousViews: map['religiousViews'] as String?,
      musicGenres: _safeNullableListConversion(map['musicGenres']),
      movieGenres: _safeNullableListConversion(map['movieGenres']),
      tvGenres: _safeNullableListConversion(map['tvGenres']),
      profileCompletionPercentage: (map['profileCompletionPercentage'] as num?)?.toInt(),
      fcmTokens: _safeNullableListConversion(map['fcmTokens']),
      lastSeen: _parseTimestamp(map['lastSeen']),
      notificationSettings: _safeMapConversion(map['notificationSettings']),
      lastLocationUpdate: (map['lastLocationUpdate'] as num?)?.toInt(),
      contactPreference: map['contactPreference'] as String?,
    );
  }

  // ===== FROM FIRESTORE =====

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    try {
      if (!doc.exists) {
        return UserModel(uid: doc.id);
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        return UserModel(uid: doc.id);
      }
      
      return UserModel.fromMap({...data, 'uid': doc.id});
    } catch (e, stackTrace) {
      print('❌ Error parsing user ${doc.id}: $e');
      print('Stack trace: $stackTrace');
      return UserModel(uid: doc.id, username: 'Error Loading User');
    }
  }

  // ===== TO MAP =====

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'profileImage': profileImage,
      'lastMessage': lastMessage,
      'timeAgo': timeAgo,
      'online': online,
      'interests': interests,
      'habits': habits,
      'profession': profession,
      'activityLevel': activityLevel,
      'relationshipGoal': relationshipGoal,
      'avatar': avatar,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'sunSign': zodiacSign ?? sunSign,
      'preferredSigns': preferredSigns,
      'personalityPriority': personalityPriority,
      'believesInAstrology': believesInAstrology ? 'yes' : 'no',
      'astrologyBeliefLevel': astrologyBeliefLevel != null 
          ? (int.tryParse(astrologyBeliefLevel!) ?? 0)
          : null,
      'relationshipPriority': relationshipPriority,
      'vibePreference': vibePreference,
      'sleepSchedule': lifestyle ?? sleepSchedule,
      'idealDate': idealDate,
      'gender': gender,
      'age': age,
      'dob': dob,
      'birthTime': birthTime,
      'location': location,
      'bio': bio,
      'compatibilityText': compatibilityText,
      'matchPercentage': matchPercentage,
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
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
      'partyingFrequency': partyingFrequency,
      'tattoos': tattoos,
      'personalityType': personalityType,
      'politicalViews': politicalViews,
      'religiousViews': religiousViews,
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
    String? dob,
    String? birthTime,
    String? location,
    String? bio,
    String? compatibilityText,
    int? matchPercentage,
    double? userLatitude,
    double? userLongitude,
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
    String? partyingFrequency,
    String? tattoos,
    String? personalityType,
    String? politicalViews,
    String? religiousViews,
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
      preferredSigns: preferredSigns ?? this.preferredSigns,
      personalityPriority: personalityPriority ?? this.personalityPriority,
      believesInAstrology: believesInAstrology ?? this.believesInAstrology,
      astrologyBeliefLevel: astrologyBeliefLevel ?? this.astrologyBeliefLevel,
      relationshipPriority: relationshipPriority ?? this.relationshipPriority,
      vibePreference: vibePreference ?? this.vibePreference,
      lifestyle: lifestyle ?? this.lifestyle,
      idealDate: idealDate ?? this.idealDate,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      dob: dob ?? this.dob,
      birthTime: birthTime ?? this.birthTime,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      compatibilityText: compatibilityText ?? this.compatibilityText,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
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
      partyingFrequency: partyingFrequency ?? this.partyingFrequency,
      tattoos: tattoos ?? this.tattoos,
      personalityType: personalityType ?? this.personalityType,
      politicalViews: politicalViews ?? this.politicalViews,
      religiousViews: religiousViews ?? this.religiousViews,
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
    );
  }
}