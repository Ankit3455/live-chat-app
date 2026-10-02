// // lib/feature/games/ludo/audio.dart
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/foundation.dart';
//
// class Audio {
//   static final AudioPlayer _player = AudioPlayer();
//
//   static Future<void> playMove() async {
//     try {
//       await _player.play(AssetSource('sounds/move.wav'));
//     } catch (e) {
//       debugPrint('❌ Audio playMove error: $e');
//     }
//   }
//
//   static Future<void> playKill() async {
//     try {
//       await _player.play(AssetSource('sounds/laugh.mp3'));
//     } catch (e) {
//       debugPrint('❌ Audio playKill error: $e');
//     }
//   }
//
//   static Future<void> rollDice() async {
//     try {
//       await _player.play(AssetSource('sounds/roll_the_dice.mp3'));
//     } catch (e) {
//       debugPrint('❌ Audio rollDice error: $e');
//     }
//   }
//
//   static void dispose() {
//     _player.dispose();
//   }
// }


// lib/feature/games/ludo/audio.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class Audio {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playMove() async {
    try {
      await _player.play(AssetSource('sounds/move.wav'));
    } catch (e) {
      debugPrint('❌ Audio playMove error: $e');
    }
  }

  static Future<void> playKill() async {
    try {
      await _player.play(AssetSource('sounds/laugh.mp3'));
    } catch (e) {
      debugPrint('❌ Audio playKill error: $e');
    }
  }

  static Future<void> rollDice() async {
    try {
      await _player.play(AssetSource('sounds/roll_the_dice.mp3'));
    } catch (e) {
      debugPrint('❌ Audio rollDice error: $e');
    }
  }

  // NEW: Win sound
  static Future<void> playWin() async {
    try {
      // Use laugh sound for win (or add new win.mp3 file)
      await _player.play(AssetSource('sounds/win.mp3'));
    } catch (e) {
      debugPrint('❌ Audio playWin error: $e');
    }
  }

  // NEW: Lose sound
  static Future<void> playLose() async {
    try {
      // Use existing sound or add new lose.mp3 file
      await _player.play(AssetSource('sounds/lose.mp3'));
    } catch (e) {
      debugPrint('❌ Audio playLose error: $e');
    }
  }

  static void dispose() {
    _player.dispose();
  }
}