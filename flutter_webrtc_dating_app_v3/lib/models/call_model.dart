import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { audio, video }

enum CallStatus {
  ringing,
  accepted,
  rejected,
  ended,
  busy,
  missed,
  ongoing,
}

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final CallType type;
  final CallStatus status;
  final DateTime timestamp;
  final int? duration; // seconds
  final String? roomId;

// Signaling payloads
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;

  CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    required this.type,
    required this.status,
    required this.timestamp,
    this.duration,
    this.roomId,
    this.offer,
    this.answer,
  });

  factory CallModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    return CallModel(
      id: doc.id,
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? '',
      callerAvatar: data['callerAvatar'],
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverAvatar: data['receiverAvatar'],
      type: (data['callType'] == 'audio') ? CallType.audio : CallType.video,
      status: _statusFromString(data['status']),
      timestamp: _toDateTime(data['timestamp']) ?? DateTime.now(),
      duration: (data['duration'] as num?)?.toInt(),
      roomId: data['roomId'],
      offer: data['offer'] as Map<String, dynamic>?,
      answer: data['answer'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'callType': type == CallType.video ? 'video' : 'audio',
      'status': _statusToString(status),
      'timestamp': Timestamp.fromDate(timestamp),
      'duration': duration,
      'roomId': roomId,
      'offer': offer,
      'answer': answer,
    };
  }

  CallModel copyWith({
    CallStatus? status,
    int? duration,
    Map<String, dynamic>? offer,
    Map<String, dynamic>? answer,
  }) {
    return CallModel(
      id: id,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverAvatar: receiverAvatar,
      type: type,
      status: status ?? this.status,
      timestamp: timestamp,
      duration: duration ?? this.duration,
      roomId: roomId,
      offer: offer ?? this.offer,
      answer: answer ?? this.answer,
    );
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static CallStatus _statusFromString(String? v) {
    switch (v) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
        return CallStatus.accepted;
      case 'rejected':
        return CallStatus.rejected;
      case 'ended':
        return CallStatus.ended;
      case 'busy':
        return CallStatus.busy;
      case 'missed':
        return CallStatus.missed;
      case 'ongoing':
        return CallStatus.ongoing;
      default:
        return CallStatus.ringing;
    }
  }

  static String _statusToString(CallStatus s) {
    switch (s) {
      case CallStatus.ringing:
        return 'ringing';
      case CallStatus.accepted:
        return 'accepted';
      case CallStatus.rejected:
        return 'rejected';
      case CallStatus.ended:
        return 'ended';
      case CallStatus.busy:
        return 'busy';
      case CallStatus.missed:
        return 'missed';
      case CallStatus.ongoing:
        return 'ongoing';
    }
  }
}