import '../../../models/question_model.dart';
import '../../../models/question_type.dart';
import '../../../models/question_category.dart';
import '../../../models/profile_section_model.dart';

/// Helper class containing all questionnaire questions
/// Converted from QuestionnaireHelper.kt
class QuestionnaireHelper {
  // ==================== SIGNUP QUESTIONS (9 - Current) ====================
  static List<Question> getSignupQuestions() {
    return [
      const Question(
        text: 'Enter your username',
        inputType: QuestionType.text,
        fieldName: 'username',
        category: QuestionCategory.basic,
        icon: '👤',
        helperText: 'This will be your display name. Choose something unique and memorable!',
      ),
      const Question(
        text: 'What is your gender?',
        options: ['Male', 'Female', 'Other'],
        inputType: QuestionType.singleChoice,
        fieldName: 'gender',
        category: QuestionCategory.basic,
        icon: '⚧',
        helperText: 'Helps us show you relevant matches based on your preferences',
      ),
      const Question(
        text: 'What are your areas of interest?',
        options: [
          'Reading',
          'Music',
          'Art',
          'Sports',
          'Tech',
          'Astrology',
          'Romance',
          'Deep Conversations',
          'Stargazing',
          'Mysticism',
          'Travel',
          'Cooking',
          'Dancing',
          'Photography',
          'Gaming',
          'Yoga',
          'Meditation',
        ],
        inputType: QuestionType.multiChoice,
        fieldName: 'interests',
        category: QuestionCategory.entertainment,
        icon: '🎯',
        helperText: 'Find people who share your passions! Select all that apply.',
      ),
      const Question(
        text: 'What are your habits?',
        options: ['Early Riser', 'Night Owl', 'Balanced'],
        inputType: QuestionType.singleChoice,
        fieldName: 'habits',
        category: QuestionCategory.lifestyle,
        icon: '🌙',
        helperText: 'Connect with someone who\'s awake when you are!',
      ),
      const Question(
        text: 'What is your profession?',
        options: [
          'Student',
          'Engineer',
          'Doctor',
          'Artist',
          'Astrology Consultant',
          'Other',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'profession',
        category: QuestionCategory.basic,
        icon: '💼',
        helperText: 'Your profession says a lot about your lifestyle and goals',
      ),
      const Question(
        text: 'What is your sexual activity level?',
        options: ['Low', 'Moderate', 'High'],
        inputType: QuestionType.singleChoice,
        fieldName: 'activityLevel',
        category: QuestionCategory.relationship,
        icon: '💕',
        helperText: 'Match with someone on the same wavelength for better compatibility',
      ),
      const Question(
        text: 'Why did you choose this app?',
        inputType: QuestionType.text,
        fieldName: 'relationshipGoal',
        category: QuestionCategory.relationship,
        icon: '💭',
        helperText: 'Let others know what you\'re looking for - honesty attracts the right people!',
      ),
      const Question(
        text: 'Where are you located?',
        inputType: QuestionType.text,
        fieldName: 'location',
        category: QuestionCategory.basic,
        icon: '📍',
        helperText: 'We\'ll show you people nearby for easier meetups!',
      ),
      const Question(
        text: 'Tell us about yourself (short bio)',
        inputType: QuestionType.text,
        fieldName: 'bio',
        category: QuestionCategory.basic,
        icon: '✍️',
        helperText: 'Your bio is your first impression! Share what makes you unique. (Max 500 words)',
      ),
    ];
  }

  // ==================== POST-SIGNUP MANDATORY (5 Questions) ====================
  static List<Question> getMandatoryQuestions() {
    return [
      const Question(
        text: 'What\'s your relationship status?',
        options: [
          'Single',
          'In a relationship',
          'Divorced',
          'Widowed',
          'Complicated',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'relationshipStatus',
        category: QuestionCategory.relationship,
        isMandatory: true,
        icon: '💑',
        helperText: 'Transparency builds trust. We\'ll match you with compatible people.',
      ),
      const Question(
        text: 'You\'re here for:',
        options: [
          'Dating',
          'Long-term relationship',
          'Friendship',
          'Open for everything',
          'Casual dating',
        ],
        inputType: QuestionType.multiChoice,
        fieldName: 'hereFor',
        category: QuestionCategory.relationship,
        isMandatory: true,
        icon: '🎯',
        helperText: 'Select all that apply - find people looking for the same thing!',
      ),
      const Question(
        text: 'Your height:',
        options: [
          'Below 5\'0"',
          '5\'0" - 5\'3"',
          '5\'4" - 5\'7"',
          '5\'8" - 5\'11"',
          '6\'0" - 6\'3"',
          'Above 6\'3"',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'height',
        category: QuestionCategory.physical,
        isMandatory: true,
        icon: '📏',
        helperText: 'Physical compatibility matters! Help others know what to expect.',
      ),
      const Question(
        text: 'Your body type:',
        options: ['Slim', 'Athletic', 'Average', 'Curvy', 'Heavyset'],
        inputType: QuestionType.singleChoice,
        fieldName: 'bodyType',
        category: QuestionCategory.physical,
        isMandatory: true,
        icon: '🏋️',
        helperText: 'Be honest - confidence is attractive! This helps set realistic expectations.',
      ),
      const Question(
        text: 'Your education:',
        options: [
          'High School',
          'Bachelor\'s',
          'Master\'s',
          'PhD',
          'Diploma',
          'Self-taught',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'education',
        category: QuestionCategory.basic,
        isMandatory: true,
        icon: '🎓',
        helperText: 'Education level helps find intellectually compatible matches',
      ),
    ];
  }

  // ==================== LIFESTYLE SECTION (8 Questions - Optional) ====================
  static List<Question> getLifestyleQuestions() {
    return [
      const Question(
        text: 'Food preference:',
        options: ['Vegetarian', 'Non-vegetarian', 'Vegan', 'Eggetarian'],
        inputType: QuestionType.singleChoice,
        fieldName: 'foodPreference',
        isMandatory: false,
        category: QuestionCategory.lifestyle,
        icon: '🍕',
        helperText: 'Shared food preferences make date planning easier!',
      ),
      const Question(
        text: 'Smoking habits:',
        options: ['Never', 'Socially', 'Regularly', 'Trying to quit'],
        inputType: QuestionType.singleChoice,
        fieldName: 'smokingHabits',
        isMandatory: false,
        category: QuestionCategory.lifestyle,
        icon: '🚬',
        helperText: 'Important for long-term compatibility - be upfront about your habits',
      ),
      const Question(
        text: 'Drinking habits:',
        options: ['Never', 'Socially', 'Regularly', 'Occasionally'],
        inputType: QuestionType.singleChoice,
        fieldName: 'drinkingHabits',
        isMandatory: false,
        category: QuestionCategory.lifestyle,
        icon: '🍷',
        helperText: 'Know if you\'ll enjoy parties together or prefer quiet nights in',
      ),
      const Question(
        text: 'Exercise frequency:',
        options: [
          'Daily',
          '3-4 times/week',
          'Occasionally',
          'Rarely',
          'Never',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'exerciseFrequency',
        isMandatory: false,
        category: QuestionCategory.lifestyle,
        icon: '💪',
        helperText: 'Find a gym buddy or someone who respects your fitness goals!',
      ),
      const Question(
        text: 'Do you have pets?',
        options: [
          'Yes, dog(s)',
          'Yes, cat(s)',
          'Yes, other',
          'No, but I love them',
          'No',
        ],
        inputType: QuestionType.multiChoice,
        fieldName: 'pets',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '🐾',
        helperText: 'Pet lovers unite! Or find someone who shares your pet-free lifestyle.',
      ),
      const Question(
        text: 'Do you want children?',
        options: ['Yes, definitely', 'Yes, someday', 'Not sure', 'No'],
        inputType: QuestionType.singleChoice,
        fieldName: 'wantsChildren',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '👶',
        helperText: 'Crucial for long-term relationships - align on future family plans',
      ),
      const Question(
        text: 'Partying frequency:',
        options: ['Love it, often', 'Occasionally', 'Rarely', 'Never'],
        inputType: QuestionType.singleChoice,
        fieldName: 'partyingFrequency',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '🎉',
        helperText: 'Find someone who matches your social energy!',
      ),
      const Question(
        text: 'Do you have tattoos?',
        options: ['Yes, many', 'Yes, a few', 'Planning to get', 'No'],
        inputType: QuestionType.singleChoice,
        fieldName: 'tattoos',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '🎨',
        helperText: 'Express yourself! Some love ink, others prefer clean skin.',
      ),
    ];
  }

  // ==================== PERSONALITY SECTION (6 Questions - Optional) ====================
  static List<Question> getPersonalityQuestions() {
    return [
      const Question(
        text: 'Your personality type:',
        options: ['Introvert', 'Extrovert', 'Ambivert'],
        inputType: QuestionType.singleChoice,
        fieldName: 'personalityType',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '🧠',
        helperText: 'Find someone who energizes you or appreciates your quiet side!',
      ),
      const Question(
        text: 'Political views:',
        options: [
          'Liberal',
          'Conservative',
          'Moderate',
          'Apolitical',
          'Prefer not to say',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'politicalViews',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '🗳️',
        helperText: 'Avoid awkward debates - find someone on the same page politically',
      ),
      const Question(
        text: 'Religious views:',
        options: [
          'Very religious',
          'Somewhat religious',
          'Spiritual not religious',
          'Agnostic',
          'Atheist',
          'Prefer not to say',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'religiousViews',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '🙏',
        helperText: 'Faith plays a big role in values - find someone who respects yours',
      ),
      const Question(
        text: 'Favorite music genres:',
        options: [
          'Pop',
          'Rock',
          'Hip-Hop',
          'Classical',
          'EDM',
          'Bollywood',
          'Jazz',
          'Country',
          'Indie',
        ],
        inputType: QuestionType.multiChoice,
        fieldName: 'musicGenres',
        isMandatory: false,
        category: QuestionCategory.entertainment,
        icon: '🎵',
        helperText: 'Bond over playlists! Music taste reveals personality.',
      ),
      const Question(
        text: 'Favorite type of movies:',
        options: [
          'Action',
          'Romance',
          'Comedy',
          'Horror',
          'Sci-Fi',
          'Drama',
          'Thriller',
          'Documentary',
          'Bollywood',
          'Hollywood',
        ],
        inputType: QuestionType.multiChoice,
        fieldName: 'movieGenres',
        isMandatory: false,
        category: QuestionCategory.entertainment,
        icon: '🎬',
        helperText: 'Plan perfect movie dates with someone who loves the same genres!',
      ),
      const Question(
        text: 'Favorite TV series genre:',
        options: [
          'Drama',
          'Comedy',
          'Thriller',
          'Sci-Fi',
          'Reality',
          'Anime',
          'Documentary',
        ],
        inputType: QuestionType.multiChoice,
        fieldName: 'tvGenres',
        isMandatory: false,
        category: QuestionCategory.entertainment,
        icon: '📺',
        helperText: 'Binge-watch together! Find your perfect Netflix companion.',
      ),
    ];
  }

  // ==================== 🆕 NEW: PROFILE SECTIONS FOR PROFILE COMPLETION ====================
  static List<ProfileSection> getProfileSections() {
    return [
      ProfileSection(
        title: 'Lifestyle Preferences',
        description: 'Your daily habits and preferences',
        questions: getLifestyleQuestions(),
        category: QuestionCategory.lifestyle,
        isMandatory: false,
        icon: '🌟',
      ),
      ProfileSection(
        title: 'Personality & Views',
        description: 'What makes you unique',
        questions: getPersonalityQuestions(),
        category: QuestionCategory.personality,
        isMandatory: false,
        icon: '💫',
      ),
    ];
  }

  // ==================== ALL SECTIONS ====================
  static List<ProfileSection> getAllSections() {
    return [
      ProfileSection(
        title: 'Lifestyle Preferences',
        description: 'Your daily habits and preferences',
        questions: getLifestyleQuestions(),
        category: QuestionCategory.lifestyle,
        isMandatory: false,
        icon: '🌟',
      ),
      ProfileSection(
        title: 'Personality & Views',
        description: 'What makes you unique',
        questions: getPersonalityQuestions(),
        category: QuestionCategory.personality,
        isMandatory: false,
        icon: '💫',
      ),
    ];
  }

  // ==================== GET ALL QUESTIONS ====================
  static List<Question> getAllQuestions() {
    return [
      ...getSignupQuestions(),
      ...getMandatoryQuestions(),
      ...getLifestyleQuestions(),
      ...getPersonalityQuestions(),
    ];
  }

  // ==================== GET QUESTION BY FIELD NAME ====================
  static Question? getQuestionByFieldName(String fieldName) {
    try {
      return getAllQuestions().firstWhere(
        (q) => q.fieldName == fieldName,
      );
    } catch (e) {
      return null;
    }
  }
}