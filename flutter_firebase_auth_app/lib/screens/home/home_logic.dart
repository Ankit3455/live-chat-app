import '../../models/user_model.dart';

String getUserInitial(UserModel? user) {
  if (user == null || user.username.isEmpty) return 'U';
  return user.username[0].toUpperCase();
}

String getProfileCompletionMessage(int completion) {
  if (completion >= 80) {
    return '🎉 Almost there! Complete your profile to get 5x more matches!';
  } else if (completion >= 60) {
    return '✨ Great start! Add more details to attract better matches.';
  } else {
    return '🚀 Complete your profile to unlock premium features!';
  }
}
