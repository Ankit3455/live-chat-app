// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:provider/provider.dart';
//
// // Core imports
// import 'bottom_navigation/managers/firestore_manager.dart';
// import 'core/theme/app_theme.dart';
// import 'core/utils/astrology_view_model.dart';
// import 'core/utils/error_handler.dart';
// import 'managers/unread_manager.dart';
//
// // Screens
// import 'screens/auth/splash_screen.dart';
// import 'screens/settings/change_password_screen.dart';
//
// // Services
// import 'services/auth_service.dart';
// import 'services/database_service.dart';
// import 'services/presence_service.dart';
// import 'services/call/webrtc/signaling_service.dart';
// import 'services/call/call_service.dart';
//
// // Calls + notifications
// import 'models/call_model.dart';
// import 'screens/calls/incoming_call_screen.dart';
// import 'services/notification/notification_channels.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//
//   ErrorHandler.initialize();
//
//   // Firestore offline persistence
//   FirebaseFirestore.instance.settings = const Settings(
//     persistenceEnabled: true,
//     cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
//   );
//
//   // RTDB persistence (calls)
//   FirebaseDatabase.instance.setPersistenceEnabled(true);
//   FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
//
//   // 🔔 Init local notification channels (+ permissions)
//   await NotificationChannels.initialize();
//
//   // 🔥 Register FCM background handler
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//   runApp(
//     MultiProvider(
//       providers: [
//         Provider<AuthService>(create: (_) => AuthService()),
//         Provider<DatabaseService>(create: (_) => DatabaseService()),
//         ChangeNotifierProvider(create: (_) => UnreadManager()..init()),
//         Provider<PresenceService>(
//           create: (_) {
//             final svc = PresenceService();
//             svc.init();
//             return svc;
//           },
//           dispose: (_, s) => s.dispose(),
//         ),
//         ChangeNotifierProvider(create: (_) => AstrologyViewModel()),
//         ChangeNotifierProvider(create: (_) => FirestoreManager()),
//         // Services as Singletons
//         Provider<SignalingService>(create: (_) => SignalingService()),
//         Provider<CallService>(create: (_) => CallService()),
//       ],
//       child: const AvailChatApp(),
//     ),
//   );
// }
//
// class AvailChatApp extends StatefulWidget {
//   const AvailChatApp({super.key});
//   @override
//   State<AvailChatApp> createState() => _AvailChatAppState();
// }
//
// class _AvailChatAppState extends State<AvailChatApp> with WidgetsBindingObserver {
//   final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//
//   StreamSubscription<User?>? _authSub;
//   StreamSubscription<CallModel?>? _incomingCallSub;
//   String? _lastShownCallId;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//
//     // 🔔 Foreground FCM listener (RING + grouped badge)
//     _initializeFCMForeground();
//
//     // 📞 Call listener after first frame (needs context)
//     WidgetsBinding.instance.addPostFrameCallback((_) => _initIncomingListener());
//   }
//
//   // 📞 Incoming call listener
//   void _initIncomingListener() {
//     final signaling = Provider.of<SignalingService>(context, listen: false);
//
//     _authSub?.cancel();
//     _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
//       _incomingCallSub?.cancel();
//
//       if (user == null || user.uid.isEmpty) {
//         debugPrint("📵 Incoming call listener stopped: User logged out.");
//         return;
//       }
//
//       debugPrint("✅ Incoming call listener for user: ${user.uid}");
//
//       _incomingCallSub = signaling.listenForIncomingCalls().listen((call) {
//         if (call == null) return;
//
//         if (_lastShownCallId == call.id) return; // avoid duplicate UI
//         _lastShownCallId = call.id;
//
//         if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
//           _showIncomingCallScreen(call);
//           // Optional: mark delivered so next app open par double sheet na aaye
//           signaling.markIncomingDelivered(call.id);
//         }
//       });
//     });
//   }
//
//   void _showIncomingCallScreen(CallModel call) {
//     final nav = navigatorKey.currentState;
//     if (nav == null) return;
//
//     debugPrint("🚀 Showing incoming call screen: ${call.id}");
//     nav.push(
//       MaterialPageRoute(
//         builder: (_) => IncomingCallScreen(call: call),
//         fullscreenDialog: true,
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _authSub?.cancel();
//     _incomingCallSub?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Destined',
//       debugShowCheckedModeBanner: false,
//       navigatorKey: navigatorKey,
//       theme: AppTheme.darkTheme,
//       home: const SplashScreen(),
//       routes: {
//         '/splash': (_) => const SplashScreen(),
//         '/change-password': (_) => const ChangePasswordScreen(),
//       },
//       builder: (_, child) => MediaQuery(
//         data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
//         child: child!,
//       ),
//     );
//   }
// }
//
// /// 🔥 FCM BACKGROUND HANDLER (runs when app is terminated/background)
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   await NotificationChannels.initialize();
//
//   final data = message.data;
//   final type = data['type'] ?? '';
//
//   if (type == 'new_message') {
//     // Background: typically system notification already alerts.
//     // If you still want a grouped summary update:
//     final uid = data['receiverId'];
//     if (uid != null) {
//       final count = await _getNewMessageCount(uid);
//       await NotificationChannels.showNewMessageGrouped(totalNewSenders: count);
//     }
//   } else if (type == 'call') {
//     await NotificationChannels.showIncomingCallNotification(
//       callId: data['callId'] ?? '',
//       callerName: data['callerName'] ?? 'Unknown',
//       isVideo: data['callType'] == 'video',
//     );
//   }
// }
//
// // 🔎 Helper: count grouped new senders
// Future<int> _getNewMessageCount(String uid) async {
//   try {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('conversations')
//         .where('participants', arrayContains: uid)
//         .where('statePerUser.$uid', isEqualTo: 'new')
//         .get();
//     return snapshot.docs.length;
//   } catch (e) {
//     debugPrint('Error counting new messages: $e');
//     return 0;
//   }
// }
//
// /// 🔔 FCM FOREGROUND HANDLER
// /// 👉 yahi pe **ring** bajti hai (ActiveChat = loud), aur grouped summary silent rehti hai
// void _initializeFCMForeground() {
//   // Ensure permissions are granted; initialize() already requests, but safe:
//   FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
//
//   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
//     final data = message.data;
//     final type = data['type'] ?? '';
//
//     if (type == 'new_message') {
//       // ✅ Foreground: loud ringtone
//       await NotificationChannels.showActiveChat(
//         title: data['title'] ?? 'New Message',
//         body: data['body'] ?? 'You have a new message',
//       );
//
//       // ✅ Silent grouped badge (untouched logic)
//       final receiverId = data['receiverId'];
//       if (receiverId != null) {
//         final count = await _getNewMessageCount(receiverId);
//         await NotificationChannels.showNewMessageGrouped(totalNewSenders: count);
//       }
//     }
//   });
// }



