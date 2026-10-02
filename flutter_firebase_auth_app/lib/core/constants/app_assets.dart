/// Asset path constants for images, animations, and icons
class AppAssets {
  // Base paths
  static const String _basePath = 'assets';
  static const String _imagesPath = '$_basePath/images';
  static const String _animationsPath = '$_basePath/animations';
  static const String _iconsPath = '$_basePath/icons';
  static const String _soundsPath = '$_basePath/sounds';
  static const String _fontsPath = '$_basePath/fonts';
  
  // Images
  static const String googleIcon = '$_imagesPath/google_icon.png';
  static const String logo = '$_imagesPath/logo.png';
  static const String defaultAvatar = '$_imagesPath/default_avatar.png';
  
  // Animations (Lottie)
  static const String spaceAnimation = '$_animationsPath/space.json';
  static const String starAnimation = '$_animationsPath/star_animation.json';
  static const String loadingAnimation = '$_animationsPath/loading.json';
  
  // Icons (SVG)
  static const String customHeartIcon = '$_iconsPath/ic_custom_heart.svg';
  
  // Sounds
  static const String incomingCallSound = '$_soundsPath/incoming_call.mp3';
  static const String messageSound = '$_soundsPath/message_notification.mp3';
  static const String clickSound = '$_soundsPath/click.mp3';
  
  // Fonts
  static const String montserratRegular = 'Montserrat-Regular';
  static const String montserratBold = 'Montserrat-Bold';
  static const String montserratMedium = 'Montserrat-Medium';
  static const String montserratSemiBold = 'Montserrat-SemiBold';
  
  // Game assets
  static const String diceSound = '$_soundsPath/dice_roll.mp3';
  static const String winSound = '$_soundsPath/win.mp3';
  static const String loseSound = '$_soundsPath/lose.mp3';

  static const String iconPath = 'assets/images/';
  static const String animationPath = 'assets/animations/';

  // Add Lottie animations
  static const String zodiacAnimation = '${animationPath}zodiac.json';
}