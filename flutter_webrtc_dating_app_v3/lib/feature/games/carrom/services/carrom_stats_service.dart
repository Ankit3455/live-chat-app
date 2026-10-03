// lib/feature/games/carrom/services/carrom_stats_service.dart
// STATUS: NEW/COMPLETE ✅

import 'package:cloud_firestore/cloud_firestore.dart';

class CarromStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== SAVE GAME RESULT =====
  /// Writes stats, history and leaderboards in one transaction. Returns false
  /// (and writes nothing) if `carrom_history/{matchId}` already exists, so the
  /// result is counted once even if called twice.
  static Future<bool> saveGameResult({
    required String odZ,
    required String odZName,
    required String? odZAvatar,
    required String opponentUid,
    required String opponentName,
    required int myScore,
    required int opponentScore,
    required String matchId,
    int? gameDurationSeconds,
    bool? won,
    bool? isDraw,
  }) {
    final bool didWin = won ?? myScore > opponentScore;
    final bool draw = isDraw ?? (won == null && myScore == opponentScore);

    final userRef = _firestore.collection('user_game_stats').doc(odZ);
    final statsRef = userRef.collection('games').doc('carrom');
    final historyRef = userRef.collection('carrom_history').doc(matchId);
    final leaderboardRefs = _leaderboardRefs(odZ, DateTime.now());

    return _firestore.runTransaction<bool>((tx) async {
      final history = await tx.get(historyRef);
      if (history.exists) return false;

      final statsSnap = await tx.get(statsRef);
      final current = statsSnap.data() ?? {};
      int read(String key) => (current[key] as num?)?.toInt() ?? 0;

      final int newWinStreak = didWin ? read('winStreak') + 1 : 0;
      final int bestWinStreak = read('bestWinStreak');
      final int totalGames = read('totalGames') + 1;
      final int wins = read('wins') + (didWin ? 1 : 0);
      final int totalScore = read('totalScore') + myScore;
      final int highScore =
          myScore > read('highScore') ? myScore : read('highScore');

      // 1. User Stats
      tx.set(
        statsRef,
        {
          'totalGames': totalGames,
          'wins': wins,
          'losses': read('losses') + (!didWin && !draw ? 1 : 0),
          'draws': read('draws') + (draw ? 1 : 0),
          'winStreak': newWinStreak,
          'bestWinStreak':
              newWinStreak > bestWinStreak ? newWinStreak : bestWinStreak,
          'highScore': highScore,
          'totalScore': totalScore,
          'averageScore': (totalScore / totalGames).round(),
          'lastPlayed': FieldValue.serverTimestamp(),
          'rank': _calculateRank(totalGames, wins),
        },
        SetOptions(merge: true),
      );

      // 2. Match History (also the idempotency marker)
      tx.set(historyRef, {
        'opponentUid': opponentUid,
        'opponentName': opponentName,
        'myScore': myScore,
        'opponentScore': opponentScore,
        'won': didWin,
        'isDraw': draw,
        'duration': gameDurationSeconds ?? 0,
        'playedAt': FieldValue.serverTimestamp(),
      });

      // 3. Leaderboards (daily, weekly, all-time)
      final leaderboardData = {
        'odZ': odZ,
        'displayName': odZName,
        'avatar': odZAvatar ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'score': FieldValue.increment(myScore),
        'wins': FieldValue.increment(didWin ? 1 : 0),
        'gamesPlayed': FieldValue.increment(1),
      };
      for (final ref in leaderboardRefs) {
        tx.set(ref, leaderboardData, SetOptions(merge: true));
      }
      return true;
    });
  }

  static List<DocumentReference<Map<String, dynamic>>> _leaderboardRefs(
    String odZ,
    DateTime now,
  ) {
    final dailyKey = '${now.year}-${now.month}-${now.day}';
    final weeklyKey = '${now.year}-W${_getWeekNumber(now)}';
    final root = _firestore.collection('leaderboards').doc('carrom');
    return [
      root.collection('daily').doc(dailyKey).collection('users').doc(odZ),
      root.collection('weekly').doc(weeklyKey).collection('users').doc(odZ),
      root.collection('allTime').doc(odZ),
    ];
  }

  // ===== GET USER STATS =====
  static Future<CarromStats?> getUserStats(String odZ) async {
    try {
      final snap = await _firestore
          .collection('user_game_stats')
          .doc(odZ)
          .collection('games')
          .doc('carrom')
          .get();

      if (!snap.exists) return null;
      return CarromStats.fromMap(snap.data()!);
    } catch (e) {
      print('Error getting stats: $e');
      return null;
    }
  }

  // ===== GET MATCH HISTORY =====
  static Stream<List<MatchHistory>> getMatchHistory(String odZ, {int limit = 20}) {
    return _firestore
        .collection('user_game_stats')
        .doc(odZ)
        .collection('carrom_history')
        .orderBy('playedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => MatchHistory.fromMap(doc.id, doc.data()))
        .toList());
  }

  // ===== GET LEADERBOARD =====
  static Stream<List<LeaderboardEntry>> getLeaderboard({
    required LeaderboardType type,
    int limit = 50,
  }) {
    String collectionName;
    String? docId;

    final now = DateTime.now();

    switch (type) {
      case LeaderboardType.daily:
        collectionName = 'daily';
        docId = '${now.year}-${now.month}-${now.day}';
        break;
      case LeaderboardType.weekly:
        collectionName = 'weekly';
        docId = '${now.year}-W${_getWeekNumber(now)}';
        break;
      case LeaderboardType.allTime:
        collectionName = 'allTime';
        docId = null;
        break;
    }

    Query query;
    if (docId != null) {
      query = _firestore
          .collection('leaderboards')
          .doc('carrom')
          .collection(collectionName)
          .doc(docId)
          .collection('users')
          .orderBy('score', descending: true)
          .limit(limit);
    } else {
      query = _firestore
          .collection('leaderboards')
          .doc('carrom')
          .collection(collectionName)
          .orderBy('score', descending: true)
          .limit(limit);
    }

    return query.snapshots().map((snap) {
      int rank = 0;
      return snap.docs.map((doc) {
        rank++;
        return LeaderboardEntry.fromMap(doc.data() as Map<String, dynamic>, rank);
      }).toList();
    });
  }

  // ===== GET USER RANK =====
  static Future<int?> getUserRank(String odZ, LeaderboardType type) async {
    try {
      final leaderboard = await getLeaderboard(type: type, limit: 100).first;
      final index = leaderboard.indexWhere((e) => e.odZ == odZ);
      return index >= 0 ? index + 1 : null;
    } catch (e) {
      return null;
    }
  }

  // ===== HELPER METHODS =====
  static String _calculateRank(int totalGames, int wins) {
    if (totalGames < 5) return 'Beginner';

    final winRate = wins / totalGames;

    if (totalGames >= 100 && winRate >= 0.7) return 'Legend';
    if (totalGames >= 50 && winRate >= 0.6) return 'Diamond';
    if (totalGames >= 30 && winRate >= 0.5) return 'Platinum';
    if (totalGames >= 20 && winRate >= 0.4) return 'Gold';
    if (totalGames >= 10) return 'Silver';
    return 'Bronze';
  }

  static int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDifference = date.difference(firstDayOfYear).inDays;
    return ((daysDifference + firstDayOfYear.weekday) / 7).ceil();
  }
}

