import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../models/conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/selection_app_bar.dart'; // ✅ selection appbar

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _chatService = ChatService();
  final _auth = FirebaseAuth.instance;

  late final TabController _tab; // ✅

  // ---- selection state ----
  final Set<String> _selected = <String>{};
  bool _selectionMode = false;

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
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  Future<void> _bulkClear() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _selected.isEmpty) return;

    for (final cid in _selected) {
      await _chatService.clearChat(cid, myUid: uid); // uses clearedBefore (soft clear)
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chat cleared')));
    }
    _exitSelection();
  }

  Future<void> _bulkDeleteForMe() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _selected.isEmpty) return;

    for (final cid in _selected) {
      await _chatService.deleteForUser(cid, uid); // soft delete for me
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Deleted for you')));
    }
    _exitSelection();
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _chatService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.appBackground,

      // ✅ Selection appbar swap
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
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'New'),
          ],
        ),
      ),

      body: StreamBuilder<List<Conversation>>(
        // ✅ single stream — no flicker
        stream: _chatService.getConversations(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child:
              CircularProgressIndicator(color: AppColors.purplePrimary),
            );
          }

          final all = snap.data ?? const [];

          // client-side split
          final active = <Conversation>[];
          final newList = <Conversation>[];

          for (final c in all) {
            // ⚠️ hide if deleted for me
            final myState = (c.statePerUser ?? const {})[myUid] ?? '';
            if (myState == 'deleted') continue;

            // primary logic: statePerUser -> active/new
            if (myState == 'active') {
              active.add(c);
              continue;
            }
            if (myState == 'new') {
              newList.add(c);
              continue;
            }

            // fallback: participantData status / hasReplied
            final meRaw = (c.participantData ?? const {})[myUid];
            final me = (meRaw is Map) ? meRaw as Map : const {};
            final status = (me['status'] ?? '').toString();
            final hasReplied = (me['hasReplied'] ?? false) == true;

            if (status == 'active' || hasReplied) {
              active.add(c);
            } else {
              newList.add(c);
            }
          }

          return TabBarView(
            controller: _tab,
            children: [
              _ConversationsList(
                items: active,
                chat: _chatService,
                myUid: myUid,
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
                selectionMode: _selectionMode,
                selected: _selected,
                onToggleSelect: _toggleSelect,
                emptyTitle: 'No new messages',
                emptySubtitle:
                'When someone new texts you, it shows up here',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConversationsList extends StatelessWidget {
  final List<Conversation> items;
  final ChatService chat;
  final String myUid;

  // ✅ selection plumbed to rows
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
      itemBuilder: (context, i) => _ConversationTile(
        conv: items[i],
        chat: chat,
        myUid: myUid,
        selectionMode: selectionMode,
        isSelected: selected.contains(items[i].id),
        onToggleSelect: onToggleSelect,
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conv;
  final ChatService chat;
  final String myUid;

  // ✅ selection
  final bool selectionMode;
  final bool isSelected;
  final void Function(String conversationId) onToggleSelect;

  const _ConversationTile({
    Key? key,
    required this.conv,
    required this.chat,
    required this.myUid,
    required this.selectionMode,
    required this.isSelected,
    required this.onToggleSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final otherId = conv.getOtherParticipantId(myUid);

    // ---- clearedBefore (per-user soft clear) ----
    DateTime? clearedBefore;
    try {
      final myPd =
          (conv.participantData ?? const {})[myUid] as Map<String, dynamic>? ??
              const {};
      final cbTs = myPd['clearedBefore'];
      if (cbTs is Timestamp) clearedBefore = cbTs.toDate();
    } catch (_) {}

    // unread (model helper preferred)
    final int unread = (() {
      try {
        return conv.unreadFor(myUid);
      } catch (_) {
        final meRaw = (conv.participantData ?? const {})[myUid];
        final me = (meRaw is Map) ? meRaw as Map : const {};
        final v = me['unreadCount'];
        return v is int ? v : (v is num ? v.toInt() : 0);
      }
    })();

    // last time (prefer newer helpers; safe fallbacks)
    final DateTime? lastTime = (() {
      try {
        // some models expose lastMessageTimeOrNew; fall back gracefully
        final t = conv.lastMessageTimeOrNew;
        if (t != null) return t;
      } catch (_) {}
      try {
        if (conv.lastMessageTime != null) return conv.lastMessageTime;
      } catch (_) {}
      return conv.lastMessageAt;
    })();

    // subtitle (fallback safe)
    String subtitle = (() {
      try {
        return conv.lastMessageText ?? conv.lastMessage ?? 'No messages yet';
      } catch (_) {
        return conv.lastMessage ?? 'No messages yet';
      }
    })();

    // muted (model helper preferred)
    final bool muted = (() {
      try {
        return conv.isMuted(myUid);
      } catch (_) {
        final v = (conv.muted ?? const {})[myUid];
        return v is bool ? v : false;
      }
    })();

    // === Apply clearedBefore masking ===
    int displayUnread = unread;
    if (clearedBefore != null &&
        lastTime != null &&
        !lastTime.isAfter(clearedBefore)) {
      subtitle = 'No messages yet';
      displayUnread = 0;
    }

    // time label (empty if masked by clearedBefore)
    final String timeStr = (lastTime == null ||
        (clearedBefore != null && !lastTime.isAfter(clearedBefore)))
        ? ''
        : _formatTime(lastTime);

    return FutureBuilder<UserModel?>(
      future: chat.getUserDetails(otherId),
      builder: (context, snap) {
        final other = snap.data;
        final name = (() {
          try {
            final n = other?.username ?? 'User';
            return (n.trim().isNotEmpty) ? n : 'User';
          } catch (_) {
            return 'User';
          }
        })();

        String? avatarUrl = other?.profileImage;
        avatarUrl ??= other?.avatarString;

        final content = ListTile(
          onLongPress: () => onToggleSelect(conv.id), // ✅ enter selection
          onTap: () async {
            if (selectionMode) {
              onToggleSelect(conv.id); // toggle within selection
              return;
            }
            await chat.markMessagesAsRead(conv.id, otherId);
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    otherUserId: otherId,
                    conversationId: conv.id,
                  ),
                ),
              );
            }
          },
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                backgroundColor: AppColors.purplePrimary,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
              if (displayUnread > 0) // ✅ use displayUnread
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

        // ✅ selected overlay
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
          endActionPane: ActionPane(
            extentRatio: 0.60,
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) async =>
                    chat.markMessagesAsRead(conv.id, otherId),
                backgroundColor: const Color(0xFF2E7D32),
                icon: Icons.mark_email_read_rounded,
              ),
              SlidableAction(
                onPressed: (_) async =>
                    chat.toggleMute(conv.id, myUid, !muted),
                backgroundColor: const Color(0xFF616161),
                icon:
                muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              ),
              SlidableAction(
                onPressed: (_) async => chat.deleteForUser(conv.id, myUid),
                backgroundColor: const Color(0xFFD32F2F),
                icon: Icons.delete_forever_rounded,
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
