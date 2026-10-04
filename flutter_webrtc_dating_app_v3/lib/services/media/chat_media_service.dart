// lib/services/media/chat_media_service.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/config/storage_config.dart';
import '../storage/storage_repo.dart';
import '../storage/cloudinary_storage_repo.dart';
import '../storage/firebase_storage_repo.dart';
import 'media_validator.dart';

class ChatMediaService {
  static final ImagePicker _imagePicker = ImagePicker();
  static final AudioRecorder _audioRecorder = AudioRecorder();

  // Storage repository
  static StorageRepo get _storage => StorageConfig.kUseCloudinaryForMedia
      ? const CloudinaryStorageRepo()
      : FirebaseStorageRepo();

  // =========================================================================
  // IMAGE METHODS
  // =========================================================================

  /// Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      debugPrint('❌ Error picking image from gallery: $e');
      return null;
    }
  }

  /// Capture image from camera
  static Future<File?> captureImageFromCamera() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      debugPrint('❌ Error capturing image: $e');
      return null;
    }
  }

  /// User-facing error if [file] cannot be sent as a chat image, else null.
  static Future<String?> validateChatImage(File file) =>
      MediaValidator.validateImageSource(file);

  /// User-facing error if the recording cannot be sent, else null.
  static Future<String?> validateVoiceMessage(
          String localPath, int durationSeconds) =>
      MediaValidator.validateVoice(File(localPath), durationSeconds);

  /// Compress image (to JPEG) before upload. Returns null on failure; the
  /// original is never uploaded uncompressed.
  static Future<File?> compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      debugPrint('❌ Error compressing image: $e');
      return null;
    }
  }

  /// Upload image to cloud storage
  static Future<String?> uploadChatImage({
    required String conversationId,
    required File file,
  }) async {
    File? compressed;
    try {
      final error = await MediaValidator.validateImageSource(file);
      if (error != null) throw MediaValidationException(error);

      compressed = await compressImage(file);
      if (compressed == null) return null;

      // Upload validates type/size of the compressed file.
      return await _storage.uploadChatImage(
        conversationId: conversationId,
        file: compressed,
      );
    } catch (e) {
      debugPrint('❌ Error uploading chat image: $e');
      return null;
    } finally {
      if (compressed != null && compressed.path != file.path) {
        try {
          await compressed.delete();
        } catch (_) {}
      }
    }
  }

  /// Get image file size
  static Future<int> getFileSize(File file) async {
    try {
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  // =========================================================================
  // AUDIO/VOICE MESSAGE METHODS
  // =========================================================================

  /// Recording cap; same as the upload limit (DEST-013: voice <= 2 min).
  static const int kMaxVoiceDuration = MediaValidator.maxVoiceSeconds;

  /// Check microphone permission
  static Future<bool> hasMicrophonePermission() async {
    if (kIsWeb) return false;
    return await _audioRecorder.hasPermission();
  }

  /// Start recording voice message
  static Future<String?> startVoiceRecording() async {
    if (kIsWeb) return null;

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return null;

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      return path;
    } catch (e) {
      debugPrint('❌ Error starting voice recording: $e');
      return null;
    }
  }

  /// Stop recording and return file path
  static Future<String?> stopVoiceRecording() async {
    try {
      final path = await _audioRecorder.stop();
      return path;
    } catch (e) {
      debugPrint('❌ Error stopping voice recording: $e');
      return null;
    }
  }

  /// Cancel recording
  static Future<void> cancelVoiceRecording() async {
    try {
      await _audioRecorder.cancel();
    } catch (e) {
      debugPrint('❌ Error canceling voice recording: $e');
    }
  }

  /// Check if currently recording
  static Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  /// Upload voice message to cloud storage
  static Future<String?> uploadVoiceMessage({
    required String conversationId,
    required String localPath,
    required int durationSeconds,
  }) async {
    try {
      final error = await validateVoiceMessage(localPath, durationSeconds);
      if (error != null) throw MediaValidationException(error);

      final url = await _storage.uploadChatAudio(
        conversationId: conversationId,
        localPath: localPath,
        durationSeconds: durationSeconds,
      );

      // Clean up temp file only after a successful upload.
      try {
        await File(localPath).delete();
      } catch (_) {}

      return url;
    } catch (e) {
      debugPrint('❌ Error uploading voice message: $e');
      return null;
    }
  }

  // =========================================================================
  // CLEANUP
  // =========================================================================

  static Future<void> dispose() async {
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.cancel();
      }
    } catch (_) {}
  }
}