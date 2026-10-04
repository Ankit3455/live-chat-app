// lib/services/account_deletion_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/utils/auth_validators.dart';
import '../models/public_profile.dart';
import 'presence_service.dart';
import 'public_profile_sync.dart';
import 'session_service.dart';

enum ReauthMethod { password, google, none }

class AccountDeletionException implements Exception {
  final String message;
  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}

/// In-app account deletion (DEST-011). Runs on the client and needs a
/// sign-in from the last few minutes, so the UI re-authenticates first.
class AccountDeletionService {
  AccountDeletionService._();

  static User get _user {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AccountDeletionException('You are not logged in.');
    }
    return user;
  }

  static ReauthMethod get reauthMethod {
    final providers =
        FirebaseAuth.instance.currentUser?.providerData
            .map((p) => p.providerId)
            .toSet() ??
        const <String>{};
    if (providers.contains('password')) return ReauthMethod.password;
    if (providers.contains('google.com')) return ReauthMethod.google;
    return ReauthMethod.none;
  }

  static Future<void> reauthenticateWithPassword(String password) async {
    final user = _user;
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AccountDeletionException(
        'No email is linked to this account.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(
        e.code == 'invalid-credential' || e.code == 'wrong-password'
            ? 'Incorrect password'
            : AuthValidators.messageFor(e),
      );
    }
  }

  /// Returns false if the user closed the Google account picker.
  static Future<bool> reauthenticateWithGoogle() async {
    final user = _user;
    final google = GoogleSignIn();
    try {
      final account = await google.signIn();
      if (account == null) return false;
      final auth = await account.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          idToken: auth.idToken,
          accessToken: auth.accessToken,
        ),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(
        e.code == 'user-mismatch'
            ? 'Choose the Google account you used to log in.'
            : AuthValidators.messageFor(e),
      );
    }
  }

  static const Duration _recentAuth = Duration(minutes: 5);
  static const Duration _stepTimeout = Duration(seconds: 20);
  static const List<String> _games = ['carrom', 'ludo'];
  static const List<String> _queues = ['ludo_queue', 'carrom_queue'];

  // Leaderboard period docs can't be listed from the client, so recent
  // period keys are recomputed the way CarromStatsService writes them.
  static const int _dailyKeysBack = 35;
  static const int _weeklyKeysBack = 6;

  static const String _reloginMessage =
      'For your security, please log in again and retry.';
  static const String _genericMessage =
      'Could not delete your account. Please try again.';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Deletes the user's data from the client (no Cloud Functions on the
  /// Spark plan), deletes the Auth user last, then ends the local session.
  /// Cloudinary media stays: deleting it needs the API secret (server only).
  static Future<void> deleteAccount() async {
    final user = _user;
    final uid = user.uid;
    await _requireRecentLogin(user);

    // Stop writers so nothing recreates users/{uid}, public_profiles/{uid}
    // or presence/{uid} (onDisconnect) after they are deleted.
    PublicProfileSync.instance.stop();
    await PresenceService.instance.stop(markOffline: false);

    final userRef = _db.collection('users').doc(uid);
    Map<String, dynamic> profile = const {};
    await _step('read profile', () async {
      profile = (await userRef.get().timeout(_stepTimeout)).data() ?? const {};
    });

    await _step('conversations', () => _anonymiseConversations(uid));
    await _step('blocks', () => _deleteBlocks(uid));
    await _step('games', () => _deleteGameData(uid));
    await _step('realtime', () => _deleteRealtime(uid));
    await _step('avatar', () => _releaseAvatarFingerprint(uid, profile));
    await _step('public profile', () async {
      await _db
          .collection(PublicProfile.collection)
          .doc(uid)
          .delete()
          .timeout(_stepTimeout);
    });

    try {
      await userRef.delete().timeout(_stepTimeout);
    } catch (e) {
      _log('profile', e);
      await PresenceService.instance.start(uid);
      PublicProfileSync.instance.start(uid);
      throw AccountDeletionException(
        _isNetworkError(e)
            ? 'Network problem. Check your connection and try again.'
            : _genericMessage,
      );
    }

    await _step('blocked by', () => _deleteBlockedBy(uid));

    await SessionService.instance.unbindPushIdentity();

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      _log('auth', e);
      throw AccountDeletionException(
        e.code == 'requires-recent-login'
            ? _reloginMessage
            : AuthValidators.messageFor(e),
      );
    } catch (e) {
      _log('auth', e);
      throw const AccountDeletionException(_genericMessage);
    }

    // Sign out of Firebase first so SessionService skips the sign-out writes
    // that would recreate users/{uid} and presence/{uid}.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await SessionService.instance.signOut();
  }

  /// Checked before any data is removed so a stale sign-in can't leave a
  /// half-deleted account behind.
  static Future<void> _requireRecentLogin(User user) async {
    DateTime? authTime;
    try {
      authTime = (await user.getIdTokenResult()).authTime;
    } catch (e) {
      _log('token', e);
      throw AccountDeletionException(
        _isNetworkError(e)
            ? 'Network problem. Check your connection and try again.'
            : _genericMessage,
      );
    }
    if (authTime == null || DateTime.now().difference(authTime) > _recentAuth) {
      throw const AccountDeletionException(_reloginMessage);
    }
  }

  // Messages stay; the conversation marks this user as deleted.
  static Future<void> _anonymiseConversations(String uid) async {
    final snap = await _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .get()
        .timeout(_stepTimeout);
    await Future.wait(
      snap.docs.map(
        (doc) => _step('conversation', () async {
          await doc.reference
              .update({
                'deletedUsers': FieldValue.arrayUnion([uid]),
                'participantData.$uid': {'deleted': true, 'unreadCount': 0},
                'statePerUser.$uid': FieldValue.delete(),
                'typingAt.$uid': FieldValue.delete(),
              })
              .timeout(_stepTimeout);
        }),
      ),
    );
  }

  static Future<void> _deleteBlocks(String uid) async {
    final me = _db.collection('users').doc(uid);
    final blocked = await me.collection('blocked').get().timeout(_stepTimeout);
    await Future.wait([
      for (final d in blocked.docs)
        _step('block mirror', () async {
          await _db
              .collection('users')
              .doc(d.id)
              .collection('blockedBy')
              .doc(uid)
              .delete()
              .timeout(_stepTimeout);
          await d.reference.delete().timeout(_stepTimeout);
        }),
    ]);
  }

  // Rules allow this only once users/{uid} is gone, so a blocked user can't
  // erase who blocked them while the account still exists.
  static Future<void> _deleteBlockedBy(String uid) async {
    final blockedBy = await _db
        .collection('users')
        .doc(uid)
        .collection('blockedBy')
        .get()
        .timeout(_stepTimeout);
    await Future.wait([
      for (final d in blockedBy.docs)
        _step('blocked by', () => d.reference.delete().timeout(_stepTimeout)),
    ]);
  }

  static Future<void> _deleteGameData(String uid) async {
    final stats = _db.collection('user_game_stats').doc(uid);
    final history = await stats
        .collection('carrom_history')
        .get()
        .timeout(_stepTimeout);

    final docs = <DocumentReference<Map<String, dynamic>>>[
      for (final q in _queues) _db.collection(q).doc(uid),
      for (final game in _games) stats.collection('games').doc(game),
      ...history.docs.map((d) => d.reference),
      stats,
    ];
    final now = DateTime.now();
    for (final game in _games) {
      final root = _db.collection('leaderboards').doc(game);
      docs.add(root.collection('allTime').doc(uid));
      final periodKeys = <String, Set<String>>{'daily': {}, 'weekly': {}};
      for (var i = 0; i <= _dailyKeysBack; i++) {
        final day = now.subtract(Duration(days: i));
        periodKeys['daily']!.add('${day.year}-${day.month}-${day.day}');
      }
      for (var i = 0; i <= _weeklyKeysBack; i++) {
        final day = now.subtract(Duration(days: 7 * i));
        periodKeys['weekly']!.add('${day.year}-W${_weekNumber(day)}');
      }
      periodKeys.forEach((period, keys) {
        for (final key in keys) {
          docs.add(
            root.collection(period).doc(key).collection('users').doc(uid),
          );
        }
      });
    }

    // Per-doc deletes so one denied path does not block the rest.
    await Future.wait(
      docs.map(
        (ref) => _step('game doc', () => ref.delete().timeout(_stepTimeout)),
      ),
    );
  }

  // Same formula as CarromStatsService._getWeekNumber.
  static int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDifference = date.difference(firstDayOfYear).inDays;
    return ((daysDifference + firstDayOfYear.weekday) / 7).ceil();
  }

  static Future<void> _deleteRealtime(String uid) async {
    final rtdb = FirebaseDatabase.instance;
    await Future.wait([
      _step(
        'presence',
        () => rtdb.ref('presence/$uid').remove().timeout(_stepTimeout),
      ),
      _step(
        'incoming calls',
        () => rtdb.ref('incoming_calls/$uid').remove().timeout(_stepTimeout),
      ),
      _step(
        'answers',
        () => rtdb.ref('users/$uid').remove().timeout(_stepTimeout),
      ),
    ]);
  }

  static Future<void> _releaseAvatarFingerprint(
    String uid,
    Map<String, dynamic> profile,
  ) async {
    final props = profile['avatarProperties'];
    final fingerprint = props is Map ? props['avatarFingerprint'] : null;
    if (fingerprint is! String || fingerprint.isEmpty) return;
    final ref = _db.collection('avatar_fingerprints').doc(fingerprint);
    await _db
        .runTransaction<void>((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists && snap.data()?['uid'] == uid) tx.delete(ref);
        })
        .timeout(_stepTimeout);
  }

  /// Runs a best-effort step; failures are logged, not thrown.
  static Future<void> _step(String name, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      _log(name, e);
    }
  }

  static bool _isNetworkError(Object e) =>
      e is TimeoutException ||
      (e is FirebaseException &&
          (e.code == 'unavailable' || e.code == 'network-request-failed'));

  static void _log(String step, Object e) {
    if (!kDebugMode) return;
    final code = e is FirebaseException ? e.code : e.runtimeType;
    debugPrint('deleteAccount $step failed: $code');
  }
}
