// lib/services/account_deletion_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/utils/auth_validators.dart';
import 'presence_service.dart';
import 'session_service.dart';

enum ReauthMethod { password, google, none }

class AccountDeletionException implements Exception {
  final String message;
  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}

/// In-app account deletion (DEST-011). The `deleteAccount` callable does the
/// work server-side and requires a sign-in from the last few minutes, so the
/// UI re-authenticates first.
class AccountDeletionService {
  AccountDeletionService._();

  static const String functionName = 'deleteAccount';

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

  /// Deletes the account on the server, then ends the local session.
  static Future<void> deleteAccount() async {
    final uid = _user.uid;

    // Cancel the RTDB onDisconnect so it cannot recreate presence/{uid}
    // after the server removed it.
    await PresenceService.instance.stop(markOffline: false);
    try {
      await FirebaseFunctions.instance
          .httpsCallable(
            functionName,
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          )
          .call({'confirm': true});
    } on FirebaseFunctionsException catch (e) {
      await PresenceService.instance.start(uid);
      if (kDebugMode)
        debugPrint('deleteAccount failed: ${e.code} ${e.message}');
      switch (e.code) {
        case 'failed-precondition':
        case 'unauthenticated':
          throw const AccountDeletionException(
            'For your security, please log in again and retry.',
          );
        case 'not-found':
        case 'unimplemented':
          throw const AccountDeletionException(
            'Account deletion is not available right now. Please contact '
            'support.',
          );
        case 'unavailable':
        case 'deadline-exceeded':
          throw const AccountDeletionException(
            'Network problem. Check your connection and try again.',
          );
        default:
          throw const AccountDeletionException(
            'Could not delete your account. Please try again.',
          );
      }
    } catch (e) {
      await PresenceService.instance.start(uid);
      if (e is AccountDeletionException) rethrow;
      throw const AccountDeletionException(
        'Could not delete your account. Please try again.',
      );
    }

    // The ID token stays valid for up to an hour after the Auth user is
    // deleted, so sign out of Firebase first: SessionService then skips the
    // sign-out writes that would recreate users/{uid} and presence/{uid}.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await SessionService.instance.signOut();
  }
}
