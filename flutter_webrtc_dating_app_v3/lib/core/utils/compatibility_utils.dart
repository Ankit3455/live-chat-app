import '../../models/user_model.dart';
import 'dart:math';

/// Kotlin वाले logic का Flutter port (70% astrology + 30% basics)
int calculateCompatibility(UserModel? currentUser, UserModel other) {
  if (currentUser == null) return 0;

  int astroScore = 0, astroTotal = 0;
  int basicScore = 0, basicTotal = 0;

  // ---- Astrology (70) ----
  astroTotal += 20; // preferredSigns
  if (currentUser.preferredSigns.isNotEmpty && other.preferredSigns.isNotEmpty) {
    final common = currentUser.preferredSigns.toSet().intersection(other.preferredSigns.toSet());
    if (common.isNotEmpty) astroScore += 20;
  }

  astroTotal += 10; // astrologyBeliefLevel
  if ((currentUser.astrologyBeliefLevel ?? '') == (other.astrologyBeliefLevel ?? '')) astroScore += 10;

  astroTotal += 5; // believesInAstrology
  if (currentUser.believesInAstrology == other.believesInAstrology) astroScore += 5;

  astroTotal += 10; // personalityPriority
  if ((currentUser.personalityPriority ?? '').toLowerCase() ==
      (other.personalityPriority ?? '').toLowerCase()) astroScore += 10;

  astroTotal += 10; // relationshipPriority
  if ((currentUser.relationshipPriority ?? '').toLowerCase() ==
      (other.relationshipPriority ?? '').toLowerCase()) astroScore += 10;

  astroTotal += 5; // vibePreference
  if ((currentUser.vibePreference ?? '').toLowerCase() ==
      (other.vibePreference ?? '').toLowerCase()) astroScore += 5;

  astroTotal += 5; // lifestyle / sleepSchedule
  final lifeA = (currentUser.lifestyle ?? currentUser.sleepSchedule ?? '').toLowerCase();
  final lifeB = (other.lifestyle ?? other.sleepSchedule ?? '').toLowerCase();
  if (lifeA.isNotEmpty && lifeA == lifeB) astroScore += 5;

  astroTotal += 5; // idealDate
  if ((currentUser.idealDate ?? '').toLowerCase() == (other.idealDate ?? '').toLowerCase()) astroScore += 5;

  // ---- Basics (30) ----
  basicTotal += 10; // interests
  if (currentUser.interests.isNotEmpty && other.interests.isNotEmpty) {
    final common = currentUser.interests.toSet().intersection(other.interests.toSet());
    basicScore += (10 * common.length) ~/ max(currentUser.interests.length, 1);
  }

  basicTotal += 5; // profession
  if ((currentUser.profession ?? '').toLowerCase() == (other.profession ?? '').toLowerCase()) basicScore += 5;

  basicTotal += 5; // habits
  if ((currentUser.habits ?? '').toLowerCase() == (other.habits ?? '').toLowerCase()) basicScore += 5;

  basicTotal += 5; // activityLevel
  if ((currentUser.activityLevel ?? '').toLowerCase() == (other.activityLevel ?? '').toLowerCase()) basicScore += 5;

  basicTotal += 3; // location
  if ((currentUser.location ?? '').toLowerCase() == (other.location ?? '').toLowerCase()) basicScore += 3;

  basicTotal += 2; // relationshipGoal
  if ((currentUser.relationshipGoal ?? '').toLowerCase() == (other.relationshipGoal ?? '').toLowerCase()) basicScore += 2;

  final astroPercent = astroTotal > 0 ? (astroScore * 100 ~/ astroTotal) : 0;
  final basicPercent = basicTotal > 0 ? (basicScore * 100 ~/ basicTotal) : 0;

  return ((astroPercent * 0.7) + (basicPercent * 0.3)).toInt();
}
