import 'package:availchat/core/utils/discover_picks.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/home/widgets/orbit_view.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _u(String uid, [Map<String, dynamic> m = const {}]) =>
    UserModel.fromMap({...m}, uid: uid);

void main() {
  group('shared answers', () {
    final me = _u('me', {
      'foodPreference': 'Vegetarian',
      'habits': 'Night Owl',
      'religion': 'Prefer not to say',
      'interests': ['Music', 'Travel', 'Art'],
      'languages': ['Hindi', 'English'],
    });

    test('equal single answers and overlapping lists, with emoji', () {
      final other = _u('o', {
        'foodPreference': 'vegetarian',
        'habits': 'Early Riser',
        'religion': 'Prefer not to say',
        'interests': ['travel', 'Gaming'],
        'languages': ['English'],
      });
      expect(DiscoverPicks.sharedAnswers(me, other), [
        '🥦 Vegetarian',
        '🎯 Travel',
        '🗣️ English',
      ]);
    });

    test('nothing without me, capped at max', () {
      expect(DiscoverPicks.sharedAnswers(null, me), isEmpty);
      expect(DiscoverPicks.sharedAnswers(me, me, max: 2).length, 2);
    });
  });

  group('tonight\'s draw', () {
    final users = [for (var i = 0; i < 8; i++) _u('u$i')];

    test('three people, stable within a day', () {
      final day = DateTime(2026, 10, 8, 9);
      final a = DiscoverPicks.tonightsDraw(users, null, day);
      final b = DiscoverPicks.tonightsDraw(
          users, null, day.add(const Duration(hours: 10)));
      expect(a.length, 3);
      expect(a.map((u) => u.uid), b.map((u) => u.uid));
    });

    test('changes from day to day', () {
      final days = {
        for (var d = 1; d <= 6; d++)
          DiscoverPicks.tonightsDraw(users, null, DateTime(2026, 10, d))
              .map((u) => u.uid)
              .join(','),
      };
      expect(days.length, greaterThan(1));
    });

    test('fewer than three users', () {
      expect(
          DiscoverPicks.tonightsDraw(
                  users.take(2).toList(), null, DateTime(2026))
              .length,
          2);
      expect(
          DiscoverPicks.tonightsDraw(const [], null, DateTime(2026)), isEmpty);
    });
  });

  test('moon phase of a known full moon', () {
    expect(DiscoverPicks.moonPhase(DateTime.utc(2024, 1, 25, 18)).name,
        'Full moon');
    expect(DiscoverPicks.moonPhase(DateTime.utc(2024, 1, 11, 12)).name,
        'New moon');
  });

  test('next draw is at local midnight', () {
    expect(
      DiscoverPicks.untilNextDraw(DateTime(2026, 10, 8, 23, 59, 30)),
      const Duration(seconds: 30),
    );
  });

  group('orbit zoom', () {
    final me = _u('me', {'countryCode': 'IN'});
    final people = [
      _u('a', {'countryCode': 'IN'}),
      _u('b', {'countryCode': 'IN'}),
      _u('c', {'countryCode': 'US'}),
      _u('d'),
    ];
    final km = {'a': 5, 'b': 30, 'c': 12000};
    int? dist(UserModel u) => km[u.uid];

    test('counts by level; unknown distance only in country/everyone', () {
      int count(int i) =>
          OrbitZoom.within(OrbitZoom.levels[i], people, me, dist).length;
      expect(count(0), 1); // ~5 km
      expect(count(2), 1); // ~25 km
      expect(count(3), 2); // ~50 km
      expect(count(5), 2); // country
      expect(count(6), 4); // everyone
    });

    test('smart default opens the smallest level with enough people', () {
      expect(OrbitZoom.smartDefault(people, me, dist, enough: 2), 3);
      expect(OrbitZoom.smartDefault(people, me, dist, enough: 1), 0);
      expect(OrbitZoom.smartDefault(people, me, dist, enough: 99), 6);
    });
  });
}
