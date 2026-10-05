// lib/screens/questionnaire/questionnaire_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';

import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:availchat/screens/questionnaire/widgets/progress_header.dart';
import 'package:availchat/screens/questionnaire/widgets/question_widget.dart';
import 'package:availchat/screens/questionnaire/widgets/avatar_live_preview.dart';
import 'package:availchat/screens/profile/avatar_preview_screen.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import 'package:availchat/services/location_service.dart';
import '../../features/onboarding/tour_prefs.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/custom_button.dart';

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
  bool _completed = false;

  // Live avatar preview: only answers that change the avatar bump it.
  static const _avatarFields = {'gender', 'interests', 'habits', 'profession'};
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  dynamic _dob;
  int _avatarRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadDob();
  }

  // DOB is written at signup; the preview needs it for the zodiac palette.
  Future<void> _loadDob() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final dob = doc.data()?['dateOfBirth'];
      if (dob != null && mounted) {
        setState(() {
          _dob = dob;
          _avatarRevision++;
        });
      }
    } catch (e) {
      debugPrint('Questionnaire: could not load DOB for preview: $e');
    }
  }

  void _onAnswerChanged(String field, dynamic answer) {
    setState(() {
      _answers[field] = answer;
      if (_avatarFields.contains(field)) _avatarRevision++;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Duration get _pageDuration => MediaQuery.disableAnimationsOf(context)
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 300);

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      if (!_isCurrentAnswerValid()) {
        _showError('Please answer this question to continue.');
        return;
      }
      _pageController.nextPage(
        duration: _pageDuration,
        curve: Curves.easeInOut,
      );
    } else {
      if (!_isCurrentAnswerValid()) {
        _showError('Please answer this question to continue.');
        return;
      }
      _saveToFirestoreAndOpenAvatar();
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

  bool _isCurrentAnswerValid() {
    final question = _questions[_currentPage];
    final answer = _answers[question.fieldName];

    if (answer == null) return false;
    if (answer is String && answer.trim().isEmpty) return false;
    if (answer is List && answer.isEmpty) return false;
    return true;
  }

  Future<void> _saveToFirestoreAndOpenAvatar() async {
    if (_isSaving || _completed) return;

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw StateError('Not logged in');

      final userData = <String, dynamic>{};
      _answers.forEach((key, value) {
        userData[key] = value is String ? value.trim() : value;
      });

      // Normalised lowercase gender keeps filters and avatar mapping consistent.
      final rawGender = (userData['gender'] ?? '').toString();
      if (rawGender.isNotEmpty) userData['gender'] = rawGender.toLowerCase();

      // The location answer is the current city; birth place stays in
      // birthLocation (written at signup).
      final city = (userData['location'] ?? '').toString();
      if (city.isNotEmpty) userData['currentCity'] = city;

      userData['avatarProperties'] = QuestionnaireHelper.buildAvatarProperties(
        _answers,
      );
      userData['avatarVersion'] = 1;
      userData['isCustomAvatar'] = false;

      if (city.isNotEmpty) {
        try {
          final list = await locationFromAddress(
            city,
          ).timeout(const Duration(seconds: 8));
          if (list.isNotEmpty) {
            // Rounded coordinates plus a coarse geohash only (DEST-002/081).
            userData.addAll(
              LocationService.locationFields(
                list.first.latitude,
                list.first.longitude,
              ),
            );
          }
        } catch (e) {
          debugPrint('Geocoding failed: $e');
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      // Also recomputes profileCompletionPercentage.
      await ProfileCompletionManager().markSignupComplete();

      await TourPrefs.setForceShowAfterSignup(true);

      if (!mounted) return;
      _completed = true;
      Haptics.success();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AvatarPreviewScreen(answers: Map<String, dynamic>.from(_answers)),
        ),
      );
    } catch (e) {
      debugPrint('Questionnaire save failed: $e');
      if (mounted) {
        _showError(
          "We couldn't save your answers. Check your connection and try again.",
        );
      }
    } finally {
      if (mounted && !_completed) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    Haptics.error();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    // Back steps through the questions; on the first question it leaves
    // the app (this screen is the root of the onboarding chain).
    return PopScope(
      canPop: _currentPage == 0 && !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving) _previousPage();
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
                    // First question is the root of onboarding: no back exit.
                    onBack:
                        _currentPage > 0 && !_isSaving ? _previousPage : null,
                  ),
                  if (uid != null) ...[
                    const SizedBox(height: 12),
                    AvatarLivePreview(
                      uid: uid,
                      revision: _avatarRevision,
                      answers: {
                        ..._answers,
                        if (_dob != null) 'dateOfBirth': _dob,
                      },
                    ),
                  ],
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
                            onAnswerChanged: (ans) =>
                                _onAnswerChanged(q.fieldName, ans),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: CustomButton(
                      text: _currentPage == _questions.length - 1
                          ? 'Finish and create avatar'
                          : 'Continue',
                      onPressed: _isSaving ? null : _nextPage,
                      isLoading: _isSaving,
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
