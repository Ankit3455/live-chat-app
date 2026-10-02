// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import '../../../core/constants/app_colors.dart';
// import '../../../models/user_model.dart';
// import 'profile_quick_sheet.dart';
//
// class ProfileCard extends StatefulWidget {
//   const ProfileCard({
//     Key? key,
//     required this.user,
//     required this.currentUser,
//     required this.onTap,
//   }) : super(key: key);
//
//   final UserModel user;
//   final UserModel? currentUser;
//   final VoidCallback onTap;
//
//   @override
//   State<ProfileCard> createState() => _ProfileCardState();
// }
//
// class _ProfileCardState extends State<ProfileCard>
//     with TickerProviderStateMixin {
//   late final AnimationController _floatCtrl;
//   late final Animation<double> _floatX;
//   late final Animation<double> _floatY;
//
//   late final AnimationController _tapCtrl;
//   late final Animation<double> _scale;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // gentle floating like Kotlin adapters
//     _floatCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 5200),
//     )..repeat(reverse: true);
//
//     _floatX = Tween<double>(begin: -4, end: 4)
//         .chain(CurveTween(curve: Curves.easeInOut))
//         .animate(_floatCtrl);
//     _floatY = Tween<double>(begin: -3, end: 3)
//         .chain(CurveTween(curve: Curves.easeInOut))
//         .animate(_floatCtrl);
//
//     // bounce on tap
//     _tapCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 160),
//       lowerBound: .94,
//       upperBound: 1.0,
//       value: 1.0,
//     );
//     _scale = _tapCtrl;
//   }
//
//   @override
//   void dispose() {
//     _floatCtrl.dispose();
//     _tapCtrl.dispose();
//     super.dispose();
//   }
//
//   String _initial() {
//     final name = widget.user.username.trim();
//     return name.isNotEmpty ? name[0].toUpperCase() : 'U';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final online = widget.user.online == true;
//
//     return GestureDetector(
//       onTapDown: (_) => _tapCtrl.reverse(),
//       onTapCancel: () => _tapCtrl.forward(),
//       onTapUp: (_) {
//         _tapCtrl.forward();
//         widget.onTap();
//       },
//       onLongPress: () {
//         showModalBottomSheet(
//           context: context,
//           backgroundColor: Colors.transparent,
//           isScrollControlled: true,
//           builder: (_) => ProfileQuickSheet(
//             currentUser: widget.currentUser,
//             user: widget.user,
//           ),
//         );
//       },
//       child: AnimatedBuilder(
//         animation: _floatCtrl,
//         builder: (_, child) {
//           return Transform.translate(
//             offset: Offset(_floatX.value, _floatY.value),
//             child: child,
//           );
//         },
//         child: ScaleTransition(
//           scale: _scale,
//           child: Container(
//             // fixed mainAxisExtent in grid will control height
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(20),
//               gradient: const LinearGradient(
//                 colors: [Color(0xFF7B2CBF), Color(0xFF9C4DFF)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.25),
//                   blurRadius: 16,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Stack(
//               children: [
//                 // glossy overlay
//                 Positioned.fill(
//                   child: IgnorePointer(
//                     child: Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(20),
//                         gradient: LinearGradient(
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                           colors: [
//                             Colors.white.withOpacity(.10),
//                             Colors.white.withOpacity(.02),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 // content
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // avatar area
//                     Expanded(
//                       child: Stack(
//                         children: [
//                           Positioned.fill(
//                             child: Center(
//                               child: Text(
//                                 _initial(),
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 72,
//                                   fontWeight: FontWeight.w800,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           if (online)
//                             Positioned(
//                               right: 10,
//                               top: 10,
//                               child: Container(
//                                 width: 16,
//                                 height: 16,
//                                 decoration: const BoxDecoration(
//                                   color: Colors.white,
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: Container(
//                                   margin: const EdgeInsets.all(2),
//                                   decoration: const BoxDecoration(
//                                     color: Colors.greenAccent,
//                                     shape: BoxShape.circle,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//
//                     // dark label strip
//                     Container(
//                       padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF150B25).withOpacity(.70),
//                         borderRadius: const BorderRadius.vertical(
//                           bottom: Radius.circular(20),
//                         ),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             widget.user.username,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 16,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Row(
//                             children: [
//                               const Icon(Icons.work_outline,
//                                   size: 14, color: Colors.white70),
//                               const SizedBox(width: 6),
//                               Expanded(
//                                 child: Text(
//                                   widget.user.profession?.isNotEmpty == true
//                                       ? widget.user.profession!
//                                       : '—',
//                                   maxLines: 1,
//                                   overflow: TextOverflow.ellipsis,
//                                   style: const TextStyle(
//                                     color: Colors.white70,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           _buildInterestsRow(widget.user.interests),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildInterestsRow(List<String> interests) {
//     final chips = interests.take(2).toList();
//     if (chips.isEmpty) {
//       return const SizedBox.shrink();
//     }
//     return Wrap(
//       spacing: 8,
//       runSpacing: 6,
//       children: chips
//           .map(
//             (e) => Container(
//           padding:
//           const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(.10),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(
//                 color: Colors.white.withOpacity(.15), width: 1),
//           ),
//           child: Text(
//             e,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//       )
//           .toList(),
//     );
//   }
// }


import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';
import 'profile_quick_sheet.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({
    Key? key,
    required this.user,
    required this.currentUser,
    required this.onTap,
  }) : super(key: key);

  final UserModel user;
  final UserModel? currentUser;
  final VoidCallback onTap;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatX;
  late final Animation<double> _floatY;

  late final AnimationController _tapCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);

    _floatX = Tween<double>(begin: -4, end: 4)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_floatCtrl);
    _floatY = Tween<double>(begin: -3, end: 3)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_floatCtrl);

    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: .94,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _tapCtrl;
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  String _initial() {
    final name = widget.user.username.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String? _avatarUrl() {
    final url = widget.user.profileImage;
    if (url.isEmpty) return null;
    final v = widget.user.avatarVersion ?? 0;
    return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
  }

  Widget _avatarBox() {
    final url = _avatarUrl();

    final fallback = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFF9C4DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        _initial(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 72,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (url == null) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.user.online == true;

    return GestureDetector(
      onTapDown: (_) => _tapCtrl.reverse(),
      onTapCancel: () => _tapCtrl.forward(),
      onTapUp: (_) {
        _tapCtrl.forward();
        widget.onTap();
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => ProfileQuickSheet(
            currentUser: widget.currentUser,
            user: widget.user,
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _floatCtrl,
        builder: (_, child) {
          return Transform.translate(
            offset: Offset(_floatX.value, _floatY.value),
            child: child,
          );
        },
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF7B2CBF), Color(0xFF9C4DFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.25),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // glossy overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(.10),
                            Colors.white.withOpacity(.02),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // avatar area (image or initials)
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: _avatarBox()),
                          if (online)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
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
                    ),

                    // dark label strip
                    Container(
                      padding:
                      const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF150B25).withOpacity(.70),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.work_outline,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.user.profession?.isNotEmpty == true
                                      ? widget.user.profession!
                                      : '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInterestsRow(widget.user.interests),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterestsRow(List<String> interests) {
    final chips = interests.take(2).toList();
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips
          .map(
            (e) => Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(.15), width: 1),
          ),
          child: Text(
            e,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      )
          .toList(),
    );
  }
}
