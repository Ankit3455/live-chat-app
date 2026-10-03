import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:availchat/screens/auth/login_screen.dart';
import '../../core/config/app_links.dart';
import '../../services/account_deletion_service.dart';
import '../../services/session_service.dart';
import '../settings/change_password_screen.dart';
import '../../features/onboarding/home_onboarding.dart';
import '../../features/onboarding/tour_prefs.dart';
import 'blocked_users_screen.dart';
import 'discovery_settings_screen.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SessionService.instance.signOut();
      if (context.mounted) _goToLogin(context);
    }
  }

  void _goToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final hasPassword = currentUser?.providerData
            .any((p) => p.providerId == 'password') ??
        false;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ====================================================================
          // Account Section
          // ====================================================================
          _buildSectionHeader('Account'),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.email,
            title: 'Email',
            subtitle: currentUser?.email ?? 'Not available',
            showChevron: false,
          ),
          if (hasPassword)
            _buildSettingsTile(
              icon: Icons.lock,
              title: 'Change Password',
              subtitle: 'Update your password',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                );
              },
            ),
          _buildSettingsTile(
            icon: Icons.tune,
            title: 'Discovery',
            subtitle: 'Who you see and who can see you',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DiscoverySettingsScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ====================================================================
          // Preferences Section
          // ====================================================================
          _buildSectionHeader('Preferences'),
          const SizedBox(height: 12),
          const _NotificationSettingsTiles(),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English',
            comingSoon: true,
          ),

          const SizedBox(height: 24),

          // ====================================================================
          // Help & Support Section
          // ====================================================================
          _buildSectionHeader('Help & Support'),
          const SizedBox(height: 12),

          _buildSettingsTile(
            icon: Icons.play_circle_outline,
            title: 'View App Tutorial',
            subtitle: 'Learn how to use the app',
            iconColor: AppColors.brandPurpleLight,
            showBadge: true,
            badgeText: 'GUIDE',
            onTap: () => _showTutorial(context),
          ),
          _buildSettingsTile(
            icon: Icons.quiz_outlined,
            title: 'FAQs',
            subtitle: 'Frequently asked questions',
            comingSoon: true,
          ),
          _buildSettingsTile(
            icon: Icons.support_agent,
            title: 'Contact Support',
            subtitle: 'Get help from our team',
            onTap: () => _openUrl(context, AppLinks.support),
          ),

          const SizedBox(height: 24),

          // ====================================================================
          // Privacy Section
          // ====================================================================
          _buildSectionHeader('Privacy & Safety'),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.block,
            title: 'Blocked Users',
            subtitle: 'Manage blocked users',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'View privacy policy',
            onTap: () => _openUrl(context, AppLinks.privacyPolicy),
          ),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'View terms and conditions',
            onTap: () => _openUrl(context, AppLinks.terms),
          ),

          const SizedBox(height: 24),

          // ====================================================================
          // Danger Zone
          // ====================================================================
          _buildSectionHeader('Danger Zone', isWarning: true),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            titleColor: Colors.red,
            onTap: () => _handleSignOut(context),
          ),
          _buildSettingsTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            titleColor: Colors.red,
            onTap: () => _deleteAccount(context),
          ),

          // Developer tools: debug builds only.
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Developer Options', isDev: true),
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.refresh,
              title: 'Reset Tutorial',
              subtitle: 'Show tutorial again on next visit',
              iconColor: Colors.grey,
              onTap: () => _resetTutorial(context),
            ),
            _buildSettingsTile(
              icon: Icons.bug_report,
              title: 'Debug Info',
              subtitle: 'View tour debug information',
              iconColor: Colors.grey,
              onTap: () => _showDebugInfo(context),
            ),
          ],

          const SizedBox(height: 40),

          // Version Info
          Center(
            child: Text(
              'AvailChat v1.0.0',
              style: TextStyle(
                color: AppColors.lavender.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ===========================================================================
  // Links
  // ===========================================================================

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    if (AppLinks.isPlaceholder(url)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This page is not available yet.')),
      );
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the page.')),
      );
    }
  }

  // ===========================================================================
  // Tutorial Methods
  // ===========================================================================

  /// Back to Home, which replays the tour on its own (live) context.
  void _showTutorial(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (!HomeOnboarding.requestReplay()) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Open Discover to view the tutorial.')),
      );
    }
  }

  /// Reset tutorial
  Future<void> _resetTutorial(BuildContext context) async {
    await HomeOnboarding.reset();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Tutorial has been reset and will show again!'),
              ),
            ],
          ),
          backgroundColor: AppColors.brandPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'VIEW NOW',
            textColor: Colors.white,
            onPressed: () {
              if (context.mounted) _showTutorial(context);
            },
          ),
        ),
      );
    }
  }

  /// Show debug info
  Future<void> _showDebugInfo(BuildContext context) async {
    final info = await TourPrefs.getDebugInfo();

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: const [
            Icon(Icons.bug_report, color: AppColors.brandPurpleLight),
            SizedBox(width: 12),
            Text(
              'Tour Debug Info',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundDeep,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: info.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: const TextStyle(color: AppColors.lavender),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${e.value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await TourPrefs.resetAll();
              messenger.showSnackBar(
                const SnackBar(content: Text('All tour data cleared!')),
              );
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.orange),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Account deletion (DEST-011)
  // ===========================================================================

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Delete Account',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'This permanently deletes your profile, photos, voice intro, game '
          'stats and sign-in. Messages you already sent stay in the other '
          'person\'s chat and show as "Deleted user". This cannot be undone.',
          style: TextStyle(color: AppColors.lavender, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final reauthed = await _reauthenticate(context);
    if (!reauthed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Deleting your account...',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await AccountDeletionService.deleteAccount();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account was deleted.')),
      );
    } on AccountDeletionException catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  /// Fresh sign-in required by the server. Returns false if cancelled.
  Future<bool> _reauthenticate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (AccountDeletionService.reauthMethod) {
        case ReauthMethod.password:
          final password = await _askPassword(context);
          if (password == null || password.isEmpty) return false;
          await AccountDeletionService.reauthenticateWithPassword(password);
          return true;
        case ReauthMethod.google:
          return await AccountDeletionService.reauthenticateWithGoogle();
        case ReauthMethod.none:
          // Unknown provider: the server still checks the sign-in age.
          return true;
      }
    } on AccountDeletionException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Confirm your password',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Password',
            hintStyle: TextStyle(color: AppColors.lavender),
          ),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text(
              'Delete my account',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  // ===========================================================================
  // UI Builders
  // ===========================================================================

  Widget _buildSectionHeader(String title, {bool isWarning = false, bool isDev = false}) {
    Color color = AppColors.lavender;
    if (isWarning) color = Colors.red;
    if (isDev) color = Colors.grey.withOpacity(0.5);

    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  /// [comingSoon] renders a disabled tile with a "SOON" badge.
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
    bool showBadge = false,
    String? badgeText,
    bool comingSoon = false,
    bool showChevron = true,
  }) {
    final enabled = !comingSoon;
    final badge = comingSoon ? 'SOON' : (showBadge ? badgeText : null);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.brandPurple.withOpacity(0.1),
          ),
        ),
        child: ListTile(
          enabled: enabled,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.brandPurple).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor ?? titleColor ?? AppColors.brandPurpleLight,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandPurple, AppColors.brandMagenta],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.lavender,
              fontSize: 12,
            ),
          ),
          trailing: enabled && showChevron && onTap != null
              ? Icon(
                  Icons.chevron_right,
                  color: titleColor ?? AppColors.lavender,
                )
              : null,
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}

