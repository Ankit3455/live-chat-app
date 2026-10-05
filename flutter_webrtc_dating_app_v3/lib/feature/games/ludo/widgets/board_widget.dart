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
        final screen = MediaQuery.sizeOf(context);
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