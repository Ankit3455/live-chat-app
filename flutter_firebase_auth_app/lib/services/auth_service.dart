import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';

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
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Sign in failed: $e');
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

      // Create user document in Firestore
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'username': username ?? email.split('@')[0],
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

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create/update user document in Firestore
      if (userCredential.user != null) {
        final user = userCredential.user!;
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
      // Update online status before signing out
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
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

  // Get FCM token and save to Firestore
  Future<void> saveFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final uid = _auth.currentUser?.uid;

      if (token != null && uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }
    } catch (e) {
      throw Exception('Failed to save FCM token: $e');
    }
  }
}
