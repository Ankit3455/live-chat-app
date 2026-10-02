import 'package:flutter/material.dart';
import '../../profile/profile_screen.dart';
import '../../../models/user_model.dart';
import '../../settings/discovery_settings_screen.dart';

class CustomDrawer extends StatelessWidget {
  final UserModel? currentUser;
  final VoidCallback onSignOut;
  final VoidCallback onAstrologyTap;

  const CustomDrawer({
    Key? key,
    required this.currentUser,
    required this.onSignOut,
    required this.onAstrologyTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final username = (currentUser?.username ?? '').trim();
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    return Drawer(
      backgroundColor: const Color(0xFF2D1B4E),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7B2CBF),
                    const Color(0xFF7B2CBF).withOpacity(0.5),
                  ],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B2CBF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    username.isNotEmpty ? username : 'User',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  if ((currentUser?.profession ?? '').trim().isNotEmpty)
                    Text(
                      currentUser!.profession!,
                      style: const TextStyle(
                        color: Color(0xFFB39DDB),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.auto_awesome, color: Color(0xFFFFD700)),
                    title: const Text('Astrology Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Enhance cosmic compatibility', style: TextStyle(color: Color(0xFFB39DDB), fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2CBF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onAstrologyTap();
                    },
                  ),
                  const Divider(color: Color(0xFF7B2CBF), thickness: 0.5),
                  ListTile(
                    leading: const Icon(Icons.tune, color: Colors.white),
                    title: const Text('Discovery Settings', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverySettingsScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFFB39DDB)),
                    title: const Text('My Profile', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Color(0xFFB39DDB)),
                    title: const Text('Settings', style: TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: Color(0xFFB39DDB)),
                    title: const Text('Help & Support', style: TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context),
                  ),
                  const Divider(color: Color(0xFF7B2CBF), thickness: 0.5),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(context);
                      onSignOut();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: const Color(0xFFB39DDB).withOpacity(0.5), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
