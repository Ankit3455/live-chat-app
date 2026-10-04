// lib/feature/games/carrom/services/carrom_audio_service.dart
// STATUS: NEW FILE ✅

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

// Reuses the sounds already bundled under assets/sounds/ (declared in
// pubspec). Swap these paths if dedicated Carrom sounds are added.
const String _strikeSound = 'sounds/move.wav';
const String _pocketSound = 'sounds/move.wav';
const String _collisionSound = 'sounds/move.wav';
const String _victorySound = 'sounds/win.mp3';
const String _defeatSound = 'sounds/lose.mp3';
const String _foulSound = 'sounds/laugh.mp3';

class CarromAudioService {
  static final CarromAudioService _instance = CarromAudioService._internal();
  factory CarromAudioService() => _instance;
  CarromAudioService._internal();

  // Audio Players
  final AudioPlayer _strikePlayer = AudioPlayer();
  final AudioPlayer _pocketPlayer = AudioPlayer();
  final AudioPlayer _collisionPlayer = AudioPlayer();
  final AudioPlayer _victoryPlayer = AudioPlayer();
  final AudioPlayer _defeatPlayer = AudioPlayer();
  final AudioPlayer _foulPlayer = AudioPlayer();

  bool _isMuted = false;
  bool _isInitialized = false;

  bool get isMuted => _isMuted;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set release mode for short sounds
      await _strikePlayer.setReleaseMode(ReleaseMode.stop);
      await _pocketPlayer.setReleaseMode(ReleaseMode.stop);
      await _collisionPlayer.setReleaseMode(ReleaseMode.stop);
      await _foulPlayer.setReleaseMode(ReleaseMode.stop);

      _isInitialized = true;
    } catch (e) {
      debugPrint('Carrom audio init error: $e');
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  Future<void> playStrike() async {
    if (_isMuted) return;
    try {
      await _strikePlayer.stop();
      await _strikePlayer.play(
        AssetSource(_strikeSound),
        volume: 0.7,
      );
    } catch (e) {
      debugPrint('Carrom sound failed: $e');
    }
  }

  Future<void> playPocket() async {
    if (_isMuted) return;
    try {
      await _pocketPlayer.stop();
      await _pocketPlayer.play(
        AssetSource(_pocketSound),
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('Carrom sound failed: $e');
    }
  }

  Future<void> playCollision() async {
    if (_isMuted) return;
    try {
      await _collisionPlayer.stop();
      await _collisionPlayer.play(
        AssetSource(_collisionSound),
        volume: 0.4,
      );
    } catch (e) {
      debugPrint('Carrom sound failed: $e');
    }
  }

  Future<void> playVictory() async {
    if (_isMuted) return;
    try {
      await _victoryPlayer.stop();
      await _victoryPlayer.play(
        AssetSource(_victorySound),
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('Carrom sound failed: $e');
    }
  }

  Future<void> playDefeat() async {
    if (_isMuted) return;
    try {
      await _defeatPlayer.stop();
      await _defeatPlayer.play(
        AssetSource(_defeatSound),
        volume: 0.6,
      );
    } catch (e) {
      debugPrint('Carrom sound failed: $e');
    }
  }

  Future<void> playFoul() async {
    if (_isMuted) return;
    try {
      await _foulPlayer.stop();
      await _foulPlayer.play(
        AssetSource(_foulSound),
        volume: 0.7,
      );
    } catch (e) {
      debugPrint('Carrom sound failed: $e');
    }
  }

  void dispose() {
    _strikePlayer.dispose();
    _pocketPlayer.dispose();
    _collisionPlayer.dispose();
    _victoryPlayer.dispose();
    _defeatPlayer.dispose();
    _foulPlayer.dispose();
  }
}