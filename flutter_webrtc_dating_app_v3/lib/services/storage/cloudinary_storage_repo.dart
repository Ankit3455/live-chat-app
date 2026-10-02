// // lib/services/storage/cloudinary_storage_repo.dart
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart' show MediaType;
//
// import '../../core/config/storage_config.dart';
// import 'storage_repo.dart';
// import 'firebase_storage_repo.dart';
//
// class CloudinaryStorageRepo implements StorageRepo {
//   const CloudinaryStorageRepo();
//
//   @override
//   Future<String> uploadVoice({
//     required String uid,
//     required String localPath,
//   }) async {
//     final file = File(localPath);
//     if (!file.existsSync()) {
//       throw Exception('Voice file not found at $localPath');
//     }
//
//     final uri = Uri.parse('https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/auto/upload');
//
//     final req = http.MultipartRequest('POST', uri)
//       ..fields['upload_preset'] = StorageConfig.uploadPresetVoices
//       ..fields['folder'] = StorageConfig.folderVoices
//       ..fields['public_id'] = '${StorageConfig.folderVoices}/${uid}_intro'
//       ..files.add(
//         await http.MultipartFile.fromPath(
//           'file',
//           localPath,
//           contentType: MediaType('audio', 'm4a'),
//         ),
//       );
//
//     final streamed = await req.send();
//     final resp = await http.Response.fromStream(streamed);
//
//     if (resp.statusCode >= 200 && resp.statusCode < 300) {
//       final Map<String, dynamic> data = jsonDecode(resp.body);
//       final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
//       if (url == null || url.isEmpty) {
//         throw Exception('Cloudinary response missing secure_url for voice upload');
//       }
//       return url;
//     } else {
//       throw Exception('Cloudinary voice upload failed: ${resp.statusCode} ${resp.body}');
//     }
//   }
//
//   @override
//   Future<void> deleteVoice({required String uid}) async {
//     // Unsigned client cannot delete — server admin required.
//     return;
//   }
//
//   @override
//   Future<String> uploadBytes(
//       Uint8List bytes, {
//         String folder = 'profile_photos',
//         String fileName = 'avatar.png',
//       }) async {
//     if (!StorageConfig.kUseCloudinaryForMedia) {
//       final firebase = FirebaseStorageRepo();
//       return firebase.uploadBytes(
//         bytes,
//         folder: folder,
//         fileName: fileName,
//       );
//     }
//
//     final uri = Uri.parse('https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/image/upload');
//
//     final baseName = fileName.contains('.') ? fileName.split('.').first : fileName;
//     final publicId = '$folder/$baseName';
//
//     final req = http.MultipartRequest('POST', uri)
//       ..fields['upload_preset'] = StorageConfig.uploadPresetImages
//       ..fields['folder'] = folder
//       ..fields['public_id'] = publicId
//       ..files.add(
//         http.MultipartFile.fromBytes(
//           'file',
//           bytes,
//           filename: fileName,
//           contentType: MediaType('image', 'png'),
//         ),
//       );
//
//     final streamed = await req.send();
//     final resp = await http.Response.fromStream(streamed);
//
//     final body = resp.body;
//     if (resp.statusCode >= 200 && resp.statusCode < 300) {
//       final Map<String, dynamic> data = jsonDecode(body);
//       final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
//       if (url == null || url.isEmpty) {
//         throw Exception('Cloudinary response missing secure_url for image upload');
//       }
//       return url;
//     }
//
//     // Include response body for debugging
//     throw Exception('Cloudinary image upload failed: ${resp.statusCode} $body');
//   }
//
//   @override
//   Future<String> uploadImageFile({
//     required File file,
//     String folder = 'profile_photos',
//   }) async {
//     if (!StorageConfig.kUseCloudinaryForMedia) {
//       final firebase = FirebaseStorageRepo();
//       return firebase.uploadImageFile(file: file, folder: folder);
//     }
//
//     final uri = Uri.parse('https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/image/upload');
//
//     final fileName = file.path.split(Platform.pathSeparator).last;
//     final baseName = fileName.contains('.') ? fileName.split('.').first : fileName;
//     final publicId = '$folder/$baseName';
//
//     final req = http.MultipartRequest('POST', uri)
//       ..fields['upload_preset'] = StorageConfig.uploadPresetImages
//       ..fields['folder'] = folder
//       ..fields['public_id'] = publicId
//       ..files.add(await http.MultipartFile.fromPath('file', file.path));
//
//     final streamed = await req.send();
//     final resp = await http.Response.fromStream(streamed);
//
//     final body = resp.body;
//     if (resp.statusCode >= 200 && resp.statusCode < 300) {
//       final Map<String, dynamic> data = jsonDecode(body);
//       final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
//       if (url == null || url.isEmpty) {
//         throw Exception('Cloudinary response missing secure_url for image file upload');
//       }
//       return url;
//     }
//
//     throw Exception('Cloudinary image file upload failed: ${resp.statusCode} $body');
//   }
// }


