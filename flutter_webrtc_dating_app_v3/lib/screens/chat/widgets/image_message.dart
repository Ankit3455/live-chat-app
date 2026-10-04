// lib/screens/chat/widgets/image_message.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/chat_message_model.dart';
import '../../../services/media/media_url_policy.dart';

class ImageMessage extends StatefulWidget {
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
  State<ImageMessage> createState() => _ImageMessageState();
}

class _ImageMessageState extends State<ImageMessage> {
  // Bumped by Retry so the image widget rebuilds and refetches.
  int _attempt = 0;

  Future<void> _retry(String url) async {
    await CachedNetworkImage.evictFromCache(url);
    if (mounted) setState(() => _attempt++);
  }

  BoxDecoration get _frame => BoxDecoration(
    color: widget.isMe ? null : AppColors.surface2,
    gradient: widget.isMe ? AppColors.primaryGradient : null,
    borderRadius: BorderRadius.circular(20),
  );

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.message.mediaUrl ?? '';
    final caption = widget.message.message;
    final hasCaption = caption.isNotEmpty;

    if (!MediaUrlPolicy.isAllowed(imageUrl)) {
      return _buildUnavailable();
    }

    return Semantics(
      button: true,
      label: hasCaption ? 'Photo: $caption' : 'Photo',
      hint: 'Open full screen',
      child: GestureDetector(
        onTap: widget.onTap ?? () => _showFullScreen(context, imageUrl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.65,
            maxHeight: 350,
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: _frame,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: hasCaption ? 280 : 320,
                        minHeight: 100,
                      ),
                      child: CachedNetworkImage(
                        key: ValueKey('$imageUrl#$_attempt'),
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Shimmer.fromColors(
                          // No sweep under reduced motion.
                          enabled: !MediaQuery.disableAnimationsOf(context),
                          baseColor: AppColors.surfaceCard,
                          highlightColor: AppColors.surface2,
                          child: Container(
                            height: 180,
                            color: AppColors.surfaceCard,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildError(imageUrl),
                      ),
                    ),
                  ),
                ),
                if (hasCaption)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Text(
                      caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        height: 1.35,
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

  Widget _buildError(String imageUrl) {
    return Container(
      height: 140,
      color: AppColors.surfaceCard,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            color: AppColors.lavender,
            size: 32,
          ),
          const SizedBox(height: 6),
          const Text(
            "Couldn't load photo",
            style: TextStyle(color: AppColors.lavender, fontSize: 13),
          ),
          TextButton.icon(
            onPressed: () => _retry(imageUrl),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandPurpleLight,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, color: AppColors.lavender),
          SizedBox(width: 8),
          Text(
            'Image unavailable',
            style: TextStyle(color: AppColors.lavender, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context, String imageUrl) {
    if (!MediaUrlPolicy.isAllowed(imageUrl)) return;

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
            tooltip: 'Download',
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
            errorWidget: (context, url, error) =>
                const Icon(Icons.error, color: Colors.white, size: 50),
          ),
        ),
      ),
    );
  }
}
