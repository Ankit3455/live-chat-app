import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';

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
          tooltip: 'Clear messages',
          icon: const Icon(Icons.cleaning_services_rounded),
          onPressed: disabled
              ? null
              : () async {
                  final ok = await _confirm(
                    context,
                    title:
                        count == 1 ? 'Clear this chat?' : 'Clear $count chats?',
                    message:
                        'Messages will be cleared for you only. The chats stay in your list.',
                    action: 'Clear',
                  );
                  if (ok == true) onClear();
                },
        ),
        IconButton(
          tooltip: 'Delete chats',
          icon: const Icon(Icons.delete_forever_rounded),
          onPressed: disabled
              ? null
              : () async {
                  final ok = await _confirm(
                    context,
                    title: count == 1
                        ? 'Delete this chat?'
                        : 'Delete $count chats?',
                    message: count == 1
                        ? 'This chat will be removed for you only. The other person can still see it.'
                        : 'These chats will be removed for you only. The other person can still see them.',
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
    Haptics.warning();
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
