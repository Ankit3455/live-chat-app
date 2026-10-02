import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../core/constants/app_colors.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.purplePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _searchQuery = _searchQuery.isEmpty ? ' ' : '';
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty) _buildSearchBar(),
          Expanded(
            child: StreamBuilder<List<Conversation>>(
              stream: _chatService.getConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.purplePrimary,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final conversations = snapshot.data!;
                final filteredConversations = _filterConversations(conversations);

                if (filteredConversations.isEmpty) {
                  return _buildNoResultsState();
                }

                return ListView.builder(
                  itemCount: filteredConversations.length,
                  itemBuilder: (context, index) {
                    return ChatListTile(
                      conversation: filteredConversations[index],
                      currentUserId: _chatService.currentUserId,
                      onTap: () => _navigateToChat(filteredConversations[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: AppColors.inputBackground,
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppColors.inputTextWhite),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: TextStyle(color: AppColors.hintPurple),
          prefixIcon: Icon(Icons.search, color: AppColors.purplePrimary),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: AppColors.hintPurple),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
            },
          ),
          filled: true,
          fillColor: AppColors.inputBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppColors.hintPurple.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.hintPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with someone!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.hintPurple.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: AppColors.hintPurple.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.hintPurple,
            ),
          ),
        ],
      ),
    );
  }

  List<Conversation> _filterConversations(List<Conversation> conversations) {
    if (_searchQuery.isEmpty) return conversations;

    return conversations.where((conv) {
      return conv.lastMessage?.toLowerCase().contains(_searchQuery) ?? false;
    }).toList();
  }

  void _navigateToChat(Conversation conversation) {
    final otherUserId = conversation.getOtherParticipantId(_chatService.currentUserId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: otherUserId,
          conversationId: conversation.id,
        ),
      ),
    );
  }
}

class ChatListTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const ChatListTile({
    Key? key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final otherUserId = conversation.getOtherParticipantId(currentUserId);
    final unreadCount = conversation.unreadCount[currentUserId] ?? 0;
    final isLastMessageMine = conversation.lastMessageSenderId == currentUserId;

    return FutureBuilder<UserModel?>(
      future: ChatService().getUserDetails(otherUserId),
      builder: (context, snapshot) {
        final otherUser = snapshot.data;

        // Using correct UserModel fields
        final displayName = otherUser?.username ?? 'Unknown User';

        // Get avatar URL - check both profileImage and avatarString
        String? avatarUrl = otherUser?.profileImage;
        if (avatarUrl == null || avatarUrl.isEmpty) {
          avatarUrl = otherUser?.avatarString;
        }

        // Use the online field directly from UserModel
        final isOnline = otherUser?.online ?? false;

        return ListTile(
          onTap: onTap,
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                backgroundColor: AppColors.purplePrimary,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.connectColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.appBackground,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                    color: AppColors.inputTextWhite,
                  ),
                ),
              ),
              if (conversation.lastMessageTime != null)
                Text(
                  _formatTime(conversation.lastMessageTime!),
                  style: TextStyle(
                    fontSize: 12,
                    color: unreadCount > 0
                        ? AppColors.purplePrimary
                        : AppColors.hintPurple,
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              if (isLastMessageMine)
                Icon(
                  Icons.done_all,
                  size: 16,
                  color: AppColors.purplePrimary,
                ),
              if (isLastMessageMine) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  conversation.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unreadCount > 0
                        ? AppColors.inputTextWhite
                        : AppColors.hintPurple,
                    fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.purplePrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(time);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}