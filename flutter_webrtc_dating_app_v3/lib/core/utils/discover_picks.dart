import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';

/// Pure helpers behind the Discover screen ("Tonight's Draw").
class DiscoverPicks {
  DiscoverPicks._();

  static const String _hidden = 'Prefer not to say';

  /// Single answers that count as shared when equal.
  static const List<String> _sameAnswerFields = [
    'foodPreference',
    'habits',
    'personalityType',
    'drinkingHabits',
    'smokingHabits',
    'exerciseFrequency',
    'wantsChildren',
    'religion',
    'communicationStyle',
    'loveLanguage',
  ];

  /// Multi answers that count as shared when they overlap.
  static const List<String> _overlapFields = [
    'interests',
    'languages',
    'musicGenres',
    'movieGenres',
  ];

  /// Up to [max] things [me] and [other] both answered the same way, as
  /// "emoji value" labels (emoji from the question's options when it has one).
  static List<String> sharedAnswers(
    UserModel? me,
    UserModel other, {
    int max = 6,
  }) {
    if (me == null) return const [];
    final a = me.toMap();
    final b = other.toMap();
    final out = <String>[];

    String label(String field, String value) {
      final q = QuestionnaireHelper.getQuestionByFieldName(field);
      final emoji = q?.emojiFor(value) ?? q?.icon;
      return emoji == null ? value : '$emoji $value';
    }

    for (final f in _sameAnswerFields) {
      final x = a[f], y = b[f];
      if (x is String && y is String) {
        final v = x.trim();
        if (v.isNotEmpty &&
            v != _hidden &&
            v.toLowerCase() == y.trim().toLowerCase()) {
          out.add(label(f, v));
        }
      }
    }
    for (final f in _overlapFields) {
      final x = a[f], y = b[f];
      if (x is List && y is List) {
        final theirs =
            y.whereType<String>().map((e) => e.toLowerCase()).toSet();
        for (final v in x.whereType<String>()) {
          if (theirs.contains(v.toLowerCase())) out.add(label(f, v));
        }
      }
    }
    return out.take(max).toList();
  }

  /// Today's three people: highest compatibility first; ties (and people
  /// without a score) are ordered by a per-day hash so the draw changes daily.
  static List<UserModel> tonightsDraw(
    List<UserModel> users,
    UserModel? me,
    DateTime day,
  ) {
    final key = dayKey(day);
    int tie(UserModel u) => _hash('${u.uid}|$key');
    final scored = [
      for (final u in users)
        if ((u.uid ?? '').isNotEmpty)
          (
            user: u,
            score: CompatibilityService.compatibilityScore(me, u) ?? -1
          ),
    ]..sort((p, q) {
        final s = q.score.compareTo(p.score);
        return s != 0 ? s : tie(p.user).compareTo(tie(q.user));
      });
    return scored.take(3).map((e) => e.user).toList();
  }

  /// yyyymmdd in local time; the draw rolls over at local midnight.
  static String dayKey(DateTime day) =>
      '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

  // FNV-1a: stable across runs, unlike String.hashCode.
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  static const List<String> _moonNames = [
    'New moon',
    'Waxing crescent',
    'First quarter',
    'Waxing gibbous',
    'Full moon',
    'Waning gibbous',
    'Last quarter',
    'Waning crescent',
  ];
  static const List<String> _moonEmoji = [
    '🌑',
    '🌒',
    '🌓',
    '🌔',
    '🌕',
    '🌖',
    '🌗',
    '🌘',
  ];

  /// Moon phase for [when] from a known new moon (6 Jan 2000, 18:14 UTC).
  static ({String emoji, String name}) moonPhase(DateTime when) {
    const synodic = 29.530588853;
    final ref = DateTime.utc(2000, 1, 6, 18, 14);
    final days = when.toUtc().difference(ref).inMinutes / 1440.0;
    final age = ((days % synodic) + synodic) % synodic;
    final i = (age / synodic * 8).round() % 8;
    return (emoji: _moonEmoji[i], name: _moonNames[i]);
  }

  static String greeting(DateTime now) => now.hour < 5
      ? 'Still up'
      : now.hour < 12
          ? 'Good morning'
          : now.hour < 17
              ? 'Good afternoon'
              : 'Good evening';

  /// Time left until local midnight, when the draw changes.
  static Duration untilNextDraw(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1).difference(now);
}
