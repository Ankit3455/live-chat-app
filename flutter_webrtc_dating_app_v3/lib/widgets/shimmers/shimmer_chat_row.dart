import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerChatList extends StatelessWidget {
  final int count;
  const ShimmerChatList({Key? key, this.count = 10}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
      itemBuilder: (_, __) => ListTile(
        leading: Shimmer.fromColors(
          baseColor: Colors.white12,
          highlightColor: Colors.white24,
          child: const CircleAvatar(radius: 24, backgroundColor: Colors.white),
        ),
        title: Shimmer.fromColors(
          baseColor: Colors.white12,
          highlightColor: Colors.white24,
          child: Container(height: 12, width: 120, color: Colors.white),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Shimmer.fromColors(
            baseColor: Colors.white12,
            highlightColor: Colors.white24,
            child: Container(height: 10, width: 180, color: Colors.white),
          ),
        ),
        trailing: Shimmer.fromColors(
          baseColor: Colors.white12,
          highlightColor: Colors.white24,
          child: Container(
            height: 18,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
    );
  }
}
