import 'package:availchat/core/constants/app_strings.dart';
import 'package:availchat/core/utils/auth_validators.dart';
import 'package:availchat/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// DEST-010 (18+ gate), DEST-131.
void main() {
  group('AgePolicy', () {
    final today = DateTime(2026, 6, 15);

    test('ageOn counts a birthday only once it has been reached', () {
      expect(AgePolicy.ageOn(DateTime(2008, 6, 15), today), 18);
      expect(AgePolicy.ageOn(DateTime(2008, 6, 16), today), 17);
      expect(AgePolicy.ageOn(DateTime(2008, 7, 1), today), 17);
      expect(AgePolicy.ageOn(DateTime(2008, 5, 31), today), 18);
    });

    test('leap-day birthdays turn 18 on 1 March in non-leap years', () {
      final dob = DateTime(2008, 2, 29);
      expect(AgePolicy.ageOn(dob, DateTime(2026, 2, 28)), 17);
      expect(AgePolicy.ageOn(dob, DateTime(2026, 3, 1)), 18);
    });

    test('latestAllowedDob is exactly 18 years before today', () {
      final latest = AgePolicy.latestAllowedDob(today);
      expect(latest, DateTime(2008, 6, 15));
      expect(AgePolicy.ageOn(latest, today), AgePolicy.minAge);
      expect(
        AgePolicy.ageOn(latest.add(const Duration(days: 1)), today),
        AgePolicy.minAge - 1,
      );
    });

    test('isAdult rejects anyone under 18', () {
      final now = DateTime.now();
      expect(AgePolicy.isAdult(DateTime(now.year - 30, 1, 1)), isTrue);
      expect(
        AgePolicy.isAdult(DateTime(now.year - 17, now.month, now.day)),
        isFalse,
      );
    });

    test('dobFromUserData prefers dateOfBirth over legacy dob', () {
      expect(
        AgePolicy.dobFromUserData({
          'dateOfBirth': Timestamp.fromDate(DateTime(1995, 2, 3)),
          'dob': '01/01/2000',
        }),
        DateTime(1995, 2, 3),
      );
      expect(
        AgePolicy.dobFromUserData({'dob': '04/05/1999'}),
        DateTime(1999, 5, 4),
      );
      expect(AgePolicy.dobFromUserData({}), isNull);
      expect(AgePolicy.dobFromUserData(null), isNull);
    });
  });

  group('UserModel.parseDob', () {
    test('accepts every stored format', () {
      final d = DateTime(1994, 8, 7);
      expect(UserModel.parseDob(Timestamp.fromDate(d)), d);
      expect(UserModel.parseDob(d), d);
      expect(UserModel.parseDob('07/08/1994'), d);
      expect(UserModel.parseDob('7-8-1994'), d);
      expect(UserModel.parseDob('1994/08/07'), d);
      expect(UserModel.parseDob('1994-08-07'), d);
      expect(UserModel.parseDob(d.millisecondsSinceEpoch ~/ 1000), d);
      expect(UserModel.parseDob(d.millisecondsSinceEpoch), d);
      final pre1970 = DateTime(1965, 3, 2);
      expect(UserModel.parseDob(pre1970.millisecondsSinceEpoch), pre1970);
      final recent = DateTime(2005, 8, 7);
      expect(UserModel.parseDob(recent.millisecondsSinceEpoch), recent);
      expect(
        UserModel.parseDob({'_seconds': d.millisecondsSinceEpoch ~/ 1000}),
        d,
      );
    });

    test('returns null for empty or garbage input', () {
      expect(UserModel.parseDob(null), isNull);
      expect(UserModel.parseDob(''), isNull);
      expect(UserModel.parseDob('   '), isNull);
      expect(UserModel.parseDob('not a date'), isNull);
      expect(UserModel.parseDob('01/01/0010'), isNull);
      expect(UserModel.parseDob(true), isNull);
    });

    test('AgePolicy.parse delegates to the same parser', () {
      expect(AgePolicy.parse('07/08/1994'), UserModel.parseDob('07/08/1994'));
    });
  });

  group('AuthValidators', () {
    test('email requires a plausible address', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('foo'), isNotNull);
      expect(AuthValidators.email('a b@c.d'), isNotNull);
      expect(AuthValidators.email(' user@example.com '), isNull);
    });

    test('newPassword enforces 8+ chars with letters and numbers', () {
      expect(AuthValidators.newPassword(''), AppStrings.passwordRequired);
      expect(AuthValidators.newPassword('abc123'), AppStrings.passwordTooShort);
      expect(AuthValidators.newPassword('abcdefgh'), AppStrings.passwordWeak);
      expect(AuthValidators.newPassword('12345678'), AppStrings.passwordWeak);
      expect(AuthValidators.newPassword('abcd1234'), isNull);
    });

    test('passwords are never trimmed', () {
      expect(
        AuthValidators.confirmPassword('abcd1234 ', 'abcd1234'),
        AppStrings.passwordsDoNotMatch,
      );
      expect(AuthValidators.confirmPassword('abcd1234', 'abcd1234'), isNull);
      expect(AuthValidators.loginPassword(' '), isNull);
    });
  });
}
