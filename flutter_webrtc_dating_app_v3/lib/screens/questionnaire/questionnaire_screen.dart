// lib/screens/questionnaire/questionnaire_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';

import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:availchat/screens/questionnaire/widgets/progress_header.dart';
import 'package:availchat/screens/questionnaire/widgets/question_widget.dart';
import 'package:availchat/screens/profile/avatar_preview_screen.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
// ✅ ADD this import
import '../../features/onboarding/tour_prefs.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({Key? key}) : super(key: key);

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  final _questions = QuestionnaireHelper.getSignupQuestions();
  final Map<String, dynamic> _answers = {};
  int _currentPage = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      if (!_isCurrentAnswerValid()) {
        _showError('Please answer this question');
        return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (!_isCurrentAnswerValid()) {
        _showError('Please answer this question');
        return;
      }
      _saveToFirestoreAndOpenAvatar();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isCurrentAnswerValid() {
    final question = _questions[_currentPage];
    final answer = _answers[question.fieldName];

    if (answer == null) return false;
    if (answer is String && answer.trim().isEmpty) return false;
    if (answer is List && answer.isEmpty) return false;
    return true;
  }

  Future<void> _saveToFirestoreAndOpenAvatar() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Prepare data
      final Map<String, dynamic> userData = Map.from(_answers);

      // --- Normalise & copy important top-level fields for consistency ---
      final rawGender = (_answers['gender'] ?? '').toString().trim();
      if (rawGender.isNotEmpty) {
        // store normalized lowercase gender so other parts (filters, mapping) read consistent value
        userData['gender'] = rawGender.toLowerCase();
      }

      final rawLocation = (_answers['location'] ?? '').toString().trim();
      if (rawLocation.isNotEmpty) {
        userData['location'] = rawLocation;
      }

      // Build avatar seed properties (used by the generator)
      userData['avatarProperties'] =
          QuestionnaireHelper.buildAvatarProperties(_answers);

      // set initial avatarVersion and isCustomAvatar properly
      userData['avatarVersion'] = 1; // first time, increment later if changed
      userData['isCustomAvatar'] = false; // using generated PNG, not uploaded photo

      // Geocode if location is given
      final location = _answers['location'] as String?;
      if (location != null && location.isNotEmpty) {
        try {
          final list = await locationFromAddress(location);
          if (list.isNotEmpty) {
            userData['userLatitude'] = list.first.latitude;
            userData['userLongitude'] = list.first.longitude;
          }
        } catch (e) {
          debugPrint('Location error: $e');
        }
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      // Mark as signup completed (phase 1)
      await ProfileCompletionManager().markSignupComplete();

      // Update profile completion percentage
      final percent = await ProfileCompletionManager().getCompletionPercentage();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profileCompletionPercentage': percent});

      // ✅ SET FLAG so onboarding shows after reaching home
      await TourPrefs.setForceShowAfterSignup(true);

      // ✅ Go to AVATAR PREVIEW SCREEN
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AvatarPreviewScreen(
              answers: Map<String, dynamic>.from(_answers),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            ProgressHeader(
              currentStep: _currentPage + 1,
              totalSteps: _questions.length,
              title: 'Basic Profile',
            ),
            const SizedBox(height: 24),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: QuestionWidget(
                      question: q,
                      answer: _answers[q.fieldName],
                      onAnswerChanged: (ans) {
                        setState(() {
                          _answers[q.fieldName] = ans;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF7B2CBF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            color: Color(0xFF7B2CBF),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),

                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B2CBF),
                        disabledBackgroundColor: const Color(0xFF2D1B4E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                          : Text(
                        _currentPage == _questions.length - 1
                            ? 'Finish & Create Avatar'
                            : 'Continue',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
  }
}
