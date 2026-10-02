// lib/screens/profile/profile_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'package:availchat/models/user_model.dart';
import 'package:availchat/widgets/voice/voice_intro_section.dart';

import 'package:availchat/core/config/storage_config.dart';
import 'package:availchat/services/storage/storage_repo.dart';
import 'package:availchat/services/storage/firebase_storage_repo.dart';
import 'package:availchat/services/storage/cloudinary_storage_repo.dart';

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
  bool _isRefreshing = false;

  StorageRepo get _storage =>
      StorageConfig.kUseCloudinaryForMedia ? const CloudinaryStorageRepo() : FirebaseStorageRepo();

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully!'),
          backgroundColor: Colors.green,
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

  Future<void> _refresh() async {
    if (widget.user.uid == null) return;
    setState(() => _isRefreshing = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('🔄 Refreshed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading photo...')),
        );
      }

      final url = await _storage.uploadImageFile(
        folder: 'profile_photos',
        file: File(picked.path),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'profileImage': url,
        // user uploaded photo -> custom avatar true
        'isCustomAvatar': true,
        'avatarVersion': FieldValue.increment(1),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profile photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _resetToAvatar() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
      final data = doc.data() ?? {};
      final props = (data['avatarProperties'] as Map<String, dynamic>?) ?? {};
      final avatarUrl = (props['avatarPngUrl'] as String?) ?? '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'profileImage': avatarUrl.isNotEmpty ? avatarUrl : null,
        // reset to generated avatar -> NOT custom
        'isCustomAvatar': false,
        'avatarVersion': FieldValue.increment(1),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reset to Avatar'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF2D1B4E),
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
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.white,
        backgroundColor: const Color(0xFF2D1B4E),
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            children: [
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
              const SizedBox(height: 20),
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
              const SizedBox(height: 28),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 18),
              _liveVoiceSection(widget.user),
              const SizedBox(height: 18),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _changePhoto,
                          icon: const Icon(Icons.photo),
                          label: const Text('Change Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7B2CBF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _resetToAvatar,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38),
                          ),
                          child: const Text(
                            'Reset to Avatar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    disabledBackgroundColor: const Color(0xFF2D1B4E),
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
              if (_isRefreshing) const SizedBox(height: 24),
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

    final docRef = FirebaseFirestore.instance.collection('users').doc(base.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
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
        labelStyle: const TextStyle(color: Color(0xFFB39DDB)),
        prefixIcon: Icon(icon, color: const Color(0xFF7B2CBF)),
        filled: true,
        fillColor: const Color(0xFF2D1B4E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
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