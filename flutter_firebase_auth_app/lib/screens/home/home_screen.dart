import 'package:flutter/material.dart';
import 'home_ui.dart';

/// Entry point for Home Screen
/// Just a wrapper that delegates to HomeUI
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const HomeUI();
  }
}