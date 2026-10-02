import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ChatListSlidableWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPin;
  final VoidCallback? onMute;
  final VoidCallback? onDelete;

  const ChatListSlidableWrapper({
    Key? key,
    required this.child,
    this.onPin,
    this.onMute,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: UniqueKey(),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.6,
        children: [
          if (onPin != null)
            SlidableAction(
              onPressed: (_) => onPin?.call(),
              icon: Icons.push_pin,
              label: 'Pin',
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
          if (onMute != null)
            SlidableAction(
              onPressed: (_) => onMute?.call(),
              icon: Icons.notifications_off,
              label: 'Mute',
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              icon: Icons.delete,
              label: 'Delete',
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
        ],
      ),
      child: child,
    );
  }
}
