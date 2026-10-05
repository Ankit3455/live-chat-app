// lib/feature/games/chat_games/flags/flag_statements.dart
//
// Red Flag, Green Flag: both vote on the same 5 dating habits.

import 'dart:math';

class FlagStatement {
  final String id;
  final String text;

  const FlagStatement(this.id, this.text);
}

class FlagStatements {
  FlagStatements._();

  static const String red = 'red';
  static const String green = 'green';
  static const List<String> votes = [red, green];

  static const List<FlagStatement> pool = [
    FlagStatement('late_reply', 'Replies after 6 hours'),
    FlagStatement('calls_mom', 'Calls their mom every day'),
    FlagStatement('five_year_plan', 'Has a 5-year plan'),
    FlagStatement('ex_friends', 'Is still friends with their ex'),
    FlagStatement('plans_dates', 'Plans every date in detail'),
    FlagStatement('split_bill', 'Always splits the bill 50/50'),
    FlagStatement('shares_location', 'Wants to share live location'),
    FlagStatement('no_pets', "Doesn't like pets"),
    FlagStatement('posts_dates', 'Posts every date on Instagram'),
    FlagStatement('fast_love', "Says 'I love you' within a month"),
    FlagStatement('never_cancels', 'Never cancels plans'),
    FlagStatement('emoji_texter', 'Uses an emoji in every message'),
    FlagStatement('early_sleeper', 'Is asleep by 9 PM'),
    FlagStatement('voice_notes', 'Sends voice notes instead of texts'),
    FlagStatement('remembers', 'Remembers tiny details you mentioned'),
    FlagStatement('always_late', 'Is always 15 minutes late'),
    FlagStatement('big_friends', 'Has a huge friend group'),
    FlagStatement('cries_movies', 'Cries at movies'),
    FlagStatement('phone_down', 'Keeps their phone face down'),
    FlagStatement('meet_family', 'Wants you to meet their family soon'),
    FlagStatement('talks_ex', 'Talks about their ex on the first date'),
    FlagStatement('surprises', 'Loves surprise plans'),
    FlagStatement('slow_ready', 'Takes 2 hours to get ready'),
    FlagStatement('cooks', 'Cooks for you on the second date'),
    FlagStatement('no_social', 'Has no social media at all'),
    FlagStatement('double_text', 'Double texts when you go quiet'),
    FlagStatement('gym_daily', 'Goes to the gym every single day'),
    FlagStatement('honest', 'Tells you when something bothers them'),
  ];

  static final Map<String, FlagStatement> _byId = {
    for (final s in pool) s.id: s,
  };

  static FlagStatement? byId(String? id) => id == null ? null : _byId[id];

  static List<List<String>> buildDeck(int rounds, Random random) {
    final shuffled = List.of(pool)..shuffle(random);
    return [
      for (final s in shuffled.take(rounds)) [s.id],
    ];
  }

  static bool isValidVote(Object? v) => votes.contains(v);

  /// ⏱️ = no vote before the round timed out.
  static String emojiOf(Object? vote) =>
      vote == red ? '🚩' : (vote == green ? '💚' : '⏱️');
}