// ===== DATA MODELS =====

class CarromStats {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;
  final int winStreak;
  final int bestWinStreak;
  final int highScore;
  final int totalScore;
  final int averageScore;
  final String rank;
  final DateTime? lastPlayed;

  CarromStats({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winStreak,
    required this.bestWinStreak,
    required this.highScore,
    required this.totalScore,
    required this.averageScore,
    required this.rank,
    this.lastPlayed,
  });

  double get winRate => totalGames > 0 ? (wins / totalGames) * 100 : 0;

  factory CarromStats.fromMap(Map<String, dynamic> map) {
    return CarromStats(
      totalGames: map['totalGames'] ?? 0,
      wins: map['wins'] ?? 0,
      losses: map['losses'] ?? 0,
      draws: map['draws'] ?? 0,
      winStreak: map['winStreak'] ?? 0,
      bestWinStreak: map['bestWinStreak'] ?? 0,
      highScore: map['highScore'] ?? 0,
      totalScore: map['totalScore'] ?? 0,
      averageScore: map['averageScore'] ?? 0,
      rank: map['rank'] ?? 'Beginner',
      lastPlayed: (map['lastPlayed'] as Timestamp?)?.toDate(),
    );
  }

  static CarromStats empty() {
    return CarromStats(
      totalGames: 0,
      wins: 0,
      losses: 0,
      draws: 0,
      winStreak: 0,
      bestWinStreak: 0,
      highScore: 0,
      totalScore: 0,
      averageScore: 0,
      rank: 'Beginner',
    );
  }
}

class MatchHistory {
  final String matchId;
  final String opponentUid;
  final String opponentName;
  final int myScore;
  final int opponentScore;
  final bool won;
  final bool isDraw;
  final int duration;
  final DateTime? playedAt;

  MatchHistory({
    required this.matchId,
    required this.opponentUid,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.won,
    required this.isDraw,
    required this.duration,
    this.playedAt,
  });

  factory MatchHistory.fromMap(String id, Map<String, dynamic> map) {
    return MatchHistory(
      matchId: id,
      opponentUid: map['opponentUid'] ?? '',
      opponentName: map['opponentName'] ?? 'Unknown',
      myScore: map['myScore'] ?? 0,
      opponentScore: map['opponentScore'] ?? 0,
      won: map['won'] ?? false,
      isDraw: map['isDraw'] ?? false,
      duration: map['duration'] ?? 0,
      playedAt: (map['playedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class LeaderboardEntry {
  final String odZ;
  final String displayName;
  final String avatar;
  final int score;
  final int wins;
  final int gamesPlayed;
  final int rank;

  LeaderboardEntry({
    required this.odZ,
    required this.displayName,
    required this.avatar,
    required this.score,
    required this.wins,
    required this.gamesPlayed,
    required this.rank,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, int rank) {
    return LeaderboardEntry(
      odZ: map['odZ'] ?? '',
      displayName: map['displayName'] ?? 'Unknown',
      avatar: map['avatar'] ?? '',
      score: map['score'] ?? 0,
      wins: map['wins'] ?? 0,
      gamesPlayed: map['gamesPlayed'] ?? 0,
      rank: rank,
    );
  }
}

enum LeaderboardType { daily, weekly, allTime }