// lib/screens/profile/avatar_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/questionnaire/post_signup_questions_screen.dart';
import 'package:availchat/services/avatar_traits.dart';
import 'package:availchat/services/dicebear_avatar_service.dart';
import 'package:availchat/services/profile_photo_service.dart';
import 'package:availchat/widgets/app_states.dart';
import 'package:availchat/widgets/avatar_story.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';

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
      _userStream =
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
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
        throw StateError('Not logged in');
      }
      await DiceBearAvatarService.generateAndSaveAvatar(
        answers: widget.answers,
      );
    } catch (e) {
      debugPrint('Avatar generation failed: $e');
      Haptics.error();
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
        Haptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ProfilePhotoException catch (e) {
      Haptics.error();
      _showSnack(e.message);
    } catch (e) {
      debugPrint('Profile photo upload failed: $e');
      Haptics.error();
      _showSnack(
        'We couldn\'t upload your photo. Check your connection and try again.',
      );
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

  String _title({required bool hasImage, required bool isPhoto}) {
    if (_generating) return 'Creating your avatar…';
    if (_uploading) return 'Uploading your photo…';
    if (hasImage) return isPhoto ? 'Looking good ✨' : 'This is you ✨';
    if (_error != null) return 'Avatar not created yet';
    return 'Meet your avatar';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: uid == null || _userStream == null
            ? _buildError('You\'re logged out. Please log in again.')
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
                    return _buildError('Check your connection and try again.');
                  }

                  final data = snap.data?.data() ?? <String, dynamic>{};
                  final user = UserModel.fromMap({...data, 'uid': uid});

                  final avatarUrl = user.profileImage.isNotEmpty
                      ? cacheBustedUrl(user.profileImage, user.avatarVersion)
                      : null;
                  final hasImage = avatarUrl != null;
                  final isPhoto = data['isCustomAvatar'] == true;
                  final avatarProps = data['avatarProperties'] is Map
                      ? Map<String, dynamic>.from(
                          data['avatarProperties'] as Map,
                        )
                      : const <String, dynamic>{};
                  final ready = hasImage && !_generating && !_uploading;
                  final String? readyUrl = ready ? avatarUrl : null;
                  final traits = ready && !isPhoto
                      ? AvatarTraits.explain(avatarProps)
                      : const <AvatarTrait>[];
                  final unique =
                      ready && !isPhoto && avatarProps['avatarUnique'] == true;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                16,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    isPhoto ? 'YOUR PHOTO' : 'YOUR AVATAR',
                                    style: const TextStyle(
                                      color: AppColors.brandPink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Semantics(
                                    header: true,
                                    liveRegion: true,
                                    child: Text(
                                      _title(
                                        hasImage: hasImage,
                                        isPhoto: isPhoto,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _AvatarCircle(
                                    child: AnimatedSwitcher(
                                      duration: MediaQuery.disableAnimationsOf(
                                        context,
                                      )
                                          ? Duration.zero
                                          : const Duration(milliseconds: 250),
                                      child: readyUrl != null
                                          ? Semantics(
                                              key: ValueKey(readyUrl),
                                              image: true,
                                              label: isPhoto
                                                  ? 'Your profile photo'
                                                  : 'Your avatar',
                                              child: CachedNetworkImage(
                                                imageUrl: readyUrl,
                                                memCacheWidth: 600,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _avatarPlaceholder(),
                                              ),
                                            )
                                          : _avatarGenerating(
                                              generating:
                                                  _generating || _uploading,
                                              error: _error,
                                              onRetry: _generateAvatar,
                                            ),
                                    ),
                                  ),
                                  if (unique) ...[
                                    const SizedBox(height: 14),
                                    const AvatarUniqueBadge(),
                                  ],
                                  if (traits.isNotEmpty) ...[
                                    const SizedBox(height: 18),
                                    AvatarWhyCard(traits: traits),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _busy ? null : _continue,
                                    icon: _busy
                                        ? const SizedBox.shrink()
                                        : const Icon(Icons.check, size: 20),
                                    label: Text(
                                      _busy
                                          ? 'Please wait…'
                                          : isPhoto
                                              ? 'Continue'
                                              : 'Use this avatar',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      backgroundColor: AppColors.brandPurple,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          AppColors.surfaceCard,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _busy ? null : _chooseProfilePhoto,
                                    icon: const Icon(
                                      Icons.photo_camera_outlined,
                                      size: 20,
                                    ),
                                    label: Text(
                                      isPhoto
                                          ? 'Choose a different photo'
                                          : 'Upload a photo instead',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: AppColors.lavender.withOpacity(
                                          0.35,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.brandPurple),
    );
  }

  Widget _buildError(String message) {
    return AppEmptyState(
      icon: Icons.error_outline,
      illustration: AppIllustrationKind.error,
      title: 'We couldn\'t load your avatar',
      message: message,
    );
  }

  Widget _avatarPlaceholder() {
    return const Center(
      child: Icon(
        Icons.person_outline_rounded,
        color: AppColors.textSubtle,
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
        key: const ValueKey('avatar-error'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
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
        key: ValueKey('avatar-generating'),
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
              'Creating your avatar…',
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _avatarPlaceholder();
  }
}

class _AvatarCircle extends StatelessWidget {
  final Widget child;

  const _AvatarCircle({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      height: 172,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.brandPurpleMid, AppColors.brandPink],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPink.withOpacity(0.35),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipOval(
        child: ColoredBox(color: AppColors.surfaceCard, child: child),
      ),
    );
  }
}
