// lib/feature/games/ludo/models/ludo_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents 1 move inside ludo_matches/{matchId}/moves/{moveId}
class LudoMove {
  final String byUid;
  final String byColor; // "green" | "yellow" | "blue" | "red"
  final String type;    // "throw" | "move"

  final int? dice;      // For type == "throw"
  final int? pawnIndex; // For type == "move"
  final int? from;      // previous step (optional)
  final int? to;        // new step (optional)

  final Timestamp ts;   // Firestore timestamp of move

  LudoMove({
    required this.byUid,
    required this.byColor,
    required this.type,
    this.dice,
    this.pawnIndex,
    this.from,
    this.to,
    required this.ts,
  });

  factory LudoMove.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return LudoMove(
      byUid: data['byUid']?.toString() ?? '',
      byColor: data['byColor']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      dice: (data['dice'] is int) ? data['dice'] as int : null,
      pawnIndex: (data['pawnIndex'] is int) ? data['pawnIndex'] as int : null,
      from: (data['from'] is int) ? data['from'] as int : null,
      to: (data['to'] is int) ? data['to'] as int : null,
      ts: (data['ts'] is Timestamp) ? data['ts'] as Timestamp : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'byUid': byUid,
      'byColor': byColor,
      'type': type,
      if (dice != null) 'dice': dice,
      if (pawnIndex != null) 'pawnIndex': pawnIndex,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      'ts': ts,
    };
  }
}
