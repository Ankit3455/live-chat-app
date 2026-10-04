import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:availchat/screens/auth/login_screen.dart';
import '../../core/config/app_links.dart';
import '../../services/account_deletion_service.dart';
import '../../services/safety_service.dart';
import '../../services/session_service.dart';
import '../../widgets/app_states.dart';
import '../../widgets/custom_button.dart';
import '../settings/change_password_screen.dart';
import '../../features/onboarding/home_onboarding.dart';
import '../../features/onboarding/tour_prefs.dart';
import 'blocked_users_screen.dart';
import 'discovery_settings_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';

/// Shown in the footer; keep in step with pubspec `version`.
const String _appVersion = '1.0.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _handleSignOut(BuildContext context) async {
    Haptics.warning();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
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
            child: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.error),
            ),
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
    final hasPassword =
        currentUser?.providerData.any((p) => p.providerId == 'password') ??
            false;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(title: const Text('Settings')),
      // Cap width on tablets so rows aren't stretched.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            children: [
              const _GroupLabel('Account', first: true),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.mail_outline,
                    title: 'Email',
                    subtitle: currentUser?.email ?? 'Not available',
                  ),
                  if (hasPassword)
                    _SettingsRow(
                      icon: Icons.lock_outline,
                      title: 'Change password',
                      subtitle: 'Update the password you log in with',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                    ),
                  _SettingsRow(
                    icon: Icons.explore_outlined,
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
                ],
              ),
              const _GroupLabel('Notifications'),
              const _NotificationSettingsTiles(),
              const _GroupLabel('Help & support'),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.auto_awesome_outlined,
                    title: 'App tour',
                    subtitle: 'Replay the quick intro to Destined',
                    onTap: () => _showTutorial(context),
                  ),
                  _SettingsRow(
                    icon: Icons.support_agent,
                    title: 'Contact support',
                    subtitle: 'Get help from the Destined team',
                    onTap: () => _openUrl(context, AppLinks.support),
                  ),
                ],
              ),
              const _GroupLabel('Privacy & safety'),
              _SettingsGroup(
                children: [
                  const _BlockedUsersRow(),
                  _SettingsRow(
                    icon: Icons.shield_outlined,
                    title: 'Privacy Policy',
                    onTap: () => _openUrl(context, AppLinks.privacyPolicy),
                  ),
                  _SettingsRow(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () => _openUrl(context, AppLinks.terms),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.logout,
                    title: 'Sign out',
                    tone: _RowTone.neutral,
                    showChevron: false,
                    onTap: () => _handleSignOut(context),
                  ),
                  _SettingsRow(
                    icon: Icons.delete_outline,
                    title: 'Delete account',
                    subtitle: 'Permanently remove your profile',
                    tone: _RowTone.danger,
                    showChevron: false,
                    onTap: () => _deleteAccount(context),
                  ),
                ],
              ),

              // Developer tools: debug builds only.
              if (kDebugMode) ...[
                const _GroupLabel('Developer options'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.refresh,
                      title: 'Reset tutorial',
                      subtitle: 'Show tutorial again on next visit',
                      tone: _RowTone.neutral,
                      onTap: () => _resetTutorial(context),
                    ),
                    _SettingsRow(
                      icon: Icons.bug_report_outlined,
                      title: 'Debug info',
                      subtitle: 'View tour debug information',
                      tone: _RowTone.neutral,
                      onTap: () => _showDebugInfo(context),
                    ),
                  ],
                ),
              ],

              Padding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 40),
                child: Column(
                  children: [
                    Text(
                      'Destined',
                      style: GoogleFonts.montserrat(
                        color: AppColors.lavender,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'v$_appVersion',
                      style: TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        const SnackBar(
          content: Text("Couldn't open this page. Please try again later."),
        ),
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
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Tutorial reset. It will show again next time.'),
              ),
            ],
          ),
          backgroundColor: AppColors.brandPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'View now',
            textColor: AppColors.white,
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: AppColors.brandPurpleLight),
            SizedBox(width: 12),
            Flexible(child: Text('Tour debug info')),
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
                    Flexible(
                      child: Text(
                        e.key,
                        style: const TextStyle(color: AppColors.lavender),
                      ),
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
                          color: AppColors.white,
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
                const SnackBar(content: Text('All tour data cleared.')),
              );
            },
            child: const Text(
              'Clear all',
              style: TextStyle(color: AppColors.warning),
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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    Haptics.warning();
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) =>
          _DeleteAccountSheet(email: FirebaseAuth.instance.currentUser?.email),
    );
    if (deleted != true) return;
    unawaited(
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      ),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account was deleted.')),
    );
  }
}

