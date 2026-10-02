// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:intl/intl.dart';
// import '../../../models/chat_message_model.dart';
// import '../../../core/constants/app_colors.dart';
// import 'image_message.dart';
// import 'audio_message.dart';
//
// class MessageBubble extends StatelessWidget {
//   final ChatMessage message;
//   final bool isMe;
//   final String otherUserName;        // Just receives String, no UserModel access
//   final String? otherUserAvatar;     // Just receives String?, no UserModel access
//   final VoidCallback? onReply;
//   final VoidCallback? onEdit;
//   final VoidCallback? onDelete;
//
//   const MessageBubble({
//     Key? key,
//     required this.message,
//     required this.isMe,
//     required this.otherUserName,
//     this.otherUserAvatar,
//     this.onReply,
//     this.onEdit,
//     this.onDelete,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onLongPress: () => _showMessageOptions(context),
//       child: Align(
//         alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
//         child: Container(
//           margin: EdgeInsets.only(
//             left: isMe ? 50 : 8,
//             right: isMe ? 8 : 50,
//             top: 4,
//             bottom: 4,
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               // Show avatar only for received messages (not mine)
//               if (!isMe) ...[
//                 CircleAvatar(
//                   radius: 16,
//                   backgroundImage: otherUserAvatar != null && otherUserAvatar!.isNotEmpty
//                       ? NetworkImage(otherUserAvatar!)
//                       : null,
//                   backgroundColor: AppColors.purpleSecondary,
//                   child: (otherUserAvatar == null || otherUserAvatar!.isEmpty)
//                       ? Text(
//                     otherUserName.isNotEmpty
//                         ? otherUserName[0].toUpperCase()
//                         : '?',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   )
//                       : null,
//                 ),
//                 const SizedBox(width: 8),
//               ],
//               Flexible(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 10,
//                   ),
//                   decoration: BoxDecoration(
//                     color: isMe ? AppColors.purplePrimary : AppColors.inputBackground,
//                     borderRadius: BorderRadius.only(
//                       topLeft: const Radius.circular(20),
//                       topRight: const Radius.circular(20),
//                       bottomLeft: Radius.circular(isMe ? 20 : 4),
//                       bottomRight: Radius.circular(isMe ? 4 : 20),
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.1),
//                         blurRadius: 4,
//                         offset: const Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       if (message.replyToMessageId != null)
//                         _buildReplyPreview(),
//                       _buildMessageContent(),
//                       const SizedBox(height: 4),
//                       _buildMessageFooter(),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildReplyPreview() {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       margin: const EdgeInsets.only(bottom: 8),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border(
//           left: BorderSide(
//             color: isMe ? Colors.white : AppColors.purplePrimary,
//             width: 3,
//           ),
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             'Replying to message',
//             style: TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.bold,
//               color: isMe ? Colors.white70 : AppColors.hintPurple,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             'Original message content...',
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontSize: 12,
//               color: isMe ? Colors.white70 : AppColors.hintPurple,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageContent() {
//     if (message.isDeleted) {
//       return Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             Icons.block,
//             size: 16,
//             color: isMe ? Colors.white54 : AppColors.hintPurple,
//           ),
//           const SizedBox(width: 8),
//           Text(
//             'This message was deleted',
//             style: TextStyle(
//               fontStyle: FontStyle.italic,
//               color: isMe ? Colors.white54 : AppColors.hintPurple,
//             ),
//           ),
//         ],
//       );
//     }
//
//     switch (message.type) {
//       case MessageType.text:
//         return Text(
//           message.message,
//           style: TextStyle(
//             color: isMe ? Colors.white : AppColors.inputTextWhite,
//             fontSize: 15,
//           ),
//         );
//       case MessageType.image:
//         return _buildImageMessage();
//       default:
//         return Text(
//           message.message,
//           style: TextStyle(
//             color: isMe ? Colors.white : AppColors.inputTextWhite,
//           ),
//         );
//     }
//   }
//
//   Widget _buildImageMessage() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(8),
//           child: Image.network(
//             message.metadata?['url'] ?? '',
//             width: 200,
//             fit: BoxFit.cover,
//             errorBuilder: (context, error, stackTrace) {
//               return Container(
//                 width: 200,
//                 height: 150,
//                 color: AppColors.midGray,
//                 child: Icon(Icons.broken_image, color: AppColors.manatee),
//               );
//             },
//           ),
//         ),
//         if (message.message.isNotEmpty) ...[
//           const SizedBox(height: 8),
//           Text(
//             message.message,
//             style: TextStyle(
//               color: isMe ? Colors.white : AppColors.inputTextWhite,
//             ),
//           ),
//         ],
//       ],
//     );
//   }
//
//   Widget _buildMessageFooter() {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         if (message.editedAt != null) ...[
//           Text(
//             'edited',
//             style: TextStyle(
//               fontSize: 10,
//               fontStyle: FontStyle.italic,
//               color: isMe ? Colors.white54 : AppColors.hintPurple,
//             ),
//           ),
//           const SizedBox(width: 4),
//         ],
//         Text(
//           DateFormat('HH:mm').format(message.timestamp),
//           style: TextStyle(
//             fontSize: 11,
//             color: isMe ? Colors.white70 : AppColors.hintPurple,
//           ),
//         ),
//         if (isMe) ...[
//           const SizedBox(width: 4),
//           _buildMessageStatus(),
//         ],
//       ],
//     );
//   }
//
//   Widget _buildMessageStatus() {
//     IconData icon;
//     Color color;
//
//     switch (message.status) {
//       case MessageStatus.sending:
//         icon = Icons.access_time;
//         color = Colors.white54;
//         break;
//       case MessageStatus.sent:
//         icon = Icons.done;
//         color = Colors.white70;
//         break;
//       case MessageStatus.delivered:
//         icon = Icons.done_all;
//         color = Colors.white70;
//         break;
//       case MessageStatus.read:
//         icon = Icons.done_all;
//         color = AppColors.blue500;
//         break;
//       case MessageStatus.failed:
//         icon = Icons.error_outline;
//         color = AppColors.dangerRed;
//         break;
//     }
//
//     return Icon(icon, size: 16, color: color);
//   }
//
//   void _showMessageOptions(BuildContext context) {
//     HapticFeedback.lightImpact();
//
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: AppColors.inputBackground,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return SafeArea(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 40,
//                 height: 4,
//                 margin: const EdgeInsets.symmetric(vertical: 12),
//                 decoration: BoxDecoration(
//                   color: AppColors.hintPurple.withOpacity(0.3),
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               ListTile(
//                 leading: Icon(Icons.content_copy, color: AppColors.purplePrimary),
//                 title: Text('Copy', style: TextStyle(color: AppColors.inputTextWhite)),
//                 onTap: () {
//                   Clipboard.setData(ClipboardData(text: message.message));
//                   Navigator.pop(context);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Message copied')),
//                   );
//                 },
//               ),
//               if (onReply != null)
//                 ListTile(
//                   leading: Icon(Icons.reply, color: AppColors.purplePrimary),
//                   title: Text('Reply', style: TextStyle(color: AppColors.inputTextWhite)),
//                   onTap: () {
//                     Navigator.pop(context);
//                     onReply!();
//                   },
//                 ),
//               if (isMe && onEdit != null && !message.isDeleted)
//                 ListTile(
//                   leading: Icon(Icons.edit, color: AppColors.purplePrimary),
//                   title: Text('Edit', style: TextStyle(color: AppColors.inputTextWhite)),
//                   onTap: () {
//                     Navigator.pop(context);
//                     onEdit!();
//                   },
//                 ),
//               if (isMe && onDelete != null && !message.isDeleted)
//                 ListTile(
//                   leading: Icon(Icons.delete, color: AppColors.dangerRed),
//                   title: Text('Delete', style: TextStyle(color: AppColors.dangerRed)),
//                   onTap: () {
//                     Navigator.pop(context);
//                     onDelete!();
//                   },
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//}

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
  final String? otherUserAvatar;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
    this.otherUserAvatar,
    this.onReply,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 50 : 8,
            right: isMe ? 8 : 50,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Show avatar only for received messages (not mine)
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundImage: otherUserAvatar != null && otherUserAvatar!.isNotEmpty
                      ? NetworkImage(otherUserAvatar!)
                      : null,
                  backgroundColor: AppColors.purpleSecondary,
                  child: (otherUserAvatar == null || otherUserAvatar!.isEmpty)
                      ? Text(
                    otherUserName.isNotEmpty
                        ? otherUserName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Reply preview if exists
                    if (message.replyToMessageId != null) _buildReplyPreview(),

                    // Main message content
                    _buildMessageContainer(context),

                    // Timestamp & status (outside bubble for media)
                    if (_isMediaMessage()) _buildExternalFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if message is media type (image, audio, video)
  bool _isMediaMessage() {
    return message.type == MessageType.image ||
        message.type == MessageType.audio ||
        message.type == MessageType.video;
  }

  /// Build the main message container
  Widget _buildMessageContainer(BuildContext context) {
    // Deleted message
    if (message.isDeleted) {
      return _buildDeletedMessage();
    }

    // Media messages have their own styling
    if (_isMediaMessage()) {
      return _buildMediaMessage();
    }

    // Text and other messages use bubble styling
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isMe ? AppColors.purplePrimary : AppColors.inputBackground,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextContent(),
          const SizedBox(height: 4),
          _buildMessageFooter(),
        ],
      ),
    );
  }

  /// Build media message (image, audio, video)
  Widget _buildMediaMessage() {
    switch (message.type) {
      case MessageType.image:
        return ImageMessage(
          message: message,
          isMe: isMe,
        );

      case MessageType.audio:
        return AudioMessage(
          message: message,
          isMe: isMe,
        );

      case MessageType.video:
      // TODO: Implement VideoMessage widget
        return _buildPlaceholderMedia(Icons.videocam, 'Video');

      default:
        return _buildTextContent();
    }
  }

  /// Placeholder for unsupported media types
  Widget _buildPlaceholderMedia(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.purplePrimary.withOpacity(0.3)
            : AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purplePrimary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.purplePrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Build reply preview
  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : AppColors.purplePrimary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Replying to message',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white70 : AppColors.hintPurple,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Original message content...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white70 : AppColors.hintPurple,
            ),
          ),
        ],
      ),
    );
  }

  /// Build deleted message indicator
  Widget _buildDeletedMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 16,
            color: isMe ? Colors.white54 : AppColors.hintPurple,
          ),
          const SizedBox(width: 8),
          Text(
            'This message was deleted',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: isMe ? Colors.white54 : AppColors.hintPurple,
            ),
          ),
        ],
      ),
    );
  }

  /// Build text content (for text messages)
  Widget _buildTextContent() {
    return Text(
      message.message,
      style: TextStyle(
        color: isMe ? Colors.white : AppColors.inputTextWhite,
        fontSize: 15,
      ),
    );
  }

  /// Build message footer (inside bubble for text messages)
  Widget _buildMessageFooter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.editedAt != null) ...[
          Text(
            'edited',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isMe ? Colors.white54 : AppColors.hintPurple,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          DateFormat('HH:mm').format(message.timestamp),
          style: TextStyle(
            fontSize: 11,
            color: isMe ? Colors.white70 : AppColors.hintPurple,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _buildMessageStatus(),
        ],
      ],
    );
  }

  /// Build external footer (outside bubble for media messages)
  Widget _buildExternalFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('HH:mm').format(message.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            _buildMessageStatus(),
          ],
        ],
      ),
    );
  }

  /// Build message status icon
  Widget _buildMessageStatus() {
    IconData icon;
    Color color;

    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.white54;
        break;
      case MessageStatus.sent:
        icon = Icons.done;
        color = Colors.white70;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.white70;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = AppColors.blue500;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = AppColors.dangerRed;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }

  /// Show message options bottom sheet
  void _showMessageOptions(BuildContext context) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.inputBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: AppColors.hintPurple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Copy (only for text messages)
              if (message.type == MessageType.text && !message.isDeleted)
                ListTile(
                  leading: Icon(Icons.content_copy, color: AppColors.purplePrimary),
                  title: Text('Copy', style: TextStyle(color: AppColors.inputTextWhite)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.message));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied')),
                    );
                  },
                ),

              // Reply
              if (onReply != null)
                ListTile(
                  leading: Icon(Icons.reply, color: AppColors.purplePrimary),
                  title: Text('Reply', style: TextStyle(color: AppColors.inputTextWhite)),
                  onTap: () {
                    Navigator.pop(context);
                    onReply!();
                  },
                ),

              // Edit (only for own text messages)
              if (isMe &&
                  onEdit != null &&
                  !message.isDeleted &&
                  message.type == MessageType.text)
                ListTile(
                  leading: Icon(Icons.edit, color: AppColors.purplePrimary),
                  title: Text('Edit', style: TextStyle(color: AppColors.inputTextWhite)),
                  onTap: () {
                    Navigator.pop(context);
                    onEdit!();
                  },
                ),

              // Delete (only for own messages)
              if (isMe && onDelete != null && !message.isDeleted)
                ListTile(
                  leading: Icon(Icons.delete, color: AppColors.dangerRed),
                  title: Text('Delete', style: TextStyle(color: AppColors.dangerRed)),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete!();
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

