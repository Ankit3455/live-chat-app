import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/haptics.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import 'package:availchat/models/question_model.dart';
import 'package:availchat/services/session_service.dart';
import 'package:availchat/widgets/custom_button.dart';
import '../auth/auth_router.dart';
import '../profile/voice_intro_screen.dart';
import 'helpers/questionnaire_helper.dart';
import 'widgets/progress_header.dart';
import 'widgets/question_widget.dart';

/// Post-signup mandatory questions (5 questions)
/// Converted from PostSignupQuestionsActivity.kt
class PostSignupQuestionsScreen extends StatefulWidget {
  const PostSignupQuestionsScreen({super.key});

  @override
  State<PostSignupQuestionsScreen> createState() =>
      _PostSignupQuestionsScreenState();
}

class _PostSignupQuestionsScreenState extends State<PostSignupQuestionsScreen> {
  final _pageController = PageController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int _currentPage = 0;
  final Map<String, dynamic> _answers = {};
  late final List<Question> _questions;
  bool _isLoading = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _questions = QuestionnaireHelper.getMandatoryQuestions();
    _loadSavedAnswers();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Prefills answers saved before the app was closed mid-flow.
  Future<void> _loadSavedAnswers() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      final snap = await _firestore.collection('users').doc(userId).get();
      final data = snap.data();
      if (data == null || !mounted) return;
      setState(() {
        for (final q in _questions) {
          final saved = data[q.fieldName];
          if (_answers[q.fieldName] == null && _isAnswered(saved)) {
            _answers[q.fieldName] = saved;
          }
        }
      });
    } catch (e) {
      debugPrint('Loading saved answers failed: $e');
    }
  }

  bool _isAnswered(dynamic answer) {
    if (answer == null) return false;
    if (answer is String) return answer.trim().isNotEmpty;
    if (answer is List) return answer.isNotEmpty;
    return true;
  }

  Duration get _pageDuration => MediaQuery.disableAnimationsOf(context)
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 300);

  void _nextPage() {
    if (_isLoading || _completed) return;
    if (!_validateCurrentQuestion()) {
      _showError('Please answer this question to continue.');
      return;
    }
    if (_currentPage < _questions.length - 1) {
      _saveCurrentAnswer();
      _pageController.nextPage(
        duration: _pageDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndProceed();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: _pageDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentQuestion() {
    final question = _questions[_currentPage];
    if (!question.isMandatory) return true;
    return _isAnswered(_answers[question.fieldName]);
  }

  /// Best-effort incremental save so a resumed flow keeps earlier answers.
  Future<void> _saveCurrentAnswer() async {
    final question = _questions[_currentPage];
    final answer = _answers[question.fieldName];

    final userId = _auth.currentUser?.uid;
    if (userId != null && answer != null) {
      try {
        await _firestore.collection('users').doc(userId).set({
          question.fieldName: answer,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving answer: $e');
      }
    }
  }

  /// Saves every mandatory answer, marks the step complete, then shows the
  /// voice intro and hands off to the router (Home once complete).
  Future<void> _saveAndProceed() async {
    if (_isLoading || _completed) return;
    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw StateError('Not logged in');

      final missing = _questions.indexWhere(
        (q) => q.isMandatory && !_isAnswered(_answers[q.fieldName]),
      );
      if (missing != -1) {
        setState(() => _isLoading = false);
        _pageController.jumpToPage(missing);
        _showError('Please answer this question to continue.');
        return;
      }

      await _firestore.collection('users').doc(userId).set({
        for (final q in _questions)
          if (_isAnswered(_answers[q.fieldName]))
            q.fieldName: _answers[q.fieldName],
      }, SetOptions(merge: true));

      // Also recomputes profileCompletionPercentage (mandatory fields included).
      await ProfileCompletionManager().markMandatoryComplete();
      await SessionService.instance.markOnboardingComplete();
    } catch (e) {
      debugPrint('Post-signup save failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(
          "We couldn't save your answers. Check your connection and try again.",
        );
      }
      return;
    }

    _completed = true;
    if (!mounted) return;

    Haptics.success();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your profile basics are done!')),
    );

    // The user can record or skip; either way continue to Home.
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceIntroScreen()),
    );

    if (mounted) await AuthRouter.routeCurrentUser(context);
  }

  void _showError(String message) {
    Haptics.error();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _completed;
    // This screen is the root of its step; back steps through the questions.
    return PopScope(
      canPop: _currentPage == 0 && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) _previousPage();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: SafeArea(
          // Cap width on tablets so the form stays readable.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  ProgressHeader(
                    currentStep: _currentPage + 1,
                    totalSteps: _questions.length,
                    onBack: _currentPage > 0 && !busy ? _previousPage : null,
                  ),

                  // Questions
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final question = _questions[index];
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: QuestionWidget(
                            question: question,
                            answer: _answers[question.fieldName],
                            onAnswerChanged: (value) {
                              setState(() {
                                _answers[question.fieldName] = value;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: CustomButton(
                      text: _currentPage == _questions.length - 1
                          ? 'Finish'
                          : 'Continue',
                      onPressed: busy ? null : _nextPage,
                      isLoading: _isLoading,
                    ),
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
