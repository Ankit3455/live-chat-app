import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:availchat/screens/questionnaire/widgets/question_widget.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import '../../core/constants/app_colors.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({Key? key}) : super(key: key);

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _sections = QuestionnaireHelper.getProfileSections();
  final _lifestyleQuestions = QuestionnaireHelper.getLifestyleQuestions();
  final _personalityQuestions = QuestionnaireHelper.getPersonalityQuestions();
  final Map<String, dynamic> _answers = {};
  final Set<String> _completedSections = {};
  bool _isSaving = false;
  int _completionPercentage = 60;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _loadCompletionPercentage();
    _checkCompletedSections();
  }

  /// Load existing user data from Firestore
  Future<void> _loadExistingData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && mounted) {
        // Don't overwrite answers the user changed while this was loading.
        setState(() {
          (doc.data() ?? {}).forEach((k, v) => _answers.putIfAbsent(k, () => v));
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  /// Load current completion percentage
  Future<void> _loadCompletionPercentage() async {
    try {
      final percentage =
          await ProfileCompletionManager().getCompletionPercentage();
      if (mounted) setState(() => _completionPercentage = percentage);
    } catch (e) {
      debugPrint('Error loading completion: $e');
    }
  }

  /// Check which sections are already completed
  Future<void> _checkCompletedSections() async {
    final manager = ProfileCompletionManager();
    try {
      final lifestyle = await manager.isLifestyleComplete();
      final personality = await manager.isPersonalityComplete();
      if (!mounted) return;
      setState(() {
        if (lifestyle) _completedSections.add('Lifestyle Preferences');
        if (personality) _completedSections.add('Personality & Views');
      });
    } catch (e) {
      debugPrint('Error checking sections: $e');
    }
  }

  /// Get questions for a specific section
  List<dynamic> _getQuestionsForSection(String sectionTitle) {
    if (sectionTitle == 'Lifestyle Preferences') {
      return _lifestyleQuestions;
    } else if (sectionTitle == 'Personality & Views') {
      return _personalityQuestions;
    }
    return [];
  }

  /// ✅ FIXED: Validate and save section with proper checks
  Future<void> _saveSection(String sectionTitle, List<dynamic> questions) async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw const _SectionError('Please sign in again.');
      }

      // ✅ Step 1: Collect ONLY answered questions for this section
      final sectionData = <String, dynamic>{};
      
      for (var question in questions) {
        final fieldName = question.fieldName;
        final answer = _answers[fieldName];
        
        // ✅ Validate answer exists and is not empty
        if (answer != null) {
          if (answer is String) {
            // For text answers, check if not empty after trimming
            if (answer.trim().isNotEmpty) {
              sectionData[fieldName] = answer.trim();
            }
          } else if (answer is List) {
            // For multi-choice, check if list has items
            if (answer.isNotEmpty) {
              sectionData[fieldName] = answer;
            }
          } else {
            // For other types (numbers, bools, etc.)
            sectionData[fieldName] = answer;
          }
        }
      }

      // ✅ Step 2: Check if minimum answers provided
      if (sectionData.isEmpty) {
        throw const _SectionError(
            'Please answer at least one question in this section');
      }

      final minimumRequired = (questions.length * 0.5).ceil(); // 50% threshold
      
      if (sectionData.length < minimumRequired) {
        throw _SectionError(
          'Please answer at least $minimumRequired questions (currently answered: ${sectionData.length})',
        );
      }

      // ✅ Step 3: Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(sectionData, SetOptions(merge: true));

      // ✅ Step 4: Mark section as complete ONLY if minimum met
      if (sectionTitle == 'Lifestyle Preferences') {
        await ProfileCompletionManager().markLifestyleComplete();
      } else if (sectionTitle == 'Personality & Views') {
        await ProfileCompletionManager().markPersonalityComplete();
      }

      // ✅ Step 5: Update completion percentage (also written back)
      final percentage =
          await ProfileCompletionManager().getCompletionPercentage();
      if (!mounted) return;
      setState(() {
        _completedSections.add(sectionTitle);
        _completionPercentage = percentage;
      });

      // ✅ Step 6: Show success message with answer count
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $sectionTitle saved!\n'
              'Answered: ${sectionData.length}/${questions.length} questions\n'
              'Profile: $_completionPercentage% complete'
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save section failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is _SectionError
                ? e.message
                : 'Could not save. Check your connection and try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '$_completionPercentage%',
                style: const TextStyle(
                  color: AppColors.brandPurpleLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Completion Progress Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandPurple.withOpacity(0.2),
                    AppColors.brandPurple.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Profile Strength',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_completionPercentage%',
                        style: const TextStyle(
                          color: AppColors.brandPurpleLight,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _completionPercentage / 100,
                      backgroundColor: AppColors.surfaceCard,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.brandPurple),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _completionPercentage == 100
                        ? '🎉 Your profile is complete!'
                        : 'Complete optional sections to boost your profile!',
                    style: const TextStyle(
                      color: AppColors.lavender,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sections
            ..._sections.map((section) {
              final questions = section.questions.isNotEmpty
              ? section.questions
              : _getQuestionsForSection(section.title);
              final isCompleted = _completedSections.contains(section.title);

              // ✅ Count how many questions are currently answered
              final answeredCount = questions.where((q) {
                final answer = _answers[q.fieldName];
                if (answer == null) return false;
                if (answer is String) return answer.trim().isNotEmpty;
                if (answer is List) return answer.isNotEmpty;
                return true;
              }).length;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.brandPurple
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    leading: Text(
                      section.icon ?? '🌟',
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            section.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // ✅ Show answer count badge
                        if (answeredCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPurple.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$answeredCount/${questions.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      section.description,
                      style: const TextStyle(
                        color: AppColors.lavender,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isCompleted
                        ? const Icon(Icons.check_circle,
                            color: AppColors.brandPurpleLight)
                        : const Icon(Icons.expand_more, color: Colors.white),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            // Questions
                            ...questions.map((question) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24.0),
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
                            }).toList(),
                            const SizedBox(height: 16),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => _saveSection(section.title, questions),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brandPurple,
                                  disabledBackgroundColor:
                                      AppColors.surfaceCard,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
                                        isCompleted
                                            ? 'Update ${section.title}'
                                            : 'Save ${section.title}',
                                        style: const TextStyle(
                                          fontSize: 16,
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
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _SectionError implements Exception {
  final String message;
  const _SectionError(this.message);
}
