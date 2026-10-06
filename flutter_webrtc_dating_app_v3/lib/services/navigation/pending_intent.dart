import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PendingIntentType { chat, call }

/// What the user did on the incoming-call notification. Push and local
/// notification taps are [show].
enum CallIntentAction { show, accept, decline }

/// Something the user asked to open from outside the app (push or local
/// notification tap). Built from untrusted payloads; handlers re-check
/// ownership and current state before acting.
@immutable
class PendingIntent {
  final PendingIntentType type;
  final String otherUserId;
  final String? receiverId;
  final String? conversationId;
  final String? callId;
  final String? callerName;
  final bool isVideo;
  final CallIntentAction callAction;

  const PendingIntent.chat({
    required this.otherUserId,
    this.conversationId,
    this.receiverId,
  }) : type = PendingIntentType.chat,
       callId = null,
       callerName = null,
       isVideo = false,
       callAction = CallIntentAction.show;

  const PendingIntent.call({
    required this.callId,
    required this.otherUserId,
    this.callerName,
    this.isVideo = false,
    this.receiverId,
    this.callAction = CallIntentAction.show,
  }) : type = PendingIntentType.call,
       conversationId = null;

  String get key => type == PendingIntentType.call
      ? 'call:$callId'
      : 'chat:${conversationId ?? otherUserId}';

  /// OneSignal `additionalData` as sent by functions/index.js.
  static PendingIntent? fromPushData(Map<String, dynamic>? data) {
    if (data == null) return null;
    String? str(String k) {
      final v = data[k];
      return v is String && v.isNotEmpty ? v : null;
    }

    switch (str('type')) {
      case 'new_message':
        final sender = str('senderId');
        if (sender == null) return null;
        return PendingIntent.chat(
          otherUserId: sender,
          conversationId: str('conversationId'),
          receiverId: str('receiverId'),
        );
      case 'missed_call':
        // Opens the chat with the caller; never treated as a ringing call.
        final missedFrom = str('callerId');
        if (missedFrom == null) return null;
        return PendingIntent.chat(
          otherUserId: missedFrom,
          conversationId: str('conversationId'),
          receiverId: str('receiverId'),
        );
      case 'call':
        final callId = str('callId');
        final caller = str('callerId');
        if (callId == null || caller == null) return null;
        return PendingIntent.call(
          callId: callId,
          otherUserId: caller,
          callerName: str('callerName'),
          isVideo: str('callType') == 'video',
          receiverId: str('receiverId'),
        );
    }
    return null;
  }

  /// Android's native incoming-call notification (MainActivity.kt
  /// `call_intent` channel): `{action, callId, callerId, callerName,
  /// callType, receiverId}`.
  static PendingIntent? fromNativeCall(Map<String, dynamic>? data) {
    if (data == null) return null;
    final call = fromPushData({...data, 'type': 'call'});
    if (call == null) return null;
    final action = CallIntentAction.values.firstWhere(
      (a) => a.name == data['action'],
      orElse: () => CallIntentAction.show,
    );
    return PendingIntent.call(
      callId: call.callId,
      otherUserId: call.otherUserId,
      callerName: call.callerName,
      isVideo: call.isVideo,
      receiverId: call.receiverId,
      callAction: action,
    );
  }

  /// Local notification payload: `chat:<otherUid>[:<conversationId>]` or
  /// `call:<callId>[:<callerUid>]`. Use [chatPayload]/[callPayload] to build.
  static PendingIntent? fromLocalPayload(String? payload) {
    if (payload == null) return null;
    final parts = payload.split(':');
    if (parts.length < 2 || parts[1].isEmpty) return null;
    switch (parts[0]) {
      case 'chat':
        return PendingIntent.chat(
          otherUserId: parts[1],
          conversationId: parts.length > 2 && parts[2].isNotEmpty
              ? parts[2]
              : null,
        );
      case 'call':
        return PendingIntent.call(
          callId: parts[1],
          otherUserId: parts.length > 2 ? parts[2] : '',
        );
    }
    return null;
  }

  static String chatPayload(String otherUid, [String? conversationId]) =>
      'chat:$otherUid:${conversationId ?? ''}';

  static String callPayload(String callId, String callerUid) =>
      'call:$callId:$callerUid';
}

typedef PendingIntentHandler = Future<void> Function(PendingIntent intent);

