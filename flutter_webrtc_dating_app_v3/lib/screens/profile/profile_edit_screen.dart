// lib/screens/profile/profile_edit_screen.dart
//
// Text fields and voice intro only. Photo/avatar actions live in
// My Profile's Change Avatar sheet (ProfilePhotoService).
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:availchat/models/user_model.dart';
import 'package:availchat/services/location_service.dart';
import 'package:availchat/widgets/voice/voice_intro_section.dart';
import '../../core/constants/app_colors.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserModel user;

  const ProfileEditScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _professionController;
  late TextEditingController _locationController;

  bool _isSaving = false;
  Stream<DocumentSnapshot>? _voiceDocStream;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _professionController = TextEditingController(text: widget.user.profession ?? '');
    _locationController = TextEditingController(text: widget.user.location ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _professionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.user.uid == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profession': _professionController.text.trim(),
        'location': _locationController.text.trim(),
      });

      // City changed: re-geocode so distance follows the new city (DEST-081).
      final newCity = _locationController.text.trim();
      final cityFound = newCity.isEmpty ||
          newCity == (widget.user.location ?? '').trim() ||
          await LocationService.instance.updateFromCity(newCity);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cityFound
              ? '✅ Profile updated successfully!'
              : 'Profile updated. Could not find that city; distance may be inaccurate.'),
          backgroundColor: cityFound ? Colors.green : null,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
            const SnackBar(content: Text('Profile not found')));
        return;
      }
      final fresh = UserModel.fromFirestore(doc);
      setState(() {
        _usernameController.text = fresh.username;
        _bioController.text = fresh.bio ?? '';
        _professionController.text = fresh.profession ?? '';
        _locationController.text = fresh.location ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Profile refresh failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not refresh. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Save changes',
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.white,
        backgroundColor: AppColors.surfaceCard,
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildSectionHeader('About you'),
              _buildTextField(
                controller: _usernameController,
                label: 'Username',
                icon: Icons.person,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Username is required'
                    : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _bioController,
                label: 'Bio',
                icon: Icons.text_fields,
                maxLines: 5,
                maxLength: 150,
              ),
              const SizedBox(height: 12),
              _buildSectionHeader('Work & location'),
              _buildTextField(
                controller: _professionController,
                label: 'Profession',
                icon: Icons.work,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _locationController,
                label: 'Location',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 18),
              _liveVoiceSection(widget.user),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    disabledBackgroundColor: AppColors.surfaceCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveVoiceSection(UserModel base) {
    if (base.uid == null) {
      return VoiceIntroSection(user: base);
    }

    _voiceDocStream ??=
        FirebaseFirestore.instance.collection('users').doc(base.uid).snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: _voiceDocStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return VoiceIntroSection(user: base);
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final liveUser = UserModel.fromMap({...data, 'uid': snap.data!.id}, uid: snap.data!.id);

        final mergedForVoice = base.copyWith(
          voiceIntroUrl: liveUser.voiceIntroUrl,
          voiceIntroDurationSeconds: liveUser.voiceIntroDurationSeconds,
        );

        return VoiceIntroSection(user: mergedForVoice);
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.lavender),
        prefixIcon: Icon(icon, color: AppColors.brandPurpleLight),
        filled: true,
        fillColor: AppColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}