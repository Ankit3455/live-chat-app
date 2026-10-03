import 'package:availchat/core/utils/auth_validators.dart';
import 'package:availchat/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_document_snapshot.dart';

void main() {
  group('UserModel.fromMap', () {
    test('reads List<dynamic> and legacy string fields', () {
      final u = UserModel.fromMap({
        'username': 'Ravi',
        'interests': <dynamic>['music', null, '', 'travel'],
        'hereFor': 'Friendship',
        'pets': <dynamic>[],
        'musicGenres': <dynamic>['rock', 7],
        'believesInAstrology': 'yes',
        'online': 1,
      }, uid: 'u1');
      expect(u.uid, 'u1');
      expect(u.interests, ['music', 'travel']);
      expect(u.hereFor, ['Friendship']);
      expect(u.pets, isNull);
      expect(u.musicGenres, ['rock', '7']);
      expect(u.believesInAstrology, isTrue);
      expect(u.online, isTrue);
    });

    test('malformed fields become null instead of throwing', () {
      final u = UserModel.fromMap({
        'username': 42,
        'age': 'twenty',
        'userLatitude': 'abc',
        'interests': 'not a list',
        'avatarProperties': 'oops',
        'profileCompletionPercentage': '80',
      });
      expect(u.username, '42');
      expect(u.age, isNull);
      expect(u.userLatitude, isNull);
      expect(u.interests, isEmpty);
      expect(u.avatarProperties, isNull);
      expect(u.profileCompletionPercentage, 80);
    });

    test('age is derived from DOB, else taken from a public profile', () {
      final own = UserModel.fromMap({'dob': '01/01/1990', 'age': 5});
      expect(own.age, AgePolicy.ageOn(DateTime(1990, 1, 1)));
      expect(own.dob, '01/01/1990');

      final public = UserModel.fromMap({'age': 27});
      expect(public.dateOfBirth, isNull);
      expect(public.age, 27);
    });

    test('profileCompletionPercentage has no default', () {
      expect(UserModel.fromMap({}).profileCompletionPercentage, isNull);
    });

    test('zodiacSign falls back to sunSign', () {
      expect(UserModel.fromMap({'sunSign': 'Leo'}).zodiacSign, 'Leo');
    });
  });

  group('UserModel.fromFirestore', () {
    test('uses the document id and tolerates a missing doc', () {
      final u = UserModel.fromFirestore(
        FakeDocumentSnapshot('abc', {'username': 'Mia'}),
      );
      expect(u.uid, 'abc');
      expect(u.username, 'Mia');

      final empty = UserModel.fromFirestore(FakeDocumentSnapshot('xyz', null));
      expect(empty.uid, 'xyz');
      expect(empty.username, 'Unknown');
    });
  });
}
