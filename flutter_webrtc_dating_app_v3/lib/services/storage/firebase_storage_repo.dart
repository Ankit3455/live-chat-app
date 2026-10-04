import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'storage_repo.dart';

class FirebaseStorageRepo implements StorageRepo {
  @override
  Future<String> uploadVoice({
    required String uid,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) throw Exception('Voice file not found at $localPath');

    final ref = FirebaseStorage.instance.ref('voices/$uid/intro.m4a');
    await ref.putFile(file, SettableMetadata(contentType: 'audio/m4a'));
    return await ref.getDownloadURL();
  }

  @override
  Future<void> deleteVoice({required String uid}) async {
    final ref = FirebaseStorage.instance.ref('voices/$uid/intro.m4a');
    try {
      await ref.delete();
    } catch (_) {}
  }

  @override
  Future<String> uploadBytes(
      Uint8List bytes, {
        String folder = 'profile_photos',
        String fileName = 'avatar.png',
      }) async {
    final ref = FirebaseStorage.instance.ref('$folder/$fileName');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/png'),
    );

    return await ref.getDownloadURL();
  }

  @override
  Future<String> uploadImageFile({
    required File file,
    String folder = 'profile_photos',
  }) async {
    // Owner folder + contentType so storage.rules can check type and owner.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    final name = contentType == 'image/jpeg' ? '$ts.jpg' : '$ts.$ext';
    final ref = FirebaseStorage.instance
        .ref(uid == null ? '$folder/$ts.jpg' : '$folder/$uid/$name');

    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  // 🆕 NEW: Chat media methods
  @override
  Future<String> uploadChatImage({
    required String conversationId,
    required File file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('chat_media/$conversationId/img_$timestamp.jpg');

    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  @override
  Future<String> uploadChatAudio({
    required String conversationId,
    required String localPath,
    required int durationSeconds,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Audio file not found');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('chat_media/$conversationId/audio_$timestamp.m4a');

    await ref.putFile(file, SettableMetadata(contentType: 'audio/m4a'));
    return await ref.getDownloadURL();
  }
}