//
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:provider/provider.dart';
//
// // Core imports
// import 'bottom_navigation/managers/firestore_manager.dart';
// import 'core/theme/app_theme.dart';
// import 'core/utils/astrology_view_model.dart';
// import 'core/utils/error_handler.dart';
// import 'managers/unread_manager.dart';
//
// // Screens
// import 'screens/auth/splash_screen.dart';
// import 'screens/settings/change_password_screen.dart';
//
// // Services
// import 'services/auth_service.dart';
// import 'services/database_service.dart';
// import 'services/presence_service.dart';
// import 'services/call/webrtc/signaling_service.dart';
// import 'services/call/call_service.dart';
//
// // Calls + notifications
// import 'models/call_model.dart';
// import 'screens/calls/incoming_call_screen.dart';
// import 'services/notification/notification_channels.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//
//   ErrorHandler.initialize();
//
//   // Firestore offline persistence
//   FirebaseFirestore.instance.settings = const Settings(
//     persistenceEnabled: true,
//     cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
//   );
//
//   // RTDB persistence (calls)
//   FirebaseDatabase.instance.setPersistenceEnabled(true);
//   FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
//
//   // ------------------------------
//   // 🔥 Register FCM background handler FIRST (very important)
//   // ------------------------------
//   // _firebaseMessagingBackgroundHandler is defined below in this file.
//   // We await registration to ensure the background isolate is ready before channels init.
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//   // 🔔 Init local notification channels (+ permissions)
//   await NotificationChannels.initialize();
//
//   runApp(
//     MultiProvider(
//       providers: [
//         Provider<AuthService>(create: (_) => AuthService()),
//         Provider<DatabaseService>(create: (_) => DatabaseService()),
//         ChangeNotifierProvider(create: (_) => UnreadManager()..init()),
//         Provider<PresenceService>(
//           create: (_) {
//             final svc = PresenceService();
//             svc.init();
//             return svc;
//           },
//           dispose: (_, s) => s.dispose(),
//         ),
//         ChangeNotifierProvider(create: (_) => AstrologyViewModel()),
//         ChangeNotifierProvider(create: (_) => FirestoreManager()),
//         // Services as Singletons
//         Provider<SignalingService>(create: (_) => SignalingService()),
//         Provider<CallService>(create: (_) => CallService()),
//       ],
//       child: const AvailChatApp(),
//     ),
//   );
// }
//
// class AvailChatApp extends StatefulWidget {
//   const AvailChatApp({super.key});
//   @override
//   State<AvailChatApp> createState() => _AvailChatAppState();
// }
//
// class _AvailChatAppState extends State<AvailChatApp> with WidgetsBindingObserver {
//   final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//
//   StreamSubscription<User?>? _authSub;
//   StreamSubscription<CallModel?>? _incomingCallSub;
//   String? _lastShownCallId;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//
//     // 🔔 Foreground FCM listener (RING + grouped badge)
//     _initializeFCMForeground();
//
//     // 📞 Call listener after first frame (needs context)
//     WidgetsBinding.instance.addPostFrameCallback((_) => _initIncomingListener());
//   }
//
//   // 📞 Incoming call listener
//   void _initIncomingListener() {
//     final signaling = Provider.of<SignalingService>(context, listen: false);
//
//     _authSub?.cancel();
//     _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
//       _incomingCallSub?.cancel();
//
//       if (user == null || user.uid.isEmpty) {
//         debugPrint("📵 Incoming call listener stopped: User logged out.");
//         return;
//       }
//
//       debugPrint("✅ Incoming call listener for user: ${user.uid}");
//
//       _incomingCallSub = signaling.listenForIncomingCalls().listen((call) {
//         if (call == null) return;
//
//         if (_lastShownCallId == call.id) return; // avoid duplicate UI
//         _lastShownCallId = call.id;
//
//         if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
//           _showIncomingCallScreen(call);
//           // Optional: mark delivered so next app open par double sheet na aaye
//           signaling.markIncomingDelivered(call.id);
//         }
//       });
//     });
//   }
//
//   void _showIncomingCallScreen(CallModel call) {
//     final nav = navigatorKey.currentState;
//     if (nav == null) return;
//
//     debugPrint("🚀 Showing incoming call screen: ${call.id}");
//     nav.push(
//       MaterialPageRoute(
//         builder: (_) => IncomingCallScreen(call: call),
//         fullscreenDialog: true,
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _authSub?.cancel();
//     _incomingCallSub?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Destined',
//       debugShowCheckedModeBanner: false,
//       navigatorKey: navigatorKey,
//       theme: AppTheme.darkTheme,
//       home: const SplashScreen(),
//       routes: {
//         '/splash': (_) => const SplashScreen(),
//         '/change-password': (_) => const ChangePasswordScreen(),
//       },
//       builder: (_, child) => MediaQuery(
//         data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
//         child: child!,
//       ),
//     );
//   }
//
//   /// 🔔 FCM FOREGROUND HANDLER
//   /// 👉 yahi pe **ring** bajti hai (ActiveChat = loud), aur grouped summary silent rehti hai
//   void _initializeFCMForeground() {
//     // Ensure permissions are granted; initialize() already requests, but safe:
//     FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
//
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
//       final data = message.data;
//       final type = data['type'] ?? '';
//
//       if (type == 'new_message') {
//         // ✅ Foreground: loud ringtone
//         await NotificationChannels.showActiveChat(
//           title: data['title'] ?? 'New Message',
//           body: data['body'] ?? 'You have a new message',
//         );
//
//         // ✅ Silent grouped badge (untouched logic)
//         final receiverId = data['receiverId'];
//         if (receiverId != null) {
//           final count = await _getNewMessageCount(receiverId);
//           await NotificationChannels.showNewMessageGrouped(totalNewSenders: count);
//         }
//       }
//     });
//   }
// }
//
// /// 🔥 FCM BACKGROUND HANDLER (runs when app is terminated/background)
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   await NotificationChannels.initialize();
//
//   final data = message.data;
//   final type = data['type'] ?? '';
//
//   if (type == 'new_message') {
//     // Background: typically system notification already alerts.
//     // If you still want a grouped summary update:
//     final uid = data['receiverId'];
//     if (uid != null) {
//       final count = await _getNewMessageCount(uid);
//       await NotificationChannels.showNewMessageGrouped(totalNewSenders: count);
//     }
//   } else if (type == 'call') {
//     await NotificationChannels.showIncomingCallNotification(
//       callId: data['callId'] ?? '',
//       callerName: data['callerName'] ?? 'Unknown',
//       isVideo: data['callType'] == 'video',
//     );
//   }
// }
//
// // 🔎 Helper: count grouped new senders
// Future<int> _getNewMessageCount(String uid) async {
//   try {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('conversations')
//         .where('participants', arrayContains: uid)
//         .where('statePerUser.$uid', isEqualTo: 'new')
//         .get();
//     return snapshot.docs.length;
//   } catch (e) {
//     debugPrint('Error counting new messages: $e');
//     return 0;
//   }
// }