import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../../core/config/storage_config.dart';
import 'storage_repo.dart';
import 'firebase_storage_repo.dart';

class CloudinaryStorageRepo implements StorageRepo {
  const CloudinaryStorageRepo();

  // =========================================================================
  // EXISTING METHODS (Keep as is)
  // =========================================================================

  @override
  Future<String> uploadVoice({
    required String uid,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Voice file not found at $localPath');
    }

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/auto/upload');

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = StorageConfig.uploadPresetVoices
      ..fields['folder'] = StorageConfig.folderVoices
      ..fields['public_id'] = '${StorageConfig.folderVoices}/${uid}_intro'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          localPath,
          contentType: MediaType('audio', 'm4a'),
        ),
      );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final Map<String, dynamic> data = jsonDecode(resp.body);
      final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
      if (url == null || url.isEmpty) {
        throw Exception('Cloudinary response missing secure_url for voice upload');
      }
      return url;
    } else {
      throw Exception('Cloudinary voice upload failed: ${resp.statusCode} ${resp.body}');
    }
  }

  @override
  Future<void> deleteVoice({required String uid}) async {
    // Unsigned client cannot delete — server admin required.
    return;
  }

  @override
  Future<String> uploadBytes(
      Uint8List bytes, {
        String folder = 'profile_photos',
        String fileName = 'avatar.png',
      }) async {
    if (!StorageConfig.kUseCloudinaryForMedia) {
      final firebase = FirebaseStorageRepo();
      return firebase.uploadBytes(
        bytes,
        folder: folder,
        fileName: fileName,
      );
    }

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/image/upload');

    final baseName = fileName.contains('.') ? fileName.split('.').first : fileName;
    final publicId = '$folder/$baseName';

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = StorageConfig.uploadPresetImages
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType('image', 'png'),
        ),
      );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    final body = resp.body;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final Map<String, dynamic> data = jsonDecode(body);
      final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
      if (url == null || url.isEmpty) {
        throw Exception('Cloudinary response missing secure_url for image upload');
      }
      return url;
    }

    throw Exception('Cloudinary image upload failed: ${resp.statusCode} $body');
  }

  @override
  Future<String> uploadImageFile({
    required File file,
    String folder = 'profile_photos',
  }) async {
    if (!StorageConfig.kUseCloudinaryForMedia) {
      final firebase = FirebaseStorageRepo();
      return firebase.uploadImageFile(file: file, folder: folder);
    }

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/image/upload');

    final fileName = file.path.split(Platform.pathSeparator).last;
    final baseName = fileName.contains('.') ? fileName.split('.').first : fileName;
    final publicId = '$folder/$baseName';

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = StorageConfig.uploadPresetImages
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    final body = resp.body;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final Map<String, dynamic> data = jsonDecode(body);
      final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
      if (url == null || url.isEmpty) {
        throw Exception('Cloudinary response missing secure_url for image file upload');
      }
      return url;
    }

    throw Exception('Cloudinary image file upload failed: ${resp.statusCode} $body');
  }

  // =========================================================================
  // 🆕 NEW: CHAT MEDIA METHODS
  // =========================================================================

  @override
  Future<String> uploadChatImage({
    required String conversationId,
    required File file,
  }) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/image/upload');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final folder = 'chat_media/$conversationId';
    final publicId = '$folder/img_$timestamp';

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = StorageConfig.uploadPresetImages
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final Map<String, dynamic> data = jsonDecode(resp.body);
      final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
      if (url == null || url.isEmpty) {
        throw Exception('Cloudinary response missing secure_url');
      }
      return url;
    }

    throw Exception('Chat image upload failed: ${resp.statusCode} ${resp.body}');
  }

  @override
  Future<String> uploadChatAudio({
    required String conversationId,
    required String localPath,
    required int durationSeconds,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Audio file not found at $localPath');
    }

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/auto/upload');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final folder = 'chat_media/$conversationId';
    final publicId = '$folder/audio_$timestamp';

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = StorageConfig.uploadPresetVoices
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          localPath,
          contentType: MediaType('audio', 'm4a'),
        ),
      );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final Map<String, dynamic> data = jsonDecode(resp.body);
      final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
      if (url == null || url.isEmpty) {
        throw Exception('Cloudinary response missing secure_url');
      }
      return url;
    }

    throw Exception('Chat audio upload failed: ${resp.statusCode} ${resp.body}');
  }
}