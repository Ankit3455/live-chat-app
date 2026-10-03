// lib/services/media/media_validator.dart
import 'dart:io';

/// Client-side limits for uploaded media (images <= 10 MB jpg/png/webp,
/// voice <= 2 min). The server/preset must enforce the same limits.
class MediaValidator {
  MediaValidator._();

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxVoiceSeconds = 120;

  /// 2 min of 64 kbps AAC is ~1 MB; leave headroom for other encoders.
  static const int maxVoiceBytes = 5 * 1024 * 1024;

  static const Set<String> allowedImageMimes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Detects the image MIME type from magic bytes, or null if unsupported.
  static Future<String?> sniffImageMime(File file) async {
    final h = await _header(file, 12);
    if (h.length >= 3 && h[0] == 0xFF && h[1] == 0xD8 && h[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (h.length >= 8 &&
        h[0] == 0x89 &&
        h[1] == 0x50 &&
        h[2] == 0x4E &&
        h[3] == 0x47 &&
        h[4] == 0x0D &&
        h[5] == 0x0A &&
        h[6] == 0x1A &&
        h[7] == 0x0A) {
      return 'image/png';
    }
    if (h.length >= 12 &&
        String.fromCharCodes(h.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(h.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  /// True for HEIC/HEIF, which the picker may return on iOS; it is converted
  /// to JPEG before upload.
  static Future<bool> isHeic(File file) async {
    final h = await _header(file, 12);
    if (h.length < 12 || String.fromCharCodes(h.sublist(4, 8)) != 'ftyp') {
      return false;
    }
    final brand = String.fromCharCodes(h.sublist(8, 12));
    return const {'heic', 'heix', 'hevc', 'heim', 'heis', 'mif1', 'msf1'}
        .contains(brand);
  }

  /// Returns a user-facing error, or null if [file] may be picked for a chat
  /// image (before compression).
  static Future<String?> validateImageSource(File file) async {
    if (!await file.exists()) return 'Image not found';
    final size = await file.length();
    if (size == 0) return 'Image is empty';
    if (size > maxImageBytes) return 'Image is larger than 10 MB';
    if (await sniffImageMime(file) == null && !await isHeic(file)) {
      return 'Only JPG, PNG or WebP images are supported';
    }
    return null;
  }

  /// Returns a user-facing error, or null if [file] may be uploaded as-is.
  static Future<String?> validateImageUpload(File file) async {
    if (!await file.exists()) return 'Image not found';
    final size = await file.length();
    if (size == 0) return 'Image is empty';
    if (size > maxImageBytes) return 'Image is larger than 10 MB';
    if (await sniffImageMime(file) == null) {
      return 'Only JPG, PNG or WebP images are supported';
    }
    return null;
  }

  /// Returns a user-facing error, or null if the voice note may be uploaded.
  static Future<String?> validateVoice(File file, int durationSeconds) async {
    if (!await file.exists()) return 'Recording not found';
    if (durationSeconds < 1) return 'Recording is too short';
    if (durationSeconds > maxVoiceSeconds) {
      return 'Voice messages can be up to 2 minutes';
    }
    final size = await file.length();
    if (size == 0) return 'Recording is empty';
    if (size > maxVoiceBytes) return 'Recording is too large';
    // MP4/M4A container: 'ftyp' box at offset 4.
    final h = await _header(file, 8);
    if (h.length < 8 || String.fromCharCodes(h.sublist(4, 8)) != 'ftyp') {
      return 'Unsupported audio format';
    }
    return null;
  }

  static Future<List<int>> _header(File file, int length) async {
    final raf = await file.open();
    try {
      return await raf.read(length);
    } finally {
      await raf.close();
    }
  }
}

/// Thrown when a file fails [MediaValidator] checks; [message] is user-facing.
class MediaValidationException implements Exception {
  final String message;
  const MediaValidationException(this.message);

  @override
  String toString() => message;
}
