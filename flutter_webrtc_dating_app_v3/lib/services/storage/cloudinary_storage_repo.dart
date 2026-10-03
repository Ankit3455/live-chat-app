import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../../core/config/storage_config.dart';
import '../media/media_validator.dart';
import 'storage_repo.dart';
import 'firebase_storage_repo.dart';

class CloudinaryStorageRepo implements StorageRepo {
  const CloudinaryStorageRepo();

  static const Duration _uploadTimeout = Duration(seconds: 60);

  Uri _endpoint(String resourceType) => Uri.parse(
      'https://api.cloudinary.com/v1_1/${StorageConfig.cloudName}/$resourceType/upload');

  /// Uploads with a 60 s timeout per attempt and one retry on connection
  /// errors (not on timeout). [folder] and the bare [publicId] are sent
  /// separately so the path is not doubled.
  Future<String> _upload({
    required String resourceType,
    required String preset,
    required String folder,
    required String publicId,
    required Future<http.MultipartFile> Function() file,
    required String label,
  }) async {
    Future<String> attempt() async {
      final req = http.MultipartRequest('POST', _endpoint(resourceType))
        ..fields['upload_preset'] = preset
        ..fields['folder'] = folder
        ..fields['public_id'] = publicId
        ..files.add(await file());

      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(resp.body);
        final url = (data['secure_url'] as String?) ?? (data['url'] as String?);
        if (url == null || url.isEmpty) {
          throw Exception('Cloudinary response missing secure_url for $label');
        }
        return url;
      }
      throw Exception('$label failed: ${resp.statusCode} ${resp.body}');
    }

    try {
      return await attempt().timeout(_uploadTimeout);
    } on SocketException {
      return attempt().timeout(_uploadTimeout);
    } on http.ClientException {
      return attempt().timeout(_uploadTimeout);
    } on TimeoutException {
      throw Exception('$label timed out');
    }
  }

  static String _baseName(String fileName) =>
      fileName.contains('.') ? fileName.split('.').first : fileName;

  @override
  Future<String> uploadVoice({
    required String uid,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Voice file not found at $localPath');
    }

    return _upload(
      resourceType: 'auto',
      preset: StorageConfig.uploadPresetVoices,
      folder: StorageConfig.folderVoices,
      publicId: '${uid}_intro',
      label: 'Cloudinary voice upload',
      file: () => http.MultipartFile.fromPath(
        'file',
        localPath,
        contentType: MediaType('audio', 'm4a'),
      ),
    );
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

    if (bytes.length > MediaValidator.maxImageBytes) {
      throw const MediaValidationException('Image is larger than 10 MB');
    }

    return _upload(
      resourceType: 'image',
      preset: StorageConfig.uploadPresetImages,
      folder: folder,
      publicId: _baseName(fileName),
      label: 'Cloudinary image upload',
      file: () async => http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType('image', 'png'),
      ),
    );
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

    if (await file.length() > MediaValidator.maxImageBytes) {
      throw const MediaValidationException('Image is larger than 10 MB');
    }

    final fileName = file.path.split(Platform.pathSeparator).last;

    return _upload(
      resourceType: 'image',
      preset: StorageConfig.uploadPresetImages,
      folder: folder,
      publicId: _baseName(fileName),
      label: 'Cloudinary image file upload',
      file: () => http.MultipartFile.fromPath('file', file.path),
    );
  }

  // =========================================================================
  // CHAT MEDIA
  // =========================================================================

  @override
  Future<String> uploadChatImage({
    required String conversationId,
    required File file,
  }) async {
    final error = await MediaValidator.validateImageUpload(file);
    if (error != null) throw MediaValidationException(error);
    final mime = await MediaValidator.sniffImageMime(file);
    final subtype = mime!.split('/').last;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _upload(
      resourceType: 'image',
      preset: StorageConfig.uploadPresetImages,
      folder: 'chat_media/$conversationId',
      publicId: 'img_$timestamp',
      label: 'Chat image upload',
      file: () => http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType('image', subtype),
      ),
    );
  }

  @override
  Future<String> uploadChatAudio({
    required String conversationId,
    required String localPath,
    required int durationSeconds,
  }) async {
    final file = File(localPath);
    final error = await MediaValidator.validateVoice(file, durationSeconds);
    if (error != null) throw MediaValidationException(error);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _upload(
      resourceType: 'auto',
      preset: StorageConfig.uploadPresetVoices,
      folder: 'chat_media/$conversationId',
      publicId: 'audio_$timestamp',
      label: 'Chat audio upload',
      file: () => http.MultipartFile.fromPath(
        'file',
        localPath,
        contentType: MediaType('audio', 'm4a'),
      ),
    );
  }
}
