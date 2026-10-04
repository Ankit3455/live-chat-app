// lib/screens/settings/blocked_users_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/safety_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_states.dart';

/// Settings > Blocked users: list with unblock (DEST-003).
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Stream<List<BlockedUser>?> _stream;
  final Map<String, Future<String?>> _names = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _stream = SafetyService.instance.watchBlockedUsers();
  }

  // Older blocks may have no name snapshot; look it up once per row.
  Future<String?> _nameFor(BlockedUser user) {
    final stored = user.displayName;
    if (stored != null && stored.isNotEmpty) return Future.value(stored);
    return _names.putIfAbsent(user.uid, () async {
      final db = FirebaseFirestore.instance;
      for (final col in ['public_profiles', 'users']) {
        try {
          final d = (await db.collection(col).doc(user.uid).get()).data();
          final name = (d?['username'] ?? d?['name']) as String?;
          if (name != null && name.isNotEmpty) return name;
        } catch (_) {}
      }
      return null;
    });
  }

  Future<void> _unblock(BlockedUser user, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Unblock $name?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You will be able to see and message each other again.',
          style: TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy.add(user.uid));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SafetyService.instance.unblock(user.uid);
      messenger.showSnackBar(SnackBar(content: Text('Unblocked $name')));
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not unblock. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(user.uid));
    }
  }

  static String _plural(int n, String unit) =>
      '$n $unit${n == 1 ? '' : 's'} ago';

  static String _blockedAgo(DateTime at) {
    final days = DateTime.now().difference(at).inDays;
    if (days >= 365) return 'Blocked ${_plural(days ~/ 365, 'year')}';
    if (days >= 30) return 'Blocked ${_plural(days ~/ 30, 'month')}';
    if (days >= 7) return 'Blocked ${_plural(days ~/ 7, 'week')}';
    if (days >= 1) return 'Blocked ${_plural(days, 'day')}';
    return 'Blocked today';
  }

  void _retry() {
    SafetyService.instance.retry();
    setState(() {
      _stream = SafetyService.instance.watchBlockedUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Blocked users'),
        centerTitle: true,
        backgroundColor: AppColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BlockedUser>?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load blocked users',
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: _retry,
            );
          }
          final users = snap.data;
          if (users == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            );
          }
          if (users.isEmpty) {
            return const AppEmptyState(
              icon: Icons.shield_outlined,
              title: 'No blocked users',
              message:
                  "If you block someone from their profile or a chat, they'll show up here.",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: users.length + 1,
            separatorBuilder: (_, i) => i == 0
                ? const SizedBox.shrink()
                : const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 80,
                    color: AppColors.border,
                  ),
            itemBuilder: (context, i) => i == 0
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      "People you block can't see your profile or message you.",
                      style: TextStyle(color: AppColors.lavender, fontSize: 14),
                    ),
                  )
                : _tile(users[i - 1]),
          );
        },
      ),
    );
  }

  Widget _tile(BlockedUser user) {
    return FutureBuilder<String?>(
      future: _nameFor(user),
      builder: (context, snap) {
        final name = snap.data ?? 'User';
        final avatar = user.avatarUrl;
        final image = avatar != null && avatar.startsWith('http')
            ? CachedNetworkImageProvider(avatar, maxWidth: 150)
            : null;
        final busy = _busy.contains(user.uid);
        final blockedAt = user.blockedAt;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Name is read from the text beside it.
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.surface2,
                    foregroundImage: image,
                    onForegroundImageError: image != null ? (_, __) {} : null,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (blockedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _blockedAgo(blockedAt),
                          style: const TextStyle(
                            color: AppColors.textSubtle,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (busy)
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Unblocking',
                          strokeWidth: 2,
                          color: AppColors.brandPurpleLight,
                        ),
                      ),
                    ),
                  )
                else
                  Tooltip(
                    message: 'Unblock $name',
                    child: OutlinedButton(
                      onPressed: () => _unblock(user, name),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        backgroundColor: AppColors.surfaceCard,
                        side: const BorderSide(color: AppColors.borderStrong),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(48, 40),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Unblock'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
