import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final CallService _callService = CallService(); // Add call service
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _conversationId;
  UserModel? _otherUser;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  ChatMessage? _replyToMessage;
  final FocusNode _messageFocusNode = FocusNode();

  // Add call state
  bool _isCallInProgress = false;

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
        _conversationId = await _chatService.getOrCreateConversation(widget.otherUserId);
      }

      _otherUser = await _chatService.getUserDetails(widget.otherUserId);
      await _chatService.markMessagesAsRead(_conversationId, widget.otherUserId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();
    _updateTypingStatus(false);

    try {
      await _chatService.sendMessage(
        conversationId: _conversationId,
        receiverId: widget.otherUserId,
        message: message,
        replyToMessageId: _replyToMessage?.id,
      );

      setState(() {
        _replyToMessage = null;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // ============= CALL METHODS =============

  Future<void> _startCall(CallType type) async {
    // Prevent multiple calls
    if (_isCallInProgress) {
      _showSnackBar('A call is already in progress');
      return;
    }

    try {
      // Check permissions first
      final permissions = type == CallType.video
          ? [Permission.camera, Permission.microphone]
          : [Permission.microphone];

      Map<Permission, PermissionStatus> statuses = {};
      for (final permission in permissions) {
        final status = await permission.request();
        statuses[permission] = status;
      }

      // Check if all permissions are granted
      bool allGranted = true;
      String deniedPermission = '';

      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
          deniedPermission = permission == Permission.camera ? 'Camera' : 'Microphone';
        }
      });

      if (!allGranted) {
        _showSnackBar('$deniedPermission permission is required for calls');

        // Open app settings if permanently denied
        if (statuses.values.any((status) => status.isPermanentlyDenied)) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.inputBackground,
              title: Text(
                'Permission Required',
                style: TextStyle(color: AppColors.inputTextWhite),
              ),
              content: Text(
                'Please enable $deniedPermission permission from settings to make calls.',
                style: TextStyle(color: AppColors.hintPurple),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: Text('Open Settings', style: TextStyle(color: AppColors.purplePrimary)),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() {
        _isCallInProgress = true;
      });

      // Show loading dialog
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

      // Start the call
      final callId = await _callService.startCall(
        receiverId: widget.otherUserId,
        type: type,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Navigate to call screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => type == CallType.video
              ? VideoCallScreen(callId: callId, isOutgoing: true)
              : AudioCallScreen(callId: callId, isOutgoing: true),
        ),
      );

      // Call ended, reset state
      setState(() {
        _isCallInProgress = false;
      });

    } catch (e) {
      setState(() {
        _isCallInProgress = false;
      });

      if (!mounted) return;

      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      String errorMessage = 'Failed to start call';
      if (e.toString().contains('network')) {
        errorMessage = 'Please check your internet connection';
      } else if (e.toString().contains('busy')) {
        errorMessage = 'User is busy on another call';
      }

      _showSnackBar(errorMessage);

      print('Error starting call: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.purplePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(_conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.purplePrimary),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _chatService.markMessagesAsRead(_conversationId, widget.otherUserId);
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _chatService.currentUserId;
                    final showDate = _shouldShowDate(
                      messages,
                      index,
                      message.timestamp,
                    );

                    return Column(
                      children: [
                        if (showDate) _buildDateSeparator(message.timestamp),
                        MessageBubble(
                          message: message,
                          isMe: isMe,
                          otherUserName: _getDisplayName(),
                          otherUserAvatar: _getUserAvatar(),
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
                );
              },
            ),
          ),
          _buildTypingIndicator(),
          if (_replyToMessage != null) _buildReplyPreview(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  String _getDisplayName() {
    return _otherUser?.username ?? 'User';
  }

  String? _getUserAvatar() {
    if (_otherUser?.profileImage != null && _otherUser!.profileImage.isNotEmpty) {
      return _otherUser!.profileImage;
    }
    return _otherUser?.avatarString;
  }

  AppBar _buildAppBar() {
    final displayName = _getDisplayName();
    final avatarUrl = _getUserAvatar();

    return AppBar(
      backgroundColor: AppColors.purplePrimary,
      title: InkWell(
        onTap: () {
          // Navigate to user profile
        },
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
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 16),
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.otherUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final data = snapshot.data?.data() as Map<String, dynamic>?;
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
                              color: isOnline
                                  ? Colors.greenAccent
                                  : Colors.white70,
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
        // Video call button
        IconButton(
          icon: Icon(
            Icons.videocam,
            color: _isCallInProgress ? Colors.grey : Colors.white,
          ),
          onPressed: _isCallInProgress
              ? null
              : () => _startCall(CallType.video),
          tooltip: 'Video Call',
        ),

        // Voice call button
        IconButton(
          icon: Icon(
            Icons.call,
            color: _isCallInProgress ? Colors.grey : Colors.white,
          ),
          onPressed: _isCallInProgress
              ? null
              : () => _startCall(CallType.audio),
          tooltip: 'Voice Call',
        ),

        // More options menu
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
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear',
              child: Text('Clear chat'),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Text('Block user'),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Text('Report user'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.waving_hand,
            size: 80,
            color: AppColors.purplePrimary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Say hi to ${_getDisplayName()}! 👋',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.hintPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<bool>(
      stream: _chatService.getTypingStatus(_conversationId, widget.otherUserId),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_getDisplayName()} is typing',
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (index) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderId == _chatService.currentUserId ? "yourself" : _getDisplayName()}',
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
            icon: Icon(Icons.close, size: 20, color: AppColors.hintPurple),
            onPressed: () {
              setState(() {
                _replyToMessage = null;
              });
            },
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
          IconButton(
            icon: Icon(Icons.attach_file, color: AppColors.purplePrimary),
            onPressed: () {
              // Implement file attachment
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              style: TextStyle(color: AppColors.inputTextWhite),
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
          CircleAvatar(
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
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
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
          Expanded(child: Divider(color: AppColors.hintPurple.withOpacity(0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                color: AppColors.hintPurple,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.hintPurple.withOpacity(0.3))),
        ],
      ),
    );
  }

  bool _shouldShowDate(List<ChatMessage> messages, int index, DateTime currentDate) {
    if (index == messages.length - 1) return true;

    final previousDate = messages[index + 1].timestamp;
    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  void _editMessage(ChatMessage message) {
    _messageController.text = message.message;
    // You'd need to track which message is being edited
  }

  void _deleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: Text('Delete Message', style: TextStyle(color: AppColors.inputTextWhite)),
        content: Text('Are you sure you want to delete this message?',
            style: TextStyle(color: AppColors.hintPurple)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple)),
          ),
          TextButton(
            onPressed: () {
              _chatService.deleteMessage(_conversationId, message.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.dangerRed)),
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
        title: Text('Clear Chat', style: TextStyle(color: AppColors.inputTextWhite)),
        content: Text('Are you sure you want to clear this chat? This action cannot be undone.',
            style: TextStyle(color: AppColors.hintPurple)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple)),
          ),
          TextButton(
            onPressed: () {
              // Implement clear chat
              Navigator.pop(context);
              _showSnackBar('Chat cleared');
            },
            child: Text('Clear', style: TextStyle(color: AppColors.dangerRed)),
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
        title: Text('Block User', style: TextStyle(color: AppColors.inputTextWhite)),
        content: Text('Are you sure you want to block ${_getDisplayName()}?',
            style: TextStyle(color: AppColors.hintPurple)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple)),
          ),
          TextButton(
            onPressed: () {
              // Implement block user
              Navigator.pop(context);
              Navigator.pop(context); // Exit chat
              _showSnackBar('User blocked');
            },
            child: Text('Block', style: TextStyle(color: AppColors.dangerRed)),
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
        title: Text('Report User', style: TextStyle(color: AppColors.inputTextWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Why are you reporting this user?',
                style: TextStyle(color: AppColors.hintPurple)),
            const SizedBox(height: 20),
            // Add report options here
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.hintPurple)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('User reported');
            },
            child: Text('Report', style: TextStyle(color: AppColors.dangerRed)),
          ),
        ],
      ),
    );
  }
}