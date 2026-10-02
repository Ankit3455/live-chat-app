import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({
    Key? key,
    required this.count,
    required this.onClose,
    required this.onClear,
    required this.onDelete,
  }) : super(key: key);

  final int count;
  final VoidCallback onClose;
  final VoidCallback onClear;  // Bulk "Clear chat" (messages remove for you, keep thread)
  final VoidCallback onDelete; // Bulk "Delete for me" (thread hide for you)

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final disabled = count <= 0;

    return AppBar(
      backgroundColor: AppColors.purplePrimary,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onClose,
        tooltip: 'Cancel selection',
      ),
      title: Text('$count selected'),
      actions: [
        IconButton(
          tooltip: 'Clear chat',
          icon: const Icon(Icons.cleaning_services_rounded),
          onPressed: disabled ? null : () async {
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
          onPressed: disabled ? null : () async {
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
        backgroundColor: AppColors.inputBackground,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: AppColors.hintPurple)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: TextStyle(
                color: danger ? AppColors.dangerRed : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
