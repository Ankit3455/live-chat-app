// lib/services/_helpers/batch_delete.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection ko batches me safe tarike se delete karta hai.
/// - batchSize: 300–500 recommended.
/// - Return: completes when collection is empty.
Future<void> deleteCollectionInBatches(
    CollectionReference<Map<String, dynamic>> ref, {
      int batchSize = 300,
    }) async {
  final firestore = FirebaseFirestore.instance;

  while (true) {
    final snap = await ref.limit(batchSize).get();
    if (snap.docs.isEmpty) break;

    final WriteBatch batch = firestore.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    // Thoda sa yield to avoid watchdog
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
