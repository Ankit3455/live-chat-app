// lib/core/utils/haptics.dart
//
// Single entry point for haptic feedback so the feel stays consistent.

import 'dart:async';

import 'package:flutter/services.dart';

class Haptics {
  Haptics._();

  /// Tab, chip, switch and other selection changes.
  static void selection() => unawaited(HapticFeedback.selectionClick());

  /// Light tap, e.g. sending a message.
  static void light() => unawaited(HapticFeedback.lightImpact());

  /// Medium tap, e.g. accepting a call.
  static void medium() => unawaited(HapticFeedback.mediumImpact());

  /// Something finished successfully.
  static void success() => unawaited(HapticFeedback.mediumImpact());

  /// Destructive or ending action (decline, end call, delete, block).
  static void warning() => unawaited(HapticFeedback.heavyImpact());

  /// An action failed.
  static void error() => unawaited(HapticFeedback.vibrate());
}
