import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/call_model.dart';
import '../../../services/call/call_consent.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/custom_button.dart';

/// "Calls with <name>": my voice/video switches plus the other user's status.
class CallSettingsSheet extends StatefulWidget {
  final String otherName;
  final String myUid;
  final String otherUid;

  /// Latest conversation doc data; the sheet rebuilds when it changes.
  final ValueListenable<Map<String, dynamic>?> conversation;

  /// False until the conversation doc exists (switches are disabled).
  final bool canEdit;

  /// Writes my setting; returns false on failure.
  final Future<bool> Function(CallType type, bool enabled) onChanged;

  const CallSettingsSheet({
    super.key,
    required this.otherName,
    required this.myUid,
    required this.otherUid,
    required this.conversation,
    required this.canEdit,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String otherName,
    required String myUid,
    required String otherUid,
    required ValueListenable<Map<String, dynamic>?> conversation,
    required bool canEdit,
    required Future<bool> Function(CallType type, bool enabled) onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppColors.borderStrong),
      ),
      builder: (_) => CallSettingsSheet(
        otherName: otherName,
        myUid: myUid,
        otherUid: otherUid,
        conversation: conversation,
        canEdit: canEdit,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<CallSettingsSheet> createState() => _CallSettingsSheetState();
}

class _CallSettingsSheetState extends State<CallSettingsSheet> {
  /// Optimistic values while a write is in flight.
  final Map<CallType, bool> _pending = {};

  Future<void> _toggle(CallType type, bool value) async {
    setState(() => _pending[type] = value);
    await widget.onChanged(type, value);
    if (!mounted) return;
    setState(() => _pending.remove(type));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: widget.conversation,
          builder: (context, data, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Semantics(
                header: true,
                child: Text(
                  'Calls with ${widget.otherName}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'A call type is available only when you both turn it on. '
                'You can turn it off any time.',
                style: TextStyle(
                  color: AppColors.lavender,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              if (!widget.canEdit) ...[
                const SizedBox(height: 8),
                const AppBanner(
                  message: 'Send a message first, then you can turn calls on.',
                ),
                const SizedBox(height: 8),
              ],
              _buildRow(data, CallType.audio),
              const Divider(color: AppColors.border, height: 1),
              _buildRow(data, CallType.video),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic>? data, CallType type) {
    final isVideo = type == CallType.video;
    final label = isVideo ? 'Video calls' : 'Voice calls';
    final mine =
        _pending[type] ??
        (data != null && CallConsent.isEnabledFor(data, widget.myUid, type));
    final theirs =
        data != null && CallConsent.isEnabledFor(data, widget.otherUid, type);

    // One semantics node: label, status and switch together.
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.videocam_outlined : Icons.call_outlined,
                size: 20,
                color: AppColors.brandPurpleLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        'You: ${mine ? 'on' : 'off'} · ${widget.otherName}:',
                        style: const TextStyle(
                          color: AppColors.lavender,
                          fontSize: 13,
                        ),
                      ),
                      _StatusPill(on: theirs),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: mine,
              onChanged: widget.canEdit && !_pending.containsKey(type)
                  ? (v) => _toggle(type, v)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool on;
  const _StatusPill({required this.on});

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        on ? 'on' : 'not yet',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
