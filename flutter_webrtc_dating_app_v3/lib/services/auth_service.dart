import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../bottom_navigation/managers/firestore_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Single source for reset link
  Future<void> sendResetLink(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // (Optional backward-compat) forwarder
  Future<void> sendPasswordResetEmail(String email) => sendResetLink(email);

  /// Change password with optional multi-device logout.
  /// logoutAllDevices=true => write `passwordChangedAt` so other devices sign out.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required bool logoutAllDevices,
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

    // Guard: email is required for reauth
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'No email is associated with this account',
      );
    }

    // Reauthenticate
    final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(cred);

    // Update password
    await user.updatePassword(newPassword);

    // Refresh local auth state (optionally force fresh token if needed)
    await user.reload();
    // await user.getIdToken(true); // optional

    if (logoutAllDevices) {
      final uid = user.uid;
      final ts = await FirestoreManager.instance.markPasswordChanged(uid);

      // Store local resolved timestamp so THIS device won't sign itself out
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('passwordChangedAt_epoch_ms', ts.millisecondsSinceEpoch);
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'username': username ?? email.split('@').first,
          'createdAt': FieldValue.serverTimestamp(),
          'online': true,
        }, SetOptions(merge: true));
      }

      return userCredential;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in aborted');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'username': user.displayName ?? 'User',
          'profileImage': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'online': true,
        }, SetOptions(merge: true));
      }

      return userCredential;
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).set({
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
    } catch (e) {
      throw Exception('Update profile failed: $e');
    }
  }

  // Get FCM token and save to Firestore (robust if doc missing)
  Future<void> saveFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final uid = _auth.currentUser?.uid;
      if (token == null || uid == null) return;

      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save FCM token: $e');
    }
  }
}
