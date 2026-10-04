// lib/screens/profile/avatar_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/questionnaire/post_signup_questions_screen.dart';
import 'package:availchat/services/dicebear_avatar_service.dart';
import 'package:availchat/services/profile_photo_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';

/// Safe cache-busting helper
String cacheBustedUrl(String url, int? version) {
  if (url.isEmpty) return url;
  final v = version ?? 0;
  return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
}

class AvatarPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> answers;

  const AvatarPreviewScreen({Key? key, required this.answers})
    : super(key: key);

  @override
  State<AvatarPreviewScreen> createState() => _AvatarPreviewScreenState();
}

class _AvatarPreviewScreenState extends State<AvatarPreviewScreen> {
  static const _generateError =
      'We couldn\'t create your avatar. Check your connection and try again.';

  bool _generating = false;
  bool _uploading = false;
  bool _continuing = false;
  String? _error;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  bool get _busy => _generating || _uploading;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateAvatar());
  }

  /// DiceBear avatar from the questionnaire answers.
  Future<void> _generateAvatar() async {
    if (_busy || !mounted) return;

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        throw StateError('Not signed in');
      }
      await DiceBearAvatarService.generateAndSaveAvatar(
        answers: widget.answers,
      );
    } catch (e) {
      debugPrint('Avatar generation failed: $e');
      _error = _generateError;
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _chooseProfilePhoto() async {
    if (_busy) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final url = await ProfilePhotoService.pickAndUploadPhoto();
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ProfilePhotoException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      debugPrint('Profile photo upload failed: $e');
      _showSnack('Could not upload the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _continue() {
    if (_busy || _continuing) return;
    _continuing = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PostSignupQuestionsScreen()),
    );
  }

  String _title({required bool hasImage}) {
    if (_generating) return 'Creating your unique avatar...';
    if (_uploading) return 'Uploading your photo...';
    if (hasImage) return '🎉 Your unique avatar is ready!';
    if (_error != null) return 'Avatar not created yet';
    return 'Meet your avatar';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        automaticallyImplyLeading: false,
        title: const Text('Meet Your Avatar'),
      ),
      body: uid == null || _userStream == null
          ? _buildError('Please sign in again.')
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return _buildLoading();
                }

                if (snap.hasError) {
                  debugPrint(
                    'Avatar preview profile stream error: ${snap.error}',
                  );
                  return _buildError(
                    'Could not load your profile. Check your connection.',
                  );
                }

                final data = snap.data?.data() ?? <String, dynamic>{};
                final user = UserModel.fromMap({...data, 'uid': uid});

                final avatarUrl = user.profileImage.isNotEmpty
                    ? cacheBustedUrl(user.profileImage, user.avatarVersion)
                    : null;
                final hasImage = avatarUrl != null;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final side = (constraints.maxWidth - 48)
                        .clamp(120.0, 240.0)
                        .toDouble();
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 48)
                              .clamp(0.0, double.infinity)
                              .toDouble(),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                const SizedBox(height: 16),
                                Text(
                                  _title(hasImage: hasImage),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  width: side,
                                  height: side,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF7B2CBF,
                                      ).withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: SizedBox.expand(
                                      child: hasImage && !_generating
                                          ? CachedNetworkImage(
                                              imageUrl: avatarUrl,
                                              memCacheWidth: 900,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  _avatarPlaceholder(),
                                            )
                                          : _avatarGenerating(
                                              generating: _generating,
                                              error: _error,
                                              onRetry: _generateAvatar,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _busy ? null : _continue,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brandPurple,
                                      disabledBackgroundColor: const Color(
                                        0xFF2D1B4E,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                    child: Text(
                                      _busy ? 'Please wait...' : 'Continue',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _busy ? null : _chooseProfilePhoto,
                                  child: _uploading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Choose Profile Photo',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.brandPurple),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
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
                color: Colors.white,
                strokeWidth: 2,
              ),
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
