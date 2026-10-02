import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../core/constants/app_colors.dart';

class ProfileBubble extends StatefulWidget {
  const ProfileBubble({
    Key? key,
    required this.user,
    required this.onTap,
  }) : super(key: key);

  final UserModel user;
  final VoidCallback onTap;

  @override
  State<ProfileBubble> createState() => _ProfileBubbleState();
}

class _ProfileBubbleState extends State<ProfileBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _floatY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _floatY = Tween<double>(begin: -6, end: 6)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _initial() {
    final name = (widget.user.username).trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  /// cache-busted avatar url (profileImage + avatarVersion)
  String? _avatarUrl() {
    final url = widget.user.profileImage;
    if (url.isEmpty) return null;
    final v = widget.user.avatarVersion ?? 0;
    return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
  }

  Widget _avatarContent() {
    final url = _avatarUrl();

    // agar url nahi hai to initials bubble
    if (url == null) {
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _initial(),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    // warna network image
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            // network fail → initials
            return Container(
              color: const Color(0xFF1A0E2E),
              alignment: Alignment.center,
              child: Text(
                _initial(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.user.online == true;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return Transform.translate(
          offset: Offset(0, _floatY.value),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 92,
          // yahi height flutter ne constraint me dikhayi thi (104), thoda safety margin
          constraints: const BoxConstraints(
            minHeight: 100,
            maxHeight: 110,
          ),
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D1B4E),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.25),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          // 🔑 Overflow fix: pura content FittedBox me, jo need hone par
          // thoda scale-down kar dega => RenderFlex overflow nahi hoga.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: _avatarContent(),
                      ),
                      if (online)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.25),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // name text ko bhi thoda compress-friendly banaya
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      widget.user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: online
                          ? Colors.green.withOpacity(.15)
                          : Colors.white.withOpacity(.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      online ? 'Online' : 'Offline',
                      style: TextStyle(
                        color:
                        online ? Colors.greenAccent : AppColors.hintPurple,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
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

