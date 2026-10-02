// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// import 'package:availchat/services/auth_service.dart';
// import 'package:availchat/screens/auth/login_screen.dart';
// import '../settings/change_password_screen.dart';
//
// class SettingsScreen extends StatelessWidget {
//   const SettingsScreen({Key? key}) : super(key: key);
//
//   Future<void> _handleSignOut(BuildContext context) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF2D1B4E),
//         title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
//         content: const Text(
//           'Are you sure you want to sign out?',
//           style: TextStyle(color: Color(0xFFB39DDB)),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm == true) {
//       await context.read<AuthService>().signOut();
//       if (context.mounted) {
//         Navigator.of(context).pushAndRemoveUntil(
//           MaterialPageRoute(builder: (_) => const LoginScreen()),
//               (route) => false,
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final currentUser = FirebaseAuth.instance.currentUser;
//
//     return Scaffold(
//       backgroundColor: const Color(0xFF1A0E2E),
//       appBar: AppBar(
//         title: const Text('Settings'),
//         backgroundColor: const Color(0xFF2D1B4E),
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16.0),
//         children: [
//           // Account Section
//           const Text(
//             'Account',
//             style: TextStyle(
//               color: Color(0xFFB39DDB),
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           _buildSettingsTile(
//             icon: Icons.email,
//             title: 'Email',
//             subtitle: currentUser?.email ?? 'Not available',
//             onTap: () {},
//           ),
//           _buildSettingsTile(
//             icon: Icons.lock,
//             title: 'Change Password',
//             subtitle: 'Update your password',
//             onTap: () {
//               Navigator.of(context).push(
//                 MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
//               );
//             },
//           ),
//
//           const SizedBox(height: 24),
//
//           // Preferences Section
//           const Text(
//             'Preferences',
//             style: TextStyle(
//               color: Color(0xFFB39DDB),
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           _buildSettingsTile(
//             icon: Icons.notifications,
//             title: 'Notifications',
//             subtitle: 'Manage notification settings',
//             onTap: () {
//               // TODO: Navigate to notification settings
//             },
//           ),
//           _buildSettingsTile(
//             icon: Icons.language,
//             title: 'Language',
//             subtitle: 'English',
//             onTap: () {
//               // TODO: Navigate to language settings
//             },
//           ),
//
//           const SizedBox(height: 24),
//
//           // Privacy Section
//           const Text(
//             'Privacy & Safety',
//             style: TextStyle(
//               color: Color(0xFFB39DDB),
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           _buildSettingsTile(
//             icon: Icons.block,
//             title: 'Blocked Users',
//             subtitle: 'Manage blocked users',
//             onTap: () {
//               // TODO: Navigate to blocked users
//             },
//           ),
//           _buildSettingsTile(
//             icon: Icons.privacy_tip,
//             title: 'Privacy Policy',
//             subtitle: 'View privacy policy',
//             onTap: () {
//               // TODO: Show privacy policy
//             },
//           ),
//
//           const SizedBox(height: 24),
//
//           // Danger Zone
//           const Text(
//             'Danger Zone',
//             style: TextStyle(
//               color: Colors.red,
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           _buildSettingsTile(
//             icon: Icons.logout,
//             title: 'Sign Out',
//             subtitle: 'Sign out of your account',
//             titleColor: Colors.red,
//             onTap: () => _handleSignOut(context),
//           ),
//           _buildSettingsTile(
//             icon: Icons.delete_forever,
//             title: 'Delete Account',
//             subtitle: 'Permanently delete your account',
//             titleColor: Colors.red,
//             onTap: () {
//               // TODO: Navigate to delete account
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSettingsTile({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required VoidCallback onTap,
//     Color? titleColor,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF2D1B4E),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: ListTile(
//         leading: Icon(icon, color: titleColor ?? const Color(0xFF7B2CBF)),
//         title: Text(
//           title,
//           style: TextStyle(
//             color: titleColor ?? Colors.white,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         subtitle: Text(
//           subtitle,
//           style: const TextStyle(
//             color: Color(0xFFB39DDB),
//             fontSize: 12,
//           ),
//         ),
//         trailing: const Icon(Icons.chevron_right, color: Color(0xFFB39DDB)),
//         onTap: onTap,
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:availchat/services/auth_service.dart';
import 'package:availchat/screens/auth/login_screen.dart';
import '../settings/change_password_screen.dart';
import '../../features/onboarding/home_onboarding.dart';
import '../../features/onboarding/tour_prefs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Color(0xFFB39DDB)),
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
      await context.read<AuthService>().signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF2D1B4E),
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
            onTap: () {},
          ),
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

          const SizedBox(height: 24),

          // ====================================================================
          // Preferences Section
          // ====================================================================
          _buildSectionHeader('Preferences'),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Manage notification settings',
            onTap: () {
              // TODO: Navigate to notification settings
            },
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English',
            onTap: () {
              // TODO: Navigate to language settings
            },
          ),

          const SizedBox(height: 24),

          // ====================================================================
          // 🆕 Help & Tutorial Section
          // ====================================================================
          _buildSectionHeader('Help & Tutorial'),
          const SizedBox(height: 12),

          // View App Tutorial
          _buildSettingsTile(
            icon: Icons.play_circle_outline,
            title: 'View App Tutorial',
            subtitle: 'Learn how to use AvailChat',
            iconColor: const Color(0xFF7B2CBF),
            showBadge: true,
            badgeText: 'GUIDE',
            onTap: () => _showTutorial(context),
          ),

          // FAQ
          _buildSettingsTile(
            icon: Icons.quiz_outlined,
            title: 'FAQs',
            subtitle: 'Frequently asked questions',
            onTap: () {
              // TODO: Navigate to FAQ
            },
          ),

          // Contact Support
          _buildSettingsTile(
            icon: Icons.support_agent,
            title: 'Contact Support',
            subtitle: 'Get help from our team',
            onTap: () {
              // TODO: Navigate to support
            },
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
              // TODO: Navigate to blocked users
            },
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'View privacy policy',
            onTap: () {
              // TODO: Show privacy policy
            },
          ),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'View terms and conditions',
            onTap: () {
              // TODO: Show terms
            },
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
            onTap: () => _showDeleteAccountDialog(context),
          ),

          const SizedBox(height: 24),

          // ====================================================================
          // 🔧 Developer Options (Remove in Production)
          // ====================================================================
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

          const SizedBox(height: 40),

          // Version Info
          Center(
            child: Text(
              'AvailChat v1.0.0',
              style: TextStyle(
                color: const Color(0xFFB39DDB).withOpacity(0.5),
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
  // Tutorial Methods
  // ===========================================================================

  /// Show tutorial
  void _showTutorial(BuildContext context) {
    // Pop back to home screen first
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Small delay then show tutorial
    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        HomeOnboarding.showManually(context);
      }
    });
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
          backgroundColor: const Color(0xFF7B2CBF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'VIEW NOW',
            textColor: Colors.white,
            onPressed: () => _showTutorial(context),
          ),
        ),
      );
    }
  }

  /// Show debug info
  Future<void> _showDebugInfo(BuildContext context) async {
    final info = await TourPrefs.getDebugInfo();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: const [
            Icon(Icons.bug_report, color: Color(0xFF7B2CBF)),
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
            color: const Color(0xFF1A0E2E),
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
                      style: const TextStyle(color: Color(0xFFB39DDB)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2CBF).withOpacity(0.2),
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
              await TourPrefs.resetAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All tour data cleared!')),
              );
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.orange),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show delete account dialog
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
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
          'Are you sure you want to permanently delete your account? '
              'This action cannot be undone and all your data will be lost.',
          style: TextStyle(color: Color(0xFFB39DDB), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion coming soon'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI Builders
  // ===========================================================================

  Widget _buildSectionHeader(String title, {bool isWarning = false, bool isDev = false}) {
    Color color = const Color(0xFFB39DDB);
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

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
    bool showBadge = false,
    String? badgeText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7B2CBF).withOpacity(0.1),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? const Color(0xFF7B2CBF)).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor ?? titleColor ?? const Color(0xFF7B2CBF),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: titleColor ?? Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showBadge && badgeText != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
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
            color: Color(0xFFB39DDB),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: titleColor ?? const Color(0xFFB39DDB),
        ),
        onTap: onTap,
      ),
    );
  }
}