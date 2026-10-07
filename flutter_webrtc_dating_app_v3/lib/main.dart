import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/notification/onesignal_service.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/error_handler.dart';
import 'managers/unread_manager.dart';

import 'screens/auth/splash_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/settings/change_password_screen.dart';

import 'services/auth_service.dart';
import 'services/call/webrtc/signaling_service.dart';
import 'services/call/call_intent_channel.dart';
import 'services/call/call_service.dart';
import 'services/location_service.dart';
import 'services/navigation/pending_intent.dart';
import 'services/safety_service.dart';
import 'services/session_service.dart';

import 'models/call_model.dart';
import 'screens/calls/incoming_call_screen.dart';
import 'services/notification/notification_channels.dart';
import 'feature/games/ludo/ludo_lobby_screen.dart';

// ================= MAIN =================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  ErrorHandler.initialize();
  await _activateAppCheck();

  // Must be set before the first Firestore/RTDB use.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024,
  );
  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
  }

  // Push: OneSignal only (DECISIONS.md DEST-097). No permission prompt here.
  _initOneSignal();
  unawaited(NotificationChannels.initialize(onTap: _onLocalNotificationTap));

  SessionService.instance.start();
  SafetyService.instance.start();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UnreadManager()..init()),
      ],
      child: const AvailChatApp(),
    ),
  );
}

Future<void> _activateAppCheck() async {
  if (kIsWeb) return;
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('App Check activation failed: $e');
  }
}

void _initOneSignal() {
  // The OneSignal Flutter SDK has no web implementation.
  if (kIsWeb) return;
  try {
    OneSignal.initialize(OneSignalService.appId);
    // Registered at startup so the tap that launched the app is delivered.
    OneSignal.Notifications.addClickListener((event) {
      final intent = PendingIntent.fromPushData(
        event.notification.additionalData,
      );
      if (intent != null) PendingIntentRouter.instance.add(intent);
    });
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      if (_suppressForegroundPush(event.notification.additionalData)) {
        event.preventDefault();
      }
    });
  } catch (e) {
    if (kDebugMode) debugPrint('OneSignal init failed: $e');
  }
}

void _onLocalNotificationTap(String? payload) {
  final intent = PendingIntent.fromLocalPayload(payload);
  if (intent != null) PendingIntentRouter.instance.add(intent);
}

/// In the foreground the in-app UI already shows the open chat, and the
/// incoming screen shows a call once it has been admitted; a call it hasn't
/// shown still notifies.
bool _suppressForegroundPush(Map<String, dynamic>? data) {
  final type = data?['type'];
  if (type == 'call') {
    final callId = data?['callId'];
    final calls = CallService();
    return callId is String &&
        (calls.ringingCall?.id == callId || calls.currentCall?.id == callId);
  }
  if (type == 'new_message') {
    final sender = data?['senderId'];
    if (sender is String &&
        SafetyService.instance.hiddenUserIdsNow.contains(sender)) {
      return true;
    }
    final conversationId = data?['conversationId'];
    return conversationId is String &&
        conversationId == PendingIntentRouter.instance.currentChatId;
  }
  return false;
}

// ================= APP =================

class AvailChatApp extends StatefulWidget {
  const AvailChatApp({super.key});

  @override
  State<AvailChatApp> createState() => _AvailChatAppState();
}

