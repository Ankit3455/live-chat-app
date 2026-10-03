// import 'package:availchat/feature/games/ludo/widgets/pawn_widget.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../constants.dart';
// import '../ludo_player.dart';
// import '../ludo_provider.dart';
//
// ///Widget for the board
// class BoardWidget extends StatelessWidget {
//   const BoardWidget({super.key});
//
//   ///Return board size
//   double ludoBoard(BuildContext context) {
//     double width = MediaQuery.of(context).size.width;
//     if (width > 500) {
//       return 500;
//     } else {
//       if (width < 300) {
//         return 300;
//       } else {
//         return width - 20;
//       }
//     }
//   }
//
//   ///Count box size
//   double boxStepSize(BuildContext context) {
//     return ludoBoard(context) / 15;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(10),
//       clipBehavior: Clip.antiAlias,
//       width: ludoBoard(context),
//       height: ludoBoard(context),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(40),
//         image: const DecorationImage(
//           image: AssetImage("assets/images/board.png"),
//           fit: BoxFit.cover,
//           alignment: Alignment.topCenter,
//         ),
//       ),
//       child: Consumer<LudoProvider>(
//         builder: (context, value, child) {
//           //We use `Stack` to put all widgets on top of each other
//           //so we make some logic to change the order of players to make sure
//           //the player on top is the one who is playing
//           List<LudoPlayer> players = List.from(value.players);
//           Map<String, List<PawnWidget>> pawnsRaw = {};
//           Map<String, List<String>> pawnsToPrint = {};
//           List<Widget> playersPawn = [];
//
//           //Sort players by current turn to make sure the player on top is the one who is playing
//           players.sort((a, b) => value.currentPlayer.type == a.type ? 1 : -1);
//
//           ///Loop through all players and add their pawns to the map
//           for (int i = 0; i < players.length; i++) {
//             var player = players[i];
//             for (int j = 0; j < player.pawns.length; j++) {
//               var pawn = player.pawns[j];
//               if (pawn.step > -1) {
//                 String step = player.path[pawn.step].toString();
//                 if (pawnsRaw[step] == null) {
//                   pawnsRaw[step] = [];
//                   pawnsToPrint[step] = [];
//                 }
//                 pawnsRaw[step]!.add(pawn);
//                 pawnsToPrint[step]!.add(player.type.toString());
//               } else {
//                 if (pawnsRaw["home"] == null) {
//                   pawnsRaw["home"] = [];
//                   pawnsToPrint["home"] = [];
//                 }
//                 pawnsRaw["home"]!.add(pawn);
//                 pawnsToPrint["home"]!.add(player.type.toString());
//               }
//             }
//           }
//
//           for (int i = 0; i < pawnsRaw.keys.length; i++) {
//             String key = pawnsRaw.keys.elementAt(i);
//             List<PawnWidget> pawnsValue = pawnsRaw[key]!;
//
//             /// This is for every pawn in home
//             if (key == "home") {
//               playersPawn.addAll(
//                 pawnsValue.map((e) {
//                   var player = value.players.firstWhere((element) => element.type == e.type);
//                   return AnimatedPositioned(
//                     key: ValueKey("${e.type.name}_${e.index}"),
//                     left: LudoPath.stepBox(ludoBoard(context), player.homePath[e.index][0]),
//                     top: LudoPath.stepBox(ludoBoard(context), player.homePath[e.index][1]),
//                     width: boxStepSize(context),
//                     height: boxStepSize(context),
//                     duration: const Duration(milliseconds: 200),
//                     child: e,
//                   );
//                 }),
//               );
//             } else {
//               // This is for every pawn in path (not in home)
//               // I'm so lazy, so make it simple h3h3
//               List<double> coordinates = key.replaceAll("[", "").replaceAll("]", "").split(",").map((e) => double.parse(e.trim())).toList();
//
//               if (pawnsValue.length == 1) {
//                 // This is for 1 pawn in 1 box
//                 var e = pawnsValue.first;
//                 playersPawn.add(AnimatedPositioned(
//                   key: ValueKey("${e.type.name}_${e.index}"),
//                   duration: const Duration(milliseconds: 200),
//                   left: LudoPath.stepBox(ludoBoard(context), coordinates[0]),
//                   top: LudoPath.stepBox(ludoBoard(context), coordinates[1]),
//                   width: boxStepSize(context),
//                   height: boxStepSize(context),
//                   child: pawnsValue.first,
//                 ));
//               } else {
//                 // This is for more than 1 pawn in 1 box
//                 playersPawn.addAll(
//                   List.generate(
//                     pawnsValue.length,
//                         (index) {
//                       var e = pawnsValue[index];
//                       return AnimatedPositioned(
//                         key: ValueKey("${e.type.name}_${e.index}"),
//                         duration: const Duration(milliseconds: 200),
//                         left: LudoPath.stepBox(ludoBoard(context), coordinates[0]) + (index * 3),
//                         top: LudoPath.stepBox(ludoBoard(context), coordinates[1]),
//                         width: boxStepSize(context) - 5,
//                         height: boxStepSize(context),
//                         child: pawnsValue[index],
//                       );
//                     },
//                   ),
//                 );
//               }
//             }
//           }
//
//           return Center(
//             child: Stack(
//               fit: StackFit.expand,
//               alignment: Alignment.center,
//               children: [
//                 ...playersPawn,
//                 ...winners(context, value.winners),
//                 turnIndicator(context, value.currentPlayer.type, value.currentPlayer.color, value.gameState),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   ///This is for the turn indicator widget
//   Widget turnIndicator(BuildContext context, LudoPlayerType turn, Color color, LudoGameState stage) {
//     //0 is left, 1 is right
//     int x = 0;
//     //0 is top, 1 is bottom
//     int y = 0;
//
//     switch (turn) {
//       case LudoPlayerType.green:
//         x = 0;
//         y = 0;
//         break;
//       case LudoPlayerType.yellow:
//         x = 1;
//         y = 0;
//         break;
//       case LudoPlayerType.blue:
//         x = 1;
//         y = 1;
//         break;
//       case LudoPlayerType.red:
//         x = 0;
//         y = 1;
//         break;
//     }
//     String stageText = "Roll the dice";
//     switch (stage) {
//       case LudoGameState.throwDice:
//         stageText = "Roll the dice";
//         break;
//       case LudoGameState.moving:
//         stageText = "Pawn is moving...";
//         break;
//       case LudoGameState.pickPawn:
//         stageText = "Pick a pawn";
//         break;
//       case LudoGameState.finish:
//         stageText = "Game is over";
//         break;
//     }
//     return Positioned(
//       top: y == 0 ? 0 : null,
//       left: x == 0 ? 0 : null,
//       right: x == 1 ? 0 : null,
//       bottom: y == 1 ? 0 : null,
//       width: ludoBoard(context) * .4,
//       height: ludoBoard(context) * .4,
//       child: IgnorePointer(
//         child: Padding(
//           padding: EdgeInsets.all(boxStepSize(context)),
//           child: Container(
//               alignment: Alignment.center,
//               clipBehavior: Clip.antiAlias,
//               decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
//               child: RichText(
//                 textAlign: TextAlign.center,
//                 text: TextSpan(style: TextStyle(fontSize: 8, color: color), children: [
//                   const TextSpan(text: "Your turn!\n", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
//                   TextSpan(text: stageText, style: const TextStyle(color: Colors.black)),
//                 ]),
//               )),
//         ),
//       ),
//     );
//   }
//
//   ///This is for the winner widget
//   List<Widget> winners(BuildContext context, List<LudoPlayerType> winners) => List.generate(
//     winners.length,
//         (index) {
//       Widget crownImage = Image.asset("assets/games/ludo/crown/1st.png");
//
//       //0 is left, 1 is right
//       int x = 0;
//       //0 is top, 1 is bottom
//       int y = 0;
//
//       if (index == 0) {
//         crownImage = Image.asset("assets/images/crown/1st.png", fit: BoxFit.cover);
//       } else if (index == 1) {
//         crownImage = Image.asset("assets/images/crown/2nd.png", fit: BoxFit.cover);
//       } else if (index == 2) {
//         crownImage = Image.asset("assets/images/crown/3rd.png", fit: BoxFit.cover);
//       } else {
//         return Container();
//       }
//
//       switch (winners[index]) {
//         case LudoPlayerType.green:
//           x = 0;
//           y = 0;
//           break;
//         case LudoPlayerType.yellow:
//           x = 1;
//           y = 0;
//           break;
//         case LudoPlayerType.blue:
//           x = 1;
//           y = 1;
//           break;
//         case LudoPlayerType.red:
//           x = 0;
//           y = 1;
//           break;
//       }
//       return Positioned(
//         top: y == 0 ? 0 : null,
//         left: x == 0 ? 0 : null,
//         right: x == 1 ? 0 : null,
//         bottom: y == 1 ? 0 : null,
//         width: ludoBoard(context) * .4,
//         height: ludoBoard(context) * .4,
//         child: Padding(
//           padding: EdgeInsets.all(boxStepSize(context)),
//           child: Container(
//             clipBehavior: Clip.antiAlias,
//             decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
//             child: crownImage,
//           ),
//         ),
//       );
//     },
//   );
// }


