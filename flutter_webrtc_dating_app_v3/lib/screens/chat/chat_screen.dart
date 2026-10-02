// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// // Models
// import '../../models/chat_message_model.dart';
// import '../../models/user_model.dart';
// import '../../models/call_model.dart';
//
// // Services
// import '../../services/chat_service.dart';
// import '../../services/call/call_service.dart';
//
// // UI Components
// import '../../core/constants/app_colors.dart';
// import 'widgets/message_bubble.dart';
//
// // Call Screens
// import '../calls/video_call_screen.dart';
// import '../calls/audio_call_screen.dart';
//
// class ChatScreen extends StatefulWidget {
//   final String otherUserId;
//   final String? conversationId;
//
//   const ChatScreen({
//     Key? key,
//     required this.otherUserId,
//     this.conversationId,
//   }) : super(key: key);
//
//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
//   final ChatService _chatService = ChatService();
//   final CallService _callService = CallService();
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//
//   // Live stream for newest messages + de-dup with paged list
//   StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesLiveSub;
//   final Set<String> _messageIds = {};
//
//   late String _conversationId;
//   UserModel? _otherUser;
//   bool _isLoading = true;
//   bool _isSending = false;
//   Timer? _typingTimer;
//   bool _isTyping = false;
//   ChatMessage? _replyToMessage;
//   final FocusNode _messageFocusNode = FocusNode();
//   DateTime? _clearedBefore;
//
//   Timer? _readDebounce;
//   void _markReadDebounced() {
//     _readDebounce?.cancel();
//     _readDebounce = Timer(const Duration(milliseconds: 350), () {
//       _chatService.markMessagesAsRead(_conversationId, widget.otherUserId);
//     });
//   }
//
//   // Call state
//   bool _isCallInProgress = false;
//
//   // Pagination state
//   final List<ChatMessage> _messages = [];
//   bool _isLoadingMore = false;
//   bool _hasMore = true;
//   DocumentSnapshot? _lastDoc; // oldest loaded (for startAfterDocument)
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initializeChat();
//     _messageController.addListener(_onTypingChanged);
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _typingTimer?.cancel();
//     _updateTypingStatus(false);
//     _messageController.removeListener(_onTypingChanged);
//     _messageController.dispose();
//     _scrollController.dispose();
//     _messageFocusNode.dispose();
//     _messagesLiveSub?.cancel();
//     _readDebounce?.cancel(); // keep
//
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.paused) {
//       _updateTypingStatus(false);
//     }
//   }
//
//   Future<void> _initializeChat() async {
//     try {
//       if (widget.conversationId != null) {
//         _conversationId = widget.conversationId!;
//       } else {
//         _conversationId =
//         await _chatService.getOrCreateConversation(widget.otherUserId);
//       }
//
//       final myUid = _chatService.currentUserId;
//       final convSnap = await FirebaseFirestore.instance
//           .collection('conversations')
//           .doc(_conversationId)
//           .get();
//
//       final data = convSnap.data() as Map<String, dynamic>? ?? {};
//       final pd = (data['participantData'] as Map?) ?? {};
//       final me = (pd[myUid] as Map?) ?? {};
//       final cbTs = me['clearedBefore'];
//       if (cbTs is Timestamp) _clearedBefore = cbTs.toDate();
//
//       _otherUser = await _chatService.getUserDetails(widget.otherUserId);
//
//       // Mark incoming as read once
//       await _chatService.markMessagesAsRead(
//           _conversationId, widget.otherUserId);
//
//       // initial page
//       await _loadMoreMessages(initial: true);
//
//       // Build de-dup set from first page
//       _messageIds
//         ..clear()
//         ..addAll(_messages.map((m) => m.id));
//
//       // Start live stream (conversationId is ready)
//       _startLiveNewMessageListener();
//
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   // ============= Typing =============
//   void _onTypingChanged() {
//     if (_messageController.text.isNotEmpty && !_isTyping) {
//       _updateTypingStatus(true);
//     }
//
//     _typingTimer?.cancel();
//     _typingTimer = Timer(const Duration(seconds: 3), () {
//       if (_isTyping) {
//         _updateTypingStatus(false);
//       }
//     });
//   }
//
//   Future<void> _updateTypingStatus(bool typing) async {
//     if (_isTyping != typing) {
//       _isTyping = typing;
//       await _chatService.updateTypingStatus(_conversationId, typing);
//     }
//   }
//
//   // ============= Pagination Loader =============
//   Future<void> _loadMoreMessages({bool initial = false}) async {
//     if (_isLoadingMore || !_hasMore) return;
//
//     setState(() {
//       _isLoadingMore = true;
//     });
//
//     try {
//       // Query messages ordered desc by 'timestamp'
//       Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
//           .collection('conversations')
//           .doc(_conversationId)
//           .collection('messages')
//           .orderBy('timestamp', descending: true);
//
//       if (_clearedBefore != null) {
//         ref = ref.where(
//           'timestamp',
//           isGreaterThan: Timestamp.fromDate(_clearedBefore!),
//         );
//       }
//
//       ref = ref.limit(30);
//
//       final QuerySnapshot<Map<String, dynamic>> snap = (_lastDoc == null)
//           ? await ref.get()
//           : await ref.startAfterDocument(_lastDoc!).get();
//
//       final docs = snap.docs;
//
//       if (docs.isEmpty) {
//         _hasMore = false;
//       } else {
//         // update lastDoc to last (oldest in this page since desc)
//         _lastDoc = docs.last;
//
//         final loaded =
//         docs.map((d) => ChatMessage.fromFirestore(d)).toList();
//
//         // Append (we keep list reversed = newest at top, so just addAll)
//         _messages.addAll(loaded);
//
//         // Track IDs to prevent duplicates when live stream also pushes them
//         for (final m in loaded) {
//           _messageIds.add(m.id);
//         }
//       }
//     } catch (e) {
//       // ignore for now
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoadingMore = false;
//         });
//       }
//     }
//   }
//
//   // === Live listener for newest messages ===
//   void _startLiveNewMessageListener() {
//     _messagesLiveSub?.cancel();
//     if (_conversationId.isEmpty) return;
//
//     Query<Map<String, dynamic>> liveRef = FirebaseFirestore.instance
//         .collection('conversations')
//         .doc(_conversationId)
//         .collection('messages')
//         .orderBy('timestamp', descending: true);
//
//     if (_clearedBefore != null) {
//       liveRef = liveRef.where(
//         'timestamp',
//         isGreaterThan: Timestamp.fromDate(_clearedBefore!),
//       );
//     }
//
//     liveRef = liveRef.limit(20); // listen to the head
//
//     _messagesLiveSub = liveRef.snapshots().listen((snap) {
//       if (!mounted) return;
//
//       final changes = snap.docChanges;
//       if (changes.isEmpty) return;
//
//       bool listChanged = false;
//
//       for (final c in changes) {
//         final data = c.doc.data();
//         if (data == null) continue;
//
//         final msg = ChatMessage.fromFirestore(c.doc);
//         // If I am viewing this chat and the other user sent a new message, mark as read.
//         final isIncoming = msg.senderId == widget.otherUserId;
//         if (isIncoming) {
//           _markReadDebounced();
//         }
//         final id = msg.id;
//
//         if (_messageIds.contains(id)) {
//           if (c.type == DocumentChangeType.modified) {
//             final idx = _messages.indexWhere((m) => m.id == id);
//             if (idx != -1) {
//               _messages[idx] = msg;
//               listChanged = true;
//             }
//           }
//           continue;
//         }
//
//         // New message: insert at top (reverse list)
//         _messages.insert(0, msg);
//         _messageIds.add(id);
//         listChanged = true;
//       }
//
//       if (listChanged) setState(() {});
//     }, onError: (_) {});
//   }
//
//   // ============= Send message =============
//   Future<void> _sendMessage() async {
//     final message = _messageController.text.trim();
//     if (message.isEmpty || _isSending) return;
//
//     setState(() => _isSending = true);
//
//     _messageController.clear();
//     _updateTypingStatus(false);
//
//     try {
//       await _chatService.sendMessage(
//         conversationId: _conversationId,
//         receiverId: widget.otherUserId,
//         message: message,
//         replyToMessageId: _replyToMessage?.id,
//       );
//
//       setState(() => _replyToMessage = null);
//
//       // Scroll to top; live stream will insert the new message
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           0,
//           duration: const Duration(milliseconds: 250),
//           curve: Curves.easeOut,
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to send message')),
//       );
//     } finally {
//       if (mounted) setState(() => _isSending = false);
//     }
//   }
//
//   // ============= CALL METHODS =============
//   Future<void> _startCall(CallType type) async {
//     if (_isCallInProgress) {
//       _showSnackBar('A call is already in progress');
//       return;
//     }
//
//     try {
//       final permissions = type == CallType.video
//           ? [Permission.camera, Permission.microphone]
//           : [Permission.microphone];
//
//       Map<Permission, PermissionStatus> statuses = {};
//       for (final permission in permissions) {
//         statuses[permission] = await permission.request();
//       }
//
//       bool allGranted = statuses.values.every((s) => s.isGranted);
//       if (!allGranted) {
//         final deniedPermission = statuses.entries
//             .firstWhere((e) => !e.value.isGranted)
//             .key;
//         _showSnackBar(
//           '${deniedPermission == Permission.camera ? 'Camera' : 'Microphone'} permission is required for calls',
//         );
//         return;
//       }
//
//       setState(() => _isCallInProgress = true);
//
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => Center(
//           child: Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: AppColors.inputBackground,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircularProgressIndicator(color: AppColors.purplePrimary),
//                 const SizedBox(height: 15),
//                 Text(
//                   'Initiating ${type == CallType.video ? "video" : "voice"} call...',
//                   style: TextStyle(color: AppColors.inputTextWhite),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//
//       final callId = await _callService.startCall(
//         receiverId: widget.otherUserId,
//         type: type,
//       );
//
//       if (!mounted) return;
//       Navigator.pop(context);
//
//       await Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => type == CallType.video
//               ? VideoCallScreen(callId: callId, isOutgoing: true)
//               : AudioCallScreen(callId: callId, isOutgoing: true),
//         ),
//       );
//
//       setState(() => _isCallInProgress = false);
//     } catch (e) {
//       setState(() => _isCallInProgress = false);
//       if (!mounted) return;
//       if (Navigator.canPop(context)) Navigator.pop(context);
//       _showSnackBar('Failed to start call');
//     }
//   }
//
//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: AppColors.purplePrimary,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }
//
//   // ============= UI BUILDERS =============
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: AppColors.appBackground,
//         body: Center(child: CircularProgressIndicator(color: AppColors.purplePrimary)),
//       );
//     }
//
//     return Scaffold(
//       backgroundColor: AppColors.appBackground,
//       appBar: _buildAppBar(),
//       body: Column(
//         children: [
//           Expanded(child: _buildMessagesList()),
//           _buildTypingIndicator(),
//           if (_replyToMessage != null) _buildReplyPreview(),
//           _buildMessageInput(),
//         ],
//       ),
//     );
//   }
//
//   AppBar _buildAppBar() {
//     final displayName = _otherUser?.username ?? 'User';
//     final avatarUrl = (() {
//       if (_otherUser?.profileImage != null && _otherUser!.profileImage.isNotEmpty) {
//         return _otherUser!.profileImage;
//       }
//       return _otherUser?.avatarString;
//     })();
//
//     return AppBar(
//       backgroundColor: AppColors.purplePrimary,
//       title: InkWell(
//         onTap: () {},
//         child: Row(
//           children: [
//             CircleAvatar(
//               radius: 18,
//               backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
//               backgroundColor: AppColors.purpleSecondary,
//               child: (avatarUrl == null || avatarUrl.isEmpty)
//                   ? Text(
//                 displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
//                 style: const TextStyle(color: Colors.white),
//               )
//                   : null,
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(displayName, style: const TextStyle(fontSize: 16)),
//                   StreamBuilder<DocumentSnapshot>(
//                     stream: FirebaseFirestore.instance
//                         .collection('users')
//                         .doc(widget.otherUserId)
//                         .snapshots(),
//                     builder: (context, snapshot) {
//                       if (!snapshot.hasData) return const SizedBox.shrink();
//                       final data = snapshot.data?.data() as Map<String, dynamic>?;
//                       final isOnline = data?['online'] ?? false;
//
//                       return Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Container(
//                             width: 8,
//                             height: 8,
//                             decoration: BoxDecoration(
//                               color: isOnline ? Colors.greenAccent : Colors.grey,
//                               shape: BoxShape.circle,
//                             ),
//                           ),
//                           const SizedBox(width: 6),
//                           Text(
//                             isOnline ? 'Online' : 'Offline',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: isOnline ? Colors.greenAccent : Colors.white70,
//                             ),
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         StreamBuilder<DocumentSnapshot>(
//           stream: FirebaseFirestore.instance
//               .collection('conversations')
//               .doc(_conversationId)
//               .snapshots(),
//           builder: (context, snap) {
//             final myUid = _chatService.currentUserId;
//             bool canCall = true;
//             bool isMuted = false;
//
//             if (snap.hasData && snap.data?.exists == true) {
//               final data = snap.data!.data() as Map<String, dynamic>;
//
//               final statePerUser = (data['statePerUser'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
//               final myState = statePerUser[myUid];
//               if (myState != null) canCall = myState == 'active';
//
//               if (myState == null) {
//                 final pd = (data['participantData'] as Map?)?[myUid];
//                 if (pd is Map) {
//                   final status = (pd['status'] ?? '').toString();
//                   final hasReplied = (pd['hasReplied'] ?? false) == true;
//                   canCall = (status == 'active') || hasReplied;
//                 }
//               }
//
//               final m = data['muted'];
//               if (m is Map && m[myUid] is bool) isMuted = m[myUid] as bool;
//             }
//
//             final disabled = _isCallInProgress || !canCall;
//
//             return Row(
//               children: [
//                 if (isMuted)
//                   const Padding(
//                     padding: EdgeInsets.only(right: 4),
//                     child: Icon(Icons.volume_off, size: 18, color: Colors.white70),
//                   ),
//                 IconButton(
//                   icon: Icon(Icons.videocam, color: disabled ? Colors.white38 : Colors.white),
//                   onPressed: disabled ? null : () => _startCall(CallType.video),
//                   tooltip: 'Video Call',
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.call, color: disabled ? Colors.white38 : Colors.white),
//                   onPressed: disabled ? null : () => _startCall(CallType.audio),
//                   tooltip: 'Voice Call',
//                 ),
//                 PopupMenuButton<String>(
//                   onSelected: (value) {
//                     switch (value) {
//                       case 'clear':
//                         _clearChat();
//                         break;
//                       case 'block':
//                         _blockUser();
//                         break;
//                       case 'report':
//                         _reportUser();
//                         break;
//                     }
//                   },
//                   itemBuilder: (context) => const [
//                     PopupMenuItem(value: 'clear', child: Text('Clear chat')),
//                     PopupMenuItem(value: 'block', child: Text('Block user')),
//                     PopupMenuItem(value: 'report', child: Text('Report user')),
//                   ],
//                 ),
//               ],
//             );
//           },
//         ),
//       ],
//     );
//   }
//
//   // Messages list with infinite scroll
//   Widget _buildMessagesList() {
//     return NotificationListener<ScrollNotification>(
//       onNotification: (n) {
//         if (n is ScrollEndNotification &&
//             _scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.90 &&
//             !_isLoadingMore &&
//             _hasMore) {
//           _loadMoreMessages();
//         }
//         return false;
//       },
//       child: ListView.builder(
//         controller: _scrollController,
//         reverse: true,
//         itemCount: _messages.length + (_hasMore ? 1 : 0),
//         itemBuilder: (context, index) {
//           if (index == _messages.length) {
//             return _isLoadingMore
//                 ? Padding(
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               child: Center(child: CircularProgressIndicator(color: AppColors.purplePrimary)),
//             )
//                 : const SizedBox.shrink();
//           }
//
//           final message = _messages[index];
//           final isMe = message.senderId == _chatService.currentUserId;
//
//           final showDate = (index == _messages.length - 1) ||
//               _shouldShowDate(_messages, index, message.timestamp);
//
//           return Column(
//             children: [
//               if (showDate) _buildDateSeparator(message.timestamp),
//               MessageBubble(
//                 message: message,
//                 isMe: isMe,
//                 otherUserName: _otherUser?.username ?? 'User',
//                 otherUserAvatar: (() {
//                   if (_otherUser?.profileImage != null && _otherUser!.profileImage.isNotEmpty) {
//                     return _otherUser!.profileImage;
//                   }
//                   return _otherUser?.avatarString;
//                 })(),
//                 onReply: () {
//                   setState(() {
//                     _replyToMessage = message;
//                   });
//                   _messageFocusNode.requestFocus();
//                 },
//                 onEdit: isMe ? () => _editMessage(message) : null,
//                 onDelete: isMe ? () => _deleteMessage(message) : null,
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildTypingIndicator() {
//     return StreamBuilder<bool>(
//       stream: _chatService.getTypingStatus(_conversationId, widget.otherUserId),
//       builder: (context, snapshot) {
//         if (snapshot.data != true) return const SizedBox.shrink();
//
//         return Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           child: Row(
//             children: [
//               Text(
//                 '${_otherUser?.username ?? "User"} is typing',
//                 style: TextStyle(
//                   color: AppColors.hintPurple,
//                   fontSize: 12,
//                   fontStyle: FontStyle.italic,
//                 ),
//               ),
//               const SizedBox(width: 4),
//               SizedBox(
//                 width: 20,
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: List.generate(3, (index) {
//                     return AnimatedContainer(
//                       duration: Duration(milliseconds: 300 + (index * 100)),
//                       curve: Curves.easeInOut,
//                       width: 4,
//                       height: 4,
//                       decoration: BoxDecoration(
//                         color: AppColors.purplePrimary,
//                         shape: BoxShape.circle,
//                       ),
//                     );
//                   }),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildReplyPreview() {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       color: AppColors.inputBackground,
//       child: Row(
//         children: [
//           Container(width: 4, height: 40, color: AppColors.purplePrimary),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Replying to ${_replyToMessage!.senderId == _chatService.currentUserId ? "yourself" : (_otherUser?.username ?? "User")}',
//                   style: TextStyle(fontSize: 12, color: AppColors.purplePrimary, fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   _replyToMessage!.message,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(fontSize: 14, color: AppColors.hintPurple),
//                 ),
//               ],
//             ),
//           ),
//           IconButton(
//             icon: Icon(Icons.close, size: 20, color: AppColors.hintPurple),
//             onPressed: () => setState(() => _replyToMessage = null),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageInput() {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: AppColors.inputBackground,
//         boxShadow: [
//           BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2)),
//         ],
//       ),
//       child: Row(
//         children: [
//           IconButton(
//             icon: Icon(Icons.attach_file, color: AppColors.purplePrimary),
//             onPressed: () {},
//           ),
//           Expanded(
//             child: TextField(
//               controller: _messageController,
//               focusNode: _messageFocusNode,
//               style: TextStyle(color: AppColors.inputTextWhite),
//               maxLines: null,
//               keyboardType: TextInputType.multiline,
//               textInputAction: TextInputAction.newline,
//               decoration: InputDecoration(
//                 hintText: 'Type a message...',
//                 hintStyle: TextStyle(color: AppColors.hintPurple),
//                 filled: true,
//                 fillColor: AppColors.inputBackground,
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//               ),
//               onSubmitted: (_) => _sendMessage(),
//             ),
//           ),
//           const SizedBox(width: 8),
//           CircleAvatar(
//             radius: 24,
//             backgroundColor: AppColors.purplePrimary,
//             child: IconButton(
//               icon: Icon(_isSending ? Icons.hourglass_empty : Icons.send, color: Colors.white),
//               onPressed: _isSending ? null : _sendMessage,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDateSeparator(DateTime date) {
//     final now = DateTime.now();
//     final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
//
//     final yesterday = now.subtract(const Duration(days: 1));
//     final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
//
//     String dateText;
//     if (isToday) {
//       dateText = 'Today';
//     } else if (isYesterday) {
//       dateText = 'Yesterday';
//     } else {
//       dateText = '${date.day}/${date.month}/${date.year}';
//     }
//
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 16),
//       child: Row(
//         children: [
//           Expanded(child: Divider(color: AppColors.hintPurple.withOpacity(0.3))),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: Text(
//               dateText,
//               style: TextStyle(color: AppColors.hintPurple, fontSize: 12, fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(child: Divider(color: AppColors.hintPurple.withOpacity(0.3))),
//         ],
//       ),
//     );
//   }
//
//   bool _shouldShowDate(List<ChatMessage> messages, int index, DateTime currentDate) {
//     if (index == messages.length - 1) return true;
//     final previousDate = messages[index + 1].timestamp;
//     return currentDate.day != previousDate.day ||
//         currentDate.month != previousDate.month ||
//         currentDate.year != previousDate.year;
//   }
//
//   void _editMessage(ChatMessage message) {
//     _messageController.text = message.message;
//   }
//
//   void _deleteMessage(ChatMessage message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: AppColors.inputBackground,
//         title: Text('Delete Message', style: TextStyle(color: AppColors.inputTextWhite)),
//         content: Text('Are you sure you want to delete this message?', style: TextStyle(color: AppColors.hintPurple)),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple))),
//           TextButton(
//             onPressed: () {
//               _chatService.deleteMessage(_conversationId, message.id);
//               Navigator.pop(context);
//             },
//             child: Text('Delete', style: TextStyle(color: AppColors.dangerRed)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _clearChat() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: AppColors.inputBackground,
//         title: Text('Clear Chat', style: TextStyle(color: AppColors.inputTextWhite)),
//         content: Text(
//           'Are you sure you want to clear this chat? This action cannot be undone.',
//           style: TextStyle(color: AppColors.hintPurple),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple)),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(context);
//
//               // 1) call service (updates participantData.{uid}.clearedBefore)
//               await _chatService.clearChat(_conversationId);
//
//               // 2) update local cutoff immediately so UI reflects clear
//               setState(() {
//                 _clearedBefore = DateTime.now();
//                 _messages.clear();
//                 _messageIds.clear();
//                 _lastDoc = null;
//                 _hasMore = true;
//               });
//
//               // 3) reload the first page (will fetch only messages after clearedBefore)
//               await _loadMoreMessages(initial: true);
//
//               _showSnackBar('Chat cleared');
//             },
//             child: Text('Clear', style: TextStyle(color: AppColors.dangerRed)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _blockUser() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: AppColors.inputBackground,
//         title: Text('Block User', style: TextStyle(color: AppColors.inputTextWhite)),
//         content: Text('Are you sure you want to block ${_otherUser?.username ?? "User"}?',
//             style: TextStyle(color: AppColors.hintPurple)),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple))),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               Navigator.pop(context);
//               _showSnackBar('User blocked');
//             },
//             child: Text('Block', style: TextStyle(color: AppColors.dangerRed)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _reportUser() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: AppColors.inputBackground,
//         title: Text('Report User', style: TextStyle(color: AppColors.inputTextWhite)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Why are you reporting this user?', style: TextStyle(color: AppColors.hintPurple)),
//             const SizedBox(height: 20),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple))),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _showSnackBar('User reported');
//             },
//             child: Text('Report', style: TextStyle(color: AppColors.dangerRed)),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

// Models
import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';

// Services
import '../../services/chat_service.dart';
import '../../services/call/call_service.dart';
import '../../services/notification/onesignal_sender.dart';

import 'widgets/attachment_sheet.dart';
import 'widgets/voice_recording_sheet.dart';
import '../../services/media/chat_media_service.dart';




// UI Components
import '../../core/constants/app_colors.dart';
import 'widgets/message_bubble.dart';

// Call Screens
import '../calls/video_call_screen.dart';
import '../calls/audio_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String? conversationId;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    this.conversationId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final CallService _callService = CallService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Live stream for newest messages + de-dup with paged list
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesLiveSub;
  final Set<String> _messageIds = {};

  late String _conversationId;
  UserModel? _otherUser;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  ChatMessage? _replyToMessage;
  final FocusNode _messageFocusNode = FocusNode();
  DateTime? _clearedBefore;
  bool _isUploadingMedia = false;

  Timer? _readDebounce;
  void _markReadDebounced() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 350), () {
      _chatService.markMessagesAsRead(_conversationId, widget.otherUserId);
    });
  }

  // Call state
  bool _isCallInProgress = false;

  // Pagination state
  final List<ChatMessage> _messages = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc; // oldest loaded (for startAfterDocument)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _messageController.addListener(_onTypingChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _updateTypingStatus(false);
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messagesLiveSub?.cancel();
    _readDebounce?.cancel(); // keep

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _updateTypingStatus(false);
    }
  }

  Future<void> _initializeChat() async {
    try {
      if (widget.conversationId != null) {
        _conversationId = widget.conversationId!;
      } else {
        _conversationId =
        await _chatService.getOrCreateConversation(widget.otherUserId);
      }

      final myUid = _chatService.currentUserId;
      final convSnap = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId)
          .get();

      final data = convSnap.data() as Map<String, dynamic>? ?? {};
      final pd = (data['participantData'] as Map?) ?? {};
      final me = (pd[myUid] as Map?) ?? {};
      final cbTs = me['clearedBefore'];
      if (cbTs is Timestamp) _clearedBefore = cbTs.toDate();

      _otherUser = await _chatService.getUserDetails(widget.otherUserId);

      // Mark incoming as read once
      await _chatService.markMessagesAsRead(
        _conversationId,
        widget.otherUserId,
      );

      // initial page
      await _loadMoreMessages(initial: true);

      // Build de-dup set from first page
      _messageIds
        ..clear()
        ..addAll(_messages.map((m) => m.id));

      // Start live stream (conversationId is ready)
      _startLiveNewMessageListener();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============= Typing =============
  void _onTypingChanged() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      _updateTypingStatus(true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _updateTypingStatus(false);
      }
    });
  }

  Future<void> _updateTypingStatus(bool typing) async {
    if (_isTyping != typing) {
      _isTyping = typing;
      await _chatService.updateTypingStatus(_conversationId, typing);
    }
  }

  // ============= Pagination Loader =============
  Future<void> _loadMoreMessages({bool initial = false}) async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Query messages ordered desc by 'timestamp'
      Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true);

      if (_clearedBefore != null) {
        ref = ref.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(_clearedBefore!),
        );
      }

      ref = ref.limit(30);

      final QuerySnapshot<Map<String, dynamic>> snap = (_lastDoc == null)
          ? await ref.get()
          : await ref.startAfterDocument(_lastDoc!).get();

      final docs = snap.docs;

      if (docs.isEmpty) {
        _hasMore = false;
      } else {
        // update lastDoc to last (oldest in this page since desc)
        _lastDoc = docs.last;

        final loaded =
        docs.map((d) => ChatMessage.fromFirestore(d)).toList();

        // Append
        _messages.addAll(loaded);

        // Track IDs
        for (final m in loaded) {
          _messageIds.add(m.id);
        }
      }
    } catch (e) {
      // ignore for now
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // === Live listener for newest messages ===
  void _startLiveNewMessageListener() {
    _messagesLiveSub?.cancel();
    if (_conversationId.isEmpty) return;

    Query<Map<String, dynamic>> liveRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(_conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    if (_clearedBefore != null) {
      liveRef = liveRef.where(
        'timestamp',
        isGreaterThan: Timestamp.fromDate(_clearedBefore!),
      );
    }

    liveRef = liveRef.limit(20); // listen to the head

    _messagesLiveSub = liveRef.snapshots().listen((snap) {
      if (!mounted) return;

      final changes = snap.docChanges;
      if (changes.isEmpty) return;

      bool listChanged = false;

      for (final c in changes) {
        final data = c.doc.data();
        if (data == null) continue;

        final msg = ChatMessage.fromFirestore(c.doc);
        // If I am viewing this chat and the other user sent a new message, mark as read.
        final isIncoming = msg.senderId == widget.otherUserId;
        if (isIncoming) {
          _markReadDebounced();
        }
        final id = msg.id;

        if (_messageIds.contains(id)) {
          if (c.type == DocumentChangeType.modified) {
            final idx = _messages.indexWhere((m) => m.id == id);
            if (idx != -1) {
              _messages[idx] = msg;
              listChanged = true;
            }
          }
          continue;
        }

        // New message: insert at top (reverse list)
        _messages.insert(0, msg);
        _messageIds.add(id);
        listChanged = true;
      }

      if (listChanged) setState(() {});
    }, onError: (_) {});
  }

  // ============= Send message =============
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    _messageController.clear();
    _updateTypingStatus(false);

    try {
      final messageId = await _chatService.sendMessage(
        conversationId: _conversationId,
        receiverId: widget.otherUserId,
        message: message,
        replyToMessageId: _replyToMessage?.id,
      );

      setState(() => _replyToMessage = null);

      // ✅ OneSignal push trigger (non-blocking for UI)
      if (messageId != null) {
        await OneSignalSender.sendChatNotification(
          conversationId: _conversationId,
          messageId: messageId,
        );
      }

      // Scroll to top; live stream will insert the new message
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ============= CALL METHODS =============
  Future<void> _startCall(CallType type) async {
    if (_isCallInProgress) {
      _showSnackBar('A call is already in progress');
      return;
    }

    try {
      final permissions = type == CallType.video
          ? [Permission.camera, Permission.microphone]
          : [Permission.microphone];

      Map<Permission, PermissionStatus> statuses = {};
      for (final permission in permissions) {
        statuses[permission] = await permission.request();
      }

      bool allGranted = statuses.values.every((s) => s.isGranted);
      if (!allGranted) {
        final deniedPermission = statuses.entries
            .firstWhere((e) => !e.value.isGranted)
            .key;
        _showSnackBar(
          '${deniedPermission == Permission.camera ? 'Camera' : 'Microphone'} permission is required for calls',
        );
        return;
      }

      setState(() => _isCallInProgress = true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.purplePrimary),
                const SizedBox(height: 15),
                Text(
                  'Initiating ${type == CallType.video ? "video" : "voice"} call...',
                  style: TextStyle(color: AppColors.inputTextWhite),
                ),
              ],
            ),
          ),
        ),
      );

      final callId = await _callService.startCall(
        receiverId: widget.otherUserId,
        type: type,
      );

      if (!mounted) return;
      Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => type == CallType.video
              ? VideoCallScreen(callId: callId, isOutgoing: true)
              : AudioCallScreen(callId: callId, isOutgoing: true),
        ),
      );

      setState(() => _isCallInProgress = false);
    } catch (e) {
      setState(() => _isCallInProgress = false);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showSnackBar('Failed to start call');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.purplePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============= UI BUILDERS =============
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.appBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.purplePrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildTypingIndicator(),
          if (_replyToMessage != null) _buildReplyPreview(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final displayName = _otherUser?.username ?? 'User';
    final avatarUrl = (() {
      if (_otherUser?.profileImage != null &&
          _otherUser!.profileImage.isNotEmpty) {
        return _otherUser!.profileImage;
      }
      return _otherUser?.avatarString;
    })();

    return AppBar(
      backgroundColor: AppColors.purplePrimary,
      title: InkWell(
        onTap: () {},
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              backgroundColor: AppColors.purpleSecondary,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(fontSize: 16)),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.otherUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final data = snapshot.data?.data()
                      as Map<String, dynamic>?;
                      final isOnline = data?['online'] ?? false;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                              isOnline ? Colors.greenAccent : Colors.white70,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .doc(_conversationId)
              .snapshots(),
          builder: (context, snap) {
            final myUid = _chatService.currentUserId;
            bool canCall = true;
            bool isMuted = false;

            if (snap.hasData && snap.data?.exists == true) {
              final data =
              snap.data!.data() as Map<String, dynamic>;

              final statePerUser =
                  (data['statePerUser'] as Map?)?.map(
                        (k, v) => MapEntry(k.toString(), v.toString()),
                  ) ??
                      {};
              final myState = statePerUser[myUid];
              if (myState != null) canCall = myState == 'active';

              if (myState == null) {
                final pd = (data['participantData'] as Map?)?[myUid];
                if (pd is Map) {
                  final status = (pd['status'] ?? '').toString();
                  final hasReplied =
                      (pd['hasReplied'] ?? false) == true;
                  canCall = (status == 'active') || hasReplied;
                }
              }

              final m = data['muted'];
              if (m is Map && m[myUid] is bool) {
                isMuted = m[myUid] as bool;
              }
            }

            final disabled = _isCallInProgress || !canCall;

            return Row(
              children: [
                if (isMuted)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.volume_off,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.videocam,
                    color: disabled ? Colors.white38 : Colors.white,
                  ),
                  onPressed:
                  disabled ? null : () => _startCall(CallType.video),
                  tooltip: 'Video Call',
                ),
                IconButton(
                  icon: Icon(
                    Icons.call,
                    color: disabled ? Colors.white38 : Colors.white,
                  ),
                  onPressed:
                  disabled ? null : () => _startCall(CallType.audio),
                  tooltip: 'Voice Call',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'clear':
                        _clearChat();
                        break;
                      case 'block':
                        _blockUser();
                        break;
                      case 'report':
                        _reportUser();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'clear',
                      child: Text('Clear chat'),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: Text('Block user'),
                    ),
                    PopupMenuItem(
                      value: 'report',
                      child: Text('Report user'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // Messages list with infinite scroll
  Widget _buildMessagesList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent * 0.90 &&
            !_isLoadingMore &&
            _hasMore) {
          _loadMoreMessages();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        itemCount: _messages.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length) {
            return _isLoadingMore
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.purplePrimary,
                ),
              ),
            )
                : const SizedBox.shrink();
          }

          final message = _messages[index];
          final isMe =
              message.senderId == _chatService.currentUserId;

          final showDate = (index == _messages.length - 1) ||
              _shouldShowDate(
                _messages,
                index,
                message.timestamp,
              );

          return Column(
            children: [
              if (showDate) _buildDateSeparator(message.timestamp),
              MessageBubble(
                message: message,
                isMe: isMe,
                otherUserName: _otherUser?.username ?? 'User',
                otherUserAvatar: (() {
                  if (_otherUser?.profileImage != null &&
                      _otherUser!.profileImage.isNotEmpty) {
                    return _otherUser!.profileImage;
                  }
                  return _otherUser?.avatarString;
                })(),
                onReply: () {
                  setState(() {
                    _replyToMessage = message;
                  });
                  _messageFocusNode.requestFocus();
                },
                onEdit: isMe ? () => _editMessage(message) : null,
                onDelete: isMe ? () => _deleteMessage(message) : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<bool>(
      stream: _chatService.getTypingStatus(
        _conversationId,
        widget.otherUserId,
      ),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }

        return Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_otherUser?.username ?? "User"} is typing',
                style: TextStyle(
                  color: AppColors.hintPurple,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 20,
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (index) {
                    return AnimatedContainer(
                      duration: Duration(
                        milliseconds: 300 + (index * 100),
                      ),
                      curve: Curves.easeInOut,
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.purplePrimary,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppColors.inputBackground,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            color: AppColors.purplePrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderId == _chatService.currentUserId ? "yourself" : (_otherUser?.username ?? "User")}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.purplePrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _replyToMessage!.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.hintPurple,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 20,
              color: AppColors.hintPurple,
            ),
            onPressed: () =>
                setState(() => _replyToMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🆕 Updated Attachment Button
          IconButton(
            icon: Icon(
              Icons.attach_file,
              color: _isUploadingMedia
                  ? AppColors.purplePrimary.withOpacity(0.5)
                  : AppColors.purplePrimary,
            ),
            onPressed: _isUploadingMedia ? null : _showAttachmentSheet,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              style: TextStyle(
                color: AppColors.inputTextWhite,
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: AppColors.hintPurple),
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          // Send button or upload indicator
          _isUploadingMedia
              ? Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(12),
            child: CircularProgressIndicator(
              color: AppColors.purplePrimary,
              strokeWidth: 2,
            ),
          )
              : CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.purplePrimary,
            child: IconButton(
              icon: Icon(
                _isSending ? Icons.hourglass_empty : Icons.send,
                color: Colors.white,
              ),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

    final yesterday =
    now.subtract(const Duration(days: 1));
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color:
              AppColors.hintPurple.withOpacity(0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Text(
              dateText,
              style: TextStyle(
                color: AppColors.hintPurple,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color:
              AppColors.hintPurple.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDate(
      List<ChatMessage> messages,
      int index,
      DateTime currentDate,
      ) {
    if (index == messages.length - 1) return true;
    final previousDate = messages[index + 1].timestamp;
    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  void _editMessage(ChatMessage message) {
    _messageController.text = message.message;
  }


  // 🆕 Add these new methods

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentSheet(
        onSelected: _handleAttachmentSelected,
      ),
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
        _showVoiceRecordingSheet();
        break;
    }
  }

  Future<void> _pickAndSendImage({required bool fromCamera}) async {
    try {
      final file = fromCamera
          ? await ChatMediaService.captureImageFromCamera()
          : await ChatMediaService.pickImageFromGallery();

      if (file == null) return;

      setState(() => _isUploadingMedia = true);

      // Get file size before compression
      final size = await ChatMediaService.getFileSize(file);

      // Upload to Cloudinary
      final url = await ChatMediaService.uploadChatImage(
        conversationId: _conversationId,
        file: file,
      );

      if (url == null) {
        throw Exception('Upload failed');
      }

      // Send message
      await _chatService.sendImageMessage(
        conversationId: _conversationId,
        receiverId: widget.otherUserId,
        imageUrl: url,
        fileSize: size,
        replyToMessageId: _replyToMessage?.id,
      );

      // Clear reply
      setState(() => _replyToMessage = null);

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }

      _showSnackBar('Image sent');
    } catch (e) {
      _showSnackBar('Failed to send image');
      debugPrint('Image send error: $e');
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _showVoiceRecordingSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => VoiceRecordingSheet(
        onSend: _sendVoiceMessage,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _sendVoiceMessage(String path, int durationSeconds) async {
    Navigator.pop(context); // Close sheet

    if (path.isEmpty || durationSeconds < 1) return;

    setState(() => _isUploadingMedia = true);

    try {
      // Upload to Cloudinary
      final url = await ChatMediaService.uploadVoiceMessage(
        conversationId: _conversationId,
        localPath: path,
        durationSeconds: durationSeconds,
      );

      if (url == null) {
        throw Exception('Upload failed');
      }

      // Send message
      await _chatService.sendVoiceMessage(
        conversationId: _conversationId,
        receiverId: widget.otherUserId,
        audioUrl: url,
        durationSeconds: durationSeconds,
        replyToMessageId: _replyToMessage?.id,
      );

      // Clear reply
      setState(() => _replyToMessage = null);

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }

      _showSnackBar('Voice message sent');
    } catch (e) {
      _showSnackBar('Failed to send voice message');
      debugPrint('Voice send error: $e');
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _deleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: Text(
          'Delete Message',
          style: TextStyle(color: AppColors.inputTextWhite),
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: AppColors.hintPurple),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.hintPurple),
            ),
          ),
          TextButton(
            onPressed: () {
              _chatService.deleteMessage(
                _conversationId,
                message.id,
              );
              Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: Text(
          'Clear Chat',
          style: TextStyle(color: AppColors.inputTextWhite),
        ),
        content: Text(
          'Are you sure you want to clear this chat? This action cannot be undone.',
          style: TextStyle(color: AppColors.hintPurple),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.hintPurple),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // 1) call service (updates participantData.{uid}.clearedBefore)
              await _chatService.clearChat(_conversationId);

              // 2) update local cutoff immediately so UI reflects clear
              setState(() {
                _clearedBefore = DateTime.now();
                _messages.clear();
                _messageIds.clear();
                _lastDoc = null;
                _hasMore = true;
              });

              // 3) reload the first page (will fetch only messages after clearedBefore)
              await _loadMoreMessages(initial: true);

              _showSnackBar('Chat cleared');
            },
            child: Text(
              'Clear',
              style: TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: Text(
          'Block User',
          style: TextStyle(color: AppColors.inputTextWhite),
        ),
        content: Text(
          'Are you sure you want to block ${_otherUser?.username ?? "User"}?',
          style: TextStyle(color: AppColors.hintPurple),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.hintPurple),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              _showSnackBar('User blocked');
            },
            child: Text(
              'Block',
              style: TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: Text(
          'Report User',
          style: TextStyle(color: AppColors.inputTextWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Why are you reporting this user?',
              style: TextStyle(color: AppColors.hintPurple),
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.hintPurple),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('User reported');
            },
            child: Text(
              'Report',
              style: TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );
  }
}