// lib/services/media/media_url_policy.dart
import 'package:firebase_core/firebase_core.dart';

import '../../core/config/storage_config.dart';

/// Hosts chat media may be loaded from (DEST-047): our Cloudinary cloud and
/// our Firebase Storage bucket. Mirrors the mediaUrl check in firestore.rules,
/// so a client-supplied URL elsewhere is never fetched by the receiver.
class MediaUrlPolicy {
  MediaUrlPolicy._();

  static const String _cloudinaryHost = 'res.cloudinary.com';
  static const String _storageHost = 'firebasestorage.googleapis.com';

  static String? _bucketBase;

  /// Project bucket name without its domain suffix, e.g. "availchatproject".
  static String? get _projectBucketBase {
    if (_bucketBase != null) return _bucketBase;
    try {
      final bucket = Firebase.app().options.storageBucket;
      if (bucket == null || bucket.isEmpty) return null;
      return _bucketBase = bucket.replaceFirst(
        RegExp(r'\.(firebasestorage\.app|appspot\.com)$'),
        '',
      );
    } catch (_) {
      return null;
    }
  }

  static bool isAllowed(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.hasPort) return false;
    final segments = uri.pathSegments;

    if (uri.host == _cloudinaryHost) {
      return segments.isNotEmpty && segments.first == StorageConfig.cloudName;
    }

    if (uri.host == _storageHost) {
      // /v0/b/<bucket>/o/<object>
      final base = _projectBucketBase;
      if (base == null ||
          segments.length < 4 ||
          segments[0] != 'v0' ||
          segments[1] != 'b' ||
          segments[3] != 'o') {
        return false;
      }
      final bucket = segments[2];
      return bucket == '$base.firebasestorage.app' ||
          bucket == '$base.appspot.com';
    }
    return false;
  }
}
