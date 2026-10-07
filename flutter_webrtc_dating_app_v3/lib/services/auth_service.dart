import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/config/auth_config.dart';
import 'session_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  /// Throws FirebaseAuthException; callers map codes with AuthValidators.
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Single source for reset link
  Future<void> sendResetLink(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // (Optional backward-compat) forwarder
  Future<void> sendPasswordResetEmail(String email) => sendResetLink(email);

  /// Changes the password. Firebase revokes every other session's refresh
  /// token on a password change, so other devices are signed out within the
  /// hour; `revokeSessions` makes it immediate and unlinks their push identity.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found', message: 'Not logged in');
    }

    // Only email/password accounts can change password here.
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (!providers.contains('password')) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'Provider has no password',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'No email is associated with this account',
      );
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await user.updatePassword(newPassword);

    try {
      await FirebaseFunctions.instance
          .httpsCallable('revokeSessions')
          .call()
          .timeout(const Duration(seconds: 10));
      // Revocation also covers this device; re-auth to get fresh tokens.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: newPassword),
      );
    } catch (_) {
      // Function not deployed or offline: Firebase's own revocation still applies.
    }

    await user.reload();
  }

  /// Creates the Auth account and the profile doc together. If the profile
  /// write fails it is retried once, then the new Auth user is deleted so the
  /// email can be used again. If an earlier attempt left an account without a
  /// profile, signing up again with the same password recovers it.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    UserCredential cred;
    var created = false;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      created = true;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      try {
        cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException {
        throw e;
      }
    }

    final user = cred.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'internal-error');
    }

    final ref = _firestore.collection('users').doc(user.uid);
    if (!created) {
      // A real profile (not just a presence write): normal login from
      // signup. If the server can't say, don't overwrite; the router sends a
      // user without a profile to setup.
      try {
        if (await SessionService.instance.hasRealProfile(user.uid)) {
          return cred;
        }
      } catch (_) {
        return cred;
      }
    }

    final data = <String, dynamic>{
      ...profile,
      'uid': user.uid,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'online': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'emailVerificationRequired': AuthConfig.requireEmailVerification,
      'signupCompleted': false,
      'mandatoryCompleted': false,
      'discoveryEnabled': false,
      'discoveryPendingOnboarding': true,
    };

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await ref
            .set(data, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      if (created) {
        try {
          await user.delete();
        } catch (_) {
          // Splash routes a signed-in user without a profile to setup.
        }
      }
      throw FirebaseAuthException(
        code: 'profile-write-failed',
        message: 'Could not save your profile. Please try again.',
      );
    }

    if (AuthConfig.requireEmailVerification) {
      try {
        await user.sendEmailVerification();
      } catch (_) {}
    }

    return cred;
  }

  /// Returns null when the user cancels the account picker. First login (or a
  /// missing profile doc) writes onboarding defaults; later logins only touch
  /// online/lastSeen so username, avatar and createdAt are preserved.
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return userCredential;

    // Best-effort: a failed write must not fail an already successful
    // sign-in; the start router sends a user without a profile to setup.
    try {
      await SessionService.instance.ensureProfileDefaults(
        user.uid,
        defaults: {
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'signupCompleted': false,
          'mandatoryCompleted': false,
          'discoveryEnabled': false,
          'discoveryPendingOnboarding': true,
        },
        always: {
          'online': true,
          'lastSeen': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {}

    return userCredential;
  }

  /// Every sign-out entry point goes through here.
  Future<void> signOut() => SessionService.instance.signOut();

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
    } catch (e) {
      throw Exception('Update profile failed: $e');
    }
  }
}