class _AvailChatAppState extends State<AvailChatApp>
    with WidgetsBindingObserver {
  // Cold start from a call notification: splash, auth, the RTDB listener and
  // CallService.admitIncoming (consent, room and profile reads) all run first.
  static const Duration _ringingLookup = Duration(seconds: 15);
  static const String _fullScreenExplainedKey = 'full_screen_intent_explained';

  final PendingIntentRouter _router = PendingIntentRouter.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<CallModel?>? _incomingCallSub;
  String? _shownCallId;
  bool _askingPermission = false;
  bool _explainingFullScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router.ready.addListener(_onRouterReadyChanged);
    _router.configure(handler: _handleIntent, canRoute: _canRouteIntents);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    CallIntentChannel.setActionHandler(_onNativeCallAction);
    unawaited(_readInitialCallAction());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.ready.removeListener(_onRouterReadyChanged);
    _authSub?.cancel();
    _incomingCallSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    // The listener may have missed entries while the app was suspended.
    if (CallService().ringingCall == null && !CallService().isInCall) {
      _listenForIncomingCalls();
    }
    _showRingingCall();
    _maybeAskNotificationPermission();
    unawaited(_processPendingDeclines());
  }

  void _onAuthChanged(User? user) {
    _incomingCallSub?.cancel();
    _incomingCallSub = null;
    _shownCallId = null;
    if (user == null) return;
    _listenForIncomingCalls();
    _maybeAskNotificationPermission();
    unawaited(_processPendingDeclines());
  }

  // ---------- Android call notification (MainActivity.kt) ----------

  Future<void> _readInitialCallAction() async {
    final action = await CallIntentChannel.initialAction();
    if (action != null) await _onNativeCallAction(action);
  }

  Future<bool> _onNativeCallAction(Map<String, dynamic> action) async {
    if (action['action'] == CallIntentAction.decline.name) {
      await _processPendingDeclines();
      return true;
    }
    final intent = PendingIntent.fromNativeCall(action);
    if (intent == null) return false;
    if (intent.callAction == CallIntentAction.accept) {
      CallIntentChannel.autoAnswerCallId.value = intent.callId;
    }
    _router.add(intent);
    return true;
  }

  /// Calls declined on the notification while Flutter was not running (or
  /// the native decline write failed). Rejecting twice is harmless.
  Future<void> _processPendingDeclines() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final ids = await CallIntentChannel.consumePendingDeclines();
    for (final id in ids) {
      if (CallService().currentCall?.id == id && CallService().isInCall) {
        continue;
      }
      await CallService().rejectCall(id);
    }
  }

  void _onRouterReadyChanged() {
    if (!_router.ready.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRingingCall();
      _maybeAskNotificationPermission();
    });
  }

  // ---------------- Incoming calls ----------------

  void _listenForIncomingCalls() {
    _incomingCallSub?.cancel();
    // SignalingService drops stale/non-ringing entries and CallService
    // applies consent, block and busy (auto-reject) before emitting.
    _incomingCallSub = SignalingService().listenForIncomingCalls().listen(
      (call) {
        if (call == null) return;
        if (SafetyService.instance.hiddenUserIdsNow.contains(call.callerId)) {
          CallService().rejectCall(call.id);
          return;
        }
        _showRingingCall();
      },
      onError: (Object e) {
        if (kDebugMode) debugPrint('Incoming call listener error: $e');
      },
    );
  }

  bool get _inForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Shows CallService's ringing call once, when the app is in the
  /// foreground and past the splash. Otherwise it is retried on resume and
  /// when the splash finishes.
  void _showRingingCall() {
    final call = CallService().ringingCall;
    if (call == null || call.id == _shownCallId) return;
    if (!_inForeground || !_router.ready.value) return;
    if (_router.hasRoute(
      PendingIntentRouter.incomingCallRouteName,
      arguments: call.id,
    )) {
      _shownCallId = call.id;
      return;
    }
    final nav = _router.navigator;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        settings: RouteSettings(
          name: PendingIntentRouter.incomingCallRouteName,
          arguments: call.id,
        ),
        builder: (_) => IncomingCallScreen(call: call),
        fullscreenDialog: true,
      ),
    );
    _shownCallId = call.id;
  }

  // ---------------- Notification taps ----------------

  Future<bool> _canRouteIntents() async {
    if (FirebaseAuth.instance.currentUser == null) return false;
    try {
      final destination = await SessionService.instance
          .resolveStartDestination();
      return destination == StartDestination.home;
    } catch (_) {
      return true;
    }
  }

  Future<void> _handleIntent(PendingIntent intent) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;
    if (intent.receiverId != null && intent.receiverId != me) return;

    switch (intent.type) {
      case PendingIntentType.chat:
        _openChat(intent);
        break;
      case PendingIntentType.call:
        await _openCall(intent);
        break;
    }
  }

  void _openChat(PendingIntent intent) {
    final other = intent.otherUserId;
    if (SafetyService.instance.hiddenUserIdsNow.contains(other)) return;
    if (intent.conversationId != null &&
        intent.conversationId == _router.currentChatId) {
      return;
    }
    _router.navigator?.push(
      MaterialPageRoute(
        settings: RouteSettings(
          name: PendingIntentRouter.chatRouteName,
          arguments: intent.conversationId,
        ),
        builder: (_) => ChatScreen(
          otherUserId: other,
          conversationId: intent.conversationId,
        ),
      ),
    );
  }

  Future<void> _openCall(PendingIntent intent) async {
    final callId = intent.callId;
    if (callId == null) return;
    final calls = CallService();
    if (intent.callAction == CallIntentAction.decline) {
      await calls.rejectCall(callId);
      return;
    }
    // Re-listening replays the inbox, so a call the listener missed or
    // failed to admit gets another try.
    if (calls.ringingCall?.id != callId &&
        FirebaseAuth.instance.currentUser != null &&
        !calls.isInCall) {
      _listenForIncomingCalls();
    }

    // On cold start the inbox listener may still be admitting this call.
    final deadline = DateTime.now().add(_ringingLookup);
    while (calls.ringingCall?.id != callId &&
        calls.currentCall?.id != callId &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    if (calls.currentCall?.id == callId) return;
    if (calls.ringingCall?.id == callId) {
      _showRingingCall();
      return;
    }
    // Gone (caller hung up, or it was answered/declined elsewhere).
    CallIntentChannel.takeAutoAnswer(callId);
    unawaited(CallIntentChannel.cancelNotification(callId));
    unawaited(CallIntentChannel.releaseLockScreen());
    final name = intent.callerName;
    final kind = intent.isVideo ? 'video' : 'voice';
    _router.showSnackBar(
      name == null ? 'Missed $kind call' : 'Missed $kind call from $name',
    );
  }

  /// Notification, then location, prompts: each asked once per install,
  /// after sign-in and once the user is in the app.
  Future<void> _maybeAskNotificationPermission() async {
    if (!_router.ready.value || !_inForeground) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    if (_askingPermission) return;
    _askingPermission = true;
    try {
      if (!await NotificationChannels.permissionAsked() &&
          await _canRouteIntents()) {
        await NotificationChannels.requestPermissionOnce();
      }
      await LocationService.instance.requestOnce();
    } finally {
      _askingPermission = false;
    }
    await _maybeExplainFullScreenIntent();
  }

  /// Android 14+ needs the user's OK before an incoming call may open
  /// full screen over the lock screen. Explained once, after notifications
  /// are allowed.
  Future<void> _maybeExplainFullScreenIntent() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_explainingFullScreen || !_router.ready.value || !_inForeground) return;
    if (!NotificationChannels.permissionGranted) return;
    _explainingFullScreen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_fullScreenExplainedKey) ?? false) return;
      if (await CallIntentChannel.canUseFullScreenIntent()) return;
      await prefs.setBool(_fullScreenExplainedKey, true);
      final context = _router.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Show incoming calls'),
          content: const Text(
            'To see who is calling when your phone is locked, allow Destined '
            'to show full-screen notifications on the next screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (allow == true) await CallIntentChannel.openFullScreenIntentSettings();
    } catch (e) {
      if (kDebugMode) debugPrint('Full-screen intent explainer failed: $e');
    } finally {
      _explainingFullScreen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Destined',
      debugShowCheckedModeBanner: false,
      navigatorKey: _router.navigatorKey,
      scaffoldMessengerKey: _router.messengerKey,
      navigatorObservers: [_router.observer],
      theme: AppTheme.darkTheme,
      // Honour large text but cap it so layouts stay intact.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            ),
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/change-password': (_) => const ChangePasswordScreen(),

        // Ludo game route -> open lobby first
        '/ludo': (_) => const LudoLobbyScreen(),
      },
    );
  }
}
