// // lib/services/storage/storage_repo.dart
// import 'dart:io';
// import 'dart:typed_data';
//
// abstract class StorageRepo {
//   Future<String> uploadVoice({
//     required String uid,
//     required String localPath,
//   });
//
//   Future<void> deleteVoice({required String uid});
//
//   Future<String> uploadBytes(
//       Uint8List bytes, {
//         String folder = 'profile_photos',
//         String fileName = 'avatar.png',
//       });
//
//   Future<String> uploadImageFile({
//     required File file,
//     String folder = 'profile_photos',
//   });
// }


import 'dart:io';
import 'dart:typed_data';

abstract class StorageRepo {
  // Existing methods
  Future<String> uploadVoice({
    required String uid,
    required String localPath,
  });

  Future<void> deleteVoice({required String uid});

  Future<String> uploadBytes(
      Uint8List bytes, {
        String folder = 'profile_photos',
        String fileName = 'avatar.png',
      });

  Future<String> uploadImageFile({
    required File file,
    String folder = 'profile_photos',
  });

  // 🆕 Chat media methods
  Future<String> uploadChatImage({
    required String conversationId,
    required File file,
  });

  Future<String> uploadChatAudio({
    required String conversationId,
    required String localPath,
    required int durationSeconds,
  });
}