// import 'dart:async';
// import 'package:flutter/material.dart';
//
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:provider/provider.dart';
// import 'package:onesignal_flutter/onesignal_flutter.dart';
//
// import 'services/notification/onesignal_service.dart';
//
// import 'bottom_navigation/managers/firestore_manager.dart';
// import 'core/theme/app_theme.dart';
// import 'core/utils/astrology_view_model.dart';
// import 'core/utils/error_handler.dart';
// import 'managers/unread_manager.dart';
//
// import 'screens/auth/splash_screen.dart';
// import 'screens/settings/change_password_screen.dart';
//
// import 'services/auth_service.dart';
// import 'services/database_service.dart';
// import 'services/presence_service.dart';
// import 'services/call/webrtc/signaling_service.dart';
// import 'services/call/call_service.dart';
//
// import 'models/call_model.dart';
// import 'screens/calls/incoming_call_screen.dart';
// import 'services/notification/notification_channels.dart';
// import 'services/notification/push_token_service.dart';
//
//
// // ================= BACKGROUND HANDLER =================
//
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   await NotificationChannels.initialize();
//
//   final data = message.data;
//   final type = (data['type'] ?? '').toString();
//
//   if (type == 'new_message') {
//     final uid = data['receiverId'];
//     if (uid != null) {
//       final count = await _getNewMessageCount(uid);
//       await NotificationChannels.showNewMessageGrouped(
//         totalNewSenders: count,
//       );
//     }
//   } else if (type == 'call') {
//     await NotificationChannels.showIncomingCallNotification(
//       callId: data['callId'] ?? '',
//       callerName: data['callerName'] ?? 'Unknown',
//       isVideo: data['callType'] == 'video',
//     );
//   }
// }
//
// Future<int> _getNewMessageCount(String uid) async {
//   try {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('conversations')
//         .where('participants', arrayContains: uid)
//         .where('statePerUser.$uid', isEqualTo: 'new')
//         .get();
//     return snapshot.docs.length;
//   } catch (_) {
//     return 0;
//   }
// }
//
// // ================= MAIN =================
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//
//   // ✅ Safe OneSignal init
//   await OneSignalService.init();
//
//   // ✅ Background push handler
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//   // ✅ Sync token
//   await PushTokenService.syncToken();
//
//   ErrorHandler.initialize();
//
//   FirebaseFirestore.instance.settings = const Settings(
//     persistenceEnabled: true,
//     cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
//   );
//
//   FirebaseDatabase.instance.setPersistenceEnabled(true);
//   FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
//
//   // ✅ Local notifications
//   await NotificationChannels.initialize();
//
//   runApp(
//     MultiProvider(
//       providers: [
//         Provider<AuthService>(create: (_) => AuthService()),
//         Provider<DatabaseService>(create: (_) => DatabaseService()),
//         ChangeNotifierProvider(create: (_) => UnreadManager()..init()),
//         Provider<PresenceService>(
//           create: (_) {
//             final svc = PresenceService();
//             svc.init();
//             return svc;
//           },
//           dispose: (_, s) => s.dispose(),
//         ),
//         ChangeNotifierProvider(create: (_) => AstrologyViewModel()),
//         ChangeNotifierProvider(create: (_) => FirestoreManager()),
//         Provider<SignalingService>(create: (_) => SignalingService()),
//         Provider<CallService>(create: (_) => CallService()),
//       ],
//       child: const AvailChatApp(),
//     ),
//   );
// }
//
// // ================= APP =================
//
// class AvailChatApp extends StatefulWidget {
//   const AvailChatApp({super.key});
//
//   @override
//   State<AvailChatApp> createState() => _AvailChatAppState();
// }
//
// class _AvailChatAppState extends State<AvailChatApp>
//     with WidgetsBindingObserver {
//   final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//
//   StreamSubscription<User?>? _authSub;
//   StreamSubscription<CallModel?>? _incomingCallSub;
//   String? _lastShownCallId;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//
//     _initializeFCMForeground();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _initIncomingListener();
//     });
//   }
//
//   void _initIncomingListener() {
//     final signaling = Provider.of<SignalingService>(context, listen: false);
//
//     _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
//       _incomingCallSub?.cancel();
//       if (user == null) return;
//
//       _incomingCallSub =
//           signaling.listenForIncomingCalls().listen((call) {
//             if (call == null || _lastShownCallId == call.id) return;
//             _lastShownCallId = call.id;
//
//             if (WidgetsBinding.instance.lifecycleState ==
//                 AppLifecycleState.resumed) {
//               _showIncomingCallScreen(call);
//             }
//           });
//     });
//   }
//
//   void _showIncomingCallScreen(CallModel call) {
//     final nav = navigatorKey.currentState;
//     if (nav == null) return;
//     nav.push(
//       MaterialPageRoute(
//         builder: (_) => IncomingCallScreen(call: call),
//         fullscreenDialog: true,
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _authSub?.cancel();
//     _incomingCallSub?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Destined',
//       debugShowCheckedModeBanner: false,
//       navigatorKey: navigatorKey,
//       theme: AppTheme.darkTheme,
//       home: const SplashScreen(),
//       routes: {
//         '/splash': (_) => const SplashScreen(),
//         '/change-password': (_) => const ChangePasswordScreen(),
//       },
//     );
//   }
//
//   // ✅ Foreground FCM
//   void _initializeFCMForeground() {
//     FirebaseMessaging.instance.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//
//     FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
//       final data = msg.data;
//       final type = data['type'] ?? '';
//
//       if (type == 'new_message') {
//         await NotificationChannels.showActiveChat(
//           title: data['title'] ?? 'New message',
//           body: data['body'] ?? 'You have a new message',
//         );
//       } else if (type == 'call') {
//         await NotificationChannels.showIncomingCallNotification(
//           callId: data['callId'] ?? '',
//           callerName: data['callerName'] ?? 'Unknown',
//           isVideo: data['callType'] == 'video',
//         );
//       }
//     });
//   }
// }


