// lib/services/profile_photo_service.dart
//
// Profile photo actions used by My Profile's Change Avatar sheet:
// upload a custom photo, reset to the generated avatar, regenerate the avatar.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config/storage_config.dart';
import 'dicebear_avatar_service.dart';
import 'storage/cloudinary_storage_repo.dart';
import 'storage/firebase_storage_repo.dart';
import 'storage/storage_repo.dart';

class ProfilePhotoException implements Exception {
  final String message;
  const ProfilePhotoException(this.message);

  @override
  String toString() => message;
}

class ProfilePhotoService {
  ProfilePhotoService._();

  static const int maxPhotoBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  static StorageRepo get _storage => StorageConfig.kUseCloudinaryForMedia
      ? const CloudinaryStorageRepo()
      : FirebaseStorageRepo();

  static String _requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const ProfilePhotoException('Please sign in again.');
    }
    return uid;
  }

  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// Lets the user pick a gallery photo and sets it as profileImage.
  /// Returns the new URL, or null if the user cancelled.
  static Future<String?> pickAndUploadPhoto() async {
    final uid = _requireUid();

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final ext = picked.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      throw const ProfilePhotoException(
          'Please choose a JPG, PNG or WEBP image.');
    }
    final file = File(picked.path);
    if (await file.length() > maxPhotoBytes) {
      throw const ProfilePhotoException('Image must be 10 MB or smaller.');
    }

    final url = await _storage.uploadImageFile(
      folder: 'profile_photos',
      file: file,
    );

    await _userDoc(uid).update({
      'profileImage': url,
      'isCustomAvatar': true,
      'avatarVersion': FieldValue.increment(1),
    });
    return url;
  }

  /// Restores the generated avatar as profileImage. If no generated avatar
  /// URL is stored, the avatar is regenerated from stored properties.
  /// Never writes an empty/null profileImage.
  static Future<String> resetToAvatar() async {
    final uid = _requireUid();

    final doc = await _userDoc(uid).get();
    final data = doc.data() ?? const <String, dynamic>{};
    final props = data['avatarProperties'] is Map
        ? Map<String, dynamic>.from(data['avatarProperties'] as Map)
        : const <String, dynamic>{};
    final avatarUrl = (props['avatarImageUrl'] as String?)?.trim() ?? '';

    if (avatarUrl.isEmpty) {
      final result =
          await DiceBearAvatarService.regenerateFromStoredProperties();
      return result['avatarImageUrl'] as String;
    }

    await _userDoc(uid).update({
      'profileImage': avatarUrl,
      'isCustomAvatar': false,
      'avatarVersion': FieldValue.increment(1),
    });
    return avatarUrl;
  }

  /// Generates a new avatar variation from the user's answers and sets it
  /// as profileImage.
  static Future<String> regenerateAvatar() async {
    _requireUid();
    final result = await DiceBearAvatarService.regenerateFromStoredProperties(
      newVariation: true,
    );
    return result['avatarImageUrl'] as String;
  }
}