/// Root navigator access plus a queue of [PendingIntent]s that is drained
/// only once the splash screen has left the stack (splash routes with
/// pushAndRemoveUntil, which would drop anything pushed earlier).
/// Also knows which conversation is on screen, for foreground suppression.
class PendingIntentRouter {
  PendingIntentRouter._();
  static final PendingIntentRouter instance = PendingIntentRouter._();

  static const Set<String> splashRouteNames = {'/', '/splash'};
  static const String chatRouteName = '/chat';
  static const String incomingCallRouteName = '/incoming_call';

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late final NavigatorObserver observer = _RouteTracker(this);

  /// True once the splash has been replaced by a real screen.
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  final Queue<PendingIntent> _queue = Queue<PendingIntent>();
  final List<Route<dynamic>> _pages = [];
  final Map<Route<dynamic>, String> _chatByRoute = {};
  PendingIntentHandler? _handler;
  Future<bool> Function()? _canRoute;
  bool _draining = false;
  bool _sawFirstRoute = false;

  /// [canRoute] is checked before each drain; when false the queue is
  /// dropped (signed out, or still in onboarding).
  void configure({
    required PendingIntentHandler handler,
    Future<bool> Function()? canRoute,
  }) {
    _handler = handler;
    _canRoute = canRoute;
    _scheduleDrain();
  }

  void add(PendingIntent intent) {
    _queue.removeWhere((i) => i.key == intent.key);
    _queue.add(intent);
    _scheduleDrain();
  }

  NavigatorState? get navigator => navigatorKey.currentState;

  bool hasRoute(String name, {Object? arguments}) => _pages.any(
    (r) =>
        r.settings.name == name &&
        (arguments == null || r.settings.arguments == arguments),
  );

  /// Conversation shown by the top-most page, if it is a chat.
  String? get currentChatId {
    if (_pages.isEmpty) return null;
    final top = _pages.last;
    final registered = _chatByRoute[top];
    if (registered != null) return registered;
    final args = top.settings.arguments;
    return top.settings.name == chatRouteName && args is String ? args : null;
  }

  /// Called by ChatScreen so chats opened from anywhere are recognised.
  void registerChat(Route<dynamic> route, String conversationId) {
    if (conversationId.isNotEmpty) _chatByRoute[route] = conversationId;
  }

  void unregisterChat(Route<dynamic> route) => _chatByRoute.remove(route);

  void showSnackBar(String message) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleDrain() {
    if (!ready.value || _queue.isEmpty) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _drain())
      ..scheduleFrame();
  }

  Future<void> _drain() async {
    final handler = _handler;
    if (_draining || handler == null || !ready.value) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && ready.value) {
        final canRoute = _canRoute;
        if (canRoute != null && !await canRoute()) {
          _queue.clear();
          break;
        }
        if (_queue.isEmpty || !ready.value) break;
        final intent = _queue.removeFirst();
        try {
          await handler(intent);
        } catch (e) {
          if (kDebugMode) debugPrint('PendingIntent ${intent.type} failed: $e');
        }
      }
    } finally {
      _draining = false;
    }
  }

  void _onStackChanged() {
    final splashOnStack = _pages.any(
      (r) => splashRouteNames.contains(r.settings.name),
    );
    final isReady = _sawFirstRoute && !splashOnStack;
    if (ready.value != isReady) {
      ready.value = isReady;
      _scheduleDrain();
    }
  }

  void _push(Route<dynamic> route) {
    if (route is! PageRoute) return;
    _sawFirstRoute = true;
    _pages.add(route);
    _onStackChanged();
  }

  void _remove(Route<dynamic>? route) {
    if (route == null || !_pages.remove(route)) return;
    _chatByRoute.remove(route);
    _onStackChanged();
  }

  void _replace(Route<dynamic>? newRoute, Route<dynamic>? oldRoute) {
    final index = oldRoute == null ? -1 : _pages.indexOf(oldRoute);
    if (index < 0) {
      _remove(oldRoute);
      if (newRoute != null) _push(newRoute);
      return;
    }
    _chatByRoute.remove(oldRoute);
    if (newRoute is PageRoute) {
      _pages[index] = newRoute;
    } else {
      _pages.removeAt(index);
    }
    _onStackChanged();
  }
}

class _RouteTracker extends NavigatorObserver {
  _RouteTracker(this._router);
  final PendingIntentRouter _router;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _router._push(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _router._remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _router._remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _router._replace(newRoute, oldRoute);
}
