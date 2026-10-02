// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../../bottom_navigation/managers/firestore_manager.dart';
// import '../../core/constants/app_colors.dart';
// import '../../services/chat_service.dart';
// import '../../services/auth_service.dart';
// import '../chat/chat_screen.dart';
//
// import 'widgets/custom_drawer.dart';
// import 'widgets/profile_bubble.dart';
// import 'widgets/profile_completion_banner.dart';
// import 'widgets/profile_bubble_grid_item.dart';
// import 'home_logic.dart';
// import 'package:badges/badges.dart' as badges;
// import '../../managers/unread_manager.dart';
// import '../../widgets/shimmers/shimmer_bubble.dart';
//
// class HomeUI extends StatefulWidget {
//   const HomeUI({Key? key}) : super(key: key);
//
//   @override
//   State<HomeUI> createState() => _HomeUIState();
// }
//
// class _HomeUIState extends State<HomeUI> {
//   bool _showProfileCompletion = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUsers();
//     // ⛔️ UnreadManager को यहाँ new मत करो; Provider में main.dart पर init() already होता है
//     // context.read<UnreadManager>().init(); // सिर्फ तब कॉल करें जब main में init() न कर रहे हों
//   }
//
//   Future<void> _loadUsers() async {
//     final manager = context.read<FirestoreManager>();
//     await manager.loadUsers(context);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<FirestoreManager>(
//       builder: (context, manager, child) {
//         return Scaffold(
//           backgroundColor: AppColors.appBackground,
//           drawer: _buildDrawer(manager),
//           appBar: _buildAppBar(),
//           body: _buildBody(manager),
//           floatingActionButton: _buildFAB(),
//         );
//       },
//     );
//   }
//
//   // ===========================================================
//   // APP BAR
//   // ===========================================================
//
//   PreferredSizeWidget _buildAppBar() {
//     // 🔔 Provider से unread पढ़ो
//     final unreadTotal = context.watch<UnreadManager>().totalUnread;
//
//     final notifButton = IconButton(
//       icon: const Icon(Icons.notifications, color: Colors.white),
//       onPressed: _handleNotifications,
//     );
//
//     return AppBar(
//       backgroundColor: AppColors.purplePrimary,
//       title: const Text('Discover', style: TextStyle(color: Colors.white)),
//       elevation: 0,
//       actions: [
//         // unread badge on notifications
//         if (unreadTotal > 0)
//           badges.Badge(
//             position: badges.BadgePosition.topEnd(top: 6, end: 6),
//             badgeContent: Text(
//               unreadTotal > 99 ? '99+' : '$unreadTotal',
//               style: const TextStyle(
//                   color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
//             ),
//             child: notifButton,
//           )
//         else
//           notifButton,
//
//         IconButton(
//           icon: const Icon(Icons.filter_list, color: Colors.white),
//           onPressed: _handleFilterSettings,
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDrawer(FirestoreManager manager) {
//     return CustomDrawer(
//       currentUser: manager.currentUser,
//       onSignOut: _handleSignOut,
//       onAstrologyTap: _handleAstrologyTap,
//     );
//   }
//
//   // ===========================================================
//   // BODY
//   // ===========================================================
//
//   Widget _buildBody(FirestoreManager manager) {
//     if (manager.isLoading) {
//       return Column(
//         children: const [
//           SizedBox(height: 8),
//           ShimmerBubbleStrip(),
//           Expanded(child: ShimmerBubbleGrid()),
//         ],
//       );
//     }
//
//     if (manager.error != null) {
//       return _buildErrorState(manager.error!);
//     }
//
//     if (manager.filteredUsers.isEmpty) {
//       return _buildEmptyState();
//     }
//
//     return RefreshIndicator(
//       onRefresh: _loadUsers,
//       color: AppColors.purplePrimary,
//       child: Column(
//         children: [
//           if (_showProfileCompletion &&
//               manager.currentUser != null &&
//               (manager.currentUser!.profileCompletionPercentage ?? 100) < 100)
//             ProfileCompletionBanner(
//               completionPercentage:
//               manager.currentUser!.profileCompletionPercentage ?? 65,
//               onDismiss: () => setState(() => _showProfileCompletion = false),
//             ),
//
//           if (manager.getTopUsers(limit: 10).isNotEmpty) ...[
//             const SizedBox(height: 6),
//             SizedBox(
//               height: 118,
//               child: ListView.separated(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 itemCount: manager.getTopUsers(limit: 10).length,
//                 separatorBuilder: (_, __) => const SizedBox(width: 16),
//                 itemBuilder: (context, index) {
//                   final user = manager.getTopUsers(limit: 10)[index];
//                   return ProfileBubbleGridItem(
//                     user: user,
//                     onTap: () => _handleUserTap(user),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 8),
//           ],
//
//           Expanded(
//             child: GridView.builder(
//               padding: const EdgeInsets.only(top: 10, bottom: 100),
//               itemCount: manager.filteredUsers.length,
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 3,
//                 mainAxisSpacing: 18,
//                 crossAxisSpacing: 18,
//                 childAspectRatio: 0.82,
//               ),
//               itemBuilder: (context, index) {
//                 final user = manager.filteredUsers[index];
//                 return Center(
//                   child: ProfileBubbleGridItem(
//                     user: user,
//                     onTap: () => _handleUserTap(user),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ===========================================================
//   // STATES
//   // ===========================================================
//
//   Widget _buildErrorState(String error) => Center(
//     child: Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(Icons.error_outline, size: 64, color: AppColors.dangerRed),
//         const SizedBox(height: 16),
//         Text(error, style: TextStyle(color: AppColors.hintPurple)),
//         const SizedBox(height: 16),
//         ElevatedButton(
//           onPressed: _loadUsers,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: AppColors.purplePrimary,
//           ),
//           child: const Text('Retry'),
//         ),
//       ],
//     ),
//   );
//
//   Widget _buildEmptyState() => Center(
//     child: Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(Icons.person_search, size: 64, color: AppColors.hintPurple),
//         const SizedBox(height: 16),
//         const Text('No users found',
//             style: TextStyle(fontSize: 18, color: Colors.white)),
//         const SizedBox(height: 6),
//         Text('Try adjusting your filters',
//             style: TextStyle(fontSize: 14, color: AppColors.hintPurple)),
//       ],
//     ),
//   );
//
//   // ===========================================================
//   // FAB
//   // ===========================================================
//
//   Widget _buildFAB() => FloatingActionButton(
//     backgroundColor: AppColors.purplePrimary,
//     onPressed: _handleExplore,
//     child: const Icon(Icons.explore),
//   );
//
//   // ===========================================================
//   // HANDLERS
//   // ===========================================================
//
//   Future<void> _handleUserTap(user) async {
//     if (user.uid == null || user.uid!.isEmpty) {
//       _showSnackBar('Cannot interact with this user');
//       return;
//     }
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) =>
//           Center(child: CircularProgressIndicator(color: AppColors.purplePrimary)),
//     );
//
//     try {
//       final chatService = ChatService();
//       final conversationId =
//       await chatService.getOrCreateConversation(user.uid!);
//
//       if (!mounted) return;
//       Navigator.pop(context);
//
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) =>
//               ChatScreen(otherUserId: user.uid!, conversationId: conversationId),
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       Navigator.pop(context);
//       _showSnackBar('Failed to open chat: $e');
//     }
//   }
//
//   void _handleNotifications() => debugPrint('Notifications tapped');
//   void _handleFilterSettings() => debugPrint('Filter settings tapped');
//   void _handleExplore() => debugPrint('Explore tapped');
//
//   Future<void> _handleSignOut() async {
//     try {
//       final authService = context.read<AuthService>();
//       await authService.signOut();
//       if (!mounted) return;
//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       _showSnackBar('Sign out failed: $e');
//     }
//   }
//
//   void _handleAstrologyTap() => debugPrint('Astrology tapped');
//
//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: AppColors.purplePrimary),
//     );
//   }
// }
