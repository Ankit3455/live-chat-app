import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Ludo sound effects. A small round-robin pool lets overlapping sounds
/// (move steps, capture, dice) play without cutting each other off.
class Audio {
  static const int _poolSize = 4;
  static final List<AudioPlayer> _pool = [];
  static int _next = 0;

  static AudioPlayer _player() {
    if (_pool.isEmpty) {
      for (int i = 0; i < _poolSize; i++) {
        _pool.add(AudioPlayer());
      }
    }
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    return player;
  }

  static Future<void> _play(String asset) async {
    try {
      final player = _player();
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('❌ Audio error ($asset): $e');
    }
  }

  static Future<void> playMove() => _play('sounds/move.wav');

  static Future<void> playKill() => _play('sounds/laugh.mp3');

  static Future<void> rollDice() => _play('sounds/roll_the_dice.mp3');

  static Future<void> playWin() => _play('sounds/win.mp3');

  static Future<void> playLose() => _play('sounds/lose.mp3');

  /// Thumb War: a thumb slams onto the other one.
  static Future<void> playThumbHit() => _play('sounds/thumb_hit.wav');

  /// Thumb War: a thumb goes down to taunt.
  static Future<void> playThumbDown() => _play('sounds/thumb_down.wav');

  /// Thumb War: "FIGHT!".
  static Future<void> playGong() => _play('sounds/thumb_gong.wav');

  /// Thumb War: a round is knocked out.
  static Future<void> playKo() => _play('sounds/thumb_ko.wav');

  static void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    _pool.clear();
    _next = 0;
  }
}