// 📁 lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
// import 'package:onesignal_flutter/onesignal_flutter.dart'; // ❌ REMOVED - Not needed directly

import 'feature/games/ludo/ludo_provider.dart';
import 'feature/games/ludo/main_screen.dart';
import 'services/notification/onesignal_service.dart';

import 'bottom_navigation/managers/firestore_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/astrology_view_model.dart';
import 'core/utils/error_handler.dart';
import 'managers/unread_manager.dart';

import 'screens/auth/splash_screen.dart';
import 'screens/settings/change_password_screen.dart';

import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/presence_service.dart';
import 'services/call/webrtc/signaling_service.dart';
import 'services/call/call_service.dart';

import 'models/call_model.dart';
import 'screens/calls/incoming_call_screen.dart';
import 'services/notification/notification_channels.dart';
import 'services/notification/push_token_service.dart';
import 'feature/games/ludo/ludo_lobby_screen.dart';


// ================= BACKGROUND HANDLER =================

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationChannels.initialize();

  final data = message.data;
  final type = (data['type'] ?? '').toString();

  if (type == 'new_message') {
    final uid = data['receiverId'];
    if (uid != null) {
      final count = await _getNewMessageCount(uid);
      await NotificationChannels.showNewMessageGrouped(
        totalNewSenders: count,
      );
    }
  } else if (type == 'call') {
    await NotificationChannels.showIncomingCallNotification(
      callId: data['callId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      isVideo: data['callType'] == 'video',
    );
  }
}

