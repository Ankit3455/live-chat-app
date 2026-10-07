// lib/screens/questionnaire/questionnaire_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';

import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:availchat/screens/questionnaire/widgets/avatar_live_preview.dart';
import 'package:availchat/screens/questionnaire/deck/deck_models.dart';
import 'package:availchat/screens/questionnaire/deck/deck_runner.dart';
import 'package:availchat/screens/questionnaire/deck/deck_widgets.dart';
import 'package:availchat/services/dicebear_avatar_service.dart';
import 'package:availchat/screens/profile/avatar_preview_screen.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import 'package:availchat/services/location_service.dart';
import '../../features/onboarding/tour_prefs.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({Key? key}) : super(key: key);

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _cards =
      DeckCard.fromQuestions(QuestionnaireHelper.getSignupQuestions());
  final _runner = GlobalKey<DeckRunnerState>();
  final Map<String, dynamic> _answers = {};
  bool _isSaving = false;
  bool _completed = false;

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  dynamic _dob;

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
      if (dob != null && mounted) setState(() => _dob = dob);
    } catch (e) {
      debugPrint('Questionnaire: could not load DOB for preview: $e');
    }
  }

  void _onAnswer(String field, Object? answer) {
    setState(() {
      if (isAnswered(answer)) {
        _answers[field] = answer;
      } else {
        _answers.remove(field);
      }
    });
  }

  /// The card circle shows the avatar these answers produce so far.
  Widget _liveAvatar(BuildContext context, DeckCard card) {
    final url = DiceBearAvatarService.preview(
      {..._answers, if (_dob != null) 'dateOfBirth': _dob},
      uniqueKey: _uid ?? 'me',
    ).url;
    return Semantics(
      label: 'Your avatar so far',
      image: true,
      child: AvatarFace(url: url, size: 92),
    );
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
    // Back steps through the cards; on the first card it leaves the app
    // (this screen is the root of the onboarding chain).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isSaving) return;
        final runner = _runner.currentState;
        if (runner != null && runner.canGoBack) {
          runner.back();
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
                child: Stack(
                  children: [
                    DeckRunner(
                      key: _runner,
                      eyebrow: 'Chapter I · Who you are',
                      cards: _cards,
                      answers: _answers,
                      leading: DeckLeading.back,
                      busy: _isSaving,
                      onAnswer: _onAnswer,
                      onFinish: _saveToFirestoreAndOpenAvatar,
                      artBuilder: _liveAvatar,
                    ),
                    if (_isSaving)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0xB30B0614),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: AppColors.gold,
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'Drawing your Destiny Card…',
                                  style: TextStyle(
                                    color: deckGoldLight,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
