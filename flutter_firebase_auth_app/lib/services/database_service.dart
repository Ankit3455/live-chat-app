import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users Collection Reference
  CollectionReference get usersCollection => _firestore.collection('users');

  // Create or Update User
  Future<void> saveUser(UserModel user) async {
    try {
      await usersCollection.doc(user.uid).set(
        user.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to save user: $e');
    }
  }

  // Get User by ID
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Update User Profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await usersCollection.doc(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Update User Status (online/offline)
  Future<void> updateUserStatus(String uid, bool isOnline) async {
    try {
      await usersCollection.doc(uid).update({
        'online': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  // Get All Users (for discover/chat)
  Stream<List<UserModel>> getAllUsers() {
    return usersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Delete User
  Future<void> deleteUser(String uid) async {
    try {
      await usersCollection.doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}