Future<int> _getNewMessageCount(String uid) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .where('statePerUser.$uid', isEqualTo: 'new')
        .get();
    return snapshot.docs.length;
  } catch (_) {
    return 0;
  }
}

// ================= MAIN =================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Safe OneSignal init
  await OneSignalService.init();
  debugPrint('FirebaseAuth.currentUser after init: ${FirebaseAuth.instance.currentUser}');


  // ✅ Background push handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Sync token
  await PushTokenService.syncToken();

  ErrorHandler.initialize();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10 * 1024 * 1024);

  // ✅ Local notifications
  await NotificationChannels.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => UnreadManager()..init()),
        Provider<PresenceService>(
          create: (_) {
            final svc = PresenceService();
            svc.init();
            return svc;
          },
          dispose: (_, s) => s.dispose(),
        ),
        ChangeNotifierProvider(create: (_) => AstrologyViewModel()),
        ChangeNotifierProvider(create: (_) => FirestoreManager()),
        Provider<SignalingService>(create: (_) => SignalingService()),
        Provider<CallService>(create: (_) => CallService()),
      ],
      child: const AvailChatApp(),
    ),
  );
}

// ================= APP =================

class AvailChatApp extends StatefulWidget {
  const AvailChatApp({super.key});

  @override
  State<AvailChatApp> createState() => _AvailChatAppState();
}

