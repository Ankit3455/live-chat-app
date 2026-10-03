// lib/screens/chat/widgets/attachment_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum AttachmentType {
  camera,
  gallery,
  audio,
}

class AttachmentSheet extends StatelessWidget {
  final Function(AttachmentType) onSelected;

  const AttachmentSheet({
    Key? key,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppColors.purplePrimary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Share',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Options Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOption(
                  context,
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFFE91E63),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(AttachmentType.camera);
                  },
                ),
                _buildOption(
                  context,
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: AppColors.brandMagenta,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(AttachmentType.gallery);
                  },
                ),
                _buildOption(
                  context,
                  icon: Icons.mic_rounded,
                  label: 'Audio',
                  color: AppColors.cyan,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(AttachmentType.audio);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Semantics(
      button: true,
      child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      ),
    );
  }
}