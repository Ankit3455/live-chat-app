import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Models
import '../../models/call_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/conversation_model.dart';
import '../../models/public_profile.dart';
import '../../models/user_model.dart';

// Services
import '../../services/call/call_consent.dart';
import '../../services/call/call_service.dart';
import '../../services/chat_service.dart';
import '../../services/discovery_feed_service.dart';
import '../../services/media/chat_media_service.dart';
import '../../services/navigation/pending_intent.dart';
import '../../services/notification/onesignal_sender.dart';
import '../../services/safety_service.dart';

// UI Components
import '../../core/constants/app_colors.dart';
import '../../widgets/app_states.dart';
import 'widgets/attachment_sheet.dart';
import 'widgets/call_settings_sheet.dart';
import 'widgets/message_bubble.dart';
import 'widgets/report_dialog.dart';
import 'widgets/typing_bubble.dart';
import 'widgets/voice_recording_sheet.dart';

// Call Screens
import '../calls/audio_call_screen.dart';
import '../calls/video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String? conversationId;

  const ChatScreen({Key? key, required this.otherUserId, this.conversationId})
    : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const int _pageSize = 30;
  static const Duration _typingHeartbeat = Duration(seconds: 3);
  static const Duration _typingIdle = Duration(seconds: 4);

  final ChatService _chatService = ChatService();
  final CallService _callService = CallService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  /// Null until resolved; nothing that needs it is built before then.
  String? _conversationId;
  String? _initError;

  /// This screen's route, registered so foreground pushes for this chat are
  /// suppressed however the chat was opened.
  Route<dynamic>? _route;
  bool _isLoading = true;

  /// Latest conversation doc (null while no message was ever sent).
  Conversation? _conversation;
  Map<String, dynamic>? _convData;

  /// Mirrors [_convData] for the call settings sheet.
  final ValueNotifier<Map<String, dynamic>?> _convDataNotifier = ValueNotifier(
    null,
  );
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _convSub;

  UserModel? _otherUser;
  bool? _otherOnline;
  bool _otherTyping = false;
  bool _isBlocked = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _onlineSub;
  StreamSubscription<bool>? _typingSub;
  StreamSubscription<bool>? _blockedSub;

  bool _isSending = false;
  bool _isUploadingMedia = false;
  bool _isCallInProgress = false;
  ChatMessage? _replyToMessage;
  ChatMessage? _editingMessage;

  DateTime? _lastTypingBeat;
  Timer? _typingStopTimer;

  bool _isForeground = true;
  Timer? _readDebounce;

  // Messages, newest first. The live listener inserts new ones at the head,
  // pagination appends older pages.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesLiveSub;
  final List<ChatMessage> _messages = [];
  final Set<String> _messageIds = {};
  final Map<String, GlobalKey> _itemKeys = {};
  DateTime? _clearedBefore;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _pageError = false;
  DocumentSnapshot? _lastDoc;

  /// Bumped on every reset so late page results from an old cutoff are dropped.
  int _listGeneration = 0;

  String? _highlightedId;
  Timer? _highlightTimer;

  String get _myUid => _chatService.currentUserId;

  bool get _isOtherDeleted =>
      _conversation?.isDeletedUser(widget.otherUserId) ?? false;

  bool get _canSend =>
      _conversationId != null && !_isBlocked && !_isOtherDeleted;

  String get _displayName =>
      _isOtherDeleted ? 'Deleted user' : (_otherUser?.username ?? 'User');

  String? get _otherAvatar {
    final u = _otherUser;
    if (u == null || _isOtherDeleted) return null;
    if (u.profileImage.isNotEmpty) return u.profileImage;
    final generated = u.avatarProperties?['avatarImageUrl'];
    if (generated is String && generated.isNotEmpty) return generated;
    final legacy = u.avatarString;
    return (legacy != null && legacy.startsWith('http')) ? legacy : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _messageController.addListener(_onTypingChanged);
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final route = _route;
    if (route != null) PendingIntentRouter.instance.unregisterChat(route);
    _stopTyping();
    _cancelSubscriptions();
    _readDebounce?.cancel();
    _highlightTimer?.cancel();
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _convDataNotifier.dispose();
    super.dispose();
  }

  void _cancelSubscriptions() {
    _messagesLiveSub?.cancel();
    _convSub?.cancel();
    _onlineSub?.cancel();
    _typingSub?.cancel();
    _blockedSub?.cancel();
    _messagesLiveSub = null;
    _convSub = null;
    _onlineSub = null;
    _typingSub = null;
    _blockedSub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _markReadDebounced();
    } else {
      _readDebounce?.cancel();
      _stopTyping();
    }
  }

  void _log(String where, Object e) {
    if (kDebugMode) debugPrint('ChatScreen.$where: $e');
  }

  // ============= Init =============
  Future<void> _initializeChat() async {
    final me = _myUid;
    final other = widget.otherUserId;
    if (me.isEmpty) {
      _setInitError('You are signed out. Please sign in again.');
      return;
    }
    if (other.isEmpty || other == me) {
      _setInitError('This chat is not available.');
      return;
    }

    try {
      final given = widget.conversationId;
      final convId = (given != null && given.isNotEmpty)
          ? given
          : await _chatService.getOrCreateConversation(other);
      if (!mounted) return;
      if (convId.isEmpty) throw StateError('No conversation id');

      final results = await Future.wait<Object?>([
        FirebaseFirestore.instance
            .collection('conversations')
            .doc(convId)
            .get(),
        DiscoveryFeed.fetchProfile(other, myUid: me),
      ]);
      if (!mounted) return;

      final snap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      _conversationId = convId;
      _route ??= ModalRoute.of(context);
      final route = _route;
      if (route != null) {
        PendingIntentRouter.instance.registerChat(route, convId);
      }
      _applyConversation(snap);
      _clearedBefore = _conversation?.clearedBeforeFor(me);
      _otherUser = results[1] as UserModel?;

      await _loadMoreMessages(initial: true);
      if (!mounted) return;

      _startLiveNewMessageListener();
      _subscribe(convId);
      _markReadDebounced();

      setState(() => _isLoading = false);
    } catch (e) {
      _log('init', e);
      _setInitError(
        'Could not open this chat. Check your connection and try again.',
      );
    }
  }

  void _setInitError(String message) {
    if (!mounted) return;
    setState(() {
      _initError = message;
      _isLoading = false;
    });
  }

  void _retryInit() {
    _cancelSubscriptions();
    _listGeneration++;
    setState(() {
      _initError = null;
      _isLoading = true;
      _conversationId = null;
      _messages.clear();
      _messageIds.clear();
      _itemKeys.clear();
      _lastDoc = null;
      _hasMore = true;
      _isLoadingMore = false;
      _pageError = false;
    });
    _initializeChat();
  }

  void _subscribe(String convId) {
    final other = widget.otherUserId;

    _convSub = FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId)
        .snapshots()
        .listen(_onConversation, onError: (Object e) => _log('conv', e));

    _typingSub = _chatService.getTypingStatus(convId, other).listen((typing) {
      if (mounted && typing != _otherTyping) {
        setState(() => _otherTyping = typing);
      }
    });

    _blockedSub = SafetyService.instance.watchIsBlockedBetween(other).listen((
      blocked,
    ) {
      if (!mounted || blocked == _isBlocked) return;
      setState(() {
        _isBlocked = blocked;
        if (blocked) {
          _replyToMessage = null;
          _editingMessage = null;
        }
      });
      if (blocked) _stopTyping();
    }, onError: (Object e) => _log('blocked', e));

    _watchOnline();
  }

  /// Online dot from the public profile, or the users doc until the
  /// public_profiles backfill has run.
  Future<void> _watchOnline() async {
    final db = FirebaseFirestore.instance;
    final other = widget.otherUserId;
    DocumentReference<Map<String, dynamic>> ref = db
        .collection(PublicProfile.collection)
        .doc(other);
    try {
      final snap = await ref.get();
      if (!snap.exists) ref = db.collection('users').doc(other);
    } catch (_) {
      ref = db.collection('users').doc(other);
    }
    if (!mounted) return;
    _onlineSub?.cancel();
    _onlineSub = ref.snapshots().listen((snap) {
      final online = snap.data()?['online'] == true;
      if (mounted && online != _otherOnline) {
        setState(() => _otherOnline = online);
      }
    }, onError: (Object e) => _log('online', e));
  }

  void _applyConversation(DocumentSnapshot<Map<String, dynamic>> snap) {
    _convData = snap.data();
    _convDataNotifier.value = _convData;
    _conversation = snap.exists ? Conversation.fromFirestore(snap) : null;
  }

  void _onConversation(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    setState(() => _applyConversation(snap));

    // Clear chat on this or another device: restart with the server cutoff.
    final serverCutoff = _conversation?.clearedBeforeFor(_myUid);
    if (serverCutoff != null &&
        !snap.metadata.hasPendingWrites &&
        serverCutoff != _clearedBefore) {
      _resetMessages(serverCutoff);
    }
  }

  // ============= Read receipts =============
  void _markReadDebounced() {
    _readDebounce?.cancel();
    final convId = _conversationId;
    if (convId == null || !_isForeground) return;
    _readDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!_isForeground) return;
      _chatService.markMessagesAsRead(convId, widget.otherUserId);
    });
  }

  // ============= Typing =============
  void _onTypingChanged() {
    final convId = _conversationId;
    if (convId == null || _conversation == null || !_canSend) return;
    if (_editingMessage != null || _messageController.text.trim().isEmpty) {
      _stopTyping();
      return;
    }

    final now = DateTime.now();
    final last = _lastTypingBeat;
    if (last == null || now.difference(last) >= _typingHeartbeat) {
      _lastTypingBeat = now;
      _chatService.updateTypingStatus(convId, true);
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(_typingIdle, _stopTyping);
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    if (_lastTypingBeat == null) return;
    _lastTypingBeat = null;
    final convId = _conversationId;
    if (convId != null) _chatService.updateTypingStatus(convId, false);
  }

  // ============= Pagination Loader =============
  Query<Map<String, dynamic>> _messagesQuery(String convId) {
    Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('timestamp', descending: true);
    final cutoff = _clearedBefore;
    if (cutoff != null) {
      ref = ref.where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff));
    }
    return ref;
  }

  /// Loads the next older page. With [initial], errors propagate to init.
  Future<void> _loadMoreMessages({bool initial = false}) async {
    final convId = _conversationId;
    if (convId == null || _isLoadingMore || !_hasMore) return;
    final gen = _listGeneration;

    _isLoadingMore = true;
    if (mounted && !initial) setState(() => _pageError = false);

    try {
      final ref = _messagesQuery(convId).limit(_pageSize);
      final last = _lastDoc;
      final snap = await (last == null
          ? ref.get()
          : ref.startAfterDocument(last).get());
      if (!mounted || gen != _listGeneration) return;

      final docs = snap.docs;
      if (docs.length < _pageSize) _hasMore = false;
      if (docs.isNotEmpty) _lastDoc = docs.last;
      for (final d in docs) {
        final m = ChatMessage.fromFirestore(d);
        if (_messageIds.add(m.id)) _messages.add(m);
      }
    } catch (e) {
      if (initial) rethrow;
      _log('loadMore', e);
      if (gen == _listGeneration) _pageError = true;
    } finally {
      if (gen == _listGeneration) {
        _isLoadingMore = false;
        if (mounted && !initial) setState(() {});
      }
    }
  }

  /// Drops the loaded list and reloads everything after [cutoff].
  void _resetMessages(DateTime? cutoff) {
    if (!mounted) return;
    _listGeneration++;
    setState(() {
      _clearedBefore = cutoff;
      _messages.clear();
      _messageIds.clear();
      _itemKeys.clear();
      _lastDoc = null;
      _hasMore = true;
      _isLoadingMore = false;
      _pageError = false;
      _replyToMessage = null;
    });
    _startLiveNewMessageListener();
    _loadMoreMessages();
  }

  // === Live listener for newest messages ===
  void _startLiveNewMessageListener() {
    _messagesLiveSub?.cancel();
    final convId = _conversationId;
    if (convId == null) return;
    final cutoff = _clearedBefore;

    _messagesLiveSub = _messagesQuery(convId).limit(20).snapshots().listen((
      snap,
    ) {
      if (!mounted) return;

      var listChanged = false;
      var hasIncoming = false;

      for (final c in snap.docChanges) {
        // Leaving the head window is not a deletion.
        if (c.type == DocumentChangeType.removed) continue;
        if (c.doc.data() == null) continue;

        // Pending server timestamps read as "now" (local estimate).
        final msg = ChatMessage.fromFirestore(c.doc);
        if (cutoff != null && !msg.timestamp.isAfter(cutoff)) continue;

        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx != -1) {
          _messages.removeAt(idx);
          _insertSorted(msg);
          listChanged = true;
          continue;
        }
        if (c.type != DocumentChangeType.added) continue;

        _insertSorted(msg);
        _messageIds.add(msg.id);
        listChanged = true;
        if (msg.senderId == widget.otherUserId) hasIncoming = true;
      }

      if (hasIncoming) {
        if (_isForeground) {
          _markReadDebounced();
        } else {
          _chatService.markDelivered(convId, widget.otherUserId);
        }
      }
      if (listChanged) setState(() {});
    }, onError: (Object e) => _log('live', e));
  }

  /// Keeps [_messages] sorted newest first.
  void _insertSorted(ChatMessage msg) {
    var i = 0;
    while (i < _messages.length &&
        !_messages[i].timestamp.isBefore(msg.timestamp)) {
      i++;
    }
    _messages.insert(i, msg);
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _notifyReceiver(String convId, String messageId) {
    unawaited(
      OneSignalSender.sendChatNotification(
        conversationId: convId,
        messageId: messageId,
      ),
    );
  }

  // ============= Send / edit message =============
  Future<void> _sendMessage() async {
    final convId = _conversationId;
    final text = _messageController.text.trim();
    if (convId == null || text.isEmpty || _isSending || !_canSend) return;

    final editing = _editingMessage;
    final replyTo = _replyToMessage;

    setState(() => _isSending = true);
    _messageController.clear();
    _stopTyping();

    try {
      if (editing != null) {
        await _chatService.editMessage(convId, editing.id, text);
        if (!mounted) return;
        setState(() => _editingMessage = null);
        return;
      }

      final messageId = await _chatService.sendMessage(
        conversationId: convId,
        receiverId: widget.otherUserId,
        message: text,
        replyToMessageId: replyTo?.id,
        replyTo: replyTo?.toReplySnapshot(),
      );
      if (messageId == null) throw StateError('Message was not sent');

      _notifyReceiver(convId, messageId);
      if (!mounted) return;
      if (identical(_replyToMessage, replyTo)) {
        setState(() => _replyToMessage = null);
      }
      _scrollToLatest();
    } catch (e) {
      _log('send', e);
      if (!mounted) return;
      // Give the text back unless the user already typed something new.
      if (_messageController.text.isEmpty) {
        _messageController.text = text;
        _messageController.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
      _showSnackBar(
        editing != null ? 'Failed to edit message' : 'Failed to send message',
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _editMessage(ChatMessage message) {
    if (!_canSend || message.isDeleted) return;
    setState(() {
      _editingMessage = message;
      _replyToMessage = null;
    });
    _messageController.text = message.message;
    _messageController.selection = TextSelection.collapsed(
      offset: message.message.length,
    );
    _messageFocusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editingMessage = null);
    _messageController.clear();
  }

  // ============= CALL METHODS =============
  bool _callAllowed(CallType type) {
    final data = _convData;
    return data != null &&
        CallConsent.isAllowed(data, _myUid, widget.otherUserId, type);
  }

  /// Neither call type is currently allowed for both users.
  bool get _callsOff =>
      !_callAllowed(CallType.audio) && !_callAllowed(CallType.video);

  /// Writes my call setting; returns false on failure.
  Future<bool> _setCallEnabled(CallType type, bool enabled) async {
    final convId = _conversationId;
    if (convId == null || _conversation == null) {
      _showSnackBar('Send a message first to enable calls.');
      return false;
    }
    try {
      await CallConsent.setCallEnabled(
        conversationId: convId,
        uid: _myUid,
        type: type,
        enabled: enabled,
      );
      return true;
    } catch (e) {
      _log('setCallEnabled', e);
      _showSnackBar('Could not update call permission. Try again.');
      return false;
    }
  }

  void _openCallSettings() {
    if (!_canSend) return;
    unawaited(
      CallSettingsSheet.show(
        context,
        otherName: _displayName,
        myUid: _myUid,
        otherUid: widget.otherUserId,
        conversation: _convDataNotifier,
        canEdit: _conversation != null,
        onChanged: _setCallEnabled,
      ),
    );
  }

  Future<void> _startCall(CallType type) async {
    final convId = _conversationId;
    if (convId == null || !_canSend) return;
    if (_isCallInProgress || _callService.isBusy) {
      _showSnackBar('A call is already in progress');
      return;
    }
    if (!_callAllowed(type)) {
      _showSnackBar(CallConsent.consentTooltip);
      return;
    }

    setState(() => _isCallInProgress = true);
    final navigator = Navigator.of(context);

    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.purplePrimary),
                const SizedBox(height: 15),
                Text(
                  'Initiating ${type == CallType.video ? "video" : "voice"} call...',
                  style: const TextStyle(
                    color: AppColors.inputTextWhite,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => dialogOpen = false);

    void closeDialog() {
      if (!dialogOpen) return;
      dialogOpen = false;
      navigator.pop();
    }

    try {
      final callId = await _callService.startCall(
        receiverId: widget.otherUserId,
        type: type,
        receiverName: _displayName,
        receiverAvatar: _otherAvatar,
        conversationId: convId,
      );
      closeDialog();
      if (!mounted) return;

      // Call screens close themselves and show the end reason.
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => type == CallType.video
              ? VideoCallScreen(callId: callId, isOutgoing: true)
              : AudioCallScreen(callId: callId, isOutgoing: true),
        ),
      );
    } on CallNotAllowedException catch (e) {
      closeDialog();
      _showSnackBar(e.message);
    } on CallPermissionDeniedException catch (e) {
      closeDialog();
      _showSnackBar(
        e.message,
        action: SnackBarAction(
          label: 'Settings',
          textColor: AppColors.white,
          onPressed: openAppSettings,
        ),
      );
    } on StateError catch (e) {
      closeDialog();
      _log('startCall', e);
      _showSnackBar(
        _callService.isBusy
            ? 'A call is already in progress'
            : 'Failed to start call',
      );
    } catch (e) {
      closeDialog();
      _log('startCall', e);
      _showSnackBar('Failed to start call');
    } finally {
      if (mounted) setState(() => _isCallInProgress = false);
    }
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.purplePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: action,
      ),
    );
  }

  // ============= UI BUILDERS =============
  @override
  Widget build(BuildContext context) {
    if (_initError != null) return _buildInitError();

    if (_isLoading || _conversationId == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPurpleMid),
        ),
      );
    }

    final editing = _editingMessage;
    final replyTo = _replyToMessage;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_canSend && _callsOff) _buildCallsOffCard(),
          Expanded(child: _buildMessagesList()),
          _buildTypingIndicator(),
          if (_canSend && editing != null)
            _buildComposerBanner(
              icon: Icons.edit,
              title: 'Editing message',
              text: editing.message,
              onClose: _cancelEdit,
            )
          else if (_canSend && replyTo != null)
            _buildComposerBanner(
              icon: Icons.reply,
              title:
                  'Replying to ${replyTo.senderId == _myUid ? "yourself" : _displayName}',
              text: replyTo.previewText,
              onClose: () => setState(() => _replyToMessage = null),
            ),
          _canSend ? _buildMessageInput() : _buildUnavailableInput(),
        ],
      ),
    );
  }

  Widget _buildInitError() {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        title: const Text('Chat'),
      ),
      body: AppEmptyState(
        icon: Icons.cloud_off,
        title: 'Chat unavailable',
        message: _initError,
        actionLabel: 'Retry',
        onAction: _myUid.isEmpty ? null : _retryInit,
      ),
    );
  }

  AppBar _buildAppBar() {
    final displayName = _displayName;
    final avatarUrl = _otherAvatar;
    final showOnline = _otherOnline != null && !_isBlocked && !_isOtherDeleted;
    final isOnline = _otherOnline == true;

    return AppBar(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      titleSpacing: 0,
      title: Semantics(
        label: showOnline
            ? '$displayName, ${isOnline ? 'online' : 'offline'}'
            : displayName,
        excludeSemantics: true,
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl, maxWidth: 120)
                      : null,
                  backgroundColor: AppColors.surface2,
                  child: avatarUrl == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                if (showOnline && isOnline)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surfaceRaised,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showOnline)
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline
                            ? AppColors.success
                            : AppColors.lavender,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_conversation?.isMuted(_myUid) ?? false)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(
              Icons.volume_off,
              size: 18,
              color: AppColors.lavender,
              semanticLabel: 'Muted',
            ),
          ),
        if (_canSend) ...[
          _buildCallButton(CallType.audio),
          _buildCallButton(CallType.video),
        ],
        _buildMenu(),
      ],
    );
  }

  static const String _callsOffTooltip =
      'Calls work when both of you turn them on';

  Widget _buildCallButton(CallType type) {
    final isVideo = type == CallType.video;
    final allowed = _callAllowed(type);
    final enabled = allowed && !_isCallInProgress;
    return IconButton(
      icon: Icon(
        isVideo ? Icons.videocam_outlined : Icons.call_outlined,
        color: enabled ? AppColors.white : AppColors.textSubtle,
      ),
      tooltip: allowed
          ? (isVideo ? 'Video call' : 'Voice call')
          : _callsOffTooltip,
      onPressed: _isCallInProgress
          ? null
          : (allowed ? () => _startCall(type) : _openCallSettings),
    );
  }

  /// Shown above the messages while no call type is allowed for both users.
  Widget _buildCallsOffCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandPurpleMid.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 18,
              color: AppColors.brandPurpleLight,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Calls are off for this chat',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Calls work only when both of you turn them on.',
                  style: TextStyle(color: AppColors.lavender, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _openCallSettings,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              backgroundColor: AppColors.surfaceCard,
              side: const BorderSide(color: AppColors.borderStrong),
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Set up'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    final hasConversation = _conversation != null;
    final blockedByMe = SafetyService.instance.hasBlocked(widget.otherUserId);

    return PopupMenuButton<String>(
      tooltip: 'Chat options',
      icon: const Icon(Icons.more_vert, color: AppColors.white),
      onSelected: (value) {
        switch (value) {
          case 'calls':
            _openCallSettings();
            break;
          case 'clear':
            _clearChat();
            break;
          case 'block':
            _blockUser();
            break;
          case 'unblock':
            _unblockUser();
            break;
          case 'report':
            _reportUser();
            break;
        }
      },
      itemBuilder: (context) => [
        if (_canSend) ...[
          const PopupMenuItem<String>(
            value: 'calls',
            child: Text('Call settings'),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<String>(
          value: 'clear',
          enabled: hasConversation,
          child: const Text('Clear chat'),
        ),
        if (!_isOtherDeleted)
          blockedByMe
              ? const PopupMenuItem<String>(
                  value: 'unblock',
                  child: Text('Unblock user'),
                )
              : const PopupMenuItem<String>(
                  value: 'block',
                  child: Text('Block user'),
                ),
        if (!_isOtherDeleted)
          const PopupMenuItem<String>(
            value: 'report',
            child: Text('Report user'),
          ),
      ],
    );
  }

  ChatMessage? _findLoaded(String id) {
    for (final m in _messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _scrollToMessage(String id) async {
    final ctx = _itemKeys[id]?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
      _highlight(id);
      return;
    }

    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1 || !_scrollController.hasClients) {
      _showSnackBar('The original message is no longer available');
      return;
    }

    // Not built yet: jump close to it, then align once it is laid out.
    final position = _scrollController.position;
    final estimate = (index * 72.0).clamp(0.0, position.maxScrollExtent);
    await _scrollController.animateTo(
      estimate,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _itemKeys[id]?.currentContext;
      if (c == null || !mounted) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 200),
        alignment: 0.5,
      );
      _highlight(id);
    });
  }

  void _highlight(String id) {
    if (!mounted) return;
    _highlightTimer?.cancel();
    setState(() => _highlightedId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  // Messages list with infinite scroll
  Widget _buildMessagesList() {
    if (_messages.isEmpty && !_hasMore && !_pageError) {
      return _isOtherDeleted
          ? const AppEmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No messages',
            )
          : AppEmptyState(
              icon: Icons.waving_hand_outlined,
              title: 'No messages yet',
              message: 'Say hi to $_displayName!',
            );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent * 0.90 &&
            !_isLoadingMore &&
            !_pageError &&
            _hasMore) {
          _loadMoreMessages();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        itemCount: _messages.length + 1,
        itemBuilder: (context, index) {
          if (index == _messages.length) return _buildListHead();

          final message = _messages[index];
          final isMe = message.senderId == _myUid;
          final showDate = _shouldShowDate(_messages, index, message.timestamp);

          final legacyReplyId = message.replyTo == null
              ? message.replyToMessageId
              : null;

          return KeyedSubtree(
            key: ValueKey(message.id),
            child: Column(
              key: _keyFor(message.id),
              children: [
                if (showDate) _buildDateSeparator(message.timestamp),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  color: _highlightedId == message.id
                      ? AppColors.purplePrimary.withOpacity(0.15)
                      : Colors.transparent,
                  child: MessageBubble(
                    message: message,
                    isMe: isMe,
                    otherUserName: _displayName,
                    repliedMessage: legacyReplyId == null
                        ? null
                        : _findLoaded(legacyReplyId),
                    onReplyTap: _scrollToMessage,
                    onReply: _canSend
                        ? () {
                            setState(() {
                              _replyToMessage = message;
                              _editingMessage = null;
                            });
                            _messageFocusNode.requestFocus();
                          }
                        : null,
                    onEdit: isMe && _canSend
                        ? () => _editMessage(message)
                        : null,
                    onDelete: isMe ? () => _deleteMessage(message) : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Oldest end of the list: page loader, retry, or nothing.
  Widget _buildListHead() {
    if (_pageError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: _loadMoreMessages,
            icon: const Icon(Icons.refresh, color: AppColors.brandPurpleLight),
            label: const Text(
              'Could not load messages. Retry',
              style: TextStyle(color: AppColors.hintPurple),
            ),
          ),
        ),
      );
    }
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.purplePrimary),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTypingIndicator() {
    if (!_otherTyping || !_canSend) return const SizedBox.shrink();
    return TypingBubble(name: _displayName);
  }

  /// Reply / edit banner above the input.
  Widget _buildComposerBanner({
    required IconData icon,
    required String title,
    required String text,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandPurpleMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: AppColors.brandPurpleLight),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.brandPurpleLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.lavender,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppColors.lavender),
            tooltip: 'Cancel',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  /// Shown instead of the input when the chat is blocked or the other
  /// account was deleted.
  Widget _buildUnavailableInput() {
    final blockedByMe = SafetyService.instance.hasBlocked(widget.otherUserId);
    final String text;
    if (_isOtherDeleted) {
      text = 'This account was deleted.';
    } else if (blockedByMe) {
      text = 'You blocked this user.';
    } else {
      text = "You can't reply to this conversation.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.lavender),
              ),
            ),
            if (blockedByMe && !_isOtherDeleted)
              TextButton(
                onPressed: _unblockUser,
                child: const Text(
                  'Unblock',
                  style: TextStyle(color: AppColors.brandPurpleLight),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final isEditing = _editingMessage != null;
    final attachDisabled = _isUploadingMedia || isEditing;
    const pillRadius = BorderRadius.all(Radius.circular(22));

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(
                Icons.add,
                color: attachDisabled
                    ? AppColors.textSubtle
                    : AppColors.lavender,
              ),
              tooltip: 'Attach photo or voice note',
              onPressed: attachDisabled ? null : _showAttachmentSheet,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: const TextStyle(color: AppColors.white, fontSize: 15),
                cursorColor: AppColors.brandPurpleLight,
                maxLines: 5,
                minLines: 1,
                maxLength: ChatMessage.maxLength,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) {
                      // Only show the counter close to the limit.
                      if (currentLength < ChatMessage.maxLength - 200) {
                        return null;
                      }
                      return Text(
                        '$currentLength/${ChatMessage.maxLength}',
                        style: const TextStyle(
                          color: AppColors.lavender,
                          fontSize: 11,
                        ),
                      );
                    },
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Message $_displayName…',
                  hintStyle: const TextStyle(color: AppColors.textSubtle),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  isDense: true,
                  border: const OutlineInputBorder(
                    borderRadius: pillRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: pillRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: pillRadius,
                    borderSide: BorderSide(color: AppColors.brandPurpleMid),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            _buildComposerAction(isEditing),
          ],
        ),
      ),
    );
  }

  /// Round gradient button: mic while empty, send (or save) with text.
  Widget _buildComposerAction(bool isEditing) {
    if (_isUploadingMedia) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            color: AppColors.brandPurpleMid,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _messageController,
      builder: (context, value, _) {
        final showSend = isEditing || value.text.trim().isNotEmpty;
        final IconData icon;
        final String label;
        final VoidCallback? onPressed;
        if (showSend) {
          icon = _isSending
              ? Icons.hourglass_empty
              : (isEditing ? Icons.check : Icons.send_rounded);
          label = isEditing ? 'Save' : 'Send';
          onPressed = _isSending ? null : _sendMessage;
        } else {
          icon = Icons.mic_none_rounded;
          label = 'Record voice message';
          onPressed = _showVoiceRecordingSheet;
        }

        return Semantics(
          button: true,
          enabled: onPressed != null,
          child: Tooltip(
            message: label,
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: Icon(icon, color: AppColors.white, size: 22),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            dateText,
            style: const TextStyle(
              color: AppColors.lavender,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowDate(
    List<ChatMessage> messages,
    int index,
    DateTime currentDate,
  ) {
    // The oldest loaded message only gets a separator once nothing older exists.
    if (index == messages.length - 1) return !_hasMore;
    final previousDate = messages[index + 1].timestamp;
    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  // ============= Media =============
  void _showAttachmentSheet() {
    if (!_canSend) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AttachmentSheet(onSelected: _handleAttachmentSelected),
    );
  }

  Future<void> _handleAttachmentSelected(AttachmentType type) async {
    switch (type) {
      case AttachmentType.camera:
        await _pickAndSendImage(fromCamera: true);
        break;
      case AttachmentType.gallery:
        await _pickAndSendImage(fromCamera: false);
        break;
      case AttachmentType.audio:
        await _showVoiceRecordingSheet();
        break;
    }
  }

  Future<void> _pickAndSendImage({required bool fromCamera}) async {
    final convId = _conversationId;
    if (convId == null || !_canSend || _isUploadingMedia) return;

    final file = fromCamera
        ? await ChatMediaService.captureImageFromCamera()
        : await ChatMediaService.pickImageFromGallery();
    if (file == null || !mounted) return;

    final error = await ChatMediaService.validateChatImage(file);
    if (!mounted) return;
    if (error != null) {
      _showSnackBar(error);
      return;
    }

    final replyTo = _replyToMessage;
    setState(() => _isUploadingMedia = true);

    try {
      final size = await ChatMediaService.getFileSize(file);
      final url = await ChatMediaService.uploadChatImage(
        conversationId: convId,
        file: file,
      );
      if (url == null) throw StateError('Upload failed');

      final messageId = await _chatService.sendImageMessage(
        conversationId: convId,
        receiverId: widget.otherUserId,
        imageUrl: url,
        fileSize: size,
        replyToMessageId: replyTo?.id,
        replyTo: replyTo?.toReplySnapshot(),
      );
      if (messageId == null) throw StateError('Image was not sent');

      _notifyReceiver(convId, messageId);
      if (!mounted) return;
      if (identical(_replyToMessage, replyTo)) {
        setState(() => _replyToMessage = null);
      }
      _scrollToLatest();
    } catch (e) {
      _log('sendImage', e);
      _showSnackBar('Failed to send image');
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _showVoiceRecordingSheet() async {
    if (!_canSend || _isUploadingMedia) return;
    final result = await showModalBottomSheet<VoiceRecordingResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const VoiceRecordingSheet(),
    );
    if (result == null || !mounted) return;
    await _sendVoiceMessage(result.path, result.durationSeconds);
  }

  Future<void> _sendVoiceMessage(String path, int durationSeconds) async {
    final convId = _conversationId;
    if (convId == null || !_canSend || path.isEmpty) return;

    final error = await ChatMediaService.validateVoiceMessage(
      path,
      durationSeconds,
    );
    if (!mounted) return;
    if (error != null) {
      _showSnackBar(error);
      return;
    }

    final replyTo = _replyToMessage;
    setState(() => _isUploadingMedia = true);

    try {
      final url = await ChatMediaService.uploadVoiceMessage(
        conversationId: convId,
        localPath: path,
        durationSeconds: durationSeconds,
      );
      if (url == null) throw StateError('Upload failed');

      final messageId = await _chatService.sendVoiceMessage(
        conversationId: convId,
        receiverId: widget.otherUserId,
        audioUrl: url,
        durationSeconds: durationSeconds,
        replyToMessageId: replyTo?.id,
        replyTo: replyTo?.toReplySnapshot(),
      );
      if (messageId == null) throw StateError('Voice message was not sent');

      _notifyReceiver(convId, messageId);
      if (!mounted) return;
      if (identical(_replyToMessage, replyTo)) {
        setState(() => _replyToMessage = null);
      }
      _scrollToLatest();
    } catch (e) {
      _log('sendVoice', e);
      _showSnackBar('Failed to send voice message');
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  // ============= Message / chat actions =============
  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.inputTextWhite),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.hintPurple),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.hintPurple),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              action,
              style: const TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final convId = _conversationId;
    if (convId == null) return;
    final confirmed = await _confirm(
      title: 'Delete Message',
      message: 'Are you sure you want to delete this message?',
      action: 'Delete',
    );
    if (!confirmed || !mounted) return;

    if (_editingMessage?.id == message.id) _cancelEdit();
    try {
      await _chatService.deleteMessage(convId, message.id);
    } catch (e) {
      _log('delete', e);
      _showSnackBar('Failed to delete message');
    }
  }

  Future<void> _clearChat() async {
    final convId = _conversationId;
    if (convId == null || _conversation == null) return;
    final confirmed = await _confirm(
      title: 'Clear Chat',
      message:
          'Are you sure you want to clear this chat? This action cannot be undone.',
      action: 'Clear',
    );
    if (!confirmed || !mounted) return;

    final before = _clearedBefore;
    try {
      await _chatService.clearChat(convId, myUid: _myUid);
    } catch (e) {
      _log('clear', e);
      _showSnackBar('Failed to clear chat');
      return;
    }
    if (!mounted) return;

    // Provisional local cutoff; the conversation listener replaces it with
    // the server value (unless that already happened).
    if (_clearedBefore == before) _resetMessages(DateTime.now());
    _showSnackBar('Chat cleared');
  }

  Future<void> _blockUser() async {
    final blocked = await confirmAndBlockUser(
      context,
      otherUid: widget.otherUserId,
      displayName: _displayName,
      avatarUrl: _otherAvatar,
    );
    if (blocked && mounted) Navigator.of(context).pop();
  }

  Future<void> _unblockUser() async {
    try {
      await SafetyService.instance.unblock(widget.otherUserId);
      _showSnackBar('Unblocked $_displayName');
    } catch (e) {
      _log('unblock', e);
      _showSnackBar('Could not unblock. Check your connection and try again.');
    }
  }

  Future<void> _reportUser() async {
    // Attach the other user's latest messages as evidence for review.
    final evidence = _messages
        .where(
          (m) =>
              m.senderId == widget.otherUserId &&
              !m.isDeleted &&
              !MessageBubble.isCallEvent(m),
        )
        .take(20)
        .map((m) => m.id)
        .toList();

    await ReportDialog.show(
      context,
      reportedUserId: widget.otherUserId,
      reportedName: _isOtherDeleted ? null : _otherUser?.username,
      conversationId: _conversation != null ? _conversationId : null,
      messageIds: evidence,
    );
  }
}
