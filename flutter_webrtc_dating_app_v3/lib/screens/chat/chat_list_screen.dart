import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../models/conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_states.dart';
import '../../widgets/shimmers/shimmer_chat_row.dart';
import '../chat/chat_screen.dart';
import 'widgets/chat_list_selection_bar.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

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
  /// ChatListSelectionBar before this is called.
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
        final newUnread = newList
            .where((c) => c.visibleUnreadFor(myUid) > 0)
            .length;

        Widget body;
        if (snap.hasError && !snap.hasData) {
          body = AppEmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load your chats",
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: _retry,
          );
        } else if (!snap.hasData) {
          body = const ShimmerChatList();
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
                emptySubtitle: 'When someone new texts you, it shows up here',
                banner:
                    'New chats are silent. Reply to move a chat to '
                    'Active and turn on notifications.',
              ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundDeep,
          appBar: _selectionMode
              ? ChatListSelectionBar(
                  count: _selected.length,
                  onClose: _exitSelection,
                  onClear: _bulkClear,
                  onDelete: _bulkDeleteForMe,
                )
              : null,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_selectionMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Chats',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _SegmentedTabs(controller: _tab, newCount: newUnread),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pill-shaped Active / New switcher driven by the shared TabController.
class _SegmentedTabs extends StatelessWidget {
  final TabController controller;
  final int newCount;
  const _SegmentedTabs({required this.controller, required this.newCount});

  @override
  Widget build(BuildContext context) {
    final pill = BorderRadius.circular(999);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: pill,
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(color: AppColors.surface2, borderRadius: pill),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: pill,
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.lavender,
        tabs: [
          const Tab(height: 38, text: 'Active'),
          Tab(
            height: 38,
            child: _TabLabel(text: 'New', badge: newCount),
          ),
        ],
      ),
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
        if (badge > 0) ...[const SizedBox(width: 6), _CountBadge(count: badge)],
      ],
    );
  }
}

/// Pink unread pill, used on the New tab and on rows.
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandPink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
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

  /// Optional info banner shown above the list.
  final String? banner;

  const _ConversationsList({
    required this.items,
    required this.chat,
    required this.myUid,
    required this.userFor,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelect,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.banner,
  });

  @override
  Widget build(BuildContext context) {
    final bannerText = banner;
    final bannerWidget = bannerText == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: AppBanner(message: bannerText),
          );

    if (items.isEmpty) {
      final empty = AppEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: emptyTitle,
        message: emptySubtitle,
      );
      if (bannerWidget == null) return empty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bannerWidget,
          Expanded(child: empty),
        ],
      );
    }

    final offset = bannerWidget == null ? 0 : 1;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length + offset,
      itemBuilder: (context, i) {
        if (bannerWidget != null && i == 0) return bannerWidget;
        final conv = items[i - offset];
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
    super.key,
    required this.conv,
    required this.chat,
    required this.myUid,
    required this.user,
    required this.selectionMode,
    required this.isSelected,
    required this.onToggleSelect,
  });

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
        builder: (_) =>
            ChatScreen(otherUserId: otherId, conversationId: conv.id),
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
        title: const Text('Delete this chat?'),
        content: const Text(
          'The chat will be removed for you. It won’t affect the other user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.lavender),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
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
    final textTheme = Theme.of(context).textTheme;

    // Clear/delete-for-me hides history at or before clearedBefore.
    final cleared = conv.isClearedFor(myUid);
    final displayUnread = conv.visibleUnreadFor(myUid);
    final unread = displayUnread > 0;
    final lastTime = conv.lastMessageTimeOrNew;
    final text = (conv.lastMessageText ?? '').trim();
    final subtitle = (cleared || text.isEmpty) ? 'No messages yet' : text;
    final timeStr = (lastTime == null || cleared) ? '' : _formatTime(lastTime);
    final muted = conv.isMuted(myUid);
    final deleted = conv.isDeletedUser(otherId);

    return FutureBuilder<UserModel?>(
      future: user,
      builder: (context, snap) {
        final other = snap.data;
        final rawName = other?.username.trim() ?? '';
        final name = deleted
            ? 'Deleted user'
            : (rawName.isNotEmpty ? rawName : 'User');
        final avatarUrl = _avatarUrl(other);
        // From the cached profile read; no extra presence listener.
        final online = !deleted && (other?.online ?? false);

        final avatar = Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl, maxWidth: 160)
                  : null,
              backgroundColor: AppColors.brandPurple,
              child: avatarUrl == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            if (online)
              Positioned(
                right: 0,
                bottom: 0,
                child: Semantics(
                  label: 'Online',
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.backgroundDeep,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

        final content = Material(
          color: isSelected
              ? AppColors.brandPurple.withValues(alpha: 0.16)
              : AppColors.backgroundDeep,
          child: InkWell(
            onLongPress: () => onToggleSelect(conv.id),
            onTap: () {
              if (selectionMode) {
                onToggleSelect(conv.id);
                return;
              }
              _openChat(context, otherId);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleMedium?.copyWith(
                                          color: AppColors.white,
                                        ),
                                      ),
                                    ),
                                    if (muted) ...[
                                      const SizedBox(width: 4),
                                      Semantics(
                                        label: 'Muted',
                                        child: const Icon(
                                          Icons.volume_off_rounded,
                                          size: 14,
                                          color: AppColors.textSubtle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (timeStr.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: unread
                                        ? AppColors.pinkLight
                                        : AppColors.textSubtle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: unread
                                        ? AppColors.white
                                        : AppColors.lavender,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (unread) ...[
                                const SizedBox(width: 8),
                                _CountBadge(count: displayUnread),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 12),
                      Semantics(
                        label: 'Selected',
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.pinkLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
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
                backgroundColor: AppColors.brandPurple,
                foregroundColor: AppColors.white,
                icon: Icons.mark_email_read_rounded,
                label: 'Read',
              ),
              SlidableAction(
                onPressed: (ctx) => _run(
                  ctx,
                  () => chat.toggleMute(conv.id, myUid, !muted),
                  muted ? 'Could not unmute chat' : 'Could not mute chat',
                ),
                backgroundColor: AppColors.surface2,
                foregroundColor: AppColors.white,
                icon: muted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: muted ? 'Unmute' : 'Mute',
              ),
              SlidableAction(
                onPressed: _confirmDelete,
                backgroundColor: _deleteFill,
                foregroundColor: AppColors.white,
                icon: Icons.delete_forever_rounded,
                label: 'Delete',
              ),
            ],
          ),
          child: content,
        );
      },
    );
  }

  /// Error tone darkened over surface2 so white label text stays readable.
  static final Color _deleteFill = Color.alphaBlend(
    AppColors.error.withValues(alpha: 0.55),
    AppColors.surface2,
  );

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
