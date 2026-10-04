// lib/screens/profile/profile_edit_screen.dart
//
// Text fields, basics, interests and voice intro. Photo/avatar actions live
// in My Profile's Change Avatar sheet (ProfilePhotoService).
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:availchat/models/question_model.dart';
import 'package:availchat/models/question_type.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/profile/voice_intro_screen.dart';
import 'package:availchat/screens/profile/widgets/interests_grid.dart';
import 'package:availchat/screens/profile/widgets/voice_intro_card.dart';
import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:availchat/services/location_service.dart';
import 'package:availchat/services/voice_intro_service.dart';
import 'package:availchat/widgets/custom_button.dart';
import 'package:availchat/widgets/user_avatar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserModel user;

  const ProfileEditScreen({super.key, required this.user});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  // Same limits as the signup questionnaire.
  static const int _nameMax = 30;
  static const int _bioMax = 500;

  // (label, Firestore field) for the Basics group.
  static const List<(String, String)> _basics = [
    ('Height', 'height'),
    ('Education', 'education'),
    ('Body type', 'bodyType'),
    ('Relationship status', 'relationshipStatus'),
    ('Looking for', 'hereFor'),
  ];

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _professionController;
  late TextEditingController _locationController;

  /// Last saved/loaded profile; the baseline for "changed".
  late UserModel _user;

  /// Basics/interests picked here but not saved yet.
  final Map<String, Object> _pending = {};

  bool _isSaving = false;
  bool _saved = false;
  Stream<DocumentSnapshot>? _voiceDocStream;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _usernameController = TextEditingController(text: _user.username);
    _bioController = TextEditingController(text: _user.bio ?? '');
    _professionController = TextEditingController(text: _user.profession ?? '');
    _locationController = TextEditingController(text: _user.location ?? '');
    for (final c in _controllers) {
      c.addListener(_onTextChanged);
    }
  }

  List<TextEditingController> get _controllers => [
        _usernameController,
        _bioController,
        _professionController,
        _locationController,
      ];

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasChanges =>
      _pending.isNotEmpty ||
      _usernameController.text.trim() != _user.username.trim() ||
      _bioController.text.trim() != (_user.bio ?? '').trim() ||
      _professionController.text.trim() != (_user.profession ?? '').trim() ||
      _locationController.text.trim() != (_user.location ?? '').trim();

  Future<void> _saveChanges() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      Haptics.error();
      return;
    }
    final uid = widget.user.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profession': _professionController.text.trim(),
        'location': _locationController.text.trim(),
        ..._pending,
      });

      // City changed: re-geocode so distance follows the new city (DEST-081).
      final newCity = _locationController.text.trim();
      final cityFound = newCity.isEmpty ||
          newCity == (_user.location ?? '').trim() ||
          await LocationService.instance.updateFromCity(newCity);

      if (!mounted) return;
      Haptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cityFound
                ? 'Profile updated'
                : 'Profile updated. We couldn\'t find that city, so distance may be off.',
          ),
        ),
      );
      // Brief success state on the button before going back.
      setState(() {
        _isSaving = false;
        _saved = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Profile save failed: $e');
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We couldn\'t save your changes. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Reloads the profile and puts the latest values into the fields.
  Future<void> _refresh() async {
    final uid = widget.user.uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We couldn\'t find your profile. Pull down to try again.',
            ),
          ),
        );
        return;
      }
      final fresh = UserModel.fromFirestore(doc);
      setState(() {
        _user = fresh;
        _pending.clear();
        _usernameController.text = fresh.username;
        _bioController.text = fresh.bio ?? '';
        _professionController.text = fresh.profession ?? '';
        _locationController.text = fresh.location ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Profile refresh failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We couldn\'t refresh your profile. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  // ---------- Basics / interests ----------

  Object? _savedValue(String field) {
    switch (field) {
      case 'height':
        return _user.height;
      case 'education':
        return _user.education;
      case 'bodyType':
        return _user.bodyType;
      case 'relationshipStatus':
        return _user.relationshipStatus;
      case 'hereFor':
        return _user.hereFor;
      case 'interests':
        return _user.interests;
    }
    return null;
  }

  Object? _value(String field) => _pending[field] ?? _savedValue(field);

  static String? _display(Object? v) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v is List && v.isNotEmpty) return v.join(', ');
    return null;
  }

  List<String> _listValue(String field) {
    final v = _value(field);
    return v is List ? v.map((e) => e.toString()).toList() : const [];
  }

  Future<void> _editField(String label, String field) async {
    final question = QuestionnaireHelper.getQuestionByFieldName(field);
    if (question == null) return;
    final multi = question.inputType == QuestionType.multiChoice;
    final current = _value(field);
    final selected = <String>{
      if (current is String && current.isNotEmpty) current,
      if (current is List) ...current.map((e) => e.toString()),
    };
    // Keep stored answers that are no longer in the option list.
    final options = [
      ...question.options,
      ...selected.where((s) => !question.options.contains(s)),
    ];

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OptionSheet(
        title: label,
        question: question,
        options: options,
        initial: selected,
        multi: multi,
      ),
    );
    if (result == null || !mounted) return;

    final Object next = multi
        ? options.where(result.contains).toList()
        : (result.isEmpty ? '' : result.first);
    final saved = _savedValue(field);
    setState(() {
      if (_sameValue(next, saved)) {
        _pending.remove(field);
      } else {
        _pending[field] = next;
      }
    });
  }

  static bool _sameValue(Object a, Object? b) {
    if (a is List) {
      final other = b is List ? b.map((e) => e.toString()).toList() : const [];
      return a.length == other.length &&
          a.toSet().containsAll(other) &&
          other.toSet().containsAll(a);
    }
    return a == (b ?? '');
  }

  // ---------- Voice intro ----------

  Future<void> _recordVoice() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceIntroScreen()),
    );
  }

  Future<void> _deleteVoice() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await VoiceIntroService.deleteVoice();
      Haptics.success();
      messenger.showSnackBar(
        const SnackBar(content: Text('Voice intro removed')),
      );
    } catch (e) {
      debugPrint('Voice delete failed: $e');
      Haptics.error();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'We couldn\'t remove your voice intro. Please try again.',
          ),
        ),
      );
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final changed = _hasChanges;
    // Centre a 560dp column on tablets.
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 600 ? (width - 560) / 2 : 20.0;
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Edit profile'),
        centerTitle: true,
        backgroundColor: AppColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: _stickySave(changed),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.brandPurple,
        backgroundColor: AppColors.surfaceCard,
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
            children: [
              _photoPreview(),
              const SizedBox(height: 16),
              _field(
                label: 'Name',
                controller: _usernameController,
                maxLength: _nameMax,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              _field(
                label: 'Bio',
                controller: _bioController,
                maxLength: _bioMax,
                maxLines: 5,
                hint: 'A few lines about you',
              ),
              const SizedBox(height: 16),
              _field(
                label: 'Profession',
                controller: _professionController,
                icon: Icons.work_outline,
              ),
              const SizedBox(height: 16),
              _field(
                label: 'City',
                controller: _locationController,
                icon: Icons.location_on_outlined,
              ),
              _groupLabel('Basics'),
              _group([
                for (final (label, field) in _basics) _basicRow(label, field),
              ]),
              _groupHeader(
                'Interests',
                onEdit: () => _editField('Interests', 'interests'),
              ),
              _interests(),
              _groupLabel('Voice intro'),
              _liveVoiceSection(widget.user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.backgroundDeep,
              ),
              child: Semantics(
                image: true,
                label: 'Your current photo',
                excludeSemantics: true,
                child: UserAvatar(user: _user, size: 76, borderRadius: 38),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile photo',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'This is what people see first.',
                  style: TextStyle(color: AppColors.lavender, fontSize: 13),
                ),
                // Photo actions live on My Profile (product decision).
                Tooltip(
                  message: 'Go back to My Profile to change your photo',
                  child: TextButton.icon(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('Change on My Profile'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandPurpleLight,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    int maxLines = 1,
    int? maxLength,
    String? hint,
    String? Function(String?)? validator,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.lavender,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 4 : 1,
          maxLength: maxLength,
          textCapitalization: maxLines > 1
              ? TextCapitalization.sentences
              : TextCapitalization.words,
          style: const TextStyle(color: AppColors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textSubtle),
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 20, color: AppColors.textSubtle),
            counterStyle: const TextStyle(
              color: AppColors.textSubtle,
              fontSize: 12,
            ),
            filled: true,
            fillColor: AppColors.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: border(AppColors.border),
            enabledBorder: border(AppColors.border),
            focusedBorder: border(AppColors.brandPurpleMid, 2),
            errorBorder: border(AppColors.error, 2),
            focusedErrorBorder: border(AppColors.error, 2),
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSubtle,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _groupHeader(String text, {required VoidCallback onEdit}) {
    return Row(
      children: [
        Expanded(child: _groupLabel(text)),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Tooltip(
            message: 'Edit ${text.toLowerCase()}',
            child: TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPurpleLight,
                minimumSize: const Size(48, 48),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _group(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  color: AppColors.border,
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _basicRow(String label, String field) {
    final value = _display(_value(field));
    final editable = QuestionnaireHelper.getQuestionByFieldName(field) != null;
    return Semantics(
      button: editable,
      label: '$label, ${value ?? 'not added'}',
      excludeSemantics: true,
      onTap: editable ? () => _editField(label, field) : null,
      child: InkWell(
        onTap: editable ? () => _editField(label, field) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value ?? 'Add',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value == null
                          ? AppColors.brandPurpleLight
                          : AppColors.lavender,
                      fontSize: 14,
                      fontWeight:
                          value == null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _interests() {
    final interests = _listValue('interests');
    if (interests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'No interests yet. Tap Edit to add some.',
          style: TextStyle(color: AppColors.textSubtle, fontSize: 14),
        ),
      );
    }
    return InterestsGrid(interests: interests);
  }

  Widget _liveVoiceSection(UserModel base) {
    final uid = base.uid;
    if (uid == null) return _voiceGroup(base);

    _voiceDocStream ??=
        FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: _voiceDocStream,
      builder: (context, snap) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: _voiceSnapshot(base, snap),
      ),
    );
  }

  Widget _voiceSnapshot(UserModel base, AsyncSnapshot<DocumentSnapshot> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Padding(
        key: ValueKey('voice-loading'),
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.brandPurpleLight,
            ),
          ),
        ),
      );
    }

    final doc = snap.data;
    if (snap.hasError || doc == null || !doc.exists) {
      return _voiceGroup(base);
    }

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final liveUser = UserModel.fromMap({...data, 'uid': doc.id}, uid: doc.id);

    final mergedForVoice = base.copyWith(
      voiceIntroUrl: liveUser.voiceIntroUrl,
      voiceIntroDurationSeconds: liveUser.voiceIntroDurationSeconds,
    );

    return _voiceGroup(mergedForVoice);
  }

  Widget _voiceGroup(UserModel user) {
    final url = (user.voiceIntroUrl ?? '').trim();
    if (url.isEmpty) {
      return _group([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Icon(Icons.mic_none, color: AppColors.lavender, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Let people hear your vibe with a 10–20 second voice intro.',
                  style: TextStyle(color: AppColors.lavender, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: _recordVoice,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPurpleLight,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Record'),
              ),
            ],
          ),
        ),
      ]);
    }
    return Column(
      children: [
        VoiceIntroCard(
          key: ValueKey(url),
          url: url,
          totalSeconds: user.voiceIntroDurationSeconds,
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _deleteVoice,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: const Size(48, 48),
              ),
            ),
            TextButton.icon(
              onPressed: _recordVoice,
              icon: const Icon(Icons.mic_none, size: 18),
              label: const Text('Re-record'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPurpleLight,
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stickySave(bool changed) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!changed && !_isSaving && !_saved)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'No changes yet',
                        style: TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  CustomButton(
                    text: 'Save changes',
                    isLoading: _isSaving,
                    isSuccess: _saved,
                    onPressed:
                        changed && !_isSaving && !_saved ? _saveChanges : null,
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

/// Picks one or more options for a questionnaire field.
class _OptionSheet extends StatefulWidget {
  final String title;
  final Question question;
  final List<String> options;
  final Set<String> initial;
  final bool multi;

  const _OptionSheet({
    required this.title,
    required this.question,
    required this.options,
    required this.initial,
    required this.multi,
  });

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late final Set<String> _selected = {...widget.initial};

  void _tap(String option) {
    Haptics.selection();
    if (!widget.multi) {
      Navigator.pop(context, {option});
      return;
    }
    setState(() {
      if (!_selected.remove(option)) _selected.add(option);
    });
  }

  @override
  Widget build(BuildContext context) {
    final helper = widget.question.helperText;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: GoogleFonts.montserrat(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (helper != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  helper,
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in widget.options)
                    _optionTile(option, _selected.contains(option)),
                ],
              ),
            ),
            if (widget.multi)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: CustomButton(
                  text: 'Done',
                  onPressed: () => Navigator.pop(context, _selected),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(String option, bool selected) {
    return Semantics(
      selected: selected,
      checked: widget.multi ? selected : null,
      inMutuallyExclusiveGroup: !widget.multi,
      button: true,
      child: InkWell(
        onTap: () => _tap(option),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 52),
          color: selected
              ? AppColors.brandPurple.withValues(alpha: 0.14)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      color: selected
                          ? AppColors.brandPurpleLight
                          : AppColors.white,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  widget.multi
                      ? (selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank)
                      : (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked),
                  size: 22,
                  color: selected
                      ? AppColors.brandPurpleLight
                      : AppColors.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
