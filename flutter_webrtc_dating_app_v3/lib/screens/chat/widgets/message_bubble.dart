import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/chat_message_model.dart';
import '../../../core/constants/app_colors.dart';
import 'image_message.dart';
import 'audio_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String otherUserName;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// The replied-to message if it is loaded; used when the message has no
  /// [ChatMessage.replyTo] snapshot (older messages).
  final ChatMessage? repliedMessage;

  /// Tapping the quote; receives the original message id.
  final ValueChanged<String>? onReplyTap;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.repliedMessage,
    this.onReplyTap,
  }) : super(key: key);

  /// Call events are written by CallService with `metadata.callId`.
  static bool isCallEvent(ChatMessage m) => m.metadata?['callId'] != null;

  static final DateFormat _timeFormat = DateFormat('h:mm a');

  static const Radius _round = Radius.circular(20);
  static const Radius _tail = Radius.circular(6);

  String get _time => _timeFormat.format(message.timestamp);

  BorderRadius get _bubbleRadius => BorderRadius.only(
    topLeft: _round,
    topRight: _round,
    bottomLeft: isMe ? _round : _tail,
    bottomRight: isMe ? _tail : _round,
  );

  /// Text colour for secondary content inside the bubble.
  Color get _metaColor =>
      isMe ? AppColors.white.withOpacity(0.8) : AppColors.lavender;

  @override
  Widget build(BuildContext context) {
    if (isCallEvent(message)) return _buildCallEvent();

    final isMedia = _isMediaMessage() && !message.isDeleted;

    // One screen-reader node: sender, content, time and status.
    return MergeSemantics(
      child: Semantics(
        label: isMe ? 'You' : otherUserName,
        hint: 'Long press for message options',
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            // Width from the parent, so it follows the 720 chat column.
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.8,
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Media keeps its own frame, so the quote sits above it.
                      if (isMedia && _hasReply) _buildReplyPreview(),
                      _buildMessageContainer(),
                      if (isMedia) _buildExternalFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isMediaMessage() {
    return message.type == MessageType.image ||
        message.type == MessageType.audio ||
        message.type == MessageType.video;
  }

  Widget _buildMessageContainer() {
    if (message.isDeleted) return _buildDeletedMessage();
    if (_isMediaMessage()) return _buildMediaMessage();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? null : AppColors.surface2,
        gradient: isMe ? AppColors.primaryGradient : null,
        borderRadius: _bubbleRadius,
      ),
      // Sized to the widest of quote / text / meta.
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasReply) _buildReplyPreview(),
            _buildTextContent(),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: _buildMessageFooter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaMessage() {
    switch (message.type) {
      case MessageType.image:
        return ImageMessage(message: message, isMe: isMe);
      case MessageType.audio:
        return AudioMessage(message: message, isMe: isMe);
      case MessageType.video:
        return _buildPlaceholderMedia(Icons.videocam, 'Video');
      default:
        return _buildTextContent();
    }
  }

  Widget _buildPlaceholderMedia(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: _bubbleRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.brandPurpleLight),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.white)),
        ],
      ),
    );
  }

  bool get _hasReply =>
      message.replyTo != null || message.replyToMessageId != null;

  /// The current user's uid, derived from who sent/received this message.
  String get _myUid => isMe ? message.senderId : message.receiverId;

  static MessageType _typeFromName(Object? name) {
    for (final t in MessageType.values) {
      if (t.name == name) return t;
    }
    return MessageType.text;
  }

  /// Centered system line for missed/declined call events.
  Widget _buildCallEvent() {
    final meta = message.metadata ?? const {};
    final isVideo = meta['callType'] == 'video';
    final status = meta['callStatus']?.toString() ?? 'missed';
    final kind = isVideo ? 'video' : 'voice';

    final String text;
    if (isMe) {
      final outcome = status == 'declined'
          ? 'Declined'
          : status == 'busy'
          ? 'Busy'
          : 'No answer';
      text = 'Outgoing $kind call · $outcome';
    } else {
      text = status == 'declined' ? 'Declined $kind call' : 'Missed $kind call';
    }
    final missed = !isMe && status != 'declined';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isVideo ? Icons.videocam_outlined : Icons.call_outlined,
            size: 14,
            color: missed ? AppColors.error : AppColors.textSubtle,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$text · $_time',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSubtle, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Quote of the replied-to message (sender + text).
  Widget _buildReplyPreview() {
    final snap = message.replyTo;
    final original = repliedMessage;
    final replyId =
        (snap?['id'] as String?) ?? message.replyToMessageId ?? original?.id;

    String? senderId = snap?['senderId'] as String?;
    String? preview;
    if (snap != null) {
      final text = (snap['text'] as String?) ?? '';
      preview = ChatMessage.previewFor(_typeFromName(snap['type']), text);
      if (preview.isEmpty) preview = ChatMessage.deletedText;
    } else if (original != null) {
      senderId = original.senderId;
      preview = original.previewText;
    }

    final String title;
    if (senderId == null) {
      title = 'Reply';
    } else if (senderId == _myUid) {
      title = 'You';
    } else {
      title = otherUserName;
    }

    final onTap = onReplyTap;
    final bodyColor = isMe
        ? AppColors.white.withOpacity(0.9)
        : AppColors.lavender;

    return Semantics(
      button: replyId != null && onTap != null,
      label: 'Quoted message from $title',
      child: GestureDetector(
        onTap: replyId == null || onTap == null ? null : () => onTap(replyId),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppColors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isMe
                    ? AppColors.white.withOpacity(0.6)
                    : AppColors.brandPurpleLight,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isMe ? AppColors.white : AppColors.brandPurpleLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                preview ?? 'Original message',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: preview == null ? FontStyle.italic : null,
                  color: bodyColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: _bubbleRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 16, color: AppColors.textSubtle),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              ChatMessage.deletedText,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: AppColors.lavender,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    return Text(
      message.message,
      style: const TextStyle(color: AppColors.white, fontSize: 15, height: 1.4),
    );
  }

  /// edited · time · ticks, inside text bubbles.
  Widget _buildMessageFooter() {
    final color = _metaColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.editedAt != null ? 'edited · $_time' : _time,
          style: TextStyle(fontSize: 11, color: color),
        ),
        if (isMe) ...[const SizedBox(width: 4), _buildMessageStatus()],
      ],
    );
  }

  /// Under media messages.
  Widget _buildExternalFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _time,
            style: const TextStyle(fontSize: 11, color: AppColors.lavender),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            _buildMessageStatus(onBubble: false),
          ],
        ],
      ),
    );
  }

  /// Read ticks use a light violet so they read on the gradient and on dark.
  Widget _buildMessageStatus({bool onBubble = true}) {
    final IconData icon;
    final Color color;
    final String label;
    final dim = onBubble
        ? AppColors.white.withOpacity(0.7)
        : AppColors.lavender;

    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = dim;
        label = 'Sending';
        break;
      case MessageStatus.sent:
        icon = Icons.done;
        color = dim;
        label = 'Sent';
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = dim;
        label = 'Delivered';
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = onBubble ? AppColors.lavenderLight : AppColors.brandPurpleLight;
        label = 'Read';
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = onBubble ? AppColors.white : AppColors.error;
        label = 'Not sent';
        break;
    }

    return Icon(icon, size: 14, color: color, semanticLabel: label);
  }

  void _showMessageOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    final reply = onReply;
    final edit = onEdit;
    final delete = onDelete;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderStrong),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Copy (only for text messages)
              if (message.type == MessageType.text && !message.isDeleted)
                ListTile(
                  leading: const Icon(
                    Icons.content_copy,
                    color: AppColors.brandPurpleLight,
                  ),
                  title: const Text(
                    'Copy',
                    style: TextStyle(color: AppColors.white),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.message));
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    Navigator.pop(context);
                    messenger?.showSnackBar(
                      const SnackBar(content: Text('Message copied')),
                    );
                  },
                ),

              if (reply != null)
                ListTile(
                  leading: const Icon(
                    Icons.reply,
                    color: AppColors.brandPurpleLight,
                  ),
                  title: const Text(
                    'Reply',
                    style: TextStyle(color: AppColors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    reply();
                  },
                ),

              // Edit (only for own text messages)
              if (isMe &&
                  edit != null &&
                  !message.isDeleted &&
                  message.type == MessageType.text)
                ListTile(
                  leading: const Icon(
                    Icons.edit,
                    color: AppColors.brandPurpleLight,
                  ),
                  title: const Text(
                    'Edit',
                    style: TextStyle(color: AppColors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    edit();
                  },
                ),

              // Delete (only for own messages)
              if (isMe && delete != null && !message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    delete();
                  },
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