/// Confirms deletion: re-authenticates (server needs a fresh sign-in), then
/// calls the deletion service. Pops `true` once the account is gone.
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.email});

  final String? email;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _password = TextEditingController();
  late final ReauthMethod _method = AccountDeletionService.reauthMethod;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_method == ReauthMethod.password && _password.text.isEmpty) {
      Haptics.error();
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_method) {
        case ReauthMethod.password:
          await AccountDeletionService.reauthenticateWithPassword(
            _password.text,
          );
          break;
        case ReauthMethod.google:
          final ok = await AccountDeletionService.reauthenticateWithGoogle();
          if (!ok) {
            if (mounted) setState(() => _busy = false);
            return;
          }
          break;
        case ReauthMethod.none:
          // Unknown provider: the server still checks the sign-in age.
          break;
      }
      await AccountDeletionService.deleteAccount();
      if (mounted) Navigator.of(context).pop(true);
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      Haptics.error();
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Widget _item(IconData icon, String bold, String rest, {bool keep = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 16,
              color: keep ? AppColors.textSubtle : AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (bold.isNotEmpty)
                    TextSpan(
                      text: '$bold ',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  TextSpan(text: rest),
                ],
              ),
              style: TextStyle(
                color: keep ? AppColors.lavender : AppColors.lavenderLight,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    final emailText = (email == null || email.isEmpty) ? 'this account' : email;
    final error = _error;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withOpacity(0.14),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  'Delete your account?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "This can't be undone.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.lavender, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _item(
                      Icons.block,
                      'Your profile',
                      'and answers are removed from Discover',
                    ),
                    _item(
                      Icons.block,
                      'Your photos',
                      'and voice intro are deleted',
                    ),
                    _item(
                      Icons.block,
                      'Logging in',
                      'stops working for $emailText',
                    ),
                    const Divider(height: 12),
                    _item(
                      Icons.chat_bubble_outline,
                      '',
                      'Messages you already sent stay in other people\'s '
                          'chats, shown from "Deleted user".',
                      keep: true,
                    ),
                  ],
                ),
              ),
              if (_method == ReauthMethod.password) ...[
                const SizedBox(height: 16),
                const Text(
                  'Enter your password to confirm',
                  style: TextStyle(color: AppColors.lavender, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.password],
                  style: const TextStyle(color: AppColors.white, fontSize: 15),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ],
              AnimatedSwitcher(
                duration: duration,
                child: error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(error),
                        padding: const EdgeInsets.only(top: 12),
                        child: AppBanner(
                          message: error,
                          tone: AppBannerTone.error,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.backgroundDeep,
                    disabledBackgroundColor: AppColors.error.withOpacity(0.6),
                    disabledForegroundColor: AppColors.backgroundDeep,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: duration,
                    child: _busy
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              semanticsLabel: 'Deleting account',
                              color: AppColors.backgroundDeep,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Delete my account',
                            key: const ValueKey('idle'),
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CustomButton(
                text: 'Cancel',
                type: ButtonType.text,
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Grouped rows
// =============================================================================

enum _RowTone { normal, neutral, danger }

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, first ? 12 : 24, 8, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSubtle,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// Inset card; rows are separated by hairlines that start after the icon.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, thickness: 1, indent: 64));
      }
      rows.add(children[i]);
    }
    return Material(
      color: AppColors.surfaceCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(children: rows),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone = _RowTone.normal,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final _RowTone tone;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final Color tileColor;
    switch (tone) {
      case _RowTone.normal:
        iconColor = AppColors.brandPurpleLight;
        tileColor = AppColors.brandPurpleMid.withOpacity(0.16);
        break;
      case _RowTone.neutral:
        iconColor = AppColors.lavender;
        tileColor = AppColors.surface2;
        break;
      case _RowTone.danger:
        iconColor = AppColors.error;
        tileColor = AppColors.error.withOpacity(0.14);
        break;
    }
    final sub = subtitle;
    final extra = trailing;
    final tappable = onTap != null;

    // Switch rows expose toggle state via MergeSemantics instead.
    return Semantics(
      button: tappable && extra is! Switch,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: tone == _RowTone.danger
                              ? AppColors.error
                              : AppColors.white,
                          fontSize: 15,
                          fontWeight: tone == _RowTone.danger
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.lavender,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (extra != null) ...[const SizedBox(width: 8), extra],
                if (tappable && showChevron && extra is! Switch)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textSubtle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocked users row with the live count from SafetyService.
class _BlockedUsersRow extends StatefulWidget {
  const _BlockedUsersRow();

  @override
  State<_BlockedUsersRow> createState() => _BlockedUsersRowState();
}

class _BlockedUsersRowState extends State<_BlockedUsersRow> {
  late final Stream<List<BlockedUser>?> _stream =
      SafetyService.instance.watchBlockedUsers();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BlockedUser>?>(
      stream: _stream,
      builder: (context, snapshot) {
        final list = snapshot.hasError ? null : snapshot.data;
        final count = list?.length ?? 0;
        return _SettingsRow(
          icon: Icons.block,
          title: 'Blocked users',
          subtitle: "They can't see or message you",
          trailing: count > 0
              ? Text(
                  '$count',
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 14,
                  ),
                )
              : null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
            );
          },
        );
      },
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
    Haptics.selection();
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
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't save your notification setting. Check your connection and try again.",
          ),
        ),
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
    final current = value ?? true;
    final handler = value == null || _saving ? null : onChanged;
    return MergeSemantics(
      child: _SettingsRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: handler == null ? null : () => handler(!current),
        trailing: Switch(value: current, onChanged: handler),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pushOn = _pushEnabled ?? true;
    return _SettingsGroup(
      children: [
        _switch(
          icon: Icons.notifications_none,
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
