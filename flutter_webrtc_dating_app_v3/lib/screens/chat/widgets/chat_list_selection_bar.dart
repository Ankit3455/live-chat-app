import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Multi-select app bar for the chat list, styled with design tokens.
/// Asks for confirmation before calling [onClear] / [onDelete].
class ChatListSelectionBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ChatListSelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.onClear,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final disabled = count <= 0;

    return AppBar(
      backgroundColor: AppColors.surfaceRaised,
      centerTitle: false,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: onClose,
        tooltip: 'Cancel selection',
      ),
      title: Text('$count selected'),
      actions: [
        IconButton(
          tooltip: 'Clear chat',
          icon: const Icon(Icons.cleaning_services_rounded),
          onPressed: disabled
              ? null
              : () async {
                  final ok = await _confirm(
                    context,
                    title: 'Clear selected chats?',
                    message:
                        'This will clear messages from selected chats for you. Threads remain.',
                    action: 'Clear',
                  );
                  if (ok == true) onClear();
                },
        ),
        IconButton(
          tooltip: 'Delete for me',
          icon: const Icon(Icons.delete_forever_rounded),
          onPressed: disabled
              ? null
              : () async {
                  final ok = await _confirm(
                    context,
                    title: 'Delete selected chats?',
                    message:
                        'This will hide/remove selected chat threads for you. It won’t affect the other user.',
                    action: 'Delete',
                    danger: true,
                  );
                  if (ok == true) onDelete();
                },
        ),
      ],
    );
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.lavender),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: danger ? AppColors.error : AppColors.white,
            ),
            child: Text(
              action,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
