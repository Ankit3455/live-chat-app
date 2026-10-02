import 'package:flutter/foundation.dart';

/// ViewModel for astrology questionnaire
/// Single source of truth used across the app
class AstrologyViewModel extends ChangeNotifier {
  // Stored fields
  List<String> _preferredSigns = [];
  bool _believesInAstrology = false;         // boolean form (used in some flows)
  String? _believesInAstrologyLabel;         // string form (e.g., 'Yes', 'Somewhat', 'No', 'Unsure')
  String? _personalityPriority;
  String? _astrologyBeliefLevel;             // stored as string to match UI
  String? _relationshipPriority;
  String? _vibePreference;
  String? _lifestyle;                        // maps to 'sleepSchedule' in review/save
  String? _idealDate;

  // Getters
  List<String> get preferredSigns => _preferredSigns;
  bool get believesInAstrology => _believesInAstrology;
  String? get believesInAstrologyLabel => _believesInAstrologyLabel;
  String? get personalityPriority => _personalityPriority;
  String? get astrologyBeliefLevel => _astrologyBeliefLevel;
  String? get relationshipPriority => _relationshipPriority;
  String? get vibePreference => _vibePreference;
  String? get lifestyle => _lifestyle;
  String? get idealDate => _idealDate;

  // Setters (primary)
  void setPreferredSigns(List<String> signs) {
    _preferredSigns = signs;
    notifyListeners();
  }

  void setBelievesInAstrology(bool value) {
    _believesInAstrology = value;
    // keep label in sync with bool
    _believesInAstrologyLabel = value ? 'Yes' : 'No';
    notifyListeners();
  }

  void setPersonalityPriority(String? value) {
    _personalityPriority = value;
    notifyListeners();
  }

  void setAstrologyBeliefLevel(String? value) {
    _astrologyBeliefLevel = value;
    notifyListeners();
  }

  void setRelationshipPriority(String? value) {
    _relationshipPriority = value;
    notifyListeners();
  }

  void setVibePreference(String? value) {
    _vibePreference = value;
    notifyListeners();
  }

  void setLifestyle(String? value) {
    _lifestyle = value;
    notifyListeners();
  }

  void setIdealDate(String? value) {
    _idealDate = value;
    notifyListeners();
  }

  /// Validate step by index
  /// 0 - Preferred Signs
  /// 1 - Believes in Astrology
  /// 2 - Personality Priority
  /// 3 - Astrology Belief Level
  /// 4 - Relationship Priority
  /// 5 - Vibe Preference
  /// 6 - Sleep Schedule (lifestyle)
  /// 7 - Ideal Date
  bool isStepValid(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return _preferredSigns.isNotEmpty;
      case 1:
        // Often a toggle or single select; treat as valid to not block
        return true;
      case 2:
        return _personalityPriority != null && _personalityPriority!.isNotEmpty;
      case 3:
        return _astrologyBeliefLevel != null && _astrologyBeliefLevel!.isNotEmpty;
      case 4:
        return _relationshipPriority != null && _relationshipPriority!.isNotEmpty;
      case 5:
        return _vibePreference != null && _vibePreference!.isNotEmpty;
      case 6:
        return _lifestyle != null && _lifestyle!.isNotEmpty;
      case 7:
        return _idealDate != null && _idealDate!.isNotEmpty;
      default:
        return true;
    }
  }

  /// Map for Firestore (generic)
  Map<String, dynamic> toMap() {
    return {
      'preferredSigns': _preferredSigns,
      'believesInAstrology': _believesInAstrology,        // bool
      'believesInAstrologyLabel': _believesInAstrologyLabel, // optional label
      'personalityPriority': _personalityPriority,
      'astrologyBeliefLevel': _astrologyBeliefLevel,
      'relationshipPriority': _relationshipPriority,
      'vibePreference': _vibePreference,
      'lifestyle': _lifestyle,
      'idealDate': _idealDate,
    };
  }

  /// Used by UI (review/save screens)
  /// Provides keys that your UI expects (including 'sleepSchedule')
  Map<String, dynamic> getAllAnswers() {
    return {
      'preferredSigns': _preferredSigns,
      // UI expects a human-readable string; default to 'yes'/'no' if label missing
      'believesInAstrology': _believesInAstrologyLabel ??
          (_believesInAstrology ? 'yes' : 'no'),
      'personalityPriority': _personalityPriority,
      'astrologyBeliefLevel': _astrologyBeliefLevel,
      'relationshipPriority': _relationshipPriority,
      'vibePreference': _vibePreference,
      'sleepSchedule': _lifestyle, // Important: UI expects 'sleepSchedule'
      'idealDate': _idealDate,
    };
  }

  // Aliases to support existing calls in step screens (updateXxx)
  void updatePreferredSigns(List<String> signs) => setPreferredSigns(signs);

  void updateBelievesInAstrology(String value) {
    // Accept common string inputs and normalize
    final v = value.trim().toLowerCase();
    _believesInAstrologyLabel = _capitalize(value);

    if (v == 'yes' || v == 'true' || v == '1') {
      _believesInAstrology = true;
    } else if (v == 'no' || v == 'false' || v == '0') {
      _believesInAstrology = false;
    }
    // For 'somewhat', 'unsure', etc., keep bool as-is but store label
    notifyListeners();
  }

  void updatePersonalityPriority(String value) =>
      setPersonalityPriority(value);

  void updateAstrologyBeliefLevel(int level) =>
      setAstrologyBeliefLevel(level.toString());

  void updateRelationshipPriority(String value) =>
      setRelationshipPriority(value);

  void updateVibePreference(String value) => setVibePreference(value);

  void updateSleepSchedule(String value) => setLifestyle(value);

  void updateIdealDate(String value) => setIdealDate(value);

  /// Reset everything
  void reset() {
    _preferredSigns = [];
    _believesInAstrology = false;
    _believesInAstrologyLabel = null;
    _personalityPriority = null;
    _astrologyBeliefLevel = null;
    _relationshipPriority = null;
    _vibePreference = null;
    _lifestyle = null;
    _idealDate = null;
    notifyListeners();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}