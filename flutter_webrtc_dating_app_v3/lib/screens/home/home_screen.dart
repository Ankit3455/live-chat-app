// import 'dart:async';
// import 'dart:math' as math;
//
// import 'package:availchat/core/constants/app_colors.dart';
// import 'package:availchat/managers/filter_preferences.dart';
// import 'package:availchat/managers/profile_completion_manager.dart';
// import 'package:availchat/managers/unread_manager.dart';
// import 'package:availchat/models/user_model.dart';
// import 'package:availchat/screens/auth/login_screen.dart';
// import 'package:availchat/screens/astrology/astrology_questionnaire_screen.dart';
// import 'package:availchat/screens/chat/chat_list_screen.dart';
// import 'package:availchat/screens/chat/chat_screen.dart';
// import 'package:availchat/screens/home/widgets/custom_bottom_nav.dart';
// import 'package:availchat/screens/profile/profile_screen.dart';
// import 'package:availchat/screens/settings/discovery_settings_screen.dart';
// import 'package:availchat/screens/home/widgets/custom_drawer.dart';
// import 'package:availchat/screens/home/widgets/profile_bubble.dart';
// import 'package:availchat/screens/home/widgets/profile_card.dart';
// import 'package:availchat/screens/home/widgets/profile_completion_banner.dart';
//
// // Onboarding
// import '../../features/onboarding/home_onboarding.dart';
// import '../../features/onboarding/tour_prefs.dart';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:lottie/lottie.dart';
// import 'package:provider/provider.dart';
// import '../../feature/games/map_runner/game_screen.dart';
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;
//   final _searchController = TextEditingController();
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   StreamSubscription<QuerySnapshot>? _usersSubscription;
//
//   List<UserModel> _allUsers = [];
//   List<UserModel> _displayedUsers = [];
//   UserModel? _currentUser;
//   bool _isLoading = true;
//
//   // Banner state
//   int _profileCompletionPercentage = 100;
//   bool _showBanner = false;
//   bool _bannerDismissed = false;
//
//   // Discovery filters
//   bool _prefDiscoveryEnabled = true; // distance filter control
//   String _prefShowMeGender = 'everyone';
//   int _prefAgeMin = 18;
//   int _prefAgeMax = 60;
//   int _prefDistanceKm = 50;
//   bool _prefOnlineOnly = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUsers();
//     _loadFilters();
//     _searchController.addListener(_onSearchChanged);
//     _checkProfileCompletion();
//
//     // Trigger onboarding after first frame & data load
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _triggerOnboardingIfNeeded();
//     });
//   }
//
//   Future<void> _triggerOnboardingIfNeeded() async {
//     // Wait a bit for Firestore stream + filters to populate
//     await Future.delayed(const Duration(seconds: 2));
//
//     if (!mounted || _displayedUsers.isEmpty) return;
//
//     await HomeOnboarding.tryShow(context);
//   }
//
//   @override
//   void dispose() {
//     _usersSubscription?.cancel();
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   // ----------------------------
//   // Filter summary (chips)
//   // ----------------------------
//   Widget _buildFilterSummary() {
//     String genderLabel = {
//       'everyone': 'Everyone',
//       'male': 'Men',
//       'female': 'Women',
//     }[_prefShowMeGender] ??
//         'Everyone';
//
//     final chips = <String>[
//       genderLabel,
//       '${_prefAgeMin}-${_prefAgeMax}',
//       '${_prefDistanceKm} km',
//       if (_prefOnlineOnly) 'Online only',
//     ];
//
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: const Color(0xFF2D1B4E).withOpacity(0.6),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.3)),
//       ),
//       child: Wrap(
//         spacing: 8,
//         runSpacing: 6,
//         crossAxisAlignment: WrapCrossAlignment.center,
//         children: chips
//             .map(
//               (c) => Container(
//             padding:
//             const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//             decoration: BoxDecoration(
//               color: const Color(0xFF7B2CBF).withOpacity(0.25),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Text(
//               c,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         )
//             .toList(),
//       ),
//     );
//   }
//
//   // ----------------------------
//   // Data loading & filtering
//   // ----------------------------
//
//   void _loadUsers() {
//     final currentUid = _auth.currentUser?.uid;
//     if (currentUid == null) return;
//
//     _usersSubscription?.cancel();
//
//     _usersSubscription = _db
//         .collection('users')
//         .where('discoveryEnabled', isEqualTo: true)
//         .snapshots()
//         .listen((snapshot) {
//       final userList = snapshot.docs.map((doc) {
//         try {
//           return UserModel.fromFirestore(doc);
//         } catch (e) {
//           debugPrint('❌ Error parsing user ${doc.id}: $e');
//           return null;
//         }
//       }).whereType<UserModel>().toList();
//
//       if (!mounted) return;
//
//       setState(() {
//         final currentUid = _auth.currentUser?.uid;
//         _currentUser = userList.firstWhere(
//               (u) => u.uid == currentUid,
//           orElse: () => UserModel(uid: currentUid),
//         );
//         _allUsers = userList.where((u) => u.uid != currentUid).toList();
//       });
//
//       _applyFilters();
//     }, onError: (error) {
//       debugPrint('Users stream error: $error');
//     });
//   }
//
//   Future<void> _loadFilters() async {
//     final prefs = await FilterPreferences.getInstance();
//     if (!mounted) return;
//     setState(() {
//       _prefDiscoveryEnabled = prefs.discoveryEnabled;
//       _prefShowMeGender = prefs.showMeGender;
//       _prefAgeMin = prefs.ageMin;
//       _prefAgeMax = prefs.ageMax;
//       _prefDistanceKm = prefs.distanceKm;
//       _prefOnlineOnly = prefs.onlineOnly;
//     });
//   }
//
//   void _applyFilters() {
//     final query = _searchController.text.toLowerCase().trim();
//
//     List<UserModel> filtered = _allUsers.where((u) {
//       // Hide users who disabled discovery
//       if (u.discoveryEnabled == false) return false;
//
//       // Gender filter
//       if (_prefShowMeGender != 'everyone') {
//         final g = (u.gender ?? '').toLowerCase();
//         if (g != _prefShowMeGender) return false;
//       }
//
//       // Age filter
//       final age = u.age ?? _ageFromDob(u.dob);
//       if (age != null) {
//         if (age < _prefAgeMin || age > _prefAgeMax) return false;
//       }
//
//       // Online only filter
//       if (_prefOnlineOnly && !u.online) return false;
//
//       // Distance filter (apply only when discovery is ON)
//       if (_prefDiscoveryEnabled &&
//           _prefDistanceKm > 0 &&
//           _currentUser?.userLatitude != null &&
//           _currentUser?.userLongitude != null &&
//           u.userLatitude != null &&
//           u.userLongitude != null) {
//         final d = _distanceKm(
//           _currentUser!.userLatitude!,
//           _currentUser!.userLongitude!,
//           u.userLatitude!,
//           u.userLongitude!,
//         );
//         if (d > _prefDistanceKm) return false;
//       }
//
//       // Search filter (username, profession, interests, location)
//       if (query.isNotEmpty) {
//         final hay = [
//           u.username,
//           u.profession ?? '',
//           u.location ?? '',
//           ...u.interests,
//         ].join(' ').toLowerCase();
//
//         if (!hay.contains(query)) return false;
//       }
//
//       return true;
//     }).toList();
//
//     // Optional: sort by nearest distance when discovery is ON
//     if (_prefDiscoveryEnabled &&
//         _currentUser?.userLatitude != null &&
//         _currentUser?.userLongitude != null) {
//       filtered.sort((a, b) {
//         final da = (a.userLatitude != null && a.userLongitude != null)
//             ? _distanceKm(
//           _currentUser!.userLatitude!,
//           _currentUser!.userLongitude!,
//           a.userLatitude!,
//           a.userLongitude!,
//         )
//             : double.infinity;
//         final db = (b.userLatitude != null && b.userLongitude != null)
//             ? _distanceKm(
//           _currentUser!.userLatitude!,
//           _currentUser!.userLongitude!,
//           b.userLatitude!,
//           b.userLongitude!,
//         )
//             : double.infinity;
//         return da.compareTo(db);
//       });
//     }
//
//     if (!mounted) return;
//     setState(() {
//       _displayedUsers = filtered;
//       _isLoading = false;
//     });
//   }
//
//   int? _ageFromDob(String? dob) {
//     if (dob == null || dob.trim().isEmpty) return null;
//     try {
//       final parts = dob.split(RegExp(r'[/\-]'));
//       if (parts.length == 3) {
//         final day = int.parse(parts[0]);
//         final month = int.parse(parts[1]);
//         final year = int.parse(parts[2]);
//         final birth = DateTime(year, month, day);
//         final now = DateTime.now();
//         int age = now.year - birth.year;
//         if (now.month < birth.month ||
//             (now.month == birth.month && now.day < birth.day)) {
//           age--;
//         }
//         return age;
//       }
//     } catch (_) {}
//     return null;
//   }
//
//   double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
//     const R = 6371.0; // km
//     final dLat = _deg2rad(lat2 - lat1);
//     final dLon = _deg2rad(lon2 - lon1);
//     final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(_deg2rad(lat1)) *
//             math.cos(_deg2rad(lat2)) *
//             math.sin(dLon / 2) *
//             math.sin(dLon / 2);
//     final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
//     return R * c;
//   }
//
//   double _deg2rad(double deg) => deg * (math.pi / 180.0);
//
//   // ----------------------------
//   // Banner (Profile Completion)
//   // ----------------------------
//
//   Future<void> _checkProfileCompletion() async {
//     try {
//       final manager = ProfileCompletionManager();
//       final percentage = await manager.getCompletionPercentage();
//       final shouldShow = await manager.shouldShowBanner();
//
//       if (!mounted) return;
//       setState(() {
//         _profileCompletionPercentage = percentage;
//         _showBanner = shouldShow && !_bannerDismissed;
//       });
//     } catch (e) {
//       debugPrint('Error checking profile completion: $e');
//     }
//   }
//
//   void _dismissBanner() async {
//     await ProfileCompletionManager().dismissBanner();
//     if (!mounted) return;
//     setState(() {
//       _bannerDismissed = true;
//       _showBanner = false;
//     });
//   }
//
//   // ----------------------------
//   // UI helpers & actions
//   // ----------------------------
//
//   Widget _buildSearchBar() {
//     final unread = context.watch<UnreadManager>().totalUnread; // from Provider
//
//     return Container(
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF2D1B4E).withOpacity(0.9),
//         borderRadius: BorderRadius.circular(30),
//         border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.search, color: Color(0xFFB39DDB)),
//           const SizedBox(width: 12),
//           Expanded(
//             child: TextField(
//               controller: _searchController,
//               style: const TextStyle(color: Colors.white),
//               decoration: const InputDecoration(
//                 hintText: 'Search users...',
//                 hintStyle: TextStyle(color: Color(0xFFB39DDB)),
//                 border: InputBorder.none,
//               ),
//             ),
//           ),
//           // Bell icon -> open Chats
//           Stack(
//             clipBehavior: Clip.none,
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.notifications_none, color: Colors.white),
//                 tooltip: 'Chats',
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => const ChatListScreen()),
//                   );
//                 },
//               ),
//               if (unread > 0)
//                 Positioned(
//                   right: 10,
//                   top: 10,
//                   child: Container(
//                     width: 10,
//                     height: 10,
//                     decoration: const BoxDecoration(
//                       color: Colors.redAccent,
//                       shape: BoxShape.circle,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           // Drawer
//           IconButton(
//             icon: const Icon(Icons.menu, color: Colors.white),
//             onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
//           ),
//           // Optional: Tutorial test button (remove in production)
//           IconButton(
//             icon: const Icon(Icons.help_outline, color: Colors.white70),
//             onPressed: () => HomeOnboarding.showManually(context),
//             tooltip: 'Show Tutorial',
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _onSearchChanged() {
//     _applyFilters();
//   }
//
//   Future<void> _onRefresh() async {
//     setState(() => _isLoading = true);
//     _loadUsers();
//     await _loadFilters();
//     await _checkProfileCompletion();
//     await Future.delayed(const Duration(milliseconds: 300));
//   }
//
//   Future<void> _openDiscoverySettings() async {
//     final changed = await Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => const DiscoverySettingsScreen()),
//     );
//     if (changed == true) {
//       await _loadFilters();
//       _applyFilters();
//     }
//   }
//
//   Future<void> _handleSignOut() async {
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
//       await FirebaseAuth.instance.signOut();
//       if (!mounted) return;
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => const LoginScreen()),
//             (route) => false,
//       );
//     }
//   }
//
//   void _navigateToAstrology() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => const AstrologyQuestionnaireScreen(),
//       ),
//     );
//   }
//
//   void _navigateToProfile(UserModel user) {
//     final otherId = user.uid;
//     if (otherId == null || otherId.isEmpty) {
//       debugPrint('❌ Cannot open chat: user.uid is null/empty');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Unable to open chat. Invalid user id.')),
//       );
//       return;
//     }
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => ChatScreen(
//           otherUserId: otherId,
//         ),
//       ),
//     );
//   }
//
//   void _onBottomNavTap(int index) {
//     switch (index) {
//       case 0:
//         break;
//       case 1:
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const ChatListScreen()),
//         );
//         break;
//       case 2:
//         debugPrint('Navigate to Games'); // TODO
//         break;
//       case 3:
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const ProfileScreen()),
//         );
//         break;
//     }
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.people_outline,
//             size: 100,
//             color: const Color(0xFFB39DDB).withOpacity(0.5),
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'No users found',
//             style: TextStyle(
//               color: Color(0xFFB39DDB),
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Try adjusting your search or filters',
//             style: TextStyle(
//               color: Color(0xFFB39DDB),
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ----------------------------
//   // Build
//   // ----------------------------
//
//   @override
//   Widget build(BuildContext context) {
//     // unread is used inside _buildSearchBar via Provider
//
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: AppColors.appBackground,
//       endDrawer: CustomDrawer(
//         currentUser: _currentUser,
//         onSignOut: _handleSignOut,
//         onAstrologyTap: _navigateToAstrology,
//       ),
//       body: Stack(
//         children: [
//           // Background Lottie animation
//           Positioned.fill(
//             child: Lottie.asset(
//               'assets/animations/space.json',
//               fit: BoxFit.cover,
//               errorBuilder: (context, error, stackTrace) {
//                 return Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [Color(0xFF1A0E2E), Color(0xFF0D0221)],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           // Dark overlay
//           Positioned.fill(
//             child: Container(color: Colors.black.withOpacity(0.3)),
//           ),
//
//           // Main content
//           SafeArea(
//             child: Column(
//               children: [
//                 _buildSearchBar(),
//                 _buildFilterSummary(),
//
//                 // Bubbles (top matches / recents)
//                 if (_displayedUsers.isNotEmpty)
//                   Container(
//                     key: HomeOnboarding.bubblesKey, // onboarding target
//                     child: SizedBox(
//                       height: 120,
//                       child: ListView.builder(
//                         scrollDirection: Axis.horizontal,
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 16, vertical: 8),
//                         itemCount: _displayedUsers.take(10).length,
//                         itemBuilder: (context, index) {
//                           final user = _displayedUsers[index];
//                           return ProfileBubble(
//                             user: user,
//                             onTap: () => _navigateToProfile(user),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//
//                 // Grid + Banner
//                 Expanded(
//                   child: _isLoading
//                       ? const Center(
//                     child: CircularProgressIndicator(
//                       color: Color(0xFF7B2CBF),
//                     ),
//                   )
//                       : Column(
//                     children: [
//                       if (_showBanner &&
//                           _profileCompletionPercentage < 100)
//                         ProfileCompletionBanner(
//                           completionPercentage:
//                           _profileCompletionPercentage,
//                           onDismiss: _dismissBanner,
//                         ),
//                       Expanded(
//                         child: RefreshIndicator(
//                           onRefresh: _onRefresh,
//                           color: const Color(0xFF7B2CBF),
//                           backgroundColor: const Color(0xFF2D1B4E),
//                           child: _displayedUsers.isEmpty
//                               ? _buildEmptyState()
//                               : GridView.builder(
//                             padding: const EdgeInsets.fromLTRB(
//                                 16, 16, 16, 100),
//                             gridDelegate:
//                             const SliverGridDelegateWithFixedCrossAxisCount(
//                               crossAxisCount: 2,
//                               childAspectRatio: 0.75,
//                               crossAxisSpacing: 12,
//                               mainAxisSpacing: 12,
//                             ),
//                             itemCount: _displayedUsers.length,
//                             itemBuilder: (context, index) {
//                               final user = _displayedUsers[index];
//
//                               // First grid item gets onboarding key
//                               final profileCard = ProfileCard(
//                                 user: user,
//                                 currentUser: _currentUser,
//                                 onTap: () =>
//                                     _navigateToProfile(user),
//                               );
//
//                               if (index == 0) {
//                                 return Container(
//                                   key: HomeOnboarding
//                                       .firstGridItemKey,
//                                   child: profileCard,
//                                 );
//                               }
//
//                               return profileCard;
//                             },
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Bottom navigation
//           Positioned(
//             left: 16,
//             right: 16,
//             bottom: 24,
//             child: CustomBottomNav(
//               currentIndex: 0,
//               onTap: _onBottomNavTap,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// lib/screens/home/home_screen.dart
// import 'dart:async';
// import 'dart:math' as math;
//
// import 'package:availchat/core/constants/app_colors.dart';
// import 'package:availchat/managers/filter_preferences.dart';
// import 'package:availchat/managers/profile_completion_manager.dart';
// import 'package:availchat/managers/unread_manager.dart';
// import 'package:availchat/models/user_model.dart';
// import 'package:availchat/screens/auth/login_screen.dart';
// import 'package:availchat/screens/astrology/astrology_questionnaire_screen.dart';
// import 'package:availchat/screens/chat/chat_list_screen.dart';
// import 'package:availchat/screens/chat/chat_screen.dart';
// import 'package:availchat/screens/home/widgets/custom_bottom_nav.dart';
// import 'package:availchat/screens/profile/profile_screen.dart';
// import 'package:availchat/screens/settings/discovery_settings_screen.dart';
// import 'package:availchat/screens/home/widgets/custom_drawer.dart';
// import 'package:availchat/screens/home/widgets/profile_bubble.dart';
// import 'package:availchat/screens/home/widgets/profile_card.dart';
// import 'package:availchat/screens/home/widgets/profile_completion_banner.dart';
//
// // Onboarding
// import '../../feature/games/game_list_screen.dart';
// import '../../features/onboarding/home_onboarding.dart';
// import '../../features/onboarding/tour_prefs.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:lottie/lottie.dart';
// import 'package:provider/provider.dart';
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;
//   final _searchController = TextEditingController();
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   StreamSubscription<QuerySnapshot>? _usersSubscription;
//
//   List<UserModel> _allUsers = [];
//   List<UserModel> _displayedUsers = [];
//   UserModel? _currentUser;
//   bool _isLoading = true;
//
//   // Banner state
//   int _profileCompletionPercentage = 100;
//   bool _showBanner = false;
//   bool _bannerDismissed = false;
//
//   // Discovery filters
//   bool _prefDiscoveryEnabled = true; // distance filter control
//   String _prefShowMeGender = 'everyone';
//   int _prefAgeMin = 18;
//   int _prefAgeMax = 60;
//   int _prefDistanceKm = 50;
//   bool _prefOnlineOnly = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUsers();
//     _loadFilters();
//     _searchController.addListener(_onSearchChanged);
//     _checkProfileCompletion();
//
//     // Trigger onboarding after first frame & data load
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _triggerOnboardingIfNeeded();
//     });
//   }
//
//   Future<void> _triggerOnboardingIfNeeded() async {
//     // Wait a bit for Firestore stream + filters to populate
//     await Future.delayed(const Duration(seconds: 2));
//
//     if (!mounted || _displayedUsers.isEmpty) return;
//
//     await HomeOnboarding.tryShow(context);
//   }
//
//   @override
//   void dispose() {
//     _usersSubscription?.cancel();
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   // ----------------------------
//   // Filter summary (chips)
//   // ----------------------------
//   Widget _buildFilterSummary() {
//     String genderLabel = {
//       'everyone': 'Everyone',
//       'male': 'Men',
//       'female': 'Women',
//     }[_prefShowMeGender] ??
//         'Everyone';
//
//     final chips = <String>[
//       genderLabel,
//       '${_prefAgeMin}-${_prefAgeMax}',
//       '${_prefDistanceKm} km',
//       if (_prefOnlineOnly) 'Online only',
//     ];
//
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: const Color(0xFF2D1B4E).withOpacity(0.6),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.3)),
//       ),
//       child: Wrap(
//         spacing: 8,
//         runSpacing: 6,
//         crossAxisAlignment: WrapCrossAlignment.center,
//         children: chips
//             .map(
//               (c) => Container(
//             padding:
//             const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//             decoration: BoxDecoration(
//               color: const Color(0xFF7B2CBF).withOpacity(0.25),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Text(
//               c,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         )
//             .toList(),
//       ),
//     );
//   }
//
//   // ----------------------------
//   // Data loading & filtering
//   // ----------------------------
//
//   void _loadUsers() {
//     final currentUid = _auth.currentUser?.uid;
//     if (currentUid == null) return;
//
//     _usersSubscription?.cancel();
//
//     _usersSubscription = _db
//         .collection('users')
//         .where('discoveryEnabled', isEqualTo: true)
//         .snapshots()
//         .listen((snapshot) {
//       final userList = snapshot.docs.map((doc) {
//         try {
//           return UserModel.fromFirestore(doc);
//         } catch (e) {
//           debugPrint('❌ Error parsing user ${doc.id}: $e');
//           return null;
//         }
//       }).whereType<UserModel>().toList();
//
//       if (!mounted) return;
//
//       setState(() {
//         final currentUid = _auth.currentUser?.uid;
//         _currentUser = userList.firstWhere(
//               (u) => u.uid == currentUid,
//           orElse: () => UserModel(uid: currentUid),
//         );
//         _allUsers = userList.where((u) => u.uid != currentUid).toList();
//       });
//
//       _applyFilters();
//     }, onError: (error) {
//       debugPrint('Users stream error: $error');
//     });
//   }
//
//   Future<void> _loadFilters() async {
//     final prefs = await FilterPreferences.getInstance();
//     if (!mounted) return;
//     setState(() {
//       _prefDiscoveryEnabled = prefs.discoveryEnabled;
//       _prefShowMeGender = prefs.showMeGender;
//       _prefAgeMin = prefs.ageMin;
//       _prefAgeMax = prefs.ageMax;
//       _prefDistanceKm = prefs.distanceKm;
//       _prefOnlineOnly = prefs.onlineOnly;
//     });
//   }
//
//   void _applyFilters() {
//     final query = _searchController.text.toLowerCase().trim();
//
//     List<UserModel> filtered = _allUsers.where((u) {
//       // Hide users who disabled discovery
//       if (u.discoveryEnabled == false) return false;
//
//       // Gender filter
//       if (_prefShowMeGender != 'everyone') {
//         final g = (u.gender ?? '').toLowerCase();
//         if (g != _prefShowMeGender) return false;
//       }
//
//       // Age filter
//       final age = u.age ?? _ageFromDob(u.dob);
//       if (age != null) {
//         if (age < _prefAgeMin || age > _prefAgeMax) return false;
//       }
//
//       // Online only filter
//       if (_prefOnlineOnly && !u.online) return false;
//
//       // Distance filter (apply only when discovery is ON)
//       if (_prefDiscoveryEnabled &&
//           _prefDistanceKm > 0 &&
//           _currentUser?.userLatitude != null &&
//           _currentUser?.userLongitude != null &&
//           u.userLatitude != null &&
//           u.userLongitude != null) {
//         final d = _distanceKm(
//           _currentUser!.userLatitude!,
//           _currentUser!.userLongitude!,
//           u.userLatitude!,
//           u.userLongitude!,
//         );
//         if (d > _prefDistanceKm) return false;
//       }
//
//       // Search filter (username, profession, interests, location)
//       if (query.isNotEmpty) {
//         final hay = [
//           u.username,
//           u.profession ?? '',
//           u.location ?? '',
//           ...u.interests,
//         ].join(' ').toLowerCase();
//
//         if (!hay.contains(query)) return false;
//       }
//
//       return true;
//     }).toList();
//
//     // Optional: sort by nearest distance when discovery is ON
//     if (_prefDiscoveryEnabled &&
//         _currentUser?.userLatitude != null &&
//         _currentUser?.userLongitude != null) {
//       filtered.sort((a, b) {
//         final da = (a.userLatitude != null && a.userLongitude != null)
//             ? _distanceKm(
//           _currentUser!.userLatitude!,
//           _currentUser!.userLongitude!,
//           a.userLatitude!,
//           a.userLongitude!,
//         )
//             : double.infinity;
//         final db = (b.userLatitude != null && b.userLongitude != null)
//             ? _distanceKm(
//           _currentUser!.userLatitude!,
//           _currentUser!.userLongitude!,
//           b.userLatitude!,
//           b.userLongitude!,
//         )
//             : double.infinity;
//         return da.compareTo(db);
//       });
//     }
//
//     if (!mounted) return;
//     setState(() {
//       _displayedUsers = filtered;
//       _isLoading = false;
//     });
//   }
//
//   int? _ageFromDob(String? dob) {
//     if (dob == null || dob.trim().isEmpty) return null;
//     try {
//       final parts = dob.split(RegExp(r'[/\-]'));
//       if (parts.length == 3) {
//         final day = int.parse(parts[0]);
//         final month = int.parse(parts[1]);
//         final year = int.parse(parts[2]);
//         final birth = DateTime(year, month, day);
//         final now = DateTime.now();
//         int age = now.year - birth.year;
//         if (now.month < birth.month ||
//             (now.month == birth.month && now.day < birth.day)) {
//           age--;
//         }
//         return age;
//       }
//     } catch (_) {}
//     return null;
//   }
//
//   double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
//     const R = 6371.0; // km
//     final dLat = _deg2rad(lat2 - lat1);
//     final dLon = _deg2rad(lon2 - lon1);
//     final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(_deg2rad(lat1)) *
//             math.cos(_deg2rad(lat2)) *
//             math.sin(dLon / 2) *
//             math.sin(dLon / 2);
//     final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
//     return R * c;
//   }
//
//   double _deg2rad(double deg) => deg * (math.pi / 180.0);
//
//   // ----------------------------
//   // Banner (Profile Completion)
//   // ----------------------------
//
//   Future<void> _checkProfileCompletion() async {
//     try {
//       final manager = ProfileCompletionManager();
//       final percentage = await manager.getCompletionPercentage();
//       final shouldShow = await manager.shouldShowBanner();
//
//       if (!mounted) return;
//       setState(() {
//         _profileCompletionPercentage = percentage;
//         _showBanner = shouldShow && !_bannerDismissed;
//       });
//     } catch (e) {
//       debugPrint('Error checking profile completion: $e');
//     }
//   }
//
//   void _dismissBanner() async {
//     await ProfileCompletionManager().dismissBanner();
//     if (!mounted) return;
//     setState(() {
//       _bannerDismissed = true;
//       _showBanner = false;
//     });
//   }
//
//   // ----------------------------
//   // UI helpers & actions
//   // ----------------------------
//
//   Widget _buildSearchBar() {
//     final unread = context.watch<UnreadManager>().totalUnread; // from Provider
//
//     return Container(
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF2D1B4E).withOpacity(0.9),
//         borderRadius: BorderRadius.circular(30),
//         border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.search, color: Color(0xFFB39DDB)),
//           const SizedBox(width: 12),
//           Expanded(
//             child: TextField(
//               controller: _searchController,
//               style: const TextStyle(color: Colors.white),
//               decoration: const InputDecoration(
//                 hintText: 'Search users...',
//                 hintStyle: TextStyle(color: Color(0xFFB39DDB)),
//                 border: InputBorder.none,
//               ),
//             ),
//           ),
//           // Bell icon -> open Chats
//           Stack(
//             clipBehavior: Clip.none,
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.notifications_none, color: Colors.white),
//                 tooltip: 'Chats',
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => const ChatListScreen()),
//                   );
//                 },
//               ),
//               if (unread > 0)
//                 Positioned(
//                   right: 10,
//                   top: 10,
//                   child: Container(
//                     width: 10,
//                     height: 10,
//                     decoration: const BoxDecoration(
//                       color: Colors.redAccent,
//                       shape: BoxShape.circle,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           // Drawer
//           IconButton(
//             icon: const Icon(Icons.menu, color: Colors.white),
//             onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
//           ),
//           // Optional: Tutorial test button (remove in production)
//           IconButton(
//             icon: const Icon(Icons.help_outline, color: Colors.white70),
//             onPressed: () => HomeOnboarding.showManually(context),
//             tooltip: 'Show Tutorial',
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _onSearchChanged() {
//     _applyFilters();
//   }
//
//   Future<void> _onRefresh() async {
//     setState(() => _isLoading = true);
//     _loadUsers();
//     await _loadFilters();
//     await _checkProfileCompletion();
//     await Future.delayed(const Duration(milliseconds: 300));
//   }
//
//   Future<void> _openDiscoverySettings() async {
//     final changed = await Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => const DiscoverySettingsScreen()),
//     );
//     if (changed == true) {
//       await _loadFilters();
//       _applyFilters();
//     }
//   }
//
//   Future<void> _handleSignOut() async {
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
//       await FirebaseAuth.instance.signOut();
//       if (!mounted) return;
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => const LoginScreen()),
//             (route) => false,
//       );
//     }
//   }
//
//   void _navigateToAstrology() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => const AstrologyQuestionnaireScreen(),
//       ),
//     );
//   }
//
//   void _navigateToProfile(UserModel user) {
//     final otherId = user.uid;
//     if (otherId == null || otherId.isEmpty) {
//       debugPrint('❌ Cannot open chat: user.uid is null/empty');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Unable to open chat. Invalid user id.')),
//       );
//       return;
//     }
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => ChatScreen(
//           otherUserId: otherId,
//         ),
//       ),
//     );
//   }
//
//   void _onBottomNavTap(int index) {
//     switch (index) {
//       case 0:
//         break;
//       case 1:
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const ChatListScreen()),
//         );
//         break;
//       case 2:
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const GameListScreen()),
//         );
//         break;
//       case 3:
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const ProfileScreen()),
//         );
//         break;
//     }
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.people_outline,
//             size: 100,
//             color: const Color(0xFFB39DDB).withOpacity(0.5),
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'No users found',
//             style: TextStyle(
//               color: Color(0xFFB39DDB),
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Try adjusting your search or filters',
//             style: TextStyle(
//               color: Color(0xFFB39DDB),
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ----------------------------
//   // Build
//   // ----------------------------
//
//   @override
//   Widget build(BuildContext context) {
//     // unread is used inside _buildSearchBar via Provider
//
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: AppColors.appBackground,
//       endDrawer: CustomDrawer(
//         currentUser: _currentUser,
//         onSignOut: _handleSignOut,
//         onAstrologyTap: _navigateToAstrology,
//       ),
//       body: Stack(
//         children: [
//           // Background Lottie animation
//           Positioned.fill(
//             child: Lottie.asset(
//               'assets/animations/space.json',
//               fit: BoxFit.cover,
//               errorBuilder: (context, error, stackTrace) {
//                 return Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [Color(0xFF1A0E2E), Color(0xFF0D0221)],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           // Dark overlay
//           Positioned.fill(
//             child: Container(color: Colors.black.withOpacity(0.3)),
//           ),
//
//           // Main content
//           SafeArea(
//             child: Column(
//               children: [
//                 _buildSearchBar(),
//                 _buildFilterSummary(),
//
//                 // Bubbles (top matches / recents)
//                 if (_displayedUsers.isNotEmpty)
//                   Container(
//                     key: HomeOnboarding.bubblesKey, // onboarding target
//                     child: SizedBox(
//                       height: 120,
//                       child: ListView.builder(
//                         scrollDirection: Axis.horizontal,
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 16, vertical: 8),
//                         itemCount: _displayedUsers.take(10).length,
//                         itemBuilder: (context, index) {
//                           final user = _displayedUsers[index];
//                           return ProfileBubble(
//                             user: user,
//                             onTap: () => _navigateToProfile(user),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//
//                 // Grid + Banner
//                 Expanded(
//                   child: _isLoading
//                       ? const Center(
//                     child: CircularProgressIndicator(
//                       color: Color(0xFF7B2CBF),
//                     ),
//                   )
//                       : Column(
//                     children: [
//                       if (_showBanner &&
//                           _profileCompletionPercentage < 100)
//                         ProfileCompletionBanner(
//                           completionPercentage:
//                           _profileCompletionPercentage,
//                           onDismiss: _dismissBanner,
//                         ),
//                       Expanded(
//                         child: RefreshIndicator(
//                           onRefresh: _onRefresh,
//                           color: const Color(0xFF7B2CBF),
//                           backgroundColor: const Color(0xFF2D1B4E),
//                           child: _displayedUsers.isEmpty
//                               ? _buildEmptyState()
//                               : GridView.builder(
//                             padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
//                             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                               crossAxisCount: 2,
//                               childAspectRatio: 0.75,
//                               crossAxisSpacing: 12,
//                               mainAxisSpacing: 12,
//                             ),
//                             itemCount: _displayedUsers.length,
//                             itemBuilder: (context, index) {
//                               final user = _displayedUsers[index];
//
//                               final profileCard = ProfileCard(
//                                 user: user,
//                                 currentUser: _currentUser,
//                                 onTap: () => _navigateToProfile(user),
//                               );
//
//                               // Assign keys to first two items for onboarding
//                               if (index == 0) {
//                                 return Container(
//                                   key: HomeOnboarding.firstGridItemKey,
//                                   child: profileCard,
//                                 );
//                               } else if (index == 1) {
//                                 return Container(
//                                   key: HomeOnboarding.secondGridItemKey,
//                                   child: profileCard,
//                                 );
//                               }
//
//                               return profileCard;
//                             },
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Bottom navigation
//           Positioned(
//             left: 16,
//             right: 16,
//             bottom: 24,
//             child: CustomBottomNav(
//               currentIndex: 0,
//               onTap: _onBottomNavTap,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

// Core
import 'package:availchat/core/constants/app_colors.dart';

// Managers
import 'package:availchat/managers/unread_manager.dart';

// Models
import 'package:availchat/models/user_model.dart';

// Screens
import 'package:availchat/screens/auth/login_screen.dart';
import 'package:availchat/screens/astrology/astrology_questionnaire_screen.dart';
import 'package:availchat/screens/chat/chat_list_screen.dart';
import 'package:availchat/screens/chat/chat_screen.dart';
import 'package:availchat/screens/profile/profile_screen.dart';
import 'package:availchat/screens/settings/discovery_settings_screen.dart';

// Widgets
import 'widgets/custom_bottom_nav.dart';
import 'widgets/custom_drawer.dart';
import 'widgets/profile_bubble.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_completion_banner.dart';

// Shimmers
import 'package:availchat/widgets/shimmers/shimmer_bubble.dart';

// Games
import '../../feature/games/game_list_screen.dart';

// Onboarding
import '../../features/onboarding/home_onboarding.dart';

// Controller (Logic)
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ===========================================================================
  // Controller & Keys
  // ===========================================================================
  late final HomeController _controller;
  final _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final HomeTourKeys _tourKeys = HomeTourKeys();
  bool _autoTourRequested = false;

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.addListener(_onControllerUpdate);
    _controller.initialize();

    _searchController.addListener(_onSearchChanged);

    HomeOnboarding.attach(_tourKeys, onReplay: _showTutorial);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartAutoTour());
  }

  @override
  void dispose() {
    HomeOnboarding.detach(_tourKeys);
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
    _maybeStartAutoTour();
  }

  // ===========================================================================
  // Onboarding
  // ===========================================================================

  /// First-run tour starts once the grid first has profiles to point at.
  void _maybeStartAutoTour() {
    if (_autoTourRequested || !mounted) return;
    if (_controller.isLoading || _controller.displayedUsers.isEmpty) return;
    _autoTourRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Don't cover a screen pushed on top; try again on the next update.
      if (ModalRoute.of(context)?.isCurrent == false) {
        _autoTourRequested = false;
        return;
      }
      HomeOnboarding.tryShow(context, _tourKeys);
    });
  }

  /// Manual replay from the drawer, Help sheet or Settings.
  void _showTutorial() {
    if (!mounted) return;
    HomeOnboarding.showManually(context, keys: _tourKeys);
  }

  // ===========================================================================
  // Event Handlers
  // ===========================================================================

  void _onSearchChanged() {
    _controller.updateSearchQuery(_searchController.text);
  }

  Future<void> _onRefresh() async {
    await _controller.refresh();
  }

  Future<void> _openDiscoverySettings() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiscoverySettingsScreen()),
    );
    if (changed == true) {
      await _controller.onFiltersChanged();
    }
  }

  void _navigateToChat(UserModel user) {
    if (!_controller.isValidUserForChat(user)) {
      _showSnackBar('Unable to open chat. Invalid user.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(otherUserId: user.uid!),
      ),
    );
  }

  void _navigateToAstrology() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyQuestionnaireScreen()),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await _showSignOutDialog();
    if (confirm == true) {
      await _controller.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Future<bool?> _showSignOutDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF7B2CBF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ===========================================================================
  // Bottom Navigation
  // ===========================================================================

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
      // Already on Discover
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatListScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameListScreen()),
        );
        break;
      case 3:
        _openDiscoverySettings();
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
    }
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.appBackground,
      endDrawer: CustomDrawer(
        currentUser: _controller.currentUser,
        onSignOut: _handleSignOut,
        onAstrologyTap: _navigateToAstrology,
        onShowTutorial: _showTutorial,
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI COMPONENTS
  // ===========================================================================

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned.fill(
          child: Lottie.asset(
            'assets/animations/space.json',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A0E2E), Color(0xFF0D0221)],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final unread = context.watch<UnreadManager>().totalUnread;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E).withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFFB39DDB)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Color(0xFFB39DDB)),
                border: InputBorder.none,
              ),
            ),
          ),
          _buildNotificationBell(unread),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(int unread) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          tooltip: 'Chats',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            );
          },
        ),
        if (unread > 0)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    // Error State
    if (_controller.error != null) {
      return _buildErrorState();
    }

    // Loading State
    if (_controller.isLoading) {
      return _buildLoadingState();
    }

    // Empty State
    if (_controller.displayedUsers.isEmpty) {
      return _buildEmptyState();
    }

    // Users List
    return _buildUsersList();
  }

  Widget _buildLoadingState() {
    return const Column(
      children: [
        SizedBox(height: 8),
        ShimmerBubbleStrip(),
        SizedBox(height: 16),
        Expanded(child: ShimmerBubbleGrid()),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.redAccent.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            _controller.error ?? 'Something went wrong',
            style: const TextStyle(color: Color(0xFFB39DDB), fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 100,
            color: const Color(0xFFB39DDB).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No users found',
            style: TextStyle(
              color: Color(0xFFB39DDB),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: Color(0xFFB39DDB), fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _openDiscoverySettings,
            icon: const Icon(Icons.tune),
            label: const Text('Adjust Filters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7B2CBF),
              side: const BorderSide(color: Color(0xFF7B2CBF)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF7B2CBF),
      backgroundColor: const Color(0xFF2D1B4E),
      child: Column(
        children: [
          // Profile Completion Banner
          if (_controller.showBanner)
            ProfileCompletionBanner(
              completionPercentage: _controller.profileCompletionPercentage,
              onDismiss: _controller.dismissBanner,
            ),

          // Top Matches Bubbles
          _buildTopMatchesBubbles(),

          // Profile Grid
          Expanded(child: _buildProfileGrid()),
        ],
      ),
    );
  }

  Widget _buildTopMatchesBubbles() {
    final topUsers = _controller.topUsers;
    if (topUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      key: _tourKeys.bubbles,
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: topUsers.length,
        itemBuilder: (context, index) {
          final user = topUsers[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ProfileBubble(
              user: user,
              onTap: () => _navigateToChat(user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileGrid() {
    final users = _controller.displayedUsers;

    final grid = GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];

        final profileCard = ProfileCard(
          user: user,
          currentUser: _controller.currentUser,
          onTap: () => _navigateToChat(user),
        );

        // Onboarding keys
        if (index == 0) {
          return Container(
            key: _tourKeys.firstGridItem,
            child: profileCard,
          );
        } else if (index == 1) {
          return Container(
            key: _tourKeys.secondGridItem,
            child: profileCard,
          );
        }

        return profileCard;
      },
    );

    // Paginated feed: fetch the next page near the end of the grid.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) {
          _controller.loadMore();
        }
        return false;
      },
      child: Stack(
        children: [
          grid,
          if (_controller.isLoadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: CustomBottomNav(
        currentIndex: 0,
        onTap: _onBottomNavTap,
      ),
    );
  }
}