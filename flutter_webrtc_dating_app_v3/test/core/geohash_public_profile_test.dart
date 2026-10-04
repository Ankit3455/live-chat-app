import 'package:availchat/core/utils/geohash.dart';
import 'package:availchat/models/public_profile.dart';
import 'package:flutter_test/flutter_test.dart';

// DEST-002: other users only ever see a precision-5 cell and a 5 km bucket.
void main() {
  group('Geohash', () {
    test('encodes the reference point', () {
      expect(Geohash.encode(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
      expect(Geohash.encode(57.64911, 10.40744), 'u4pru');
    });

    test('decode returns the cell centre and rejects invalid hashes', () {
      final c = Geohash.decode('u4pru')!;
      expect((c.lat - 57.64911).abs(), lessThan(0.03));
      expect((c.lng - 10.40744).abs(), lessThan(0.03));
      expect(Geohash.decode(null), isNull);
      expect(Geohash.decode(''), isNull);
      expect(Geohash.decode('u4pra'), isNull); // 'a' is not base32
    });

    test('distanceKm matches a known city pair', () {
      final d = Geohash.distanceKm(51.5074, -0.1278, 48.8566, 2.3522);
      expect(d, closeTo(343.5, 2));
      expect(Geohash.distanceKm(10, 10, 10, 10), 0);
    });

    test('approxDistanceKm rounds up to 5 km buckets, never below 5', () {
      expect(
        Geohash.approxDistanceKm(
          28.6139,
          77.2090,
          Geohash.encode(28.6139, 77.2090),
        ),
        5,
      );
      final far = Geohash.approxDistanceKm(
        51.5074,
        -0.1278,
        Geohash.encode(48.8566, 2.3522),
      );
      expect(far % 5, 0);
      expect(far, inInclusiveRange(340, 355));
      expect(Geohash.approxDistanceKm(0, 0, null), -1);
    });
  });

  group('PublicProfile.fromUserData', () {
    final adult = {
      'username': 'Asha',
      'email': 'asha@example.com',
      'dateOfBirth': '15/06/1995',
      'dob': '15/06/1995',
      'birthTime': '10:30',
      'birthLocation': 'Pune',
      'userLatitude': 18.5204,
      'userLongitude': 73.8567,
      'fcmTokens': ['t1'],
      'notificationSettings': {'pushEnabled': true},
      'gender': ' Female ',
      'avatarProperties': {'avatarImageUrl': 'https://x/a.png', 'hair': 3},
      'discoveryEnabled': true,
    };

    test('publishes no private fields', () {
      final out = PublicProfile.fromUserData('u1', adult);
      for (final key in [
        'email',
        'dateOfBirth',
        'dob',
        'birthTime',
        'birthLocation',
        'userLatitude',
        'userLongitude',
        'fcmTokens',
        'notificationSettings',
      ]) {
        expect(out.containsKey(key), isFalse, reason: key);
      }
      expect(out['uid'], 'u1');
      expect(out['username'], 'Asha');
      expect(out['gender'], 'female');
      expect(out['avatarProperties'], {'avatarImageUrl': 'https://x/a.png'});
      expect(out['geohash'], Geohash.encode(18.5204, 73.8567));
      expect(out['age'], isA<int>());
      expect(out['discoveryEnabled'], isTrue);
    });

    test('discovery stays off for minors and users without a DOB', () {
      final now = DateTime.now();
      final minorDob =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year - 16}';
      final minor = Map<String, dynamic>.from(adult)
        ..['dateOfBirth'] = minorDob
        ..['dob'] = minorDob;
      expect(
        PublicProfile.fromUserData('u2', minor)['discoveryEnabled'],
        isFalse,
      );

      final noDob = Map<String, dynamic>.from(adult)
        ..remove('dateOfBirth')
        ..remove('dob');
      final out = PublicProfile.fromUserData('u3', noDob);
      expect(out['discoveryEnabled'], isFalse);
      expect(out.containsKey('age'), isFalse);
    });

    test('stored geohash is truncated to the public precision', () {
      expect(
        PublicProfile.geohashFromUserData({'geohash': 'tdr1vzc8x'}),
        'tdr1v',
      );
      expect(PublicProfile.geohashFromUserData({'geohash': 'td'}), isNull);
      expect(PublicProfile.geohashFromUserData({}), isNull);
    });
  });
}
