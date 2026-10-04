// lib/feature/games/ludo/widgets/game_chat_widget.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/ludo_game_service.dart';
import '../constants.dart';
import '../../../../core/constants/app_colors.dart';

class GameChatWidget extends StatefulWidget {
  final String matchId;
  final String localColor;

  const GameChatWidget({
    Key? key,
    required this.matchId,
    required this.localColor,
  }) : super(key: key);

  @override
  State<GameChatWidget> createState() => _GameChatWidgetState();
}

class _GameChatWidgetState extends State<GameChatWidget> {
  final _service = LudoGameService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _quickReactions = [
    '👍',
    '😂',
    '😢',
    '😡',
    '🎉',
    '🔥',
    '💀',
    '🎲'
  ];

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _chatStream;
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    _chatStream = _service.watchChat(widget.matchId);
  }

  /// The list is reversed (newest at offset 0), so "bottom" is 0.
  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getColorFromString(String colorStr) {
    switch (colorStr.toLowerCase()) {
      case 'green':
        return LudoColor.green;
      case 'yellow':
        return LudoColor.yellow;
      case 'blue':
        return LudoColor.blue;
      case 'red':
        return LudoColor.red;
      default:
        return AppColors.lavender;
    }
  }

  Future<void> _sendMessage(String message, {String type = 'text'}) async {
    if (message.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _service.sendChatMessage(
      matchId: widget.matchId,
      senderUid: user.uid,
      senderName: user.displayName ?? 'Player',
      senderColor: widget.localColor,
      message: message.trim(),
      type: type,
    );

    if (type == 'text') _textController.clear();
    _scrollToLatest();
  }

  @override
  Widget build(BuildContext context) {
    // Shrink above the keyboard so the input stays visible.
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final height = math.max(
      200.0,
      math.min(
        media.size.height * 0.6,
        media.size.height - inset - media.padding.top - 24,
      ),
    );
    return Container(
      height: height,
      margin: EdgeInsets.only(bottom: inset),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.brandPurpleLight,
                ),
                const SizedBox(width: 8),
                Semantics(
                  header: true,
                  child: const Text(
                    'Game chat',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close chat',
                  icon: const Icon(Icons.close, color: AppColors.lavender),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Quick Reactions
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _quickReactions.map((emoji) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      button: true,
                      label: 'Send reaction $emoji',
                      excludeSemantics: true,
                      onTap: () => _sendMessage(emoji, type: 'reaction'),
                      child: Material(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _sendMessage(emoji, type: 'reaction'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPurpleLight,
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 40,
                            color: AppColors.pinkLight,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Say hi with a reaction or a message.',
                            style: TextStyle(
                              color: AppColors.lavender,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final newestId = messages.first.id;
                if (newestId != _lastMessageId) {
                  _lastMessageId = newestId;
                  _scrollToLatest();
                }

                // Query is newest-first; a reversed list shows newest at the bottom.
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    return _buildMessageBubble(data);
                  },
                );
              },
            ),
          ),

          // Input Field
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceRaised,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLength: LudoGameService.chatMaxLength,
                    style: const TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Type a message…',
                      hintStyle: const TextStyle(color: AppColors.lavender),
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: 'Send message',
                    icon: const Icon(
                      Icons.send,
                      color: AppColors.white,
                      size: 20,
                    ),
                    onPressed: () => _sendMessage(_textController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final senderColor = data['senderColor']?.toString() ?? 'green';
    final senderName = data['senderName']?.toString() ?? 'Player';
    final message = data['message']?.toString() ?? '';
    final type = data['type']?.toString() ?? 'text';
    final senderUid = data['senderUid']?.toString();
    final isMe = senderUid != null
        ? senderUid == _myUid
        : senderColor == widget.localColor;

    final color = _getColorFromString(senderColor);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Message bubble
            Container(
              padding: type == 'reaction'
                  ? const EdgeInsets.all(8)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.brandPurple : AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: type == 'reaction' ? 28 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
