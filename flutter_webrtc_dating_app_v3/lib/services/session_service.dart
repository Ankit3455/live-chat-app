import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/auth_validators.dart';
import 'notification/push_token_service.dart';
import 'call/webrtc/ice_servers.dart';
import 'presence_service.dart';
import 'public_profile_sync.dart';
import 'stale_cleanup.dart';

/// Where a signed-in (or signed-out) user should land on app start.
enum StartDestination {
  login,

  /// Signed in but no profile doc, or no date of birth yet.
  profileSetup,

  /// DOB on file is under 18.
  underage,
  verifyEmail,
  questionnaire,
  postSignup,
  home,
}

/// Owns the session side effects: push identity, presence, sign-out cleanup
/// and the profile-completion routing decision. Start once with [start].
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const Duration _netTimeout = Duration(seconds: 4);

  /// Device-global prefs that hold the previous account's data.
  /// Per-uid keys (e.g. tour flags) are kept on purpose.
  static const List<String> _accountPrefKeys = [
    'passwordChangedAt_epoch_ms',
    'discovery_enabled',
    'apply_discovery_filters',
    'show_me_gender',
    'filter_age_min',
    'filter_age_max',
    'filter_distance_km',
    'filter_online_only',
    'banner_dismissed',
    'banner_last_shown',
  ];

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  StreamSubscription<User?>? _authSub;
  Future<void> _queue = Future.value();
  String? _uid;
  bool _signingOut = false;

  /// Idempotent. Safe to call from main and from splash.
  void start() {
    if (_authSub != null) return;
    _authSub = _auth.authStateChanges().listen((user) {
      _queue = _queue.then((_) => _onAuthChanged(user)).catchError((e) {
        if (kDebugMode) debugPrint('Session auth handler error: $e');
      });
    });
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user != null) {
      if (_uid == user.uid) return;
      if (_uid != null) await _endLocalSession(markOffline: false);
      _uid = user.uid;
      await bindPushIdentity(user.uid);
      await PresenceService.instance.start(user.uid);
      PublicProfileSync.instance.start(user.uid);
      unawaited(StaleCleanup.run(user.uid));
    } else if (_uid != null && !_signingOut) {
      // Signed out without signOut() (token revoked, account deleted):
      // Firestore writes are no longer allowed, so clean up locally only.
      await _endLocalSession(markOffline: false);
    }
  }

  Future<void> _endLocalSession({required bool markOffline}) async {
    PublicProfileSync.instance.stop();
    await PresenceService.instance.stop(markOffline: markOffline);
    await unbindPushIdentity();
    IceServers.clearCache();
    _uid = null;
  }

  // The OneSignal Flutter SDK has no working JWT login yet; once it does,
  // fetch a token from the `mintOneSignalJwt` callable and pass it here.
  Future<void> bindPushIdentity(String uid) async {
    if (kIsWeb) return;
    try {
      await OneSignal.login(uid);
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal login failed: $e');
    }
  }

  Future<void> unbindPushIdentity() async {
    if (kIsWeb) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal logout failed: $e');
    }
  }

  /// The only sign-out path. Order matters: writes that need auth first,
  /// then Firebase/Google sign-out, then local cache wipe.
  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      await PresenceService.instance.stop(markOffline: true);
      // Publishes the offline state before auth goes away.
      await PublicProfileSync.instance.flushAndStop();
      await PushTokenService.removeToken();
      await unbindPushIdentity();
      _uid = null;

      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      await _auth.signOut();

      await _clearLocalData();
    } finally {
      _signingOut = false;
    }
  }

  Future<void> _clearLocalData() async {
    try {
      // clearPersistence is only allowed after terminate; the instance is
      // recreated on next use.
      await _db.terminate();
      await _db.clearPersistence();
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore cache clear failed: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _accountPrefKeys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  /// Turns discovery on once onboarding is done. Only acts on accounts that
  /// signup/Google first login marked `discoveryPendingOnboarding`, so a
  /// user's own discovery choice is never overridden.
  /// Call at the end of the onboarding chain.
  Future<void> markOnboardingComplete() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get().timeout(_netTimeout);
      if (snap.data()?['discoveryPendingOnboarding'] != true) return;
      await ref
          .set({
            'discoveryEnabled': true,
            'discoveryPendingOnboarding': FieldValue.delete(),
          }, SetOptions(merge: true))
          .timeout(_netTimeout);
    } catch (e) {
      if (kDebugMode) debugPrint('markOnboardingComplete failed: $e');
    }
  }

  /// Decides the landing screen from auth + `users/{uid}` state.
  /// Falls back to home when the profile cannot be read (offline, no cache)
  /// so a network blip never locks a user out.
  Future<StartDestination> resolveStartDestination() async {
    final user = _auth.currentUser;
    if (user == null) return StartDestination.login;

    DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      // Presence writes online/lastSeen right at sign-in. Read while that
      // write is pending, the doc can come back with only those two fields
      // (no DOB), which would send a finished account to the age gate.
      for (var i = 0; i < 6 && snap.metadata.hasPendingWrites; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        snap = await _db
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      try {
        snap = await _db
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
      } catch (_) {
        return StartDestination.home;
      }
    }

    if (!snap.exists) {
      return snap.metadata.isFromCache
          ? StartDestination.home
          : StartDestination.profileSetup;
    }
    final data = snap.data() ?? const <String, dynamic>{};

    if (data['emailVerificationRequired'] == true && !user.emailVerified) {
      try {
        await user.reload().timeout(_netTimeout);
      } catch (_) {}
      if (!(_auth.currentUser?.emailVerified ?? false)) {
        return StartDestination.verifyEmail;
      }
    }

    final dob = AgePolicy.dobFromUserData(data);
    if (dob == null) return StartDestination.profileSetup;
    if (!AgePolicy.isAdult(dob)) return StartDestination.underage;

    // Accounts created before these flags existed are treated as complete
    // when the questionnaire data is present.
    final signupCompleted = data['signupCompleted'];
    final answeredQuestionnaire =
        (data['gender'] as Object?)?.toString().isNotEmpty ?? false;
    if (signupCompleted == false ||
        (signupCompleted == null && !answeredQuestionnaire)) {
      return StartDestination.questionnaire;
    }
    if (data['mandatoryCompleted'] == false) {
      return StartDestination.postSignup;
    }

    if (data['discoveryPendingOnboarding'] == true) {
      unawaited(markOnboardingComplete());
    }
    return StartDestination.home;
  }
}