// lib/feature/games/ludo/widgets/board_widget.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../ludo_player.dart';
import '../ludo_multiplayer_provider.dart';
import 'pawn_widget.dart';

class BoardWidget extends StatelessWidget {
  const BoardWidget({super.key});

  static const double _margin = 10;

  @override
  Widget build(BuildContext context) {
    // Fit the shorter side so the board never overflows short or
    // landscape screens.
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.of(context).size;
        final maxW = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : screen.width;
        final maxH = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : screen.height;
        final size = (min(maxW, maxH) - 2 * _margin).clamp(120.0, 500.0);
        return _buildBoard(size);
      },
    );
  }

  Widget _buildBoard(double board) {
    return Container(
      margin: const EdgeInsets.all(_margin),
      clipBehavior: Clip.antiAlias,
      width: board,
      height: board,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
        image: const DecorationImage(
          image: AssetImage("assets/images/board.png"),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: Consumer<LudoMultiplayerProvider>(
        builder: (context, provider, child) {
          return _buildPawnsStack(board, provider);
        },
      ),
    );
  }

  Widget _buildPawnsStack(double board, LudoMultiplayerProvider provider) {
    final cell = board / 15;
    final boardColors = provider.boardColors;
    final players = provider.players
        .where((p) => boardColors.contains(p.type.name))
        .toList();
    final currentTurn = provider.currentTurnType;

    // Current player's pawns drawn last (on top); otherwise keep board order.
    int rank(LudoPlayer p) =>
        (p.type == currentTurn ? 10 : 0) + p.type.index;
    final sortedPlayers = List<LudoPlayer>.from(players)
      ..sort((a, b) => rank(a).compareTo(rank(b)));

    Map<String, List<PawnWidget>> pawnsRaw = {};
    List<Widget> playersPawn = [];

    // Group pawns by position
    for (var player in sortedPlayers) {
      for (int j = 0; j < player.pawns.length; j++) {
        var pawn = player.pawns[j];
        if (pawn.step > -1 && pawn.step < player.path.length) {
          String step = player.path[pawn.step].toString();
          pawnsRaw.putIfAbsent(step, () => []);
          pawnsRaw[step]!.add(pawn);
        } else {
          pawnsRaw.putIfAbsent("home", () => []);
          pawnsRaw["home"]!.add(pawn);
        }
      }
    }

    // Build positioned pawns
    for (var key in pawnsRaw.keys) {
      List<PawnWidget> pawnsValue = pawnsRaw[key]!;

      if (key == "home") {
        // Pawns at home
        playersPawn.addAll(
          pawnsValue.map((e) {
            var player = players.firstWhere((p) => p.type == e.type);
            return AnimatedPositioned(
              key: ValueKey("${e.type.name}_${e.index}"),
              left: LudoPath.stepBox(board, player.homePath[e.index][0]),
              top: LudoPath.stepBox(board, player.homePath[e.index][1]),
              width: cell,
              height: cell,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: e,
            );
          }),
        );
      } else {
        // Pawns on board
        List<double> coordinates = key
            .replaceAll("[", "")
            .replaceAll("]", "")
            .split(",")
            .map((e) => double.parse(e.trim()))
            .toList();

        if (pawnsValue.length == 1) {
          var e = pawnsValue.first;
          playersPawn.add(AnimatedPositioned(
            key: ValueKey("${e.type.name}_${e.index}"),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: LudoPath.stepBox(board, coordinates[0]),
            top: LudoPath.stepBox(board, coordinates[1]),
            width: cell,
            height: cell,
            child: e,
          ));
        } else {
          // Multiple pawns on same position - stack them
          playersPawn.addAll(
            List.generate(pawnsValue.length, (index) {
              var e = pawnsValue[index];
              return AnimatedPositioned(
                key: ValueKey("${e.type.name}_${e.index}"),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: LudoPath.stepBox(board, coordinates[0]) + (index * 4),
                top: LudoPath.stepBox(board, coordinates[1]) - (index * 2),
                width: cell - 4,
                height: cell,
                child: e,
              );
            }),
          );
        }
      }
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        ...playersPawn,
        ..._buildWinners(board, provider.winners),
      ],
    );
  }

  List<Widget> _buildWinners(double board, List<LudoPlayerType> winners) {
    final cell = board / 15;
    return List.generate(winners.length, (index) {
      if (index > 2) return const SizedBox.shrink();

      Widget crownImage;
      if (index == 0) {
        crownImage = Image.asset("assets/images/crown/1st.png", fit: BoxFit.cover);
      } else if (index == 1) {
        crownImage = Image.asset("assets/images/crown/2nd.png", fit: BoxFit.cover);
      } else {
        crownImage = Image.asset("assets/images/crown/3rd.png", fit: BoxFit.cover);
      }

      int x = 0, y = 0;
      switch (winners[index]) {
        case LudoPlayerType.green:
          x = 0; y = 0;
          break;
        case LudoPlayerType.yellow:
          x = 1; y = 0;
          break;
        case LudoPlayerType.blue:
          x = 1; y = 1;
          break;
        case LudoPlayerType.red:
          x = 0; y = 1;
          break;
      }

      return Positioned(
        top: y == 0 ? 0 : null,
        left: x == 0 ? 0 : null,
        right: x == 1 ? 0 : null,
        bottom: y == 1 ? 0 : null,
        width: board * .4,
        height: board * .4,
        child: Padding(
          padding: EdgeInsets.all(cell),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
            child: crownImage,
          ),
        ),
      );
    });
  }
}