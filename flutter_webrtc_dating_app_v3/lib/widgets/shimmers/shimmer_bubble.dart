import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerBubbleGrid extends StatelessWidget {
  final int count;
  const ShimmerBubbleGrid({Key? key, this.count = 9}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 100, left: 18, right: 18),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.white12,
            highlightColor: Colors.white24,
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Shimmer.fromColors(
            baseColor: Colors.white12,
            highlightColor: Colors.white24,
            child: Container(
              width: 70,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerBubbleStrip extends StatelessWidget {
  final int count;
  const ShimmerBubbleStrip({Key? key, this.count = 8}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => Column(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.white12,
              highlightColor: Colors.white24,
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: Colors.white12,
              highlightColor: Colors.white24,
              child: Container(
                width: 70,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
