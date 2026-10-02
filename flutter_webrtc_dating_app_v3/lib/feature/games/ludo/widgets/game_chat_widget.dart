// lib/feature/games/ludo/widgets/game_chat_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/ludo_game_service.dart';
import '../constants.dart';

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

  final List<String> _quickReactions = ['👍', '😂', '😢', '😡', '🎉', '🔥', '💀', '🎲'];

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
        return Colors.grey;
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

    _textController.clear();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1A0E2E),
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
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Game Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

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
                    child: GestureDetector(
                      onTap: () => _sendMessage(emoji, type: 'reaction'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.watchChat(widget.matchId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  );
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send a reaction or message!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
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
                GestureDetector(
                  onTap: () => _sendMessage(_textController.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getColorFromString(widget.localColor),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
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
    final isMe = senderColor == widget.localColor;

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
                color: isMe ? color : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isMe ? Colors.white : color,
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