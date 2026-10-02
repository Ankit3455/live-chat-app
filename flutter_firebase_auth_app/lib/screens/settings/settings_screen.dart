import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/services/auth_service.dart';
import 'package:availchat/screens/auth/login_screen.dart';

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
      await AuthService().signOut();
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Account Section
          const Text(
            'Account',
            style: TextStyle(
              color: Color(0xFFB39DDB),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
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
              // TODO: Navigate to change password screen
            },
          ),

          const SizedBox(height: 24),

          // Preferences Section
          const Text(
            'Preferences',
            style: TextStyle(
              color: Color(0xFFB39DDB),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
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

          // Privacy Section
          const Text(
            'Privacy & Safety',
            style: TextStyle(
              color: Color(0xFFB39DDB),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
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

          const SizedBox(height: 24),

          // Danger Zone
          const Text(
            'Danger Zone',
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            onTap: () {
              // TODO: Navigate to delete account
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? const Color(0xFF7B2CBF)),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFB39DDB),
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFB39DDB)),
        onTap: onTap,
      ),
    );
  }
}