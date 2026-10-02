// lib/core/config/storage_config.dart
class StorageConfig {
  /// Quickly switch providers later (only for audio intro).
  static const bool kUseCloudinaryForAudio = true; // <- set false to go Firebase

  /// ✅ NEW: Switch all media (images, avatars, profile pics)
  static const bool kUseCloudinaryForMedia = true; // <- set false to go Firebase

  // --- Cloudinary (unsigned) ---
  static const String cloudName = 'dekipip5j';

  // AUDIO
  static const String uploadPresetVoices = 'voices'; // your unsigned preset name
  static const String folderVoices = 'voices';       // optional folder

  // ✅ NEW: IMAGE upload presets & folder (can reuse same unsigned preset if needed)
  static const String uploadPresetImages = 'profile_image'; // change to your actual preset
  static const String folderImages = 'profile_image';
}
