import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import 'astrology_view_model.dart';

/// Main astrology questionnaire screen with page view
/// Converted from AstrologyQuestionnaireActivity.kt
class AstrologyQuestionnaireScreen extends StatefulWidget {
  const AstrologyQuestionnaireScreen({super.key});

  @override
  State<AstrologyQuestionnaireScreen> createState() =>
      _AstrologyQuestionnaireScreenState();
}

class _AstrologyQuestionnaireScreenState
    extends State<AstrologyQuestionnaireScreen> {
  final PageController _pageController = PageController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentPage = 0;
  late AstrologyViewModel _viewModel;

  // Note: Step fragments will be created in PHASE 2
  // For now, using placeholder widgets
  final List<Widget> _pages = [
    const PlaceholderStep(title: 'Preferred Signs', stepNumber: 3),
    const PlaceholderStep(title: 'Believe in Astrology?', stepNumber: 4),
    const PlaceholderStep(title: 'Personality Priority', stepNumber: 5),
    const PlaceholderStep(title: 'Belief Level', stepNumber: 6),
    const PlaceholderStep(title: 'Relationship Priority', stepNumber: 7),
    const PlaceholderStep(title: 'Vibe Preference', stepNumber: 8),
    const PlaceholderStep(title: 'Lifestyle', stepNumber: 9),
    const PlaceholderStep(title: 'Ideal Date', stepNumber: 10),
    const PlaceholderStep(title: 'Review', stepNumber: 11),
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<AstrologyViewModel>(context, listen: false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      // Validate current step
      if (!_viewModel.isStepValid(_currentPage)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete this step'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
        return;
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveToFirestore();
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveToFirestore() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('users').doc(uid).set(
            _viewModel.toMap(),
            SetOptions(merge: true),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved!'),
            backgroundColor: AppColors.connectColor,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentPage > 0) {
          _goToPreviousPage();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.appBackground,
        appBar: AppBar(
          title: const Text('Astrology Match'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_currentPage > 0) {
                _goToPreviousPage();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Lottie Header
            Lottie.asset(
              'assets/animations/zodiac.json',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.auto_awesome,
                  size: 120,
                  color: AppColors.purpleSecondary,
                );
              },
            ),

            // Progress Dots
            _buildProgressDots(),

            const SizedBox(height: 16),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: _pages,
              ),
            ),

            // Navigation Buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == _currentPage
                  ? AppColors.purpleSecondary
                  : AppColors.hintPurple.withOpacity(0.3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          Expanded(
            child: OutlinedButton(
              onPressed: _currentPage > 0 ? _goToPreviousPage : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: _currentPage > 0
                      ? AppColors.purpleSecondary
                      : AppColors.hintPurple,
                ),
              ),
              child: Text(
                AppStrings.back,
                style: TextStyle(
                  color: _currentPage > 0
                      ? AppColors.purpleSecondary
                      : AppColors.hintPurple,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Next/Save Button
          Expanded(
            child: ElevatedButton(
              onPressed: _goToNextPage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.purplePrimary,
              ),
              child: Text(
                _currentPage == _pages.length - 1
                    ? AppStrings.save
                    : AppStrings.next,
                style: const TextStyle(color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder step widget (will be replaced with actual steps in PHASE 2)
class PlaceholderStep extends StatelessWidget {
  final String title;
  final int stepNumber;

  const PlaceholderStep({
    super.key,
    required this.title,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 80,
            color: AppColors.hintPurple.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Step $stepNumber',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.hintPurple,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '(Will be implemented in PHASE 2)',
            style: TextStyle(
              color: AppColors.hintPurple,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}