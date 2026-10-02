import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Core imports
import 'bottom_navigation/managers/firestore_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/astrology_view_model.dart';
import 'screens/auth/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/presence_service.dart';

// Call-related imports
import 'services/call/webrtc/signaling_service.dart';
import 'models/call_model.dart';
import 'screens/calls/incoming_call_screen.dart';
import 'services/notification/notification_channels.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize notification channels for calls
  await NotificationChannels.initialize();

  runApp(const AvailChatApp());
}

class AvailChatApp extends StatefulWidget {
  const AvailChatApp({super.key});

  @override
  State<AvailChatApp> createState() => _AvailChatAppState();
}

class _AvailChatAppState extends State<AvailChatApp> with WidgetsBindingObserver {
  final SignalingService _signalingService = SignalingService();
  StreamSubscription<CallModel?>? _incomingCallSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCallListener();
  }

  void _initializeCallListener() {
    // Listen for incoming calls only when user is authenticated
    _incomingCallSubscription = _signalingService
        .listenForIncomingCalls()
        .listen((call) {
      if (call != null) {
        _handleIncomingCall(call);
      }
    });
  }

  void _handleIncomingCall(CallModel call) {
    // Check if app is in foreground
    final appState = WidgetsBinding.instance.lifecycleState;

    if (appState == AppLifecycleState.resumed) {
      // App is in foreground, show incoming call screen
      _showIncomingCallScreen(call);
    } else {
      // App is in background, show notification (handled by FCM)
      // The notification will bring app to foreground
      // Then incoming call screen will be shown
    }
  }

  void _showIncomingCallScreen(CallModel call) {
    // Use navigator key to show incoming call from anywhere
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(call: call),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle for calls
    if (state == AppLifecycleState.paused) {
      // App going to background
      debugPrint('App going to background');
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground
      debugPrint('App coming to foreground');

      // Re-initialize call listener if needed
      if (_incomingCallSubscription == null) {
        _initializeCallListener();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Regular providers (non-ChangeNotifier)
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),

        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),

        Provider<PresenceService>(
          create: (_) {
            final svc = PresenceService();
            svc.init();
            return svc;
          },
          dispose: (_, service) => service.dispose(),
        ),

        // ChangeNotifier providers (auto-dispose)
        ChangeNotifierProvider<AstrologyViewModel>(
          create: (_) => AstrologyViewModel(),
        ),

        ChangeNotifierProvider<FirestoreManager>(
          create: (_) => FirestoreManager(),
        ),

        // Add SignalingService provider for global access
        Provider<SignalingService>(
          create: (_) => _signalingService,
        ),
      ],
      child: MaterialApp(
        title: 'Destined',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey, // Important for showing calls from anywhere
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),

        // Add routes if needed
        routes: {
          '/splash': (context) => const SplashScreen(),
          // Add more routes as needed
        },

        // Handle errors
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child!,
          );
        },
      ),
    );
  }
}