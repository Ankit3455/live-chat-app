// lib/screens/settings/blocked_users_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/safety_service.dart';

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
        backgroundColor: const Color(0xFF2D1B4E),
        title: Text(
          'Unblock $name?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You will be able to see and message each other again.',
          style: TextStyle(color: Color(0xFFB39DDB)),
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
        const SnackBar(
          content: Text('Could not unblock. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      appBar: AppBar(
        title: const Text('Blocked users'),
        backgroundColor: const Color(0xFF2D1B4E),
        elevation: 0,
      ),
      body: StreamBuilder<List<BlockedUser>?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _message(
              icon: Icons.cloud_off,
              text: 'Could not load blocked users.',
              action: TextButton(
                onPressed: () {
                  SafetyService.instance.retry();
                  setState(() {
                    _stream = SafetyService.instance.watchBlockedUsers();
                  });
                },
                child: const Text('Retry'),
              ),
            );
          }
          final users = snap.data;
          if (users == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (users.isEmpty) {
            return _message(
              icon: Icons.block,
              text: 'You have not blocked anyone.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _tile(users[i]),
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
            ? NetworkImage(avatar)
            : null;
        final busy = _busy.contains(user.uid);
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D1B4E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF7B2CBF).withValues(alpha: 0.3),
              foregroundImage: image,
              onForegroundImageError: image != null ? (_, __) {} : null,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () => _unblock(user, name),
                    child: const Text('Unblock'),
                  ),
          ),
        );
      },
    );
  }

  Widget _message({
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFB39DDB)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB39DDB)),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }
}
