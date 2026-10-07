import 'package:availchat/models/user_model.dart';
import 'package:availchat/services/discovery_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user(Map<String, dynamic> m) => UserModel.fromMap(m, uid: 'u');

void main() {
  final age = DateTime.now().year - 1995;
  final me = _user({'gender': 'male', 'dob': '01/01/1995'});

  test('no published filters shows me', () {
    expect(DiscoveryFeed.wouldShowMe(_user({}), me, 10), isTrue);
  });

  test('gender preference must include me', () {
    expect(
      DiscoveryFeed.wouldShowMe(_user({'prefGender': 'female'}), me, 10),
      isFalse,
    );
    expect(
      DiscoveryFeed.wouldShowMe(_user({'prefGender': 'Male'}), me, 10),
      isTrue,
    );
    expect(
      DiscoveryFeed.wouldShowMe(_user({'prefGender': 'everyone'}), me, 10),
      isTrue,
    );
  });

  test('my age must be in their range', () {
    expect(
      DiscoveryFeed.wouldShowMe(
        _user({'prefAgeMin': 18, 'prefAgeMax': age - 1}),
        me,
        10,
      ),
      isFalse,
    );
    expect(
      DiscoveryFeed.wouldShowMe(
        _user({'prefAgeMin': age, 'prefAgeMax': age}),
        me,
        10,
      ),
      isTrue,
    );
  });

  test('distance must be within their max, unknown distance passes', () {
    final other = _user({'prefMaxKm': 25});
    expect(DiscoveryFeed.wouldShowMe(other, me, 30), isFalse);
    expect(DiscoveryFeed.wouldShowMe(other, me, 25), isTrue);
    expect(DiscoveryFeed.wouldShowMe(other, me, null), isTrue);
  });

  test('missing data about me does not hide anyone', () {
    expect(
      DiscoveryFeed.wouldShowMe(_user({'prefGender': 'female'}), _user({}), 5),
      isTrue,
    );
    expect(DiscoveryFeed.wouldShowMe(_user({'prefGender': 'female'}), null, 5),
        isTrue);
  });
}
