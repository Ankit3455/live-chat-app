import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/profile/profile_details_screen.dart';
import 'package:availchat/screens/profile/profile_edit_screen.dart';
import 'package:availchat/screens/profile/voice_intro_screen.dart';
import 'package:availchat/screens/astrology/astrology_questionnaire_screen.dart';
import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:availchat/screens/questionnaire/profile_completion_screen.dart';
import 'package:availchat/screens/settings/blocked_users_screen.dart';
import 'package:availchat/screens/settings/discovery_settings_screen.dart';
import 'package:availchat/screens/settings/settings_screen.dart';
import 'package:availchat/screens/profile/widgets/astrology_compatibility_card.dart';
import 'package:availchat/screens/profile/widgets/interests_grid.dart';
import 'package:availchat/screens/profile/widgets/profile_completion_card.dart';
import 'package:availchat/screens/profile/widgets/profile_header.dart';
import 'package:availchat/screens/profile/widgets/profile_section.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import 'package:availchat/models/question_model.dart';
import 'package:availchat/services/profile_photo_service.dart';
import 'package:availchat/widgets/app_states.dart';
import 'package:availchat/widgets/custom_button.dart';
import 'package:availchat/widgets/user_avatar.dart';
import 'package:availchat/widgets/avatar_story.dart';
import '../../core/constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _loadError;
  bool _avatarBusy = false;
  int _completionPercentage = 0;
  // Raw profile doc; drives the completion checklist.
  Map<String, dynamic> _profileData = const {};

  @override
  void initState() {
    super.initState();
    // Deferred so the signed-out path never calls setState during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  Future<void> _loadUserData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _loadError = 'You are signed out. Please sign in again.';
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!mounted) return;

      if (!doc.exists) {
        setState(() {
          _currentUser = null;
          _loadError = 'We could not find your profile.';
        });
        return;
      }

      setState(() {
        _currentUser = UserModel.fromFirestore(doc);
        _profileData = doc.data() ?? const {};
        _loadError = null;
      });

      final percentage = await ProfileCompletionManager()
          .getCompletionPercentage();
      if (!mounted) return;
      setState(() => _completionPercentage = percentage);
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (!mounted) return;
      if (_currentUser == null) {
        setState(() => _loadError = 'Please check your connection.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh your profile.')),
        );
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;
    // Keep the current profile on screen during a refresh; only show the
    // full-screen spinner when there is nothing to show yet.
    if (_currentUser == null) setState(() => _isLoading = true);
    await _loadUserData();
  }

  Future<void> _runAvatarAction(
    Future<Object?> Function() action, {
    required String successMessage,
  }) async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);
    try {
      final result = await action();
      if (!mounted) return;
      // null means the user cancelled (e.g. closed the photo picker).
      if (result == null) return;
      await _loadUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      final message = e is ProfilePhotoException
          ? e.message
          : 'Could not update your photo. Please try again.';
      debugPrint('Avatar action failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  /// "Why you look like this" for the generated avatar in use.
  void _showAvatarStorySheet() {
    final user = _currentUser;
    if (user == null || _avatarBusy) return;
    final traits = avatarTraitsFor(user);
    if (traits.isEmpty) return;
    final unique = user.avatarProperties?['avatarUnique'] == true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        void choose(Future<Object?> Function() action, String message) {
          Navigator.pop(sheetContext);
          _runAvatarAction(action, successMessage: message);
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, controller) => SafeArea(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lavender.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: UserAvatar(user: user, size: 96, borderRadius: 48),
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: const Text(
                    'Made from your answers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your habits, interests and zodiac sign shaped this face.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.lavender, fontSize: 14),
                ),
                if (unique) ...[
                  const SizedBox(height: 12),
                  const Center(child: AvatarUniqueBadge()),
                ],
                const SizedBox(height: 16),
                AvatarWhyCard(traits: traits),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => choose(
                      ProfilePhotoService.regenerateAvatar,
                      'New avatar created',
                    ),
                    icon: const Icon(Icons.autorenew, size: 20),
                    label: const Text(
                      'Generate a new one',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.brandPurple,
                      foregroundColor: Colors.white,
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
                    onPressed: () => choose(
                      ProfilePhotoService.pickAndUploadPhoto,
                      'Profile photo updated',
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text(
                      'Upload a photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: AppColors.lavender.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A new one still follows your answers and stays unique to you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangeAvatarSheet() {
    final user = _currentUser;
    if (user == null || _avatarBusy) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        void choose(Future<Object?> Function() action, String message) {
          Navigator.pop(sheetContext);
          _runAvatarAction(action, successMessage: message);
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: user, size: 88, borderRadius: 44),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    'Change photo or avatar',
                    style: GoogleFonts.montserrat(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.brandPurpleLight,
                  ),
                  title: const Text(
                    'Upload a photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Choose from your gallery',
                    style: TextStyle(color: AppColors.lavender),
                  ),
                  onTap: () => choose(
                    ProfilePhotoService.pickAndUploadPhoto,
                    'Profile photo updated',
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.face_outlined,
                    color: AppColors.brandPurpleLight,
                  ),
                  title: const Text(
                    'Use my avatar',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Switch back to your generated avatar',
                    style: TextStyle(color: AppColors.lavender),
                  ),
                  onTap: () => choose(
                    ProfilePhotoService.resetToAvatar,
                    'Avatar restored',
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.autorenew,
                    color: AppColors.pinkLight,
                  ),
                  title: const Text(
                    'Generate a new avatar',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Based on your profile answers',
                    style: TextStyle(color: AppColors.lavender),
                  ),
                  onTap: () => choose(
                    ProfilePhotoService.regenerateAvatar,
                    'New avatar created',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Navigation ----------

  Future<void> _openEdit() async {
    final user = _currentUser;
    if (user == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditScreen(user: user)),
    );
    if (result == true && mounted) await _refreshProfile();
  }

  void _openPreview() {
    final user = _currentUser;
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileDetailsScreen(user: user)),
    );
  }

  Future<void> _openVoiceIntro() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceIntroScreen()),
    );
    if (saved == true && mounted) await _refreshProfile();
  }

  Future<void> _openAstrology() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyQuestionnaireScreen()),
    );
    if (mounted) await _refreshProfile();
  }

  Future<void> _openCompletion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
    );
    if (mounted) await _refreshProfile();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openDiscoverySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiscoverySettingsScreen()),
    );
  }

  void _openBlockedUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
    );
  }

  // ---------- Completion checklist ----------

  static bool _answered(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    if (v is Map) return v.isNotEmpty;
    return true;
  }

  bool _allAnswered(Iterable<String> fields) =>
      fields.every((f) => _answered(_profileData[f]));

  // Mirrors ProfileCompletionManager: flag set or half the questions answered.
  bool _sectionDone(String flag, List<Question> questions) {
    if (_profileData[flag] == true) return true;
    final fields = questions.map((q) => q.fieldName).where((f) => f.isNotEmpty);
    final answered = fields.where((f) => _answered(_profileData[f])).length;
    return answered >= (fields.length * 0.5).ceil();
  }

  List<ProfileTodo> _todos(UserModel user) {
    final basics = QuestionnaireHelper.getMandatoryQuestions()
        .map((q) => q.fieldName)
        .where((f) => f.isNotEmpty);
    final astrologyDone =
        _answered(_profileData['preferredSigns']) ||
        _profileData['believesInAstrology'] != null;
    return [
      ProfileTodo(
        label: 'Basic profile',
        done: _allAnswered(const [
          'bio',
          'profession',
          'location',
          'interests',
        ]),
        actionLabel: 'Edit',
        onTap: _openEdit,
      ),
      ProfileTodo(
        label: 'Record a voice intro',
        done: (user.voiceIntroUrl ?? '').trim().isNotEmpty,
        actionLabel: 'Add',
        onTap: _openVoiceIntro,
      ),
      ProfileTodo(
        label: 'Complete astrology profile',
        done: astrologyDone,
        actionLabel: 'Start',
        onTap: _openAstrology,
      ),
      ProfileTodo(
        label: 'Height, education & body type',
        done: _allAnswered(basics),
        actionLabel: 'Add',
        onTap: _openEdit,
      ),
      ProfileTodo(
        label: 'Lifestyle & personality',
        done:
            _sectionDone(
              'lifestyleCompleted',
              QuestionnaireHelper.getLifestyleQuestions(),
            ) &&
            _sectionDone(
              'personalityCompleted',
              QuestionnaireHelper.getPersonalityQuestions(),
            ),
        actionLabel: 'Add',
        onTap: _openCompletion,
      ),
    ];
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    // Centre a 560dp column on tablets.
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 600 ? (width - 560) / 2 : 20.0;
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            )
          : user == null
          ? SafeArea(
              child: AppEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load your profile',
                message: _loadError ?? 'Please try again.',
                actionLabel: 'Retry',
                onAction: _refreshProfile,
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              color: AppColors.brandPurple,
              backgroundColor: AppColors.surfaceCard,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: AppColors.backgroundDeep,
                    surfaceTintColor: Colors.transparent,
                    centerTitle: false,
                    titleSpacing: 20,
                    title: Semantics(
                      header: true,
                      child: Text(
                        'Profile',
                        style: GoogleFonts.montserrat(
                          color: AppColors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.white,
                        ),
                        tooltip: 'Settings',
                        onPressed: _openSettings,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(_content(user)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _content(UserModel user) {
    final todos = _todos(user);
    final showCompletion =
        _completionPercentage < 100 || todos.any((t) => !t.done);
    final bio = (user.bio ?? '').trim();

    return [
      ProfileHeader(
        user: user,
        busy: _avatarBusy,
        onChangePhoto: _showChangeAvatarSheet,
        onAvatarStoryTap: avatarTraitsFor(user).isEmpty
            ? null
            : _showAvatarStorySheet,
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: CustomButton(
              text: 'Edit profile',
              type: ButtonType.outline,
              leftIcon: Icons.edit_outlined,
              onPressed: _openEdit,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CustomButton(
              text: 'Preview',
              type: ButtonType.outline,
              leftIcon: Icons.visibility_outlined,
              onPressed: _openPreview,
            ),
          ),
        ],
      ),
      if (showCompletion) ...[
        const SizedBox(height: 20),
        ProfileCompletionCard(percentage: _completionPercentage, items: todos),
      ],
      ProfileSectionTitle(
        title: 'About me',
        actionLabel: 'Edit',
        actionTooltip: 'Edit about me',
        onAction: _openEdit,
      ),
      Text(
        bio.isEmpty ? 'Add a few lines so people get to know you.' : bio,
        style: TextStyle(
          color: bio.isEmpty ? AppColors.textSubtle : AppColors.lavender,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      ProfileSectionTitle(
        title: 'Cosmic profile',
        actionLabel: 'Edit',
        actionTooltip: 'Edit astrology profile',
        onAction: _openAstrology,
      ),
      AstrologyCompatibilityCard(user: user, onTap: _openAstrology),
      ProfileSectionTitle(
        title: 'Interests',
        actionLabel: 'Edit',
        actionTooltip: 'Edit interests',
        onAction: _openEdit,
      ),
      if (user.interests.isNotEmpty)
        InterestsGrid(interests: user.interests)
      else
        const Text(
          'Add interests to find people who share them.',
          style: TextStyle(color: AppColors.textSubtle, fontSize: 15),
        ),
      const ProfileSectionTitle(title: 'More'),
      ProfileMenuCard(
        items: [
          ProfileMenuItem(
            icon: Icons.explore_outlined,
            title: 'Discovery settings',
            onTap: _openDiscoverySettings,
          ),
          ProfileMenuItem(
            icon: Icons.shield_outlined,
            title: 'Privacy & safety',
            onTap: _openBlockedUsers,
          ),
          ProfileMenuItem(
            icon: Icons.help_outline,
            title: 'Help & app tour',
            onTap: _openSettings,
          ),
        ],
      ),
    ];
  }
}
