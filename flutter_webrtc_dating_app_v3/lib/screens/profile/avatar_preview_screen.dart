// // lib/screens/profile/avatar_preview_screen.dart
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// import 'package:availchat/models/user_model.dart';
// import 'package:availchat/screens/questionnaire/post_signup_questions_screen.dart';
// import 'package:availchat/services/dicebear_avatar_service.dart';
//
// /// Safe cache-busting helper
// String cacheBustedUrl(String url, int? version) {
//   if (url.isEmpty) return url;
//   final v = version ?? 0;
//   return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
// }
//
// class AvatarPreviewScreen extends StatefulWidget {
//   final Map<String, dynamic> answers;
//
//   const AvatarPreviewScreen({
//     Key? key,
//     required this.answers,
//   }) : super(key: key);
//
//   @override
//   State<AvatarPreviewScreen> createState() => _AvatarPreviewScreenState();
// }
//
// class _AvatarPreviewScreenState extends State<AvatarPreviewScreen> {
//   bool _generating = false;
//   String? _error;
//   bool _autoTriggered = false;
//
//   Future<void> _generateAvatar() async {
//     if (_generating) return;
//
//     setState(() {
//       _generating = true;
//       _error = null;
//     });
//
//     try {
//       final uid = FirebaseAuth.instance.currentUser?.uid;
//       if (uid == null) throw Exception('User not authenticated');
//
//       debugPrint('🎨 AvatarPreviewScreen: Triggering DiceBear generation');
//       debugPrint('📥 Answers: ${widget.answers}');
//
//       // ✅ FIXED: Removed 'context: context' parameter
//       await DiceBearAvatarService.generateAndSaveAvatar(
//         answers: widget.answers,
//       );
//
//       debugPrint('✅ Avatar generation completed');
//     } catch (e) {
//       debugPrint('❌ Avatar generation error: $e');
//       _error = e.toString();
//     } finally {
//       if (mounted) {
//         setState(() {
//           _generating = false;
//         });
//       }
//     }
//   }
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     if (!_autoTriggered) {
//       _autoTriggered = true;
//       Future.microtask(() => _generateAvatar());
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//
//     return Scaffold(
//       backgroundColor: const Color(0xFF1A0E2E),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF2D1B4E),
//         title: const Text('Meet Your Avatar'),
//       ),
//       body: uid == null
//           ? _buildError('User not authenticated')
//           : StreamBuilder<DocumentSnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('users')
//             .doc(uid)
//             .snapshots(),
//         builder: (context, snap) {
//           if (snap.connectionState == ConnectionState.waiting) {
//             return _buildLoading();
//           }
//
//           if (snap.hasError) {
//             return _buildError('Failed to load profile: ${snap.error}');
//           }
//
//           if (!snap.hasData || !snap.data!.exists) {
//             return _buildError('Profile not found');
//           }
//
//           final data = snap.data!.data() as Map<String, dynamic>? ?? {};
//           final user = UserModel.fromMap({...data, 'uid': uid});
//
//           final avatarUrl = user.profileImage.isNotEmpty
//               ? cacheBustedUrl(user.profileImage, user.avatarVersion)
//               : null;
//
//           return Padding(
//             padding: const EdgeInsets.all(24.0),
//             child: Column(
//               children: [
//                 const SizedBox(height: 16),
//                 const Text(
//                   '🎉 Your unique avatar is ready!',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 Expanded(
//                   child: Center(
//                     child: Container(
//                       width: 240,
//                       height: 240,
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF2D1B4E),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: const Color(0xFF7B2CBF).withOpacity(0.4),
//                           width: 2,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.3),
//                             blurRadius: 20,
//                             offset: const Offset(0, 10),
//                           ),
//                         ],
//                       ),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(18),
//                         child: (avatarUrl != null)
//                             ? SizedBox
//                             .expand( // ✅ Yahin se magic – child ko 240x240 force karega
//                           child: Image.network(
//                             avatarUrl,
//                             fit: BoxFit.cover, // image poora box fill karegi
//                             errorBuilder: (_, __, ___) => _avatarPlaceholder(),
//                           ),
//                         )
//                             : SizedBox.expand(
//                           child: _avatarGenerating(
//                             generating: _generating,
//                             error: _error,
//                             onRetry: _generateAvatar,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 SizedBox(
//                   width: double.infinity,
//                   height: 56,
//                   child: ElevatedButton(
//                     onPressed: () {
//                       Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) =>
//                           const PostSignupQuestionsScreen(),
//                         ),
//                       );
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFF7B2CBF),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(28),
//                       ),
//                     ),
//                     child: const Text(
//                       'Continue',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 TextButton(
//                   onPressed: _generating ? null : _generateAvatar,
//                   child: _generating
//                       ? const SizedBox(
//                     width: 18,
//                     height: 18,
//                     child: CircularProgressIndicator(strokeWidth: 2),
//                   )
//                       : const Text(
//                     'Regenerate',
//                     style: TextStyle(color: Colors.white70),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildLoading() {
//     return const Center(
//       child: CircularProgressIndicator(color: Color(0xFF7B2CBF)),
//     );
//   }
//
//   Widget _buildError(String message) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
//             const SizedBox(height: 12),
//             Text(
//               message,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.white70),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _avatarPlaceholder() {
//     return const Center(
//       child: Icon(Icons.image_outlined, color: Colors.white24, size: 48),
//     );
//   }
//
//   Widget _avatarGenerating({
//     required bool generating,
//     required String? error,
//     required Future<void> Function() onRetry,
//   }) {
//     if (error != null) {
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.error_outline, color: Colors.redAccent),
//             const SizedBox(height: 8),
//             Text(
//               error,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.white70, fontSize: 12),
//             ),
//             const SizedBox(height: 12),
//             OutlinedButton(
//               onPressed: onRetry,
//               child: const Text('Try again'),
//             )
//           ],
//         ),
//       );
//     }
//
//     if (generating) {
//       return const Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             SizedBox(
//               width: 28,
//               height: 28,
//               child: CircularProgressIndicator(
//                   color: Colors.white, strokeWidth: 2),
//             ),
//             SizedBox(height: 8),
//             Text(
//               '🎨 Creating your unique avatar...',
//               style: TextStyle(color: Colors.white70),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       );
//     }
//
//     return _avatarPlaceholder();
//   }
// }



