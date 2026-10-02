// lib/screens/chat/widgets/image_message.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/chat_message_model.dart';

class ImageMessage extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onTap;

  const ImageMessage({
    Key? key,
    required this.message,
    required this.isMe,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = message.mediaUrl ?? '';
    final caption = message.message;
    final hasCaption = caption.isNotEmpty;

    return GestureDetector(
      onTap: onTap ?? () => _showFullScreen(context, imageUrl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
          maxHeight: 350, // ⭐ Increased max height
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.purplePrimary.withOpacity(0.3)
                : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.purplePrimary.withOpacity(0.2),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ⭐ Important: min size
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⭐ Image with Flexible to prevent overflow
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: hasCaption ? 280 : 320, // Leave room for caption
                      minHeight: 100,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        height: 180,
                        color: AppColors.inputBackground,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.purplePrimary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 120,
                        color: AppColors.inputBackground,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white38,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Caption (if any) - with max lines to prevent overflow
                if (hasCaption)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      caption,
                      maxLines: 3, // ⭐ Limit caption lines
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }
}

// Full screen image viewer
class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageView({Key? key, required this.imageUrl})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download coming soon')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.error,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
      ),
    );
  }
}