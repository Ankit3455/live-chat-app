// lib/services/dicebear_avatar_service.dart
//
// Downloads a DiceBear avataaars SVG built from explicit params
// (AvatarMapping.dicebearParams), converts it to PNG and uploads it.

import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

import '../core/config/storage_config.dart';
import 'storage/cloudinary_storage_repo.dart';
import 'storage/firebase_storage_repo.dart';
import 'avatar_mapping.dart';

class DiceBearAvatarService {
  DiceBearAvatarService._();

  static bool _inProgress = false;

  static const String _apiVersion = '7.x';
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

      final props = AvatarMapping.buildFromAnswers(answers);

      _validateProperties(props);

      final seed = _buildSeed(props);

      final apiUrl = _buildApiUrl(seed, props);

      final svgBytes = await _downloadSvgWithRetry(apiUrl);

      final pngBytes = await _convertSvgToPng(svgBytes);

      final uploadResult = await _uploadPngImage(
        uid: uid,
        pngBytes: pngBytes,
      );

      final imageUrl = uploadResult['imageUrl'] as String;

      final avatarPropsToSave = <String, dynamic>{
        ...props,
        'avatarSeed': seed,
        'avatarImageUrl': imageUrl,
        'avatarStyle': 'avataaars',
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'generatedBy': 'dicebear-v7',
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'profileImage': imageUrl,
        'avatarProperties': _withLegacyKeysRemoved(avatarPropsToSave),
        'isCustomAvatar': false,
        'avatarVersion': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _log('DiceBear: avatar saved');

      return {
        'uid': uid,
        'avatarImageUrl': imageUrl,
        'avatarProperties': avatarPropsToSave,
      };
    } catch (e, st) {
      _log('DiceBear: generation failed: $e\n$st');
      rethrow;
    } finally {
      _inProgress = false;
    }
  }

  /// Regenerate from stored properties. With [newVariation] a fresh seed is
  /// used so the user gets a different avatar within the same constraints;
  /// otherwise the stored seed reproduces the same avatar.
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

      final storedSeed = stored['avatarSeed'] as String?;
      final baseSeed = (storedSeed != null && storedSeed.isNotEmpty)
          ? storedSeed
          : _buildSeed(props);
      final seed = newVariation
          ? '${_buildSeed(props)}_${Random().nextInt(1000000000)}'
          : baseSeed;

      final apiUrl = _buildApiUrl(seed, props);
      final svgBytes = await _downloadSvgWithRetry(apiUrl);
      final pngBytes = await _convertSvgToPng(svgBytes);

      final uploadResult = await _uploadPngImage(
        uid: uid,
        pngBytes: pngBytes,
      );

      final imageUrl = uploadResult['imageUrl'] as String;

      final propsToSave = Map<String, dynamic>.from(props);
      propsToSave['avatarSeed'] = seed;
      propsToSave['avatarImageUrl'] = imageUrl;
      propsToSave['avatarStyle'] = 'avataaars';
      propsToSave['generatedAt'] = DateTime.now().toUtc().toIso8601String();
      propsToSave['generatedBy'] = 'dicebear-v7';

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'profileImage': imageUrl,
        'avatarProperties': _withLegacyKeysRemoved(propsToSave),
        'isCustomAvatar': false,
        'avatarVersion': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _log('DiceBear: regenerated');

      return {
        'uid': uid,
        'avatarImageUrl': imageUrl,
        'avatarProperties': propsToSave,
      };
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

  /// Build DiceBear API URL: seed for stable randomness plus explicit
  /// avataaars params mapped from the answers.
  static String _buildApiUrl(String seed, Map<String, dynamic> props) {
    const String style = 'avataaars';

    final Map<String, String> params = <String, String>{
      'seed': seed,
      'size': '400',
      // Zoom in on the face and shift up slightly.
      'scale': '180',
      'translateY': '-10',
      ...AvatarMapping.dicebearParams(props),
    };

    final uri = Uri.parse('$_baseUrl/$style/svg');
    return uri.replace(queryParameters: params).toString();
  }


  /// Download SVG with retry logic
  static Future<Uint8List> _downloadSvgWithRetry(
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
            throw Exception('Downloaded SVG is empty');
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

  /// ✅ Convert SVG bytes to PNG bytes
  static Future<Uint8List> _convertSvgToPng(Uint8List svgBytes) async {
    try {
      // Decode SVG string
      final svgString = String.fromCharCodes(svgBytes);

      // Parse SVG
      final pictureInfo = await vg.loadPicture(
        SvgStringLoader(svgString),
        null,
      );

      // Convert to image
      final image = await pictureInfo.picture.toImage(400, 400);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      final pngBytes = byteData.buffer.asUint8List();
      return pngBytes;
    } catch (e) {
      _log('DiceBear: SVG to PNG conversion failed: $e');
      rethrow;
    }
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

    return merged;
  }

  /// Validate required properties
  static void _validateProperties(Map<String, dynamic> props) {
    if (!props.containsKey('gender') || props['gender'].toString().trim().isEmpty) {
      props['gender'] = 'other';
    }
  }

  /// Build deterministic seed
  static String _buildSeed(Map<String, dynamic> props) {
    final gender = _normalizeGender(props['gender']);

    final username = (props['username'] ?? props['userName'] ?? 'user')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');

    final habit = (props['habit'] ?? props['habits'] ?? 'balanced')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');

    final interests = (props['interests'] is List)
        ? List<String>.from((props['interests'] as List).map((e) => e.toString().toLowerCase()))
        : <String>[];
    interests.sort();

    String ageTag = '';
    if (props.containsKey('dateOfBirth') || props.containsKey('dob')) {
      DateTime? dob;
      final raw = props['dateOfBirth'] ?? props['dob'];
      try {
        if (raw is DateTime) {
          dob = raw;
        } else if (raw is Timestamp) {
          dob = (raw as Timestamp).toDate();
        } else if (raw is String) {
          dob = DateTime.tryParse(raw);
        } else if (raw is int) {
          dob = raw > 1000000000000
              ? DateTime.fromMillisecondsSinceEpoch(raw)
              : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
        }
      } catch (_) {}

      if (dob != null) {
        final now = DateTime.now();
        final age = now.year - dob.year -
            ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
        final ageGroup = (age <= 20) ? 'teen' : (age <= 35) ? 'young' : 'adult';
        ageTag = '_$ageGroup';
      }
    }

    final genderPrefix = gender == 'male'
        ? 'MALE'
        : (gender == 'female' ? 'FEMALE' : 'NEUTRAL');

    final parts = <String>[
      genderPrefix,
      username,
      habit,
      if (interests.isNotEmpty) interests.join('_'),
    ];

    return parts.join('_') + ageTag;
  }

  /// Normalize gender
  static String _normalizeGender(dynamic gender) {
    if (gender == null) return 'other';
    final g = gender.toString().trim().toLowerCase();
    if (g.isEmpty) return 'other';
    if (g == 'male' || g == 'man') return 'male';
    if (g == 'female' || g == 'woman') return 'female';
    return 'other';
  }
}


