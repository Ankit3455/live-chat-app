import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/haptics.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import 'package:availchat/models/question_model.dart';
import 'package:availchat/services/session_service.dart';
import '../auth/auth_router.dart';
import '../profile/voice_intro_screen.dart';
import 'helpers/questionnaire_helper.dart';
import 'deck/deck_models.dart';
import 'deck/deck_runner.dart';
import 'deck/deck_widgets.dart';

/// Chapter II of signup: relationship status, here for, height, body type,
/// education (required) and an optional opening line. Each answer is saved as
/// it is given so a resumed flow keeps it.
class PostSignupQuestionsScreen extends StatefulWidget {
  const PostSignupQuestionsScreen({super.key});

  @override
  State<PostSignupQuestionsScreen> createState() =>
      _PostSignupQuestionsScreenState();
}

class _PostSignupQuestionsScreenState extends State<PostSignupQuestionsScreen> {
  final _runner = GlobalKey<DeckRunnerState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final Map<String, dynamic> _answers = {};
  late final List<Question> _questions;
  late final List<DeckCard> _cards;
  bool _intro = true;
  bool _isLoading = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _questions = QuestionnaireHelper.getMandatoryQuestions();
    _cards = DeckCard.fromQuestions(_questions);
    _loadSavedAnswers();
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

  void _onAnswer(String field, Object? answer) {
    setState(() {
      if (_isAnswered(answer)) {
        _answers[field] = answer;
      } else {
        _answers.remove(field);
      }
    });
    _saveAnswer(field, answer);
  }

  /// Best-effort incremental save so a resumed flow keeps earlier answers.
  Future<void> _saveAnswer(String field, Object? answer) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _firestore.collection('users').doc(userId).set({
        field: answerWriteValue(answer),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving answer: $e');
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
        _runner.currentState?.goTo(missing);
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
    // Root of its step: back steps through the cards, then leaves the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || busy) return;
        final runner = _runner.currentState;
        if (!_intro && runner != null && runner.canGoBack) {
          runner.back();
        } else if (!_intro) {
          setState(() => _intro = true);
        } else {
          unawaited(SystemNavigator.pop());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDarkest,
        body: DeckBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _intro ? _buildIntro() : _buildDeck(busy),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Column(
        children: [
          const Spacer(),
          const Text('💞', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 14),
          Text(
            'CHAPTER II',
            style: deckSerif(15, color: AppColors.gold, italic: true)
                .copyWith(letterSpacing: 4),
          ),
          const SizedBox(height: 6),
          Semantics(
            header: true,
            child: Text('What you seek', style: deckSerif(38)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Six cards about the kind of connection you want. Five are needed to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.lavender,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const Spacer(),
          DeckButton(
            label: 'Draw the cards ✦',
            height: 52,
            onPressed: () => setState(() => _intro = false),
          ),
        ],
      ),
    );
  }

  Widget _buildDeck(bool busy) {
    final firstOpen = _cards.indexWhere((c) => !c.isDone(_answers));
    return Stack(
      children: [
        DeckRunner(
          key: _runner,
          eyebrow: 'Chapter II · What you seek',
          cards: _cards,
          answers: _answers,
          startIndex: firstOpen < 0 ? _cards.length - 1 : firstOpen,
          leading: DeckLeading.back,
          busy: busy,
          savedToast: '✦ Saved',
          onAnswer: _onAnswer,
          onFinish: _saveAndProceed,
          onClose: () => setState(() => _intro = true),
        ),
        if (busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xB30B0614),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ),
          ),
      ],
    );
  }
}
