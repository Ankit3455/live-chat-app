// lib/services/voice_intro_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/config/storage_config.dart';
import 'storage/storage_repo.dart';
import 'storage/firebase_storage_repo.dart';
import 'storage/cloudinary_storage_repo.dart'; // <-- ADD THIS

class VoiceIntroService {
  static const int kMaxSeconds = 20;
  static final AudioRecorder _recorder = AudioRecorder();

  static StorageRepo get _storage =>
      StorageConfig.kUseCloudinaryForAudio
          ? const CloudinaryStorageRepo()
          : FirebaseStorageRepo();

  static Future<bool> hasMicPermission() async {
    if (kIsWeb) return false;
    return await _recorder.hasPermission();
  }

  static Future<String?> startRecording() async {
    if (kIsWeb) return null;
    final ok = await _recorder.hasPermission();
    if (!ok) return null;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_intro_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    return path;
  }

  static Future<({String path, int seconds})?> stopRecording({
    required String tempPath,
  }) async {
    if (kIsWeb) return null;
    final path = await _recorder.stop();
    if (path == null) return null;
    final f = File(path);
    if (!f.existsSync()) return null;
    return (path: path, seconds: 0);
  }

  static Future<({String url, int seconds})?> uploadAndSave({
    required String localPath,
    required int durationSeconds,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    if (kIsWeb) return null;

    final url = await _storage.uploadVoice(uid: uid, localPath: localPath);

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'voiceIntroUrl': url,
      'voiceIntroDurationSeconds': durationSeconds,
    });

    return (url: url, seconds: durationSeconds);
  }

  static Future<void> deleteVoice() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _storage.deleteVoice(uid: uid);
    } catch (_) {
      // ignore, Cloudinary unsigned can't delete from client
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'voiceIntroUrl': null,
      'voiceIntroDurationSeconds': null,
    });
  }
}
