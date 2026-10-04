// lib/services/dicebear_avatar_service.dart
//
// Downloads a DiceBear avataaars PNG built from explicit params
// (AvatarMapping.dicebearParams) and uploads it. DiceBear renders the PNG
// server-side, so there is no client SVG conversion (flutter_svg does not
// draw avataaars' masks reliably).

import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/config/storage_config.dart';
import 'storage/cloudinary_storage_repo.dart';
import 'storage/firebase_storage_repo.dart';
import 'avatar_mapping.dart';

class DiceBearAvatarService {
  DiceBearAvatarService._();

  static bool _inProgress = false;

  static const String _apiVersion = '9.x';
  static const String _baseUrl = 'https://api.dicebear.com/$_apiVersion';
  static const Duration _apiTimeout = Duration(seconds: 15);

  // Debug-only logging; never log uid, answers, seed or URLs (PII).
  static void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// Generate avatar from questionnaire answers
  static Future<Map<String, dynamic>> generateAndSaveAvatar({
    required Map<String, dynamic> answers,
  }) async {
    if (_inProgress) {
      _log('DiceBear: generation already in progress');
      throw Exception('Avatar generation already in progress');
    }
    _inProgress = true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _log('DiceBear: user not authenticated');
        throw Exception('User not authenticated');
      }

      _log('DiceBear: starting generation');

      // Questionnaire answers don't include the DOB (written at signup), so
      // fill missing fields from the user doc before mapping.
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final merged = _mergeWithUserDocFields(
        Map<String, dynamic>.from(answers),
        data,
      );
      final props = AvatarMapping.buildFromAnswers(merged);
      _validateProperties(props);

      final stored = data['avatarProperties'] is Map
          ? Map<String, dynamic>.from(data['avatarProperties'] as Map)
          : const <String, dynamic>{};

