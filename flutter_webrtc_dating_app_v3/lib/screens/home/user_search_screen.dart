import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/profile/profile_details_screen.dart';
import 'package:availchat/services/user_search_service.dart';
import 'package:availchat/widgets/user_avatar.dart';

/// Search any available user by username; tap a result to open the profile.
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _controller = TextEditingController();
  late final UserSearchService _service;
  Timer? _debounce;
  int _requestId = 0;
  String _query = '';
  bool _loading = false;
  bool _failed = false;
  List<UserModel> _results = const [];

  @override
  void initState() {
    super.initState();
    _service =
        UserSearchService(myUid: FirebaseAuth.instance.currentUser?.uid ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() => _query = q);
    if (q.isEmpty) {
      _requestId++;
      setState(() {
        _results = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    final id = ++_requestId;
    try {
      final res = await _service.search(q);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = res;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  void _open(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileDetailsScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppColors.white),
          cursorColor: AppColors.brandPurple,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search by name',
            hintStyle: const TextStyle(color: AppColors.textSubtle),
            border: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return _message(Icons.search_rounded, 'Find someone by their name');
    }
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPurple),
      );
    }
    if (_failed) {
      return _message(
          Icons.cloud_off_outlined, "Couldn't search right now. Try again.");
    }
    if (_results.isEmpty) {
      return _message(
          Icons.person_search_outlined, 'No one found for "$_query"');
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final user = _results[i];
        final age = user.age;
        return ListTile(
          onTap: () => _open(user),
          leading: UserAvatar(user: user, size: 48, borderRadius: 14),
          title: Text(
            user.username,
            style: const TextStyle(
                color: AppColors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: age == null
              ? null
              : Text('$age',
                  style: const TextStyle(color: AppColors.textMuted)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted),
        );
      },
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textSubtle),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
}