class _AvailChatAppState extends State<AvailChatApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<CallModel?>? _incomingCallSub;
  String? _lastShownCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeFCMForeground();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initIncomingListener();
    });
  }

  void _initIncomingListener() {
    final signaling = Provider.of<SignalingService>(context, listen: false);

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _incomingCallSub?.cancel();
      if (user == null) return;

      _incomingCallSub = signaling.listenForIncomingCalls().listen((call) {
        if (call == null || _lastShownCallId == call.id) return;
        _lastShownCallId = call.id;

        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          _showIncomingCallScreen(call);
        }
      });
    });
  }

  void _showIncomingCallScreen(CallModel call) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(call: call),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _incomingCallSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Destined',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/change-password': (_) => const ChangePasswordScreen(),

        // Ludo game route -> open lobby first
        '/ludo': (_) => const LudoLobbyScreen(),
      },
    );
  }

  // ✅ Foreground FCM
  void _initializeFCMForeground() {
    FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final data = msg.data;
      final type = data['type'] ?? '';

      if (type == 'new_message') {
        await NotificationChannels.showActiveChat(
          title: data['title'] ?? 'New message',
          body: data['body'] ?? 'You have a new message',
        );
      } else if (type == 'call') {
        await NotificationChannels.showIncomingCallNotification(
          callId: data['callId'] ?? '',
          callerName: data['callerName'] ?? 'Unknown',
          isVideo: data['callType'] == 'video',
        );
      }
    });
  }
}