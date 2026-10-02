// lib/services/dicebear_avatar_service.dart
//
// FINAL WORKING VERSION
// - Downloads SVG from DiceBear
// - Converts to PNG before upload
// - Works with Cloudinary restrictions

import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

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

  /// Generate avatar from questionnaire answers
  static Future<Map<String, dynamic>> generateAndSaveAvatar({
    required Map<String, dynamic> answers,
  }) async {
    if (_inProgress) {
      debugPrint('⚠️ DiceBear: Generation already in progress');
      throw Exception('Avatar generation already in progress');
    }
    _inProgress = true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('❌ DiceBear: User not authenticated');
        throw Exception('User not authenticated');
      }

      debugPrint('🎨 DiceBear: Starting generation for user: $uid');

      final props = AvatarMapping.buildFromAnswers(answers);
      debugPrint('📋 Mapped properties: $props');

      _validateProperties(props);

      final seed = _buildSeed(props);
      debugPrint('🌱 Seed: $seed');

      final apiUrl = _buildApiUrl(seed);
      debugPrint('🔗 API URL: $apiUrl');

      // Download SVG
      final svgBytes = await _downloadSvgWithRetry(apiUrl);
      debugPrint('✅ Downloaded SVG: ${svgBytes.length} bytes');

      // ✅ Convert SVG to PNG
      final pngBytes = await _convertSvgToPng(svgBytes);
      debugPrint('✅ Converted to PNG: ${pngBytes.length} bytes');

      // Upload PNG (not SVG!)
      final uploadResult = await _uploadPngImage(
        uid: uid,
        pngBytes: pngBytes,
      );

      final imageUrl = uploadResult['imageUrl'] as String;

      debugPrint('🔗 Image URL: $imageUrl');

      // Save to Firestore
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
        'avatarProperties': avatarPropsToSave,
        'isCustomAvatar': false,
        'avatarVersion': FieldValue.increment(1),
      }, SetOptions(merge: true));

      debugPrint('💾 Saved to Firestore ✅');

      return {
        'uid': uid,
        'avatarImageUrl': imageUrl,
        'avatarProperties': avatarPropsToSave,
      };
    } catch (e, st) {
      debugPrint('❌ Generation failed: $e');
      debugPrint('Stack: $st');
      rethrow;
    } finally {
      _inProgress = false;
    }
  }

  /// Regenerate from stored properties
  static Future<Map<String, dynamic>> regenerateFromStoredProperties() async {
    if (_inProgress) {
      debugPrint('⚠️ DiceBear: Regeneration already in progress');
      throw Exception('Avatar generation already in progress');
    }
    _inProgress = true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      debugPrint('🔄 DiceBear: Regenerating for user: $uid');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        throw Exception('User document not found');
      }

      final data = doc.data() ?? {};
      var props = (data['avatarProperties'] as Map<String, dynamic>?) ?? {};

      props = _mergeWithUserDocFields(props, data);

      if (props.isEmpty) {
        throw Exception('No avatar data found');
      }

      _validateProperties(props);

      final seed = (props['avatarSeed'] as String?) ?? _buildSeed(props);
      debugPrint('🌱 Seed: $seed');

      final apiUrl = _buildApiUrl(seed);
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
      propsToSave['generatedAt'] = DateTime.now().toUtc().toIso8601String();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'profileImage': imageUrl,
        'avatarProperties': propsToSave,
        'isCustomAvatar': false,
        'avatarVersion': FieldValue.increment(1),
      }, SetOptions(merge: true));

      debugPrint('💾 Regenerated successfully ✅');

      return {
        'uid': uid,
        'avatarImageUrl': imageUrl,
        'avatarProperties': propsToSave,
      };
    } catch (e, st) {
      debugPrint('❌ Regeneration failed: $e');
      debugPrint('Stack: $st');
      rethrow;
    } finally {
      _inProgress = false;
    }
  }

  // ==================== PRIVATE HELPERS ====================

  /// Build DiceBear API URL (minimal params)
  static String _buildApiUrl(String seed) {
    const String style = 'avataaars';

    final Map<String, String> params = <String, String>{
      'seed': seed,
      'size': '400',

      // 👇 Avatar zoom + position
      'scale': '180',        // 140 se bhi bada – kam background, zyada face
      'translateY': '-10',   // thoda sa upar shift
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
        debugPrint('📥 Attempt $attempt/$maxRetries: Downloading...');

        final response = await http.get(Uri.parse(url)).timeout(_apiTimeout);

        debugPrint('📡 Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
            throw Exception('Downloaded SVG is empty');
          }
          debugPrint('✅ Download successful (${bytes.length} bytes)');
          return bytes;
        } else {
          debugPrint('❌ Response body: ${response.body}');
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        lastError = e;
        debugPrint('⚠️ Attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2);
          debugPrint('⏳ Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }
    }

    throw Exception('Failed after $maxRetries attempts: $lastError');
  }

  /// ✅ Convert SVG bytes to PNG bytes
  static Future<Uint8List> _convertSvgToPng(Uint8List svgBytes) async {
    try {
      debugPrint('🔄 Converting SVG to PNG...');

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
      debugPrint('✅ SVG converted to PNG: ${pngBytes.length} bytes');

      return pngBytes;
    } catch (e) {
      debugPrint('❌ SVG to PNG conversion failed: $e');
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

    debugPrint('📤 Uploading PNG to ${useCloudinary ? "Cloudinary" : "Firebase"}...');

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

    if (!merged.containsKey('dateOfBirth') && !merged.containsKey('dob')) {
      merged['dateOfBirth'] = userDoc['dateOfBirth'];
    }

    if (!merged.containsKey('bio') || merged['bio'] == null) {
      merged['bio'] = userDoc['bio'];
    }

    return merged;
  }

  /// Validate required properties
  static void _validateProperties(Map<String, dynamic> props) {
    if (!props.containsKey('gender') || props['gender'].toString().trim().isEmpty) {
      debugPrint('⚠️ Warning: Gender missing, using "other"');
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


