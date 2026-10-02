/// App-wide string constants converted from strings.xml
class AppStrings {
  // Common actions
  static const String next = 'Next';
  static const String back = 'Back';
  static const String save = 'Save';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String submit = 'Submit';
  
  // App info
  static const String appName = 'Destined';
  
  // Navigation
  static const String peopleSearch = 'People search';
  static const String open = 'Open Drawer';
  static const String close = 'Close Drawer';
  static const String settings = 'Settings';
  
  // Authentication
  static const String forgotPasswordText = 'Forgot Password?';
  static const String signupText = 'Sign Up';
  
  // Astrology questionnaire
  static const String astrologyPreferences = 'Astrology Preferences';
  static const String whatIsYourDob = 'What is your Date of Birth?';
  static const String selectYourSunSign = 'Select your Sun Sign';
  static const String preferredSigns = 'Preferred Signs (pick any)';
  static const String doYouBelieveInAstrology = 'Do you believe in astrology?';
  static const String whichTraitIsMostImportant = 'Which trait is most important?';
  
  // Step questions
  static const String howStronglyBelieve = 'How strongly do you believe in astrology?';
  static const String relationshipPriorities = 'What matters most in a partner?';
  static const String vibePreference = 'Which energy attracts you more?';
  static const String lifestyleAlignment = 'Are you more of a night person or morning person?';
  static const String idealDate = 'If we match, what\'s your ideal first date?';
  
  // Call status
  static const String callRinging = 'Ringing…';
  static const String callInProgress = 'Call in progress';
  
  // Firebase
  static const String defaultWebClientId = '179987163172-4j1tnbeov5kejo7le97ni65iasougv7j.apps.googleusercontent.com';
  
  // Zodiac signs
  static const List<String> zodiacSigns = [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces',
  ];
  
  // Belief level options (StepSix)
  static const List<String> beliefLevelOptions = [
    'Not at all',
    'Somewhat',
    'Strongly',
  ];
  
  // Relationship priority options (StepSeven)
  static const List<String> relationshipPriorityOptions = [
    'Personality',
    'Looks',
    'Career',
    'Astrology compatibility',
  ];
  
  // Vibe options (StepEight)
  static const List<String> vibeOptions = [
    'Calm & Stable',
    'Adventurous & Bold',
    'Caring & Emotional',
    'Practical & Ambitious',
  ];
  
  // Lifestyle options (StepNine)
  static const List<String> lifestyleOptions = [
    'Morning Person ☀️',
    'Night Person 🌙',
  ];
  
  // Ideal date options (StepTen)
  static const List<String> idealDateOptions = [
    'Coffee',
    'Adventure',
    'Long Drive',
    'Movie',
    'Dinner',
  ];
}