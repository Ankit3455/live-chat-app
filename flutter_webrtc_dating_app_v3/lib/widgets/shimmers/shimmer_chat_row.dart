import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';

class ShimmerChatList extends StatelessWidget {
  final int count;
  const ShimmerChatList({Key? key, this.count = 10}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Static placeholders under reduced motion.
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Loading chats',
      child: ExcludeSemantics(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: count,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.border),
          // One Shimmer per row instead of one per placeholder: each Shimmer
          // runs its own controller and shader layer every frame.
          itemBuilder: (_, __) => Shimmer.fromColors(
            enabled: animate,
            baseColor: AppColors.surfaceCard,
            highlightColor: AppColors.surface2,
            child: ListTile(
              leading: const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
              ),
              title: Container(height: 12, width: 120, color: Colors.white),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Container(height: 10, width: 180, color: Colors.white),
              ),
              trailing: Container(
                height: 18,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
