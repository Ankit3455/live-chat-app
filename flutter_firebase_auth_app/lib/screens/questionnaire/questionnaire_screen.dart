import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:availchat/screens/questionnaire/widgets/progress_header.dart';
import 'package:availchat/screens/questionnaire/widgets/question_widget.dart';
import 'package:availchat/screens/questionnaire/post_signup_questions_screen.dart';
import 'package:availchat/screens/profile/avatar_selection_screen.dart';
import 'package:availchat/managers/profile_completion_manager.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({Key? key}) : super(key: key);

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  final _questions = QuestionnaireHelper.getSignupQuestions(); // ✅ FIXED
  final Map<String, dynamic> _answers = {};
  int _currentPage = 0;
  int? _selectedAvatar;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      // Validate current answer
      if (!_isCurrentAnswerValid()) {
        _showError('Please answer this question');
        return;
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last question - proceed to avatar
      if (!_isCurrentAnswerValid()) {
        _showError('Please answer this question');
        return;
      }
      _selectAvatar();
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

  Future<void> _selectAvatar() async {
    final avatar = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const AvatarSelectionScreen()),
    );

    if (avatar != null) {
      setState(() => _selectedAvatar = avatar);
      _saveToFirestore();
    }
  }

  Future<void> _saveToFirestore() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Prepare data
      final Map<String, dynamic> userData = Map.from(_answers);
      userData['avatar'] = _selectedAvatar ?? 0;

      // Geocode location if provided
      final location = _answers['location'] as String?;
      if (location != null && location.isNotEmpty) {
        try {
          final locations = await locationFromAddress(location);
          if (locations.isNotEmpty) {
            userData['userLatitude'] = locations.first.latitude;
            userData['userLongitude'] = locations.first.longitude;
          }
        } catch (e) {
          debugPrint('Geocoding error: $e');
        }
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      // Mark signup complete
      await ProfileCompletionManager().markSignupComplete();

      // Update profile completion percentage
      final percentage =
          await ProfileCompletionManager().getCompletionPercentage();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profileCompletionPercentage': percentage});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Basic profile created!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to mandatory questions
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PostSignupQuestionsScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
            
            // Progress Header
            ProgressHeader(
              currentStep: _currentPage + 1,
              totalSteps: _questions.length,
              title: 'Basic Profile',
            ),

            const SizedBox(height: 24),

            // Questions PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final question = _questions[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: QuestionWidget(
                      question: question,
                      answer: _answers[question.fieldName],
                      onAnswerChanged: (answer) {
                        setState(() {
                          _answers[question.fieldName] = answer;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            // Navigation Buttons
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
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _currentPage == _questions.length - 1
                                  ? 'Choose Avatar'
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