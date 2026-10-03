import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../constants/app_strings.dart';

/// Shared form validators and auth error text for login, signup and
/// change password. Passwords are never trimmed.
class AuthValidators {
  AuthValidators._();

  static const int minPasswordLength = 8;
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Login only checks presence; the server decides if it is correct.
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
    return null;
  }

  /// One policy for signup and change password: 8+ chars, letters and numbers.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return AppStrings.passwordRequired;
    if (v.length < minPasswordLength) return AppStrings.passwordTooShort;
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return AppStrings.passwordWeak;
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return AppStrings.passwordsDoNotMatch;
    return null;
  }

  /// Friendly text for FirebaseAuthException codes.
  static String messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password';
      case 'user-not-found':
        return 'No account found for this email';
      case 'invalid-email':
        return 'Enter a valid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'email-already-in-use':
        return 'An account already exists for this email';
      case 'weak-password':
        return AppStrings.passwordWeak;
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return AppStrings.networkError;
      case 'requires-recent-login':
        return AppStrings.requiresRecentLogin;
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different sign-in method';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled';
      default:
        return AppStrings.genericAuthError;
    }
  }
}

/// 18+ policy (DECISIONS.md DEST-010).
class AgePolicy {
  AgePolicy._();

  static const int minAge = 18;
  static final DateFormat legacyDobFormat = DateFormat('dd/MM/yyyy');

  /// Latest DOB that is still 18+ today.
  static DateTime latestAllowedDob([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year - minAge, n.month, n.day);
  }

  static int ageOn(DateTime dob, [DateTime? now]) {
    final n = now ?? DateTime.now();
    var age = n.year - dob.year;
    if (n.month < dob.month || (n.month == dob.month && n.day < dob.day)) {
      age--;
    }
    return age;
  }

  static bool isAdult(DateTime dob) => ageOn(dob) >= minAge;

  /// Reads `dateOfBirth` (Timestamp/ISO) or legacy `dob` (dd/MM/yyyy).
  static DateTime? dobFromUserData(Map<String, dynamic>? data) {
    if (data == null) return null;
    return parse(data['dateOfBirth']) ?? parse(data['dob']);
  }

  /// Same tolerant parser the profile model uses, so the age gate and the
  /// discovery feed agree on every stored DOB format.
  static DateTime? parse(dynamic raw) => UserModel.parseDob(raw);

  /// Firestore fields written for a confirmed DOB. Keeps legacy `dob` for
  /// readers that still expect the dd/MM/yyyy string.
  static Map<String, dynamic> dobFields(DateTime dob, String? zodiacSign) {
    final day = DateTime(dob.year, dob.month, dob.day);
    return {
      'dateOfBirth': Timestamp.fromDate(day),
      'dob': legacyDobFormat.format(day),
      'birthYear': day.year,
      if (zodiacSign != null) 'zodiacSign': zodiacSign,
      if (zodiacSign != null) 'sunSign': zodiacSign,
      'ageConfirmedAt': FieldValue.serverTimestamp(),
    };
  }
}
