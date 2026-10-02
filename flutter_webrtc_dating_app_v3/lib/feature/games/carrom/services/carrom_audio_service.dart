// lib/feature/games/carrom/services/carrom_audio_service.dart
// STATUS: NEW FILE ✅

import 'package:audioplayers/audioplayers.dart';

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
      print('Audio init error: $e');
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
        AssetSource('games/carrom/audio/strike.mp3'),
        volume: 0.7,
      );
    } catch (e) {
      // Silently fail if audio not available
    }
  }

  Future<void> playPocket() async {
    if (_isMuted) return;
    try {
      await _pocketPlayer.stop();
      await _pocketPlayer.play(
        AssetSource('games/carrom/audio/pocket.mp3'),
        volume: 0.8,
      );
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> playCollision() async {
    if (_isMuted) return;
    try {
      await _collisionPlayer.stop();
      await _collisionPlayer.play(
        AssetSource('games/carrom/audio/collision.mp3'),
        volume: 0.4,
      );
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> playVictory() async {
    if (_isMuted) return;
    try {
      await _victoryPlayer.stop();
      await _victoryPlayer.play(
        AssetSource('games/carrom/audio/victory.mp3'),
        volume: 0.8,
      );
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> playDefeat() async {
    if (_isMuted) return;
    try {
      await _defeatPlayer.stop();
      await _defeatPlayer.play(
        AssetSource('games/carrom/audio/defeat.mp3'),
        volume: 0.6,
      );
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> playFoul() async {
    if (_isMuted) return;
    try {
      await _foulPlayer.stop();
      await _foulPlayer.play(
        AssetSource('games/carrom/audio/foul.mp3'),
        volume: 0.7,
      );
    } catch (e) {
      // Silently fail
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