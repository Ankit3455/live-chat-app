// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
//
// import '../../../models/user_model.dart';
// import 'profile_quick_sheet.dart'; // same folder
//
// class ProfileBubbleGridItem extends StatelessWidget {
//   const ProfileBubbleGridItem({
//     Key? key,
//     required this.user,
//     required this.onTap,
//   }) : super(key: key);
//
//   final UserModel user;
//   final VoidCallback onTap;
//
//   // --- helpers preserved for compatibility ---
//   ImageProvider? _avatarImage() {
//     final url = user.profileImage;
//     if (url != null && url.isNotEmpty) return NetworkImage(url);
//     return null; // initials fallback
//   }
//
//   String get _initial {
//     final n = (user.username).trim();
//     return n.isNotEmpty ? n[0].toUpperCase() : 'U';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final online = user.online == true;
//     final profession = (user.profession ?? '').trim();
//     final interests = (user.interests ?? const <String>[]).take(3).toList();
//
//     final card = InkWell(
//       onTap: onTap,
//       onLongPress: () {
//         // existing iOS-style bottom sheet (unchanged behavior)
//         showCupertinoModalBottomSheet(
//           context: context,
//           barrierColor: Colors.black54,
//           backgroundColor: Colors.transparent,
//           builder: (_) => ProfileQuickSheet(
//             currentUser: null,
//             user: user,
//           ),
//         );
//       },
//       borderRadius: BorderRadius.circular(24),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(24),
//         child: Container(
//           decoration: BoxDecoration(
//             // subtle outer gradient to blend with your purple theme
//             gradient: const LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [Color(0x26211B3E), Color(0x1A7B2CBF)],
//             ),
//             border: Border.all(color: Colors.white.withOpacity(0.06)),
//           ),
//           child: Stack(
//             children: [
//               // --- background image or gradient ---
//               Positioned.fill(
//                 child: _avatarImage() != null
//                     ? Ink.image(
//                   image: _avatarImage()!,
//                   fit: BoxFit.cover,
//                 )
//                     : Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [
//                         Color(0xFF3C256B),
//                         Color(0xFF2A184A),
//                       ],
//                     ),
//                   ),
//                   alignment: Alignment.center,
//                   child: Text(
//                     _initial,
//                     style: const TextStyle(
//                       fontSize: 56,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.white70,
//                     ),
//                   ),
//                 ),
//               ),
//
//               // --- soft glass overlay at bottom ---
//               Positioned(
//                 left: 12,
//                 right: 12,
//                 bottom: 12,
//                 child: _GlassPanel(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // name + online dot
//                       Row(
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         children: [
//                           Expanded(
//                             child: Text(
//                               user.username,
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 18.5,
//                                 fontWeight: FontWeight.w800,
//                                 letterSpacing: 0.2,
//                               ),
//                             ),
//                           ),
//                           if (online)
//                             Container(
//                               width: 10,
//                               height: 10,
//                               margin: const EdgeInsets.only(left: 6),
//                               decoration: const BoxDecoration(
//                                 color: Colors.greenAccent,
//                                 shape: BoxShape.circle,
//                               ),
//                             ),
//                         ],
//                       ),
//
//                       if (profession.isNotEmpty) ...[
//                         const SizedBox(height: 6),
//                         Row(
//                           children: [
//                             const Icon(Icons.work_outline,
//                                 size: 14, color: Colors.white70),
//                             const SizedBox(width: 6),
//                             Expanded(
//                               child: Text(
//                                 profession,
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: const TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 13.5,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//
//                       if (interests.isNotEmpty) ...[
//                         const SizedBox(height: 10),
//                         Wrap(
//                           spacing: 6,
//                           runSpacing: 6,
//                           children: [
//                             for (final tag in interests)
//                               _TagChip(text: tag),
//                             if ((user.interests?.length ?? 0) > interests.length)
//                               _TagChip(text: '+${(user.interests!.length - interests.length)}'),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//
//               // --- subtle corner highlight like mockup ---
//               Positioned(
//                 top: 10,
//                 right: 10,
//                 child: Container(
//                   width: 8,
//                   height: 8,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.25),
//                     shape: BoxShape.circle,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     )
//     // gentle float animation (kept from your original)
//         .animate(onPlay: (c) => c.repeat(reverse: true))
//         .moveY(begin: -4, end: 4, duration: 1200.ms, curve: Curves.easeInOut);
//
//     return card;
//   }
// }
//
// // ===== Small building blocks (internal, no API changes) =====
//
// class _GlassPanel extends StatelessWidget {
//   const _GlassPanel({required this.child});
//
//   final Widget child;
//
//   @override
//   Widget build(BuildContext context) {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(16),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.08),
//             border: Border.all(color: Colors.white.withOpacity(0.10)),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.25),
//                 blurRadius: 18,
//                 offset: const Offset(0, 6),
//               ),
//             ],
//           ),
//           child: child,
//         ),
//       ),
//     );
//   }
// }
//
// class _TagChip extends StatelessWidget {
//   const _TagChip({required this.text});
//   final String text;
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.10),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: Colors.white.withOpacity(0.12)),
//       ),
//       child: Text(
//         text,
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//         style: const TextStyle(
//           color: Colors.white,
//           fontSize: 12.5,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//     );
//   }
// }


import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../../models/user_model.dart';
import '../../astrology/widgets/compatibility_chip.dart';
import 'profile_quick_sheet.dart'; // same folder

class ProfileBubbleGridItem extends StatelessWidget {
  const ProfileBubbleGridItem({
    Key? key,
    required this.user,
    required this.onTap,
    this.currentUser,
  }) : super(key: key);

  final UserModel user;
  final VoidCallback onTap;
  final UserModel? currentUser;

  // --- helpers preserved for compatibility ---
  ImageProvider? _avatarImage() {
    final url = user.profileImage;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null; // initials fallback
  }

  String get _initial {
    final n = (user.username).trim();
    return n.isNotEmpty ? n[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final online = user.online == true;
    final profession = (user.profession ?? '').trim();
    final interests = (user.interests ?? const <String>[]).take(3).toList();

    // ✅ NEW: has voice flag
    final bool hasVoice =
    (user.voiceIntroUrl != null && user.voiceIntroUrl!.trim().isNotEmpty);

    final card = InkWell(
      onTap: onTap,
      onLongPress: () {
        // existing iOS-style bottom sheet (unchanged behavior)
        showCupertinoModalBottomSheet(
          context: context,
          barrierColor: Colors.black54,
          backgroundColor: Colors.transparent,
          builder: (_) => ProfileQuickSheet(
            currentUser: currentUser,
            user: user,
            onMessage: onTap,
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            // subtle outer gradient to blend with your purple theme
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x26211B3E), Color(0x1A7B2CBF)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Stack(
            children: [
              // --- background image or gradient ---
              Positioned.fill(
                child: _avatarImage() != null
                    ? Ink.image(
                  image: _avatarImage()!,
                  fit: BoxFit.cover,
                )
                    : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF3C256B),
                        Color(0xFF2A184A),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initial,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),

              // --- soft glass overlay at bottom ---
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // name + online dot
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              user.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (online)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      if (profession.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.work_outline,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                profession,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (interests.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in interests) _TagChip(text: tag),
                            if ((user.interests?.length ?? 0) > interests.length)
                              _TagChip(
                                  text:
                                  '+${(user.interests!.length - interests.length)}'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // --- subtle corner highlight like mockup ---
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Positioned(
                top: hasVoice ? 46 : 10,
                left: 10,
                child: CompatibilityChip(currentUser: currentUser, user: user),
              ),

              // ✅ NEW: VOICE badge (visible only if voice intro exists)
              if (hasVoice)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.graphic_eq, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'VOICE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Gentle float, skipped when the system asks for reduced motion.
    if (MediaQuery.of(context).disableAnimations) {
      return RepaintBoundary(child: card);
    }
    return RepaintBoundary(
      child: card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -4, end: 4, duration: 1200.ms, curve: Curves.easeInOut),
    );
  }
}

// ===== Small building blocks (internal, no API changes) =====

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
