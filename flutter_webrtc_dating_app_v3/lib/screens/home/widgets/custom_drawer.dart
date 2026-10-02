// import 'package:flutter/material.dart';
// import '../../../features/onboarding/tour_prefs.dart';
// import '../../profile/profile_screen.dart';
// import '../../../models/user_model.dart';
// import '../../settings/discovery_settings_screen.dart';
//
// class CustomDrawer extends StatelessWidget {
//   final UserModel? currentUser;
//   final VoidCallback onSignOut;
//   final VoidCallback onAstrologyTap;
//
//   const CustomDrawer({
//     Key? key,
//     required this.currentUser,
//     required this.onSignOut,
//     required this.onAstrologyTap,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final username = (currentUser?.username ?? '').trim();
//     final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';
//
//     return Drawer(
//       backgroundColor: const Color(0xFF2D1B4E),
//       child: SafeArea(
//         child: Column(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     const Color(0xFF7B2CBF),
//                     const Color(0xFF7B2CBF).withOpacity(0.5),
//                   ],
//                 ),
//               ),
//               child: Column(
//                 children: [
//                   CircleAvatar(
//                     radius: 50,
//                     backgroundColor: Colors.white,
//                     child: Text(
//                       initial,
//                       style: const TextStyle(
//                         fontSize: 40,
//                         fontWeight: FontWeight.bold,
//                         color: Color(0xFF7B2CBF),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     username.isNotEmpty ? username : 'User',
//                     style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold),
//                   ),
//                   if ((currentUser?.profession ?? '').trim().isNotEmpty)
//                     Text(
//                       currentUser!.profession!,
//                       style: const TextStyle(
//                         color: Color(0xFFB39DDB),
//                         fontSize: 14,
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: ListView(
//                 padding: EdgeInsets.zero,
//                 children: [
//                   ListTile(
//                     leading: const Icon(Icons.auto_awesome, color: Color(0xFFFFD700)),
//                     title: const Text('Astrology Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
//                     subtitle: const Text('Enhance cosmic compatibility', style: TextStyle(color: Color(0xFFB39DDB), fontSize: 12)),
//                     trailing: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF7B2CBF),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
//                     ),
//                     onTap: () {
//                       Navigator.pop(context);
//                       onAstrologyTap();
//                     },
//                   ),
//                   const Divider(color: Color(0xFF7B2CBF), thickness: 0.5),
//                   ListTile(
//                     leading: const Icon(Icons.tune, color: Colors.white),
//                     title: const Text('Discovery Settings', style: TextStyle(color: Colors.white)),
//                     onTap: () {
//                       Navigator.pop(context);
//                       Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverySettingsScreen()));
//                     },
//                   ),
//                   ListTile(
//                     leading: const Icon(Icons.person, color: Color(0xFFB39DDB)),
//                     title: const Text('My Profile', style: TextStyle(color: Colors.white)),
//                     onTap: () {
//                       Navigator.pop(context);
//                       Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
//                     },
//                   ),
//                   ListTile(
//                     leading: const Icon(Icons.settings, color: Color(0xFFB39DDB)),
//                     title: const Text('Settings', style: TextStyle(color: Colors.white)),
//                     onTap: () => Navigator.pop(context),
//                   ),
//                   ListTile(
//                     leading: const Icon(Icons.help_outline, color: Color(0xFFB39DDB)),
//                     title: const Text('Help & Support', style: TextStyle(color: Colors.white)),
//                     onTap: () => Navigator.pop(context),
//                   ),
//                   const Divider(color: Color(0xFF7B2CBF), thickness: 0.5),
//                   // Add in drawer items list (for testing only)
//                   ListTile(
//                     leading: const Icon(Icons.refresh, color: Colors.white70),
//                     title: const Text('Reset Tutorial', style: TextStyle(color: Colors.white70)),
//                     onTap: () async {
//                       await TourPrefs.resetAll();
//                       Navigator.pop(context);
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text('Tutorial reset! Restart app to see it again.')),
//                       );
//                     },
//                   ),
//                   ListTile(
//                     leading: const Icon(Icons.logout, color: Colors.redAccent),
//                     title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
//                     onTap: () {
//                       Navigator.pop(context);
//                       onSignOut();
//                     },
//                   ),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Text(
//                 'Version 1.0.0',
//                 style: TextStyle(color: const Color(0xFFB39DDB).withOpacity(0.5), fontSize: 12),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import '../../../features/onboarding/home_onboarding.dart';
import '../../../features/onboarding/tour_prefs.dart';
import '../../profile/profile_screen.dart';
import '../../../models/user_model.dart';
import '../../settings/discovery_settings_screen.dart';
import '../../settings/settings_screen.dart';

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
            // Header Section
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
                      fontWeight: FontWeight.bold,
                    ),
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

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Astrology Profile
                  ListTile(
                    leading: const Icon(Icons.auto_awesome, color: Color(0xFFFFD700)),
                    title: const Text(
                      'Astrology Profile',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Enhance cosmic compatibility',
                      style: TextStyle(color: Color(0xFFB39DDB), fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2CBF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onAstrologyTap();
                    },
                  ),

                  const Divider(color: Color(0xFF7B2CBF), thickness: 0.5),

                  // Discovery Settings
                  ListTile(
                    leading: const Icon(Icons.tune, color: Colors.white),
                    title: const Text(
                      'Discovery Settings',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DiscoverySettingsScreen()),
                      );
                    },
                  ),

                  // My Profile
                  ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFFB39DDB)),
                    title: const Text(
                      'My Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),

                  // Settings
                  ListTile(
                    leading: const Icon(Icons.settings, color: Color(0xFFB39DDB)),
                    title: const Text(
                      'Settings',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),

                  const Divider(color: Color(0xFF7B2CBF), thickness: 0.5),

                  // ============================================================
                  // 🆕 APP TUTORIAL - View Tutorial Again
                  // ============================================================
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2CBF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Color(0xFF7B2CBF),
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'App Tutorial',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Learn how to use the app',
                      style: TextStyle(color: Color(0xFFB39DDB), fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFFB39DDB),
                      size: 16,
                    ),
                    onTap: () => _showTutorial(context),
                  ),

                  // Help & Support
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: Color(0xFFB39DDB)),
                    title: const Text(
                      'Help & Support',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showHelpDialog(context);
                    },
                  ),

                  const Divider(color: Color(0xFF7B2CBF), thickness: 0.5),

                  // Sign Out
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onSignOut();
                    },
                  ),

                  // ============================================================
                  // 🔧 DEBUG ONLY - Reset Tutorial (Remove in Production)
                  // ============================================================
                  const SizedBox(height: 20),
                  const Divider(color: Colors.grey, thickness: 0.3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Developer Options',
                      style: TextStyle(
                        color: Colors.grey.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.refresh,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    title: Text(
                      'Reset Tutorial',
                      style: TextStyle(color: Colors.grey.withOpacity(0.5)),
                    ),
                    onTap: () => _resetTutorial(context),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.bug_report,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    title: Text(
                      'Debug Tour Info',
                      style: TextStyle(color: Colors.grey.withOpacity(0.5)),
                    ),
                    onTap: () => _showDebugInfo(context),
                  ),
                ],
              ),
            ),

            // Version Footer
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: const Color(0xFFB39DDB).withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Tutorial Methods
  // ===========================================================================

  /// Show tutorial from drawer
  void _showTutorial(BuildContext context) {
    Navigator.pop(context); // Close drawer first

    // Small delay to let drawer close
    Future.delayed(const Duration(milliseconds: 300), () {
      if (context.mounted) {
        HomeOnboarding.showManually(context);
      }
    });
  }

  /// Reset tutorial (for testing)
  Future<void> _resetTutorial(BuildContext context) async {
    Navigator.pop(context);

    await HomeOnboarding.reset();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Tutorial reset! It will show again.'),
            ],
          ),
          backgroundColor: const Color(0xFF7B2CBF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'SHOW NOW',
            textColor: Colors.white,
            onPressed: () {
              HomeOnboarding.showManually(context);
            },
          ),
        ),
      );
    }
  }

  /// Show debug info (for development)
  Future<void> _showDebugInfo(BuildContext context) async {
    final info = await TourPrefs.getDebugInfo();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        title: const Text(
          'Tour Debug Info',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: info.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(color: Color(0xFFB39DDB)),
                  ),
                  Text(
                    '${e.value}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show help dialog
  void _showHelpDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D1B4E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B2CBF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.help_outline,
                    color: Color(0xFF7B2CBF),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Help & Support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Options
            _buildHelpOption(
              context,
              icon: Icons.play_circle_outline,
              title: 'Watch App Tutorial',
              subtitle: 'Learn how to use AvailChat',
              onTap: () {
                Navigator.pop(context);
                _showTutorial(context);
              },
            ),
            _buildHelpOption(
              context,
              icon: Icons.chat_bubble_outline,
              title: 'Contact Support',
              subtitle: 'Get help from our team',
              onTap: () {
                Navigator.pop(context);
                // TODO: Open support chat or email
              },
            ),
            _buildHelpOption(
              context,
              icon: Icons.description_outlined,
              title: 'FAQs',
              subtitle: 'Frequently asked questions',
              onTap: () {
                Navigator.pop(context);
                // TODO: Open FAQs
              },
            ),
            _buildHelpOption(
              context,
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              subtitle: 'Help us improve',
              onTap: () {
                Navigator.pop(context);
                // TODO: Open bug report
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOption(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7B2CBF).withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF7B2CBF)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
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
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFFB39DDB),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}