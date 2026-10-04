import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import 'astrology_utils.dart';

/// State of the astrology flow. Created per flow (never global), preloaded from
/// `users/{uid}`, and saves only the fields the user answered (DEST-077).
///
/// Only questions that feed or explain the compatibility score are asked:
/// preferred signs (score bonus) and one belief question (old steps 2 + 4).
/// Answers saved by the older 8-step flow stay untouched in the user doc.
class AstrologyViewModel extends ChangeNotifier {
  AstrologyViewModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Belief answers: value -> (label saved, bool saved, level saved).
  static const Map<String, ({String label, bool believes, int level})>
      beliefOptions = {
    'yes': (label: 'Yes', believes: true, level: 9),
    'somewhat': (label: 'Somewhat', believes: true, level: 6),
    'no': (label: 'No', believes: false, level: 2),
    'unsure': (label: 'Unsure', believes: false, level: 5),
  };

  List<String> _preferredSigns = [];
  String? _belief;
  String? _ownSign;
  bool _loading = false;
  bool _saving = false;
  bool _disposed = false;
  final Set<String> _dirty = {};

  List<String> get preferredSigns => List.unmodifiable(_preferredSigns);
  String? get belief => _belief;

  /// My sun sign from the stored sign or my DOB; null if no DOB yet.
  String? get ownSign => _ownSign;
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  bool get hasChanges => _dirty.isNotEmpty;

  Future<void> load(String uid) async {
    _loading = true;
    _notify();
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      final data = snap.data() ?? const <String, dynamic>{};

      final dob = UserModel.parseDob(data['dateOfBirth']) ??
          UserModel.parseDob(data['dob']);
      _ownSign = AstrologyUtils.normalizeSign(data['zodiacSign']?.toString()) ??
          AstrologyUtils.normalizeSign(data['sunSign']?.toString()) ??
          (dob != null ? AstrologyUtils.zodiacFromDate(dob) : null);

      // Keep anything the user already touched while the doc was loading.
      if (!_dirty.contains('preferredSigns')) {
        final raw = data['preferredSigns'];
        _preferredSigns = raw is List
            ? raw
                .map((e) => AstrologyUtils.normalizeSign(e?.toString()))
                .whereType<String>()
                .toSet()
                .toList()
            : [];
      }
      if (!_dirty.contains('belief')) {
        _belief = _beliefFrom(data);
      }
    } catch (e) {
      debugPrint('AstrologyViewModel.load failed: $e');
    } finally {
      _loading = false;
      _notify();
    }
  }

  void toggleSign(String sign) {
    final s = AstrologyUtils.normalizeSign(sign);
    if (s == null) return;
    _preferredSigns.contains(s)
        ? _preferredSigns.remove(s)
        : _preferredSigns.add(s);
    _dirty.add('preferredSigns');
    _notify();
  }

  void setBelief(String value) {
    if (!beliefOptions.containsKey(value)) return;
    _belief = value;
    _dirty.add('belief');
    _notify();
  }

  /// Firestore fields for the answered questions only, so skipping a question
  /// never overwrites a stored answer.
  Map<String, dynamic> changedFields() {
    final out = <String, dynamic>{};
    if (_dirty.contains('preferredSigns')) {
      out['preferredSigns'] = List<String>.from(_preferredSigns);
    }
    final option = beliefOptions[_belief];
    if (_dirty.contains('belief') && option != null) {
      out['believesInAstrology'] = option.believes;
      out['believesInAstrologyLabel'] = option.label;
      out['astrologyBeliefLevel'] = option.level;
    }
    return out;
  }

  /// Saves the answered fields. Returns false on failure.
  Future<bool> save(String uid) async {
    final fields = changedFields();
    if (fields.isEmpty) return true;
    _saving = true;
    _notify();
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(fields, SetOptions(merge: true));
      _dirty.clear();
      return true;
    } catch (e) {
      debugPrint('AstrologyViewModel.save failed: $e');
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  static String? _beliefFrom(Map<String, dynamic> data) {
    final label = data['believesInAstrologyLabel'];
    // The old flow stored the label in `believesInAstrology` itself.
    final legacy = data['believesInAstrology'];
    for (final raw in [label, legacy]) {
      if (raw is String && beliefOptions.containsKey(raw.trim().toLowerCase())) {
        return raw.trim().toLowerCase();
      }
    }
    if (legacy is bool) return legacy ? 'yes' : 'no';
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