      return await _createAvatar(
        uid: uid,
        props: props,
        startVariant: 0,
        previousFingerprint: stored['avatarFingerprint'] as String?,
      );
    } catch (e, st) {
      _log('DiceBear: generation failed: $e\n$st');
      rethrow;
    } finally {
      _inProgress = false;
    }
  }

  /// Regenerate from stored properties. With [newVariation] the next
  /// variant is used so the user gets a different (still unique) avatar
  /// within the same answer-based constraints; otherwise the stored variant
  /// reproduces the same avatar with the current mapping.
  static Future<Map<String, dynamic>> regenerateFromStoredProperties({
    bool newVariation = false,
  }) async {
    if (_inProgress) {
      _log('DiceBear: generation already in progress');
      throw Exception('Avatar generation already in progress');
    }
    _inProgress = true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      _log('DiceBear: regenerating');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        throw Exception('User document not found');
      }

      final data = doc.data() ?? {};
      final stored = data['avatarProperties'] is Map
          ? Map<String, dynamic>.from(data['avatarProperties'] as Map)
          : <String, dynamic>{};

      final merged = _mergeWithUserDocFields(stored, data);

      // Re-run the mapping so older docs get the current props shape.
      final props = AvatarMapping.buildFromAnswers(merged);
      _validateProperties(props);

      final storedVariant = (stored['avatarVariant'] as num?)?.toInt() ?? 0;

      return await _createAvatar(
        uid: uid,
        props: props,
        startVariant: newVariation ? storedVariant + 1 : storedVariant,
        previousFingerprint: stored['avatarFingerprint'] as String?,
      );
    } catch (e, st) {
      _log('DiceBear: regeneration failed: $e\n$st');
      rethrow;
    } finally {
      _inProgress = false;
    }
  }

  // ==================== PRIVATE HELPERS ====================

  /// Older avatarProperties stored exact DOB and bio; a merge write keeps
  /// nested keys, so delete them explicitly.
  static Map<String, dynamic> _withLegacyKeysRemoved(
    Map<String, dynamic> props,
  ) {
    return <String, dynamic>{
      ...props,
      'dateOfBirth': FieldValue.delete(),
      'dob': FieldValue.delete(),
      'bio': FieldValue.delete(),
      'avatarPngUrl': FieldValue.delete(),
    };
  }

  /// Picks a unique face for [uid], renders, uploads and saves it.
  static Future<Map<String, dynamic>> _createAvatar({
    required String uid,
    required Map<String, dynamic> props,
    required int startVariant,
    String? previousFingerprint,
  }) async {
    final choice = await _claimUniqueFace(uid, props, startVariant);
    final params = choice.params;
    final fingerprint = choice.fingerprint;

    final pngBytes = await _downloadWithRetry(_buildApiUrl(uid, params));
    final uploadResult = await _uploadPngImage(uid: uid, pngBytes: pngBytes);
    final imageUrl = uploadResult['imageUrl'] as String;

    final propsToSave = <String, dynamic>{
      ...props,
      'avatarVariant': choice.variant,
      'avatarFingerprint': fingerprint,
      'avatarParams': params,
      'avatarImageUrl': imageUrl,
      'avatarStyle': 'avataaars',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'generatedBy': 'dicebear-v9',
    };

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'profileImage': imageUrl,
      'avatarProperties': _withLegacyKeysRemoved(propsToSave),
      'isCustomAvatar': false,
      'avatarVersion': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (previousFingerprint != null &&
        previousFingerprint.isNotEmpty &&
        previousFingerprint != fingerprint) {
      await _releaseFingerprint(uid, previousFingerprint);
    }

    _log('DiceBear: avatar saved');
    return {
      'uid': uid,
      'avatarImageUrl': imageUrl,
      'avatarProperties': propsToSave,
    };
  }

  static const int _maxVariantTries = 40;

  /// Tries variants from [startVariant] until one whose face fingerprint is
  /// free (or already ours) is claimed in avatar_fingerprints. If the
  /// registry can't be reached the first variant is used, so a missing
  /// network or undeployed rule never blocks avatar creation.
  static Future<({Map<String, String> params, String fingerprint, int variant})>
      _claimUniqueFace(
    String uid,
    Map<String, dynamic> props,
    int startVariant,
  ) async {
    final registry =
        FirebaseFirestore.instance.collection('avatar_fingerprints');

    for (var v = startVariant; v < startVariant + _maxVariantTries; v++) {
      final r = AvatarMapping.resolve(props, uniqueKey: uid, variant: v);
      try {
        final claimed = await FirebaseFirestore.instance
            .runTransaction<bool>((tx) async {
          final ref = registry.doc(r.fingerprint);
          final snap = await tx.get(ref);
          if (snap.exists) return snap.data()?['uid'] == uid;
          tx.set(ref, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
          return true;
        });
        if (claimed) {
          return (params: r.params, fingerprint: r.fingerprint, variant: v);
        }
        _log('DiceBear: face taken, trying next variant');
      } catch (e) {
        _log('DiceBear: uniqueness registry unavailable: $e');
        return (params: r.params, fingerprint: r.fingerprint, variant: v);
      }
    }

    // Every tried variant was taken (practically impossible); fall back.
    final r = AvatarMapping.resolve(props,
        uniqueKey: uid, variant: startVariant + _maxVariantTries);
    return (
      params: r.params,
      fingerprint: r.fingerprint,
      variant: startVariant + _maxVariantTries,
    );
  }

  static Future<void> _releaseFingerprint(String uid, String fingerprint) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('avatar_fingerprints')
          .doc(fingerprint);
      await FirebaseFirestore.instance.runTransaction<void>((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists && snap.data()?['uid'] == uid) tx.delete(ref);
      });
    } catch (e) {
      _log('DiceBear: could not release old fingerprint: $e');
    }
  }

  /// DiceBear URL with one explicit value per part (from
  /// AvatarMapping.resolve), so the server adds no randomness of its own.
  static String _buildApiUrl(String uid, Map<String, String> params) {
    const String style = 'avataaars';

    // 256 is DiceBear's PNG maximum. No zoom: scaling crops long hair.
    final query = <String, String>{
      'seed': uid,
      'size': '256',
      ...params,
    };

    final uri = Uri.parse('$_baseUrl/$style/png');
    return uri.replace(queryParameters: query).toString();
  }

  /// Download the avatar PNG with retry logic
  static Future<Uint8List> _downloadWithRetry(
      String url, {
        int maxRetries = 3,
      }) async {
    var lastError;

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(_apiTimeout);

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
            throw Exception('Downloaded avatar is empty');
          }
          return bytes;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        lastError = e;
        _log('DiceBear: download attempt $attempt/$maxRetries failed: $e');

        if (attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2);
          await Future.delayed(delay);
        }
      }
    }

    throw Exception('Failed after $maxRetries attempts: $lastError');
  }

  /// Upload PNG image (not SVG!)
  static Future<Map<String, String>> _uploadPngImage({
    required String uid,
    required Uint8List pngBytes,
  }) async {
    final fileName = '${uid}_avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final useCloudinary = StorageConfig.kUseCloudinaryForMedia;

    if (useCloudinary) {
      final repo = const CloudinaryStorageRepo();
      final imageUrl = await repo.uploadBytes(
        pngBytes,
        folder: StorageConfig.folderImages.isNotEmpty
            ? StorageConfig.folderImages
            : 'avatars',
        fileName: fileName,
      );

      return {'imageUrl': imageUrl};
    } else {
      final repo = FirebaseStorageRepo();
      final imageUrl = await repo.uploadBytes(
        pngBytes,
        folder: 'avatars',
        fileName: fileName,
      );

      return {'imageUrl': imageUrl};
    }
  }

  /// Merge avatarProperties with top-level fields (fallback)
  static Map<String, dynamic> _mergeWithUserDocFields(
      Map<String, dynamic> props,
      Map<String, dynamic> userDoc,
      ) {
    final merged = Map<String, dynamic>.from(props);

    if (!merged.containsKey('gender') || merged['gender'] == null) {
      merged['gender'] = userDoc['gender'];
    }

    if (!merged.containsKey('username') || merged['username'] == null) {
      merged['username'] = userDoc['username'];
    }

    if (!merged.containsKey('habits') && !merged.containsKey('habit')) {
      merged['habits'] = userDoc['habits'];
    }

    if (!merged.containsKey('interests') ||
        (merged['interests'] is List && (merged['interests'] as List).isEmpty)) {
      merged['interests'] = userDoc['interests'];
    }

    if (merged['dateOfBirth'] == null && merged['dob'] == null) {
      merged['dateOfBirth'] = userDoc['dateOfBirth'] ?? userDoc['dob'];
    }

    if (merged['profession'] == null) {
      merged['profession'] = userDoc['profession'];
    }

    // Post-signup answers that shape the avatar (see AvatarMapping).
    for (final key in const [
      'personalityType',
      'exerciseFrequency',
      'partyingFrequency',
      'musicGenres',
      'zodiacSign',
      'sunSign',
    ]) {
      merged[key] ??= userDoc[key];
    }

    return merged;
  }

  /// Validate required properties
  static void _validateProperties(Map<String, dynamic> props) {
    if (!props.containsKey('gender') || props['gender'].toString().trim().isEmpty) {
      props['gender'] = 'other';
    }
  }
}
