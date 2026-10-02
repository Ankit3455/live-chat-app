import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:availchat/models/question_model.dart';

class ProfileCompletionManager {
  // ===== Banner UX keys (preserved) =====
  static const String _keyBannerDismissed = 'banner_dismissed';
  static const String _keyBannerLastShown = 'banner_last_shown';
  static const int _bannerReappearDays = 3;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ---------- Question field helpers ----------
  List<String> _fieldNames(List<Question> qs) =>
      qs.map((q) => q.fieldName).where((f) => f.isNotEmpty).toList();

  List<String> get _signupFields =>
      _fieldNames(QuestionnaireHelper.getSignupQuestions());

  List<String> get _lifestyleFields =>
      _fieldNames(QuestionnaireHelper.getLifestyleQuestions());

  List<String> get _personalityFields =>
      _fieldNames(QuestionnaireHelper.getPersonalityQuestions());

  List<String> get _allFields =>
      [..._signupFields, ..._lifestyleFields, ..._personalityFields];

  bool _isAnswered(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    if (v is Map) return v.isNotEmpty;
    return true;
  }

  int _countAnswered(Map<String, dynamic> data, List<String> fields) {
    var c = 0;
    for (final f in fields) {
      if (_isAnswered(data[f])) c++;
    }
    return c;
  }

  Future<Map<String, dynamic>> _userData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};
    final snap = await _firestore.collection('users').doc(uid).get();
    return (snap.data() ?? {}) as Map<String, dynamic>;
  }

  Future<void> _writePercent(int percent) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final clamped = percent.clamp(0, 100);
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'profileCompletionPercentage': clamped}, SetOptions(merge: true));
  }

  // ========== PUBLIC API (names preserved) ==========

  /// ✅ Authoritative recompute from Firestore answers. Also writes back.
  Future<int> getCompletionPercentage() async {
    final data = await _userData();
    final total = _allFields.length;
    if (total == 0) {
      await _writePercent(0);
      return 0;
    }
    final answered = _countAnswered(data, _allFields);
    final pct = ((answered / total) * 100).round().clamp(0, 100);
    await _writePercent(pct);
    return pct;
  }

  // --- Section “complete” markers: keep compatible names & behavior.
  // We store boolean flags (in Firestore) for UI/quick checks, but % remains data-driven.
  Future<void> markSignupComplete() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {'signupCompleted': true},
      SetOptions(merge: true),
    );
    await getCompletionPercentage();
  }

  Future<void> markMandatoryComplete() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {'mandatoryCompleted': true},
      SetOptions(merge: true),
    );
    await getCompletionPercentage();
  }

  Future<void> markLifestyleComplete() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {'lifestyleCompleted': true},
      SetOptions(merge: true),
    );
    await getCompletionPercentage();
  }

  Future<void> markPersonalityComplete() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {'personalityCompleted': true},
      SetOptions(merge: true),
    );
    await getCompletionPercentage();
  }

  /// Some flows may call this after post-signup steps.
  Future<void> markPostSignupComplete() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {'postSignupCompleted': true},
      SetOptions(merge: true),
    );
    await getCompletionPercentage();
  }

  /// Section checks keep your UI logic intact: consider complete if flag is true
  /// OR at least 50% of that section’s questions are answered.
  Future<bool> isLifestyleComplete() async {
    final data = await _userData();
    if (data['lifestyleCompleted'] == true) return true;
    final answered = _countAnswered(data, _lifestyleFields);
    final threshold = (_lifestyleFields.length * 0.5).ceil();
    return answered >= threshold;
  }

  Future<bool> isPersonalityComplete() async {
    final data = await _userData();
    if (data['personalityCompleted'] == true) return true;
    final answered = _countAnswered(data, _personalityFields);
    final threshold = (_personalityFields.length * 0.5).ceil();
    return answered >= threshold;
  }

  // ========== Banner helpers (names preserved / compatible) ==========

  Future<bool> shouldShowBanner() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_keyBannerDismissed) ?? false;
    if (!dismissed) return true;

    final lastMs = prefs.getInt(_keyBannerLastShown);
    if (lastMs == null) return true;

    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final next = last.add(Duration(days: _bannerReappearDays));
    return DateTime.now().isAfter(next);
  }

  /// Alias to old API name some code uses
  Future<void> dismissBanner() async => markBannerShown();

  Future<void> markBannerShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBannerDismissed, true);
    await prefs.setInt(
      _keyBannerLastShown,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Alias to old API that returns a banner message based on %.
  Future<String> getCompletionMessage() async {
    final pct = await getCompletionPercentage();
    return getBannerMessage(pct);
  }

  String getBannerMessage(int percentage) {
    if (percentage >= 100) {
      return 'Profile complete 🎉';
    } else if (percentage >= 80) {
      return 'Almost there! Complete your profile to get 5x more matches!';
    } else if (percentage >= 60) {
      return 'Great start! Add more details to improve your matches.';
    } else if (percentage >= 40) {
      return 'Complete your profile to unlock better matches!';
    } else {
      return 'Let\'s build your profile!';
    }
  }

  // Keep a reset method (compat) — only resets local banner state.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBannerDismissed);
    await prefs.remove(_keyBannerLastShown);
    // NOTE: We intentionally do NOT clear Firestore user data here.
  }
}