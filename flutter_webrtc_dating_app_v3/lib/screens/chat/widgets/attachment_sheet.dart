// lib/screens/chat/widgets/attachment_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum AttachmentType { camera, gallery, audio, game }

class AttachmentSheet extends StatelessWidget {
  final Function(AttachmentType) onSelected;

  const AttachmentSheet({Key? key, required this.onSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    void pick(AttachmentType type) {
      Navigator.pop(context);
      onSelected(type);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        // Scrolls in landscape, where the sheet is short.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Share',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    semanticLabel: 'Take a photo',
                    accent: AppColors.brandPink,
                    iconColor: AppColors.pinkLight,
                    onTap: () => pick(AttachmentType.camera),
                  ),
                  const SizedBox(width: 12),
                  _buildOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    semanticLabel: 'Choose a photo from gallery',
                    accent: AppColors.brandPurpleMid,
                    iconColor: AppColors.brandPurpleLight,
                    onTap: () => pick(AttachmentType.gallery),
                  ),
                  const SizedBox(width: 12),
                  _buildOption(
                    icon: Icons.mic_rounded,
                    label: 'Voice note',
                    semanticLabel: 'Record a voice note',
                    accent: AppColors.gold,
                    iconColor: AppColors.gold,
                    onTap: () => pick(AttachmentType.audio),
                  ),
                  const SizedBox(width: 12),
                  _buildOption(
                    icon: Icons.sports_esports_rounded,
                    label: 'Games',
                    semanticLabel: 'Play a game together',
                    accent: AppColors.brandPink,
                    iconColor: AppColors.brandPink,
                    onTap: () => pick(AttachmentType.game),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required String semanticLabel,
    required Color accent,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticLabel,
        // excludeSemantics drops the InkWell's tap action, so re-add it.
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.35)),
                    ),
                    child: Icon(icon, color: iconColor, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
