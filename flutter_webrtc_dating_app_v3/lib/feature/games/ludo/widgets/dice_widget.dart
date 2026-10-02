// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:simple_ripple_animation/simple_ripple_animation.dart';
//
// import '../constants.dart';
// import '../ludo_multiplayer_provider.dart';
// import '../ludo_provider.dart';
//
// ///Widget for the dice
// class DiceWidget extends StatelessWidget {
//   const DiceWidget({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<LudoProvider>(
//       builder: (context, value, child) => RippleAnimation(
//         color: value.gameState == LudoGameState.throwDice ? value.currentPlayer.color : Colors.white.withOpacity(0),
//         ripplesCount: 3,
//         minRadius: 30,
//         repeat: true,
//         child: CupertinoButton(
//             onPressed: () {
//               LudoMultiplayerProvider? mp;
//               try {
//                 mp = Provider.of<LudoMultiplayerProvider?>(context, listen: false);
//               } catch (_) {
//                 mp = null;
//               }
//               if (mp != null) {
//                 if (!mp.isLocalPlayerTurn) return;
//                 mp.throwDice();
//                 return;
//               }
//               // fallback
//               final local = Provider.of<LudoProvider>(context, listen: false);
//               local.throwDice();
//             },
//           padding: const EdgeInsets.only(),
//           child: value.diceStarted ? Image.asset("assets/images/dice/draw.gif", fit: BoxFit.contain) : Image.asset("assets/images/dice/${value.diceResult}.png", fit: BoxFit.contain),
//         ),
//       ),
//     );
//   }
// }


// lib/feature/games/ludo/widgets/dice_widget.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';

import '../constants.dart';
import '../ludo_multiplayer_provider.dart';

class DiceWidget extends StatelessWidget {
  const DiceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LudoMultiplayerProvider>(
      builder: (context, provider, child) {
        final canThrow = provider.isLocalPlayerTurn &&
            provider.gameState == LudoGameState.throwDice &&
            !provider.diceStarted;

        final diceColor = provider.currentPlayer.color;

        return GestureDetector(
          onTap: canThrow ? () => provider.throwDice() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: canThrow
                  ? [
                BoxShadow(
                  color: diceColor.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple animation when can throw
                if (canThrow)
                  RippleAnimation(
                    color: diceColor,
                    ripplesCount: 3,
                    minRadius: 25,
                    repeat: true,
                    child: const SizedBox.shrink(),
                  ),

                // Dice image
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: canThrow ? 1.0 : 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: canThrow
                          ? Border.all(color: diceColor, width: 2)
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: provider.diceStarted
                          ? Image.asset(
                        "assets/images/dice/draw.gif",
                        fit: BoxFit.contain,
                      )
                          : Image.asset(
                        "assets/images/dice/${provider.diceResult}.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}