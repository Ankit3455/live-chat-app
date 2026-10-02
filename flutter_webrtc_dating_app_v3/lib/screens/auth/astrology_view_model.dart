import 'package:flutter/foundation.dart';

/// ViewModel for astrology questionnaire
/// Converted from AstrologyViewModel.kt
class AstrologyViewModel extends ChangeNotifier {
  // Questionnaire fields
  List<String> _preferredSigns = [];
  String? _believesInAstrology; // 'yes', 'somewhat', 'no', 'unsure'
  String? _personalityPriority;
  int? _astrologyBeliefLevel; // 1-10 scale
  String? _relationshipPriority;
  String? _vibePreference;
  String? _sleepSchedule; // Renamed from _lifestyle
  String? _idealDate;

  // Getters
  List<String> get preferredSigns => _preferredSigns;
  String? get believesInAstrology => _believesInAstrology;
  String? get personalityPriority => _personalityPriority;
  int? get astrologyBeliefLevel => _astrologyBeliefLevel;
  String? get relationshipPriority => _relationshipPriority;
  String? get vibePreference => _vibePreference;
  String? get sleepSchedule => _sleepSchedule;
  String? get idealDate => _idealDate;

  // Update methods (used by step screens)
  void updatePreferredSigns(List<String> signs) {
    _preferredSigns = signs;
    notifyListeners();
  }

  void updateBelievesInAstrology(String value) {
    _believesInAstrology = value;
    notifyListeners();
  }

  void updatePersonalityPriority(String value) {
    _personalityPriority = value;
    notifyListeners();
  }

  void updateAstrologyBeliefLevel(int level) {
    _astrologyBeliefLevel = level;
    notifyListeners();
  }

  void updateRelationshipPriority(String value) {
    _relationshipPriority = value;
    notifyListeners();
  }

  void updateVibePreference(String value) {
    _vibePreference = value;
    notifyListeners();
  }

  void updateSleepSchedule(String value) {
    _sleepSchedule = value;
    notifyListeners();
  }

  void updateIdealDate(String value) {
    _idealDate = value;
    notifyListeners();
  }

  /// Validate step by index
  /// Index mapping:
  /// 0 - Step 1: Preferred Signs
  /// 1 - Step 2: Believes in Astrology
  /// 2 - Step 3: Personality Priority
  /// 3 - Step 4: Astrology Belief Level
  /// 4 - Step 5: Relationship Priority
  /// 5 - Step 6: Vibe Preference
  /// 6 - Step 7: Sleep Schedule
  /// 7 - Step 8: Ideal Date
  bool isStepValid(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return _preferredSigns.isNotEmpty;
      case 1:
        return _believesInAstrology != null && _believesInAstrology!.isNotEmpty;
      case 2:
        return _personalityPriority != null && _personalityPriority!.isNotEmpty;
      case 3:
        return _astrologyBeliefLevel != null;
      case 4:
        return _relationshipPriority != null && _relationshipPriority!.isNotEmpty;
      case 5:
        return _vibePreference != null && _vibePreference!.isNotEmpty;
      case 6:
        return _sleepSchedule != null && _sleepSchedule!.isNotEmpty;
      case 7:
        return _idealDate != null && _idealDate!.isNotEmpty;
      default:
        return true; // Review or unknown
    }
  }

  /// Get all answers for Firestore (used in review screen)
  Map<String, dynamic> getAllAnswers() {
    return {
      'preferredSigns': _preferredSigns,
      'believesInAstrology': _believesInAstrology,
      'personalityPriority': _personalityPriority,
      'astrologyBeliefLevel': _astrologyBeliefLevel,
      'relationshipPriority': _relationshipPriority,
      'vibePreference': _vibePreference,
      'sleepSchedule': _sleepSchedule, // Renamed field
      'idealDate': _idealDate,
    };
  }

  /// Alias for backward compatibility
  Map<String, dynamic> toMap() => getAllAnswers();

  /// Reset all fields
  void reset() {
    _preferredSigns = [];
    _believesInAstrology = null;
    _personalityPriority = null;
    _astrologyBeliefLevel = null;
    _relationshipPriority = null;
    _vibePreference = null;
    _sleepSchedule = null;
    _idealDate = null;
    notifyListeners();
  }
}