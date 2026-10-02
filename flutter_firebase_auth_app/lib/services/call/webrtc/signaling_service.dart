import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/call_model.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<String> createCall({
    required String receiverId,
    required String receiverName,
    String? receiverAvatar,
    required CallType type,
    required Map<String, dynamic> offer,
  }) async {
    final callRef = _firestore.collection('calls').doc();
    final user = _auth.currentUser!;
    final call = CallModel(
      id: callRef.id,
      callerId: user.uid,
      callerName: user.displayName ?? 'User',
      callerAvatar: user.photoURL,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverAvatar: receiverAvatar,
      type: type,
      status: CallStatus.ringing,
      timestamp: DateTime.now(),
      roomId: callRef.id,
      offer: offer,
    );

    await callRef.set(call.toFirestore());
    await _sendCallNotification(receiverId, type);
    return callRef.id;
  }

  Future<void> answerCall(String callId, Map<String, dynamic> answer) async {
    await _firestore.collection('calls').doc(callId).update({
      'answer': answer,
      'status': 'accepted',
    });
  }

  Future<void> rejectCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'rejected',
    });
  }

  Future<void> endCall(String callId, int duration) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'ended',
      'duration': duration,
    });
  }

  Stream<CallModel?> getCallStream(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots().map((doc) {
      if (doc.exists) {
        return CallModel.fromFirestore(doc);
      }
      return null;
    });
  }

  Stream<CallModel?> listenForIncomingCalls() {
    if (currentUserId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isNotEmpty) {
        return CallModel.fromFirestore(snap.docs.first);
      }
      return null;
    });
  }

  Future<void> addIceCandidate({
    required String callId,
    required Map<String, dynamic> candidate,
    required bool isOffer,
  }) async {
    final path = isOffer ? 'offerCandidates' : 'answerCandidates';
    await _firestore.collection('calls').doc(callId).collection(path).add(candidate);
  }

  Stream<List<Map<String, dynamic>>> getIceCandidates({
    required String callId,
    required bool isOffer,
  }) {
    final path = isOffer ? 'answerCandidates' : 'offerCandidates';
    return _firestore
        .collection('calls')
        .doc(callId)
        .collection(path)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> _sendCallNotification(String receiverId, CallType type) async {
// Hook up FCM here if needed.
  }
}