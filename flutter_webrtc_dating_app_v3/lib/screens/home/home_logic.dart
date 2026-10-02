// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../../../models/user_model.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class HomeLogic {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;
//
//   /// Stream authenticated user, then stream discoverable users.
//   /// Server query simple rakhen; client-side text filter.
//   Stream<List<UserModel>> usersStream({String? query}) {
//     final q = (query ?? '').trim().toLowerCase();
//
//     return _auth.authStateChanges().where((u) => u != null).switchMap((_) {
//       return _db
//           .collection('users')
//           .where('discoveryEnabled', isEqualTo: true)
//           .limit(120)
//           .snapshots();
//     }).map((snap) {
//       // Explicit lambda to avoid inference issues
//       final all = snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
//
//       if (q.isEmpty) return all;
//
//       bool matches(UserModel u) {
//         final uName = (u.username).toLowerCase();
//         final prof = (u.profession ?? '').toLowerCase();
//         final habits = (u.habits ?? '').toLowerCase();
//         // ✅ null-safe interests
//         final interests =
//         (u.interests ?? const <String>[]).map((e) => e.toLowerCase());
//
//         return uName.contains(q) ||
//             prof.contains(q) ||
//             habits.contains(q) ||
//             interests.any((i) => i.contains(q));
//       }
//
//       return all.where(matches).toList();
//     });
//   }
//
//   /// Unread indicator for the bell.
//   /// If rules/fields not present, fallback 0.
//   Stream<int> unreadCountStream() {
//     return _auth.authStateChanges().switchMap((user) {
//       if (user == null) {
//         // return a single-value stream 0
//         return Stream<int>.value(0);
//       }
//
//       final s1 = _db
//           .collection('users')
//           .doc(user.uid)
//           .snapshots()
//           .map((d) => (d.data()?['unreadCount'] as num? ?? 0).toInt());
//
//       // If s1 errors (rules/field), fallback to s2; if s2 errors, fallback 0.
//       // Minimal dependency approach without rxdart; handleError returns same stream.
//       return s1.handleError((_) {}).switchMap((_) => s1).handleError((_) {
//         // try alternative location
//       }).switchMap((_) {
//         final s2 = _db
//             .collection('user_unreads')
//             .doc(user.uid)
//             .snapshots()
//             .map((d) => (d.data()?['count'] as num? ?? 0).toInt());
//         return s2.handleError((_) {}).switchMap((__) => s2);
//       }).handleError((_) {}).switchMap((_) => Stream<int>.value(0));
//     });
//   }
// }
//
// // ---- Password change watcher ----------------------------------------------
//
// StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pwdChangedSub;
//
// /// Call once after user logs in (e.g., in authStateChanges when user != null).
// Future<void> attachPasswordChangeListener() async {
//   final user = FirebaseAuth.instance.currentUser;
//   if (user == null) return;
//
//   await _pwdChangedSub?.cancel();
//   final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
//   _pwdChangedSub = docRef.snapshots().listen((snap) async {
//     if (!snap.exists) return;
//     final data = snap.data();
//     if (data == null) return;
//
//     final ts = data['passwordChangedAt'];
//     if (ts == null) return;
//
//     final serverMs = (ts as Timestamp).millisecondsSinceEpoch;
//     final prefs = await SharedPreferences.getInstance();
//     final localMs = prefs.getInt('passwordChangedAt_epoch_ms');
//
//     // If mismatch, another device changed the password -> sign out here.
//     if (localMs == null || localMs != serverMs) {
//       await FirebaseAuth.instance.signOut();
//     }
//   });
// }
//
// /// Call on logout / dispose to avoid leaks.
// Future<void> detachPasswordChangeListener() async {
//   await _pwdChangedSub?.cancel();
//   _pwdChangedSub = null;
// }
//
// // ---- Minimal switchMap helper (no extra dependency) ------------------------
//
// extension _SwitchMap<T> on Stream<T> {
//   Stream<S> switchMap<S>(Stream<S> Function(T) project) {
//     StreamController<S>? controller;
//     StreamSubscription<T>? outerSub;
//     StreamSubscription<S>? innerSub;
//
//     controller = StreamController<S>(
//       onListen: () {
//         outerSub = this.listen((t) {
//           innerSub?.cancel();
//           innerSub = project(t).listen(
//             controller!.add,
//             onError: controller!.addError,
//           );
//         }, onError: controller!.addError, onDone: () => controller!.close());
//       },
//       onPause: () {
//         outerSub?.pause();
//         innerSub?.pause();
//       },
//       onResume: () {
//         outerSub?.resume();
//         innerSub?.resume();
//       },
//       onCancel: () async {
//         await innerSub?.cancel();
//         await outerSub?.cancel();
//       },
//     );
//     return controller.stream;
//   }
// }
