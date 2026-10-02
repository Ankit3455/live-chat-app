// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:availchat/core/constants/app_colors.dart';
// import 'package:availchat/managers/profile_completion_manager.dart';
// import '../home/home_screen.dart'; // ✅ CHANGED FROM AstrologyQuestionnaireScreen
// import 'helpers/questionnaire_helper.dart';
// import 'widgets/progress_header.dart';
// import 'widgets/question_widget.dart';
//
// /// Post-signup mandatory questions (5 questions)
// /// Converted from PostSignupQuestionsActivity.kt
// class PostSignupQuestionsScreen extends StatefulWidget {
//   const PostSignupQuestionsScreen({super.key});
//
//   @override
//   State<PostSignupQuestionsScreen> createState() =>
//       _PostSignupQuestionsScreenState();
// }
//
// class _PostSignupQuestionsScreenState extends State<PostSignupQuestionsScreen> {
//   final _pageController = PageController();
//   final _firestore = FirebaseFirestore.instance;
//   final _auth = FirebaseAuth.instance;
//
//   int _currentPage = 0;
//   final Map<String, dynamic> _answers = {};
//   late final List<dynamic> _questions;
//   bool _isLoading = false; // new to protect future call
//
//   @override
//   void initState() {
//     super.initState();
//     _questions = QuestionnaireHelper.getMandatoryQuestions();
//   }
//
//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }
//
//   // Move nextPage down, and it needs validation and save handling
//   void _nextPage() async {
//     if (_currentPage < _questions.length - 1) {
//       // Check and go to next page
//       if (!_validateCurrentQuestion()) {
//         _showError('Please answer this question');
//         return;
//       }
//       _saveCurrentAnswer(); // side effect
//
//       _pageController.nextPage(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//       );
//     } else {
//       // last page, check valid, save and go to Home:
//       await _saveAndProceed();
//     }
//   }
//
//   void _previousPage() {
//     if (_currentPage > 0) {
//       _pageController.previousPage(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//       );
//     }
//   }
//
//   // keep existing - to validate each screen
//   bool _validateCurrentQuestion() {
//     final question = _questions[_currentPage];
//     final answer = _answers[question.fieldName];
//
//     if (question.isMandatory) {
//       if (answer == null || answer.toString().isEmpty) {
//         return false;
//       }
//     }
//     return true;
//   }
//
//   // keep existing - to save Firestore incrementally. We may not need this in every page, but this should also work
//   Future<void> _saveCurrentAnswer() async {
//     final question = _questions[_currentPage];
//     final answer = _answers[question.fieldName];
//
//     final userId = _auth.currentUser?.uid;
//     if (userId != null && answer != null) {
//       try {
//         await _firestore
//             .collection('users')
//             .doc(userId)
//             .set({question.fieldName: answer}, SetOptions(merge: true));
//       } catch (e) {
//         debugPrint('Error saving answer: $e');
//       }
//     }
//   }
//
//   // This fixes the hang on what should be the last page
//   Future<void> _saveAndProceed() async {
//     // set loading and protect from errors to not have user lost
//     setState(() => _isLoading = true);
//
//     try {
//       if (!_validateCurrentQuestion()) {
//         _showError('Please answer this question');
//         return;
//       }
//       await _saveCurrentAnswer();   // make sure the last thing we do is save answers
//       // Then, and only then navigate to home
//       if (mounted) {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(
//             builder: (_) => const HomeScreen(),
//           ),
//         );
//
//         // Mark completion and show success. NOTE: don't block success, so await in background.
//         if (mounted) {
//            // this could be an update, so handle in a separate thread,
//            // so it returns to Main / UI without blocking. It runs, so it's OK
//           Future.delayed(const Duration(milliseconds: 300), () async {
//             final userId = _auth.currentUser?.uid;
//             final percentage = await ProfileCompletionManager().getCompletionPercentage();
//             await Future.wait([
//               ProfileCompletionManager().markMandatoryComplete(),  // Mark completion for new users
//               if (userId!=null) _firestore.collection('users').doc(userId).update({
//                 'profileCompletionPercentage': percentage  // Then save in Firestore
//               }),
//             ]);
//
//           });
//         }
//         // if no-one errors, now notify the user, show it worked
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('🎉 Mandatory profile complete!'),
//               backgroundColor: AppColors.connectColor,
//             ),
//           );
//         }
//       }
//
//     } catch (e) {
//       if (mounted) {
//          _showError('Failed to save and proceed: $e');
//       }
//     } finally{
//     if (mounted) {  // IMPORTANT: don't do anything if the object is no longer in context, will error on framework
//               setState(() {
//                 _isLoading = false;  // release
//               });
//     }
//     }
//   }
//
//   // Quick message dialogs
//   void _showLoading() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//   }
//
//   void _hideLoading() {
//     Navigator.of(context).pop();
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: AppColors.dangerRed),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.appBackground,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Progress bar and title
//             ProgressHeader(
//               currentStep: _currentPage + 1,
//               totalSteps: _questions.length,
//               title: 'Complete Your Profile',
//             ),
//
//             const SizedBox(height: 24),
//
//             // Questions
//             Expanded(
//               child: PageView.builder(
//                 controller: _pageController,
//                 physics: const NeverScrollableScrollPhysics(),
//                 onPageChanged: (index) {
//                   setState(() => _currentPage = index);
//                 },
//                 itemCount: _questions.length,
//                 itemBuilder: (context, index) {
//                   final question = _questions[index];
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 24),
//                     child: QuestionWidget(
//                       question: question,
//                       answer: _answers[question.fieldName],
//                       onAnswerChanged: (value) {
//                         setState(() {
//                           _answers[question.fieldName] = value;
//                         });
//                       },
//                     ),
//                   );
//                 },
//               ),
//             ),
//
//             // Navigation
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   // Back button (except on first page)
//                   if (_currentPage > 0)
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: _previousPage,
//                         style: OutlinedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           side: const BorderSide(
//                             color: AppColors.purpleSecondary,
//                           ),
//                         ),
//                         child: const Text(
//                           'Back',
//                           style: TextStyle(color: AppColors.purpleSecondary),
//                         ),
//                       ),
//                     ),
//
//                   if (_currentPage > 0) const SizedBox(width: 16),
//
//                   // Next and Save
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: _nextPage,
//                       style: ElevatedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         backgroundColor: AppColors.purplePrimary,
//                       ),
//                       child: _isLoading
//                           ? const SizedBox(
//                               height: 20,
//                               width: 20,
//                               child: CircularProgressIndicator(
//                                 color: Colors.white,
//                                 strokeWidth: 2,
//                               ),
//                             )
//                           : Text(
//                               _currentPage == _questions.length - 1
//                                   ? 'Finish'
//                                   : 'Next',
//                               style: const TextStyle(color: AppColors.white),
//                             ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import '../home/home_screen.dart';
import '../profile/voice_intro_screen.dart'; // ✅ NEW: voice intro screen
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
  late final List<dynamic> _questions;
  bool _isLoading = false; // new to protect future call

  @override
  void initState() {
    super.initState();
    _questions = QuestionnaireHelper.getMandatoryQuestions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Move nextPage down, and it needs validation and save handling
  void _nextPage() async {
    if (_currentPage < _questions.length - 1) {
      // Check and go to next page
      if (!_validateCurrentQuestion()) {
        _showError('Please answer this question');
        return;
      }
      _saveCurrentAnswer(); // side effect

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // last page, check valid, save and go to Voice Intro -> Home
      await _saveAndProceed();
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

  // keep existing - to validate each screen
  bool _validateCurrentQuestion() {
    final question = _questions[_currentPage];
    final answer = _answers[question.fieldName];

    if (question.isMandatory) {
      if (answer == null || answer.toString().isEmpty) {
        return false;
      }
    }
    return true;
  }

  // keep existing - to save Firestore incrementally
  Future<void> _saveCurrentAnswer() async {
    final question = _questions[_currentPage];
    final answer = _answers[question.fieldName];

    final userId = _auth.currentUser?.uid;
    if (userId != null && answer != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .set({question.fieldName: answer}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving answer: $e');
      }
    }
  }

  // ✅ UPDATED: After saving, show VoiceIntroScreen, then go Home
  Future<void> _saveAndProceed() async {
    setState(() => _isLoading = true);

    try {
      if (!_validateCurrentQuestion()) {
        _showError('Please answer this question');
        return;
      }

      await _saveCurrentAnswer();

      // Fire-and-forget: mark mandatory complete & update percentage
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () async {
          final userId = _auth.currentUser?.uid;
          final percentage =
          await ProfileCompletionManager().getCompletionPercentage();
          await Future.wait([
            ProfileCompletionManager().markMandatoryComplete(),
            if (userId != null)
              _firestore
                  .collection('users')
                  .doc(userId)
                  .update({'profileCompletionPercentage': percentage}),
          ]);
        });
      }

      // Instant feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Mandatory profile complete!'),
            backgroundColor: AppColors.connectColor,
          ),
        );
      }

      // ✅ Show Voice Intro screen right after completion (user can record or skip)
      if (mounted) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const VoiceIntroScreen()),
        );
      }

      // ✅ Then go to Home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save and proceed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Quick message dialogs
  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoading() {
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.dangerRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar and title
            ProgressHeader(
              currentStep: _currentPage + 1,
              totalSteps: _questions.length,
              title: 'Complete Your Profile',
            ),

            const SizedBox(height: 24),

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
                  return Padding(
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

            // Navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Back button (except on first page)
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                            color: AppColors.purpleSecondary,
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(color: AppColors.purpleSecondary),
                        ),
                      ),
                    ),

                  if (_currentPage > 0) const SizedBox(width: 16),

                  // Next and Save
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.purplePrimary,
                      ),
                      child: _isLoading
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
                            ? 'Finish'
                            : 'Next',
                        style: const TextStyle(color: AppColors.white),
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
