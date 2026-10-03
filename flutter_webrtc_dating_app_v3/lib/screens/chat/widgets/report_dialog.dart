// lib/screens/chat/widgets/report_dialog.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/safety_service.dart';

/// Report flow (DEST-003). Returns true once the report is stored.
///
///   final reported = await ReportDialog.show(context,
///       reportedUserId: otherUid, reportedName: name,
///       conversationId: convId, messageIds: selectedIds);
class ReportDialog extends StatefulWidget {
  final String reportedUserId;
  final String? reportedName;
  final String? conversationId;
  final List<String> messageIds;
  final String source;

  const ReportDialog({
    super.key,
    required this.reportedUserId,
    this.reportedName,
    this.conversationId,
    this.messageIds = const [],
    this.source = 'chat',
  });

  static Future<bool> show(
    BuildContext context, {
    required String reportedUserId,
    String? reportedName,
    String? conversationId,
    List<String> messageIds = const [],
    String source = 'chat',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ReportDialog(
        reportedUserId: reportedUserId,
        reportedName: reportedName,
        conversationId: conversationId,
        messageIds: messageIds,
        source: source,
      ),
    );
    return result == true;
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final TextEditingController _details = TextEditingController();
  String? _reason;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await SafetyService.instance.report(
        reportedUserId: widget.reportedUserId,
        reason: reason,
        details: _details.text,
        conversationId: widget.conversationId,
        messageIds: widget.messageIds,
        source: widget.source,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop(true);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Thanks. Your report was sent for review.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            'Could not send the report. Check your connection and '
            'try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.reportedName;
    return AlertDialog(
      backgroundColor: AppColors.inputBackground,
      title: Text(
        name == null || name.isEmpty ? 'Report user' : 'Report $name',
        style: const TextStyle(color: AppColors.inputTextWhite),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you reporting this user?',
              style: TextStyle(color: AppColors.hintPurple),
            ),
            const SizedBox(height: 8),
            for (final reason in SafetyService.reportReasons)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                enabled: !_submitting,
                selected: _reason == reason,
                leading: Icon(
                  _reason == reason
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _reason == reason
                      ? AppColors.purplePrimary
                      : AppColors.hintPurple,
                ),
                title: Text(
                  reason,
                  style: const TextStyle(color: AppColors.inputTextWhite),
                ),
                onTap: () => setState(() => _reason = reason),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              enabled: !_submitting,
              maxLength: SafetyService.maxReportDetails,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(color: AppColors.inputTextWhite),
              decoration: const InputDecoration(
                hintText: 'Add details (optional)',
                hintStyle: TextStyle(color: AppColors.hintPurple),
                counterStyle: TextStyle(color: AppColors.hintPurple),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.dangerRed)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.hintPurple),
          ),
        ),
        TextButton(
          onPressed: _reason == null || _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Report',
                  style: TextStyle(color: AppColors.dangerRed),
                ),
        ),
      ],
    );
  }
}

/// Confirms, then blocks [otherUid]. Shows the success snackbar only after
/// the write lands. Returns true if the user is now blocked; the caller
/// should then leave the chat.
Future<bool> confirmAndBlockUser(
  BuildContext context, {
  required String otherUid,
  String? displayName,
  String? avatarUrl,
}) async {
  final name = displayName == null || displayName.isEmpty
      ? 'this user'
      : displayName;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.inputBackground,
      title: Text(
        'Block $name?',
        style: const TextStyle(color: AppColors.inputTextWhite),
      ),
      content: const Text(
        'You will no longer see each other in discovery or chats, and '
        'neither of you can message or call the other. You can unblock '
        'from Settings > Blocked users.',
        style: TextStyle(color: AppColors.hintPurple),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.hintPurple),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'Block',
            style: TextStyle(color: AppColors.dangerRed),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await SafetyService.instance.block(
      otherUid,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    messenger?.showSnackBar(SnackBar(content: Text('Blocked $name')));
    return true;
  } catch (e) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Could not block. Check your connection and try again.'),
        backgroundColor: AppColors.dangerRed,
      ),
    );
    return false;
  }
}
