// lib/feature/games/chat_games/game_space.dart
//
// Where a 2-player game lives. A game started from a chat lives under
// conversations/{convId}/games; a game with a random player (matched from
// the Games tab) lives under game_rooms/{roomId}/games. Services and screens
// take one "space id": the conversation id, or 'room:<roomId>' (conversation
// ids never contain ':').

import 'package:cloud_firestore/cloud_firestore.dart';

class GameSpace {
  GameSpace._();

  static const String _roomPrefix = 'room:';

  static String room(String roomId) => '$_roomPrefix$roomId';

  static bool isRoom(String spaceId) => spaceId.startsWith(_roomPrefix);

  static String roomId(String spaceId) => spaceId.substring(_roomPrefix.length);

  /// conversations/{convId} or game_rooms/{roomId}.
  static DocumentReference<Map<String, dynamic>> parent(String spaceId) {
    final db = FirebaseFirestore.instance;
    return isRoom(spaceId)
        ? db.collection('game_rooms').doc(roomId(spaceId))
        : db.collection('conversations').doc(spaceId);
  }

  static DocumentReference<Map<String, dynamic>> game(
    String spaceId,
    String name,
  ) =>
      parent(spaceId).collection('games').doc(name);
}
