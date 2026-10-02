// import 'package:availchat/feature/games/ludo/widgets/board_widget.dart';
// import 'package:availchat/feature/games/ludo/widgets/dice_widget.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import 'ludo_provider.dart';
//
// class MainScreen extends StatefulWidget {
//   const MainScreen({super.key});
//
//   @override
//   State<MainScreen> createState() => _MainScreenState();
// }
//
// class _MainScreenState extends State<MainScreen> {
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         alignment: Alignment.center,
//         children: [
//           const Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               BoardWidget(),
//               Center(child: SizedBox(width: 50, height: 50, child: DiceWidget())),
//             ],
//           ),
//           Consumer<LudoProvider>(
//             builder: (context, value, child) => value.winners.length == 3
//                 ? Container(
//               color: Colors.black.withOpacity(0.8),
//               child: Center(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Image.asset("assets/images/thankyou.gif"),
//                     const Text("Thank you for playing 😙", style: TextStyle(color: Colors.white, fontSize: 20), textAlign: TextAlign.center),
//                     Text("The Winners is: ${value.winners.map((e) => e.name.toUpperCase()).join(", ")}", style: const TextStyle(color: Colors.white, fontSize: 30), textAlign: TextAlign.center),
//                     const Divider(color: Colors.white),
//                     const Text("This game made with Flutter ❤️ by Mochamad Nizwar Syafuan", style: TextStyle(color: Colors.white, fontSize: 15), textAlign: TextAlign.center),
//                     const SizedBox(height: 20),
//                     const Text("Refresh your browser to play again", style: TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
//                   ],
//                 ),
//               ),
//             )
//                 : const SizedBox.shrink(),
//           ),
//         ],
//       ),
//     );
//   }
// }


// lib/feature/games/ludo/main_screen.dart
// This file is no longer needed for online mode
// LudoWrapperScreen handles everything now
// You can delete this file or keep it empty

// If you want to keep it for any reason:
import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Use LudoWrapperScreen for online games'),
      ),
    );
  }
}