import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Labelled round call control shared by the voice and video screens.
/// [toggled] fills the disc white; [isEnd] makes it the larger red End button.
class CallControlButton extends StatelessWidget {
  final IconData icon;

  /// Short visible label under the disc ("Mute", "Muted", "End").
  final String label;

  /// Tooltip / screen-reader text; defaults to [label].
  final String? tooltip;
  final VoidCallback? onPressed;

  /// Null for plain actions (Flip, End).
  final bool? toggled;
  final bool isEnd;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.toggled,
    this.isEnd = false,
  });

  const CallControlButton.end({
    super.key,
    required this.onPressed,
    this.label = 'End',
    this.tooltip = 'End call',
  }) : icon = Icons.call_end_rounded,
       toggled = null,
       isEnd = true;

  static const double _size = 60;
  static const double _endSize = 68;

  @override
  Widget build(BuildContext context) {
    final on = toggled ?? false;
    final size = isEnd ? _endSize : _size;
    final Color fill = isEnd
        ? AppColors.error
        : on
        ? AppColors.white
        : AppColors.white.withOpacity(0.12);
    final Color iconColor = on ? AppColors.backgroundDeep : AppColors.white;
    final message = tooltip ?? label;

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      toggled: toggled,
      label: message,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: message,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Same box height for every disc so labels line up.
            SizedBox(
              height: _endSize,
              child: Center(
                child: Material(
                  color: fill,
                  shape: CircleBorder(
                    side: isEnd || on
                        ? BorderSide.none
                        : BorderSide(color: AppColors.white.withOpacity(0.16)),
                  ),
                  elevation: isEnd ? 6 : 0,
                  shadowColor: AppColors.error.withOpacity(0.5),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: isEnd ? 30 : 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              // Full label stays in the tooltip / semantics.
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: isEnd || on ? AppColors.white : AppColors.lavender,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of call controls; each slot gets an equal share of the width.
class CallControlRow extends StatelessWidget {
  final List<Widget> children;

  const CallControlRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Call controls',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final c in children) Expanded(child: c)],
      ),
    );
  }
}

/// Large Accept / Decline button on the incoming-call screen.
class CallAnswerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color color;
  final Color iconColor;
  final VoidCallback? onPressed;

  const CallAnswerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.color,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: color,
              shape: const CircleBorder(),
              elevation: 8,
              shadowColor: color.withOpacity(0.5),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(icon, color: iconColor, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum CallStatusTone { ok, pending, warning }

/// Pill showing the call phase ("Connected", "Reconnecting…").
class CallStatusChip extends StatelessWidget {
  final String label;
  final CallStatusTone tone;

  const CallStatusChip({super.key, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final Color accent;
    switch (tone) {
      case CallStatusTone.ok:
        accent = AppColors.success;
        break;
      case CallStatusTone.pending:
        accent = AppColors.brandPurpleLight;
        break;
      case CallStatusTone.warning:
        accent = AppColors.warning;
        break;
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withOpacity(0.32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