// lib/screens/profile/avatar_preview_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/questionnaire/post_signup_questions_screen.dart';
import 'package:availchat/services/dicebear_avatar_service.dart';

// Storage config + repos (same as ProfileEditScreen)
import 'package:availchat/core/config/storage_config.dart';
import 'package:availchat/services/storage/storage_repo.dart';
import 'package:availchat/services/storage/firebase_storage_repo.dart';
import 'package:availchat/services/storage/cloudinary_storage_repo.dart';

/// Safe cache-busting helper
String cacheBustedUrl(String url, int? version) {
  if (url.isEmpty) return url;
  final v = version ?? 0;
  return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
}

class AvatarPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> answers;

  const AvatarPreviewScreen({
    Key? key,
    required this.answers,
  }) : super(key: key);

  @override
  State<AvatarPreviewScreen> createState() => _AvatarPreviewScreenState();
}

class _AvatarPreviewScreenState extends State<AvatarPreviewScreen> {
  bool _generating = false; // avatar/ upload dono ke liye same flag use kar rahe
  String? _error;
  bool _autoTriggered = false;

  // ✅ Same pattern as ProfileEditScreen – storage toggle respect karta hai
  StorageRepo get _storage =>
      StorageConfig.kUseCloudinaryForMedia ? const CloudinaryStorageRepo() : FirebaseStorageRepo();

  /// ORIGINAL NAME: _generateAvatar
  /// Ye ab bhi **DiceBear avatar generate** karta hai (questionnaire based)
  Future<void> _generateAvatar() async {
    if (_generating) return;

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      debugPrint('🎨 AvatarPreviewScreen: Triggering DiceBear generation');
      debugPrint('📥 Answers: ${widget.answers}');

      await DiceBearAvatarService.generateAndSaveAvatar(
        answers: widget.answers,
      );

      debugPrint('✅ Avatar generation completed');
    } catch (e) {
      debugPrint('❌ Avatar generation error: $e');
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  /// NEW: User gallery se custom profile photo choose karega
  Future<void> _chooseProfilePhoto() async {
    if (_generating) return;

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        // user ne cancel kiya
        setState(() {
          _generating = false;
        });
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading profile photo...')),
        );
      }

      final url = await _storage.uploadImageFile(
        folder: 'profile_photos',
        file: File(picked.path),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'profileImage': url,
        'isCustomAvatar': true,
        'avatarVersion': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile photo updated'),
            backgroundColor: Colors.green,
          ),
        );
      }

      debugPrint('✅ Custom profile photo set from AvatarPreviewScreen');
    } catch (e) {
      debugPrint('❌ Profile photo selection error: $e');
      _error = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Screen open hote hi ek hi baar DiceBear avatar generate karega
    if (!_autoTriggered) {
      _autoTriggered = true;
      Future.microtask(() => _generateAvatar());
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D1B4E),
        title: const Text('Meet Your Avatar'),
      ),
      body: uid == null
          ? _buildError('User not authenticated')
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }

          if (snap.hasError) {
            return _buildError('Failed to load profile: ${snap.error}');
          }

          if (!snap.hasData || !snap.data!.exists) {
            return _buildError('Profile not found');
          }

          final data =
              snap.data!.data() as Map<String, dynamic>? ?? {};
          final user = UserModel.fromMap({...data, 'uid': uid});

          final avatarUrl = user.profileImage.isNotEmpty
              ? cacheBustedUrl(user.profileImage, user.avatarVersion)
              : null;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  '🎉 Your unique avatar is ready!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D1B4E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF7B2CBF)
                              .withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: (avatarUrl != null)
                            ? SizedBox.expand(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatarPlaceholder(),
                          ),
                        )
                            : SizedBox.expand(
                          child: _avatarGenerating(
                            generating: _generating,
                            error: _error,
                            onRetry: _generateAvatar,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const PostSignupQuestionsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CBF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  // ⬇️ Pehle yahan Regenerate tha, ab custom photo picker
                  onPressed: _generating ? null : _chooseProfilePhoto,
                  child: _generating
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Choose Profile Photo',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF7B2CBF)),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return const Center(
      child: Icon(
        Icons.person_outline_rounded,
        color: Colors.white24,
        size: 48,
      ),
    );
  }

  Widget _avatarGenerating({
    required bool generating,
    required String? error,
    required Future<void> Function() onRetry,
  }) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style:
              const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            )
          ],
        ),
      );
    }

    if (generating) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(height: 8),
            Text(
              '🎨 Creating your unique avatar...',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _avatarPlaceholder();
  }
}
