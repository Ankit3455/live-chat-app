import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../models/conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widgets/selection_app_bar.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _chatService = ChatService();
  final _auth = FirebaseAuth.instance;

  late final TabController _tab;
  late Stream<List<Conversation>> _conversations;

  // Profile lookups cached per uid so rebuilds don't refetch.
  final Map<String, Future<UserModel?>> _users = {};

  // ---- selection state ----
  final Set<String> _selected = <String>{};
  bool _selectionMode = false;

  Future<UserModel?> _userFor(String uid) =>
      _users.putIfAbsent(uid, () => _chatService.getUserDetails(uid));

  void _retry() {
    setState(() => _conversations = _chatService.getConversations());
  }

  void _toggleSelect(String conversationId) {
    setState(() {
      if (_selected.contains(conversationId)) {
        _selected.remove(conversationId);
      } else {
        _selected.add(conversationId);
      }
      _selectionMode = _selected.isNotEmpty;
    });
  }

  void _exitSelection() {
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Runs [action] for every selected conversation; confirmation is asked by
  /// SelectionAppBar before this is called.
  Future<void> _bulk(
    Future<void> Function(String cid, String uid) action, {
    required String done,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _selected.isEmpty) return;

    final ids = _selected.toList();
    var failed = 0;
    for (final cid in ids) {
      try {
        await action(cid, uid);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _showSnack(failed == 0 ? done : 'Could not update $failed chat(s)');
    _exitSelection();
  }

  Future<void> _bulkClear() => _bulk(
        (cid, uid) => _chatService.clearChat(cid, myUid: uid),
        done: 'Chat cleared',
      );

  Future<void> _bulkDeleteForMe() => _bulk(
        (cid, uid) => _chatService.deleteForUser(cid, uid),
        done: 'Deleted for you',
      );

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _conversations = _chatService.getConversations();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _chatService.currentUserId;

    return StreamBuilder<List<Conversation>>(
      stream: _conversations,
      builder: (context, snap) {
        final all = snap.data ?? const <Conversation>[];

        final active = <Conversation>[];
        final newList = <Conversation>[];
        for (final c in all) {
          if (!c.isVisibleTo(myUid)) continue;
          switch (c.stateFor(myUid)) {
            case 'active':
              active.add(c);
              break;
            case 'new':
              newList.add(c);
              break;
          }
        }
        final newUnread =
            newList.where((c) => c.visibleUnreadFor(myUid) > 0).length;

        Widget body;
        if (snap.hasError && !snap.hasData) {
          body = _ErrorState(onRetry: _retry);
        } else if (!snap.hasData) {
          body = Center(
            child: CircularProgressIndicator(color: AppColors.purplePrimary),
          );
        } else {
          body = TabBarView(
            controller: _tab,
            children: [
              _ConversationsList(
                items: active,
                chat: _chatService,
                myUid: myUid,
                userFor: _userFor,
                selectionMode: _selectionMode,
                selected: _selected,
                onToggleSelect: _toggleSelect,
                emptyTitle: 'No active chats',
                emptySubtitle: 'Reply to move chats from New → Active',
              ),
              _ConversationsList(
                items: newList,
                chat: _chatService,
                myUid: myUid,
                userFor: _userFor,
                selectionMode: _selectionMode,
                selected: _selected,
                onToggleSelect: _toggleSelect,
                emptyTitle: 'No new messages',
                emptySubtitle:
                    'When someone new texts you, it shows up here',
              ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: AppColors.appBackground,
          appBar: _selectionMode
              ? SelectionAppBar(
                  count: _selected.length,
                  onClose: _exitSelection,
                  onClear: _bulkClear,
                  onDelete: _bulkDeleteForMe,
                )
              : AppBar(
                  backgroundColor: AppColors.purplePrimary,
                  title: const Text('Messages'),
                  bottom: TabBar(
                    controller: _tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    tabs: [
                      const Tab(text: 'Active'),
                      Tab(child: _TabLabel(text: 'New', badge: newUnread)),
                    ],
                  ),
                ),
          body: body,
        );
      },
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  final int badge;
  const _TabLabel({required this.text, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (badge > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              style: TextStyle(
                color: AppColors.purplePrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConversationsList extends StatelessWidget {
  final List<Conversation> items;
  final ChatService chat;
  final String myUid;
  final Future<UserModel?> Function(String uid) userFor;

  final bool selectionMode;
  final Set<String> selected;
  final void Function(String conversationId) onToggleSelect;

  final String emptyTitle;
  final String emptySubtitle;

  const _ConversationsList({
    Key? key,
    required this.items,
    required this.chat,
    required this.myUid,
    required this.userFor,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelect,
    required this.emptyTitle,
    required this.emptySubtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(title: emptyTitle, subtitle: emptySubtitle);
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(color: AppColors.hintPurple.withOpacity(0.1), height: 1),
      itemBuilder: (context, i) {
        final conv = items[i];
        return _ConversationTile(
          key: ValueKey(conv.id),
          conv: conv,
          chat: chat,
          myUid: myUid,
          user: userFor(conv.getOtherParticipantId(myUid)),
          selectionMode: selectionMode,
          isSelected: selected.contains(conv.id),
          onToggleSelect: onToggleSelect,
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conv;
  final ChatService chat;
  final String myUid;
  final Future<UserModel?> user;

  final bool selectionMode;
  final bool isSelected;
  final void Function(String conversationId) onToggleSelect;

  const _ConversationTile({
    Key? key,
    required this.conv,
    required this.chat,
    required this.myUid,
    required this.user,
    required this.selectionMode,
    required this.isSelected,
    required this.onToggleSelect,
  }) : super(key: key);

  static String? _avatarUrl(UserModel? u) {
    if (u == null) return null;
    final candidates = [
      u.profileImage,
      u.avatarProperties?['avatarImageUrl']?.toString(),
      u.avatarString,
    ];
    for (final c in candidates) {
      if (c != null && c.startsWith('http')) return c;
    }
    return null;
  }

  void _openChat(BuildContext context, String otherId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: otherId,
          conversationId: conv.id,
        ),
      ),
    );
    unawaited(chat.markMessagesAsRead(conv.id, otherId));
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String failure,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: const Text('Delete this chat?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'The chat will be removed for you. It won’t affect the other user.',
          style: TextStyle(color: AppColors.hintPurple),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: AppColors.hintPurple)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.dangerRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      () => chat.deleteForUser(conv.id, myUid),
      'Could not delete chat',
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherId = conv.getOtherParticipantId(myUid);

    // Clear/delete-for-me hides history at or before clearedBefore.
    final cleared = conv.isClearedFor(myUid);
    final displayUnread = conv.visibleUnreadFor(myUid);
    final lastTime = conv.lastMessageTimeOrNew;
    final text = (conv.lastMessageText ?? '').trim();
    final subtitle = (cleared || text.isEmpty) ? 'No messages yet' : text;
    final timeStr =
        (lastTime == null || cleared) ? '' : _formatTime(lastTime);
    final muted = conv.isMuted(myUid);

    return FutureBuilder<UserModel?>(
      future: user,
      builder: (context, snap) {
        final other = snap.data;
        final rawName = other?.username.trim() ?? '';
        final name = conv.isDeletedUser(otherId)
            ? 'Deleted user'
            : (rawName.isNotEmpty ? rawName : 'User');
        final avatarUrl = _avatarUrl(other);

        final content = ListTile(
          onLongPress: () => onToggleSelect(conv.id),
          onTap: () {
            if (selectionMode) {
              onToggleSelect(conv.id);
              return;
            }
            _openChat(context, otherId);
          },
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                backgroundColor: AppColors.purplePrimary,
                child: avatarUrl == null
                    ? Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
              if (displayUnread > 0)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.purplePrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayUnread > 99 ? '99+' : '$displayUnread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              if (muted)
                const Icon(Icons.volume_off, size: 16, color: Colors.white70),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(timeStr,
                    style:
                    TextStyle(fontSize: 12, color: AppColors.hintPurple)),
              ],
            ],
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.hintPurple),
          ),
        );

        final decorated = Stack(
          children: [
            content,
            if (isSelected)
              Positioned.fill(
                child: Container(color: Colors.white.withOpacity(0.06)),
              ),
            if (isSelected)
              const Positioned(
                right: 12,
                top: 12,
                child: Icon(Icons.check_circle, color: Colors.greenAccent),
              ),
          ],
        );

        return Slidable(
          key: ValueKey(conv.id),
          enabled: !selectionMode,
          endActionPane: ActionPane(
            extentRatio: 0.72,
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (ctx) => _run(
                  ctx,
                  () => chat.markMessagesAsRead(conv.id, otherId),
                  'Could not mark as read',
                ),
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                icon: Icons.mark_email_read_rounded,
                label: 'Read',
              ),
              SlidableAction(
                onPressed: (ctx) => _run(
                  ctx,
                  () => chat.toggleMute(conv.id, myUid, !muted),
                  muted ? 'Could not unmute chat' : 'Could not mute chat',
                ),
                backgroundColor: const Color(0xFF616161),
                foregroundColor: Colors.white,
                icon:
                muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                label: muted ? 'Unmute' : 'Mute',
              ),
              SlidableAction(
                onPressed: _confirmDelete,
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                icon: Icons.delete_forever_rounded,
                label: 'Delete',
              ),
            ],
          ),
          child: decorated,
        );
      },
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.inDays > 7) return DateFormat('MMM d').format(t);
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 72, color: AppColors.hintPurple.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text("Couldn't load your chats",
                style: TextStyle(fontSize: 18, color: AppColors.hintPurple)),
            const SizedBox(height: 8),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.hintPurple)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purplePrimary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 80, color: AppColors.hintPurple.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(fontSize: 18, color: AppColors.hintPurple)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                TextStyle(fontSize: 14, color: AppColors.hintPurple)),
          ],
        ),
      ),
    );
  }
}
