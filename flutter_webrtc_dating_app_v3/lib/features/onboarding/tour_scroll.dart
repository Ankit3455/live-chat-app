import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Scrolls a tour step's target into view before its spotlight shows (the
/// coach mark measures the target only after this), in every scrollable
/// around it: up/down and left/right. Vertically the target goes near the
/// top when the tooltip sits below it, near the bottom when the tooltip
/// sits above, otherwise to the middle; sideways it is centred.
Future<void> revealTourTarget(TargetFocus target) async {
  final context = target.keyTarget?.currentContext;
  final targetObject = context?.findRenderObject();
  if (context == null || targetObject == null || !targetObject.attached) {
    return;
  }
  final align =
      target.contents?.isNotEmpty == true ? target.contents!.first.align : null;
  final vertical = switch (align) {
    ContentAlign.bottom => 0.15,
    ContentAlign.top => 0.85,
    _ => 0.5,
  };
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final duration =
      reduceMotion ? Duration.zero : const Duration(milliseconds: 350);

  final moves = <Future<void>>[];
  var scrollable = Scrollable.maybeOf(context);
  RenderObject object = targetObject;
  while (scrollable != null) {
    final position = scrollable.position;
    moves.add(position.ensureVisible(
      object,
      alignment: position.axis == Axis.vertical ? vertical : 0.5,
      duration: duration,
      curve: Curves.easeInOut,
      targetRenderObject: identical(object, targetObject) ? null : targetObject,
    ));
    final outer = scrollable.context.findRenderObject();
    if (outer == null) break;
    object = outer;
    scrollable = Scrollable.maybeOf(scrollable.context);
  }
  if (moves.isEmpty) return;
  await Future.wait(moves);
  // One frame so the new layout is what the spotlight measures.
  await WidgetsBinding.instance.endOfFrame;
}
