import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/astrology_utils.dart';
import '../../core/utils/auth_validators.dart';
import '../../core/utils/haptics.dart';
import '../../models/question_model.dart';
import '../../models/question_type.dart';
import '../../services/session_service.dart';
import '../../widgets/app_states.dart';
import '../../widgets/custom_button.dart';
import '../questionnaire/deck/deck_widgets.dart';
import 'auth_router.dart';

/// DOB + 18+ confirmation for accounts that have no DOB yet (Google first
/// login, older accounts) or no profile doc. With [blocked] it only explains
/// that the app is 18+ and offers sign-out.
class AgeGateScreen extends StatefulWidget {
  final bool blocked;

  const AgeGateScreen({super.key, this.blocked = false});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  DateTime? _dob;
  bool _confirmedAdult = false;
  bool _saving = false;
  String? _error;
  late bool _blocked = widget.blocked;

  /// Set once the DOB is saved: the card flips to the sign before routing.
  bool _revealed = false;

  static const _birthQuestion = Question(
    text: 'When were you born?',
    inputType: QuestionType.text,
    icon: '📅',
  );

  @override
  void initState() {
    super.initState();
    final latest = AgePolicy.latestAllowedDob();
    _dob = DateTime(latest.year - 7, latest.month, latest.day);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final dob = _dob;
    if (dob == null) {
      _showError('Please choose your date of birth');
      return;
    }
    if (!AgePolicy.isAdult(dob)) {
      Haptics.warning();
      setState(() => _blocked = true);
      return;
    }
    if (!_confirmedAdult) {
      _showError('Please confirm you are 18 or older');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await AuthRouter.signOutToLogin(context);
      return;
    }

    setState(() => _saving = true);
    try {
      final zodiac = AstrologyUtils.zodiacFromDob(
        AgePolicy.legacyDobFormat.format(dob),
      );
      // Throws offline, which shows the retry error below.
      await SessionService.instance.ensureProfileDefaults(
        user.uid,
        defaults: {
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'signupCompleted': false,
          'mandatoryCompleted': false,
          'discoveryEnabled': false,
          'discoveryPendingOnboarding': true,
        },
        always: AgePolicy.dobFields(dob, zodiac),
      );

      if (!mounted) return;
      Haptics.success();
      setState(() => _revealed = true);
      await Future<void>.delayed(
        MediaQuery.disableAnimationsOf(context)
            ? const Duration(milliseconds: 900)
            : const Duration(milliseconds: 1800),
      );
      if (!mounted) return;
      await AuthRouter.routeCurrentUser(context);
    } catch (_) {
      _showError(
        "We couldn't save your date of birth. Check your connection and try again.",
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Errors show inline above Continue.
  void _showError(String message) {
    if (!mounted) return;
    Haptics.error();
    setState(() => _error = message);
  }

  TextStyle get _titleStyle => GoogleFonts.montserrat(
        color: AppColors.white,
        fontSize: 26,
        fontWeight: FontWeight.w700,
      );

  /// Not signing up after all (e.g. a new Google account): back to login.
  /// Only signs out; continuing with Google later resumes from here.
  void _backToLogin() {
    if (_saving) return;
    AuthRouter.signOutToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    // This screen is the root, so system back would close the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToLogin();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDarkest,
        body: DeckBackground(
          child: SafeArea(
            child: Column(
              children: [
                if (!_blocked)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.white),
                        tooltip: 'Back to login',
                        onPressed: _saving ? null : _backToLogin,
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: _constrained(
                      AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        child: _blocked
                            ? KeyedSubtree(
                                key: const ValueKey('blocked'),
                                child: _buildBlocked(),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('form'),
                                child: _buildForm(),
                              ),
                      ),
                    ),
                  ),
                ),
                _constrained(_buildFooter()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Caps line length on tablets.
  Widget _constrained(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }

  // Calm blocked state: moon art, one sentence, one way out.
  Widget _buildBlocked() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.brandPurple.withOpacity(0.35),
                  AppColors.brandPurple.withOpacity(0.0),
                ],
              ),
            ),
            child: const Icon(
              Icons.nightlight_round,
              size: 56,
              color: AppColors.lavenderLight,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            'Destined is only for adults',
            textAlign: TextAlign.center,
            style: _titleStyle,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'You must be 18 or older to use Destined.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.lavender, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final dob = _dob!;
    final sign = AstrologyUtils.zodiacFromDate(dob);
    final latest = AgePolicy.latestAllowedDob();
    return Column(
      children: [
        Text(
          'PROLOGUE',
          style: deckSerif(15, color: AppColors.gold, italic: true)
              .copyWith(letterSpacing: 4),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text('Your birth card', style: deckSerif(32)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Destined is for adults. We show your age, never your birthday.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.lavender, fontSize: 13.5),
        ),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          tween: Tween(end: _revealed ? 1 : 0),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
          builder: (context, t, _) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateY(t * math.pi),
            child: SizedBox(
              width: 216,
              height: 262,
              child: t < .5
                  ? const CardFront(
                      index: 0,
                      question: _birthQuestion,
                      hint: 'Spin the wheels below',
                      required: true,
                    )
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: CardBack(
                        answer: "You're a $sign",
                        emoji: AstrologyUtils.zodiacEmoji[sign],
                        quip: '${AgePolicy.ageOn(dob)} years of you',
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withOpacity(.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: dob,
              minimumDate: DateTime(1920),
              maximumDate: latest,
              onDateTimeChanged: _saving || _revealed
                  ? (_) {}
                  : (d) => setState(() {
                        _dob = DateTime(d.year, d.month, d.day);
                        _error = null;
                      }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          checked: _confirmedAdult,
          label: "I confirm I'm 18 or older and the date above is correct",
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _saving || _revealed
                ? null
                : () {
                    Haptics.selection();
                    setState(() {
                      _confirmedAdult = !_confirmedAdult;
                      _error = null;
                    });
                  },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withOpacity(.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withOpacity(.35)),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _confirmedAdult ? null : AppColors.surface2,
                      gradient: _confirmedAdult
                          ? const RadialGradient(
                              center: Alignment(-.3, -.4),
                              colors: [
                                Color(0xFFFF7AA8),
                                AppColors.brandMagenta,
                                Color(0xFF7A1C8A),
                              ],
                            )
                          : null,
                      boxShadow: _confirmedAdult
                          ? [
                              BoxShadow(
                                color: AppColors.brandPink.withOpacity(.6),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: _confirmedAdult
                        ? const Text('✦', style: TextStyle(color: Colors.white))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: "I confirm I'm "),
                        TextSpan(
                          text: '18 or older',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' and the date above is correct.'),
                      ]),
                      style: TextStyle(
                        color: AppColors.lavenderLight,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final error = _error;
    final email = FirebaseAuth.instance.currentUser?.email;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocked
            ? [
                CustomButton(
                  text: 'Sign out',
                  type: ButtonType.outline,
                  onPressed: () => AuthRouter.signOutToLogin(context),
                ),
                if (email != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Logged in as $email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 12,
                    ),
                  ),
                ],
              ]
            : [
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: error == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(error),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppBanner(
                            message: error,
                            tone: AppBannerTone.error,
                          ),
                        ),
                ),
                DeckButton(
                  label: _saving || _revealed ? 'Saving…' : 'Reveal my sign ✦',
                  height: 52,
                  onPressed: _saving || _revealed ? null : _submit,
                ),
                const SizedBox(height: 4),
                CustomButton(
                  text: 'Back to login',
                  type: ButtonType.text,
                  onPressed: _saving || _revealed ? null : _backToLogin,
                ),
              ],
      ),
    );
  }
}