/// Push and message notification switches, stored in
/// users/{uid}.notificationSettings (read by the push Functions). The push
/// switch also opts this device in or out of OneSignal.
class _NotificationSettingsTiles extends StatefulWidget {
  const _NotificationSettingsTiles();

  @override
  State<_NotificationSettingsTiles> createState() =>
      _NotificationSettingsTilesState();
}

class _NotificationSettingsTilesState
    extends State<_NotificationSettingsTiles> {
  static const String _field = 'notificationSettings';
  static const String _push = 'pushEnabled';
  static const String _messages = 'messageNotifications';

  bool? _pushEnabled;
  bool? _messagesEnabled;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var push = true;
    var messages = true;
    try {
      final settings = (await _ref?.get())?.data()?[_field];
      if (settings is Map) {
        push = settings[_push] != false;
        messages = settings[_messages] != false;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _pushEnabled = push;
      _messagesEnabled = messages;
    });
  }

  Future<void> _save(String key, bool value) async {
    final ref = _ref;
    if (ref == null || _saving) return;
    final previous = key == _push ? _pushEnabled : _messagesEnabled;
    setState(() {
      _saving = true;
      if (key == _push) {
        _pushEnabled = value;
      } else {
        _messagesEnabled = value;
      }
    });
    try {
      await ref.set({
        _field: {key: value},
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      if (key == _push) {
        try {
          if (value) {
            await OneSignal.User.pushSubscription.optIn();
          } else {
            await OneSignal.User.pushSubscription.optOut();
          }
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (key == _push) {
          _pushEnabled = previous;
        } else {
          _messagesEnabled = previous;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _switch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool? value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandPurple.withOpacity(0.1),
        ),
      ),
      child: SwitchListTile(
        value: value ?? true,
        onChanged: value == null || _saving ? null : onChanged,
        activeColor: AppColors.brandPurple,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.brandPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.brandPurpleLight, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.lavender, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pushOn = _pushEnabled ?? true;
    return Column(
      children: [
        _switch(
          icon: Icons.notifications,
          title: 'Push notifications',
          subtitle: 'Calls, messages and updates on this device',
          value: _pushEnabled,
          onChanged: (v) => _save(_push, v),
        ),
        _switch(
          icon: Icons.chat_bubble_outline,
          title: 'Message notifications',
          subtitle: 'Notify me about new chat messages',
          value: _messagesEnabled,
          onChanged: pushOn ? (v) => _save(_messages, v) : null,
        ),
      ],
    );
  }
}
