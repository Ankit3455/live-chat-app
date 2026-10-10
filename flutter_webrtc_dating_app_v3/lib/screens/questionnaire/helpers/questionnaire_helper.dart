import '../../../models/question_model.dart';
import '../../../models/question_type.dart';
import '../../../models/question_category.dart';
import '../../../models/profile_section_model.dart';
import '../../../services/avatar_mapping.dart';

/// Helper class containing all questionnaire questions
/// Converted from QuestionnaireHelper.kt
class QuestionnaireHelper {
  // ==================== SIGNUP QUESTIONS (Chapter I) ====================
  // activityLevel moved to Lifestyle and relationshipGoal to the post-signup
  // chapter; their stored values are unchanged.
  static List<Question> getSignupQuestions() {
    return [
      const Question(
        text: 'What should we call you?',
        inputType: QuestionType.text,
        deckStyle: DeckStyle.write,
        fieldName: 'username',
        category: QuestionCategory.basic,
        icon: '👤',
        placeholder: 'Your display name',
        maxLength: 30,
        minLength: 2,
        helperText:
            'This will be your display name. Choose something unique and memorable!',
      ),
      const Question(
        text: 'You are…',
        options: ['Male', 'Female', 'Other'],
        optionEmojis: ['👨', '👩', '🌈'],
        optionQuips: ['Hello, gentleman', 'Hello, gorgeous', 'Wonderfully you'],
        inputType: QuestionType.singleChoice,
        fieldName: 'gender',
        category: QuestionCategory.basic,
        icon: '⚧',
        helperText:
            'Helps us show you relevant matches based on your preferences',
      ),
      const Question(
        text: 'What lights you up?',
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
          'Movies',
          'Fitness',
          'Foodie',
          'Nature',
          'Fashion',
          'Writing',
          'Pets',
        ],
        maxSelections: 8,
        inputType: QuestionType.multiChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'interests',
        category: QuestionCategory.entertainment,
        icon: '🎯',
        helperText:
            'Find people who share your passions! Select all that apply.',
      ),
      const Question(
        text: 'Morning lark or night owl?',
        options: ['Early Riser', 'Balanced', 'Night Owl'],
        optionEmojis: ['🌅', '🌗', '🦉'],
        optionQuips: [
          'Up with the sun',
          'Best of both',
          'Alive after midnight',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.scale,
        fieldName: 'habits',
        category: QuestionCategory.lifestyle,
        icon: '🌙',
        helperText: 'Connect with someone who\'s awake when you are!',
      ),
      const Question(
        text: 'What do you do?',
        options: [
          'Student',
          'Engineer',
          'IT / Software',
          'Doctor',
          'Healthcare',
          'Business',
          'Finance',
          'Design',
          'Marketing',
          'Teacher',
          'Artist',
          'Government',
          'Self-employed',
          'Astrology Consultant',
          'Other',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'profession',
        category: QuestionCategory.basic,
        icon: '💼',
        helperText: 'Your profession says a lot about your lifestyle and goals',
      ),
      const Question(
        text: 'Which city are you in?',
        inputType: QuestionType.text,
        deckStyle: DeckStyle.write,
        fieldName: 'location',
        category: QuestionCategory.basic,
        icon: '📍',
        placeholder: 'e.g. Pune',
        maxLength: 100,
        minLength: 2,
        ideas: ['Mumbai', 'Delhi', 'Bengaluru', 'Hyderabad', 'Pune', 'Chennai'],
        offersCurrentLocation: true,
        helperText:
            'Your current city. We\'ll show you people nearby for easier meetups!',
      ),
      const Question(
        text: 'Tell your story',
        inputType: QuestionType.text,
        deckStyle: DeckStyle.write,
        fieldName: 'bio',
        category: QuestionCategory.basic,
        icon: '✍️',
        placeholder: 'A few lines about you…',
        maxLength: 500,
        minLength: 10,
        ideas: [
          'My perfect Sunday is…',
          'I\'m happiest when…',
          'Two truths and a lie:',
          'Swipe right if you…',
          'My friends say I\'m…',
        ],
        helperText:
            'Your bio is your first impression! Share what makes you unique. (Max 500 characters)',
      ),
    ];
  }

  // ==================== POST-SIGNUP (Chapter II) ====================
  static List<Question> getMandatoryQuestions() {
    return [
      const Question(
        text: 'Your relationship status',
        options: [
          'Single',
          'In a relationship',
          'Married',
          'Divorced',
          'Widowed',
          'Complicated',
        ],
        optionEmojis: ['🙋', '💞', '💍', '🌱', '🕊️', '🌀'],
        optionQuips: [
          'Ready to mingle',
          'Here for friends',
          'Here for friends',
          'New chapter',
          'Carrying love',
          'It\'s a story',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'relationshipStatus',
        category: QuestionCategory.relationship,
        isMandatory: true,
        icon: '💑',
        helperText:
            'Transparency builds trust. We\'ll match you with compatible people.',
      ),
      const Question(
        text: 'You\'re here for…',
        options: [
          'Dating',
          'Long-term relationship',
          'Friendship',
          'Open for everything',
          'Casual dating',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'hereFor',
        category: QuestionCategory.relationship,
        isMandatory: true,
        icon: '🎯',
        helperText:
            'Pick the one that fits best - find people looking for the same thing!',
      ),
      const Question(
        text: 'How tall are you?',
        options: [
          'Below 5\'0"',
          '5\'0" - 5\'3"',
          '5\'4" - 5\'7"',
          '5\'8" - 5\'11"',
          '6\'0" - 6\'3"',
          'Above 6\'3"',
        ],
        optionEmojis: ['📏', '📏', '📏', '📏', '📏', '📏'],
        optionQuips: [
          'Fun-sized',
          'Petite',
          'Just right',
          'Tall-ish',
          'Tall',
          'Sky high',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.scale,
        fieldName: 'height',
        category: QuestionCategory.physical,
        isMandatory: true,
        icon: '📏',
        helperText:
            'Physical compatibility matters! Help others know what to expect.',
      ),
      const Question(
        text: 'Your body type',
        options: ['Slim', 'Athletic', 'Average', 'Curvy', 'Heavyset'],
        optionEmojis: ['🌿', '💪', '🙂', '⏳', '🐻'],
        optionQuips: [
          'Lean & light',
          'Built to move',
          'Comfortably me',
          'All the curves',
          'Big & cosy',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'bodyType',
        category: QuestionCategory.physical,
        isMandatory: true,
        icon: '🏋️',
        helperText:
            'Be honest - confidence is attractive! This helps set realistic expectations.',
      ),
      const Question(
        text: 'Your education',
        options: [
          'High School',
          'Diploma',
          'Bachelor\'s',
          'Master\'s',
          'PhD',
          'Self-taught',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'education',
        category: QuestionCategory.basic,
        isMandatory: true,
        icon: '🎓',
        helperText:
            'Education level helps find intellectually compatible matches',
      ),
      const Question(
        text: 'Your opening line',
        inputType: QuestionType.text,
        deckStyle: DeckStyle.write,
        fieldName: 'relationshipGoal',
        category: QuestionCategory.relationship,
        isMandatory: false,
        icon: '💭',
        placeholder: 'What are you hoping to find?',
        maxLength: 200,
        ideas: [
          'Looking for my person',
          'A partner in crime for…',
          'Someone who loves…',
        ],
        helperText:
            'Let others know what you\'re looking for - honesty attracts the right people!',
      ),
    ];
  }

  // ==================== LIFESTYLE SECTION (10 Questions - Optional) ====================
  // Stored option strings must not change: existing answers and avatar
  // mapping match on them. Scale options are listed low to high.
  static List<Question> getLifestyleQuestions() {
    return [
      const Question(
        text: 'What fills your plate?',
        options: ['Vegetarian', 'Eggetarian', 'Non-vegetarian', 'Vegan'],
        optionEmojis: ['🥦', '🍳', '🍗', '🌱'],
        optionQuips: [
          'Greens on the first date',
          'Sunny side up',
          'Butter chicken believer',
          'Plant-powered',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'foodPreference',
        isMandatory: false,
        category: QuestionCategory.lifestyle,
        icon: '🍽️',
        helperText: 'Shared food preferences make date planning easier!',
      ),
      const Question(
        text: 'A drink with dinner?',
        options: ['Never', 'Occasionally', 'Socially', 'Regularly'],
        optionEmojis: ['🚫', '🥂', '🍻', '🍷'],
        optionQuips: [
          'Mocktail royalty',
          'Only when it\'s special',
          'Cheers with friends',
          'Wine o\'clock regular',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.scale,
        fieldName: 'drinkingHabits',
        isMandatory: false,
        category: QuestionCategory.lifestyle,
        icon: '🍷',
        helperText:
            'Know if you\'ll enjoy parties together or prefer quiet nights in',
      ),
      const Question(
        text: 'Do you smoke?',
        options: ['Never', 'Socially', 'Regularly', 'Trying to quit'],
        optionEmojis: ['🚭', '💨', '🚬', '💪'],
        optionQuips: [
          'Fresh air only',
          'Now and then',
          'Honest answer',
          'Working on it',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'smokingHabits',
        isMandatory: false,
        category: QuestionCategory.lifestyle,
        icon: '🌫️',
        helperText:
            'Important for long-term compatibility - be upfront about your habits',
      ),
      const Question(
        text: 'How much do you move?',
        options: [
          'Never',
          'Rarely',
          'Occasionally',
          '3-4 times/week',
          'Daily',
        ],
        optionEmojis: ['😴', '🛋️', '🚶', '💪', '🔥'],
        optionQuips: [
          'Couch is cardio',
          'Weekend walker',
          'When the mood hits',
          'Consistent grinder',
          'Gym is home',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.scale,
        fieldName: 'exerciseFrequency',
        isMandatory: false,
        category: QuestionCategory.lifestyle,
        icon: '🏃',
        helperText:
            'Find a gym buddy or someone who respects your fitness goals!',
      ),
      const Question(
        text: 'Your party energy',
        options: ['Never', 'Rarely', 'Occasionally', 'Love it, often'],
        optionEmojis: ['📚', '🏡', '🎶', '🪩'],
        optionQuips: [
          'Books over bars',
          'Cosy nights in',
          'Good party, sometimes',
          'Last one on the floor',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.scale,
        fieldName: 'partyingFrequency',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '🪩',
        helperText: 'Find someone who matches your social energy!',
      ),
      const Question(
        text: 'Your pace in romance',
        options: ['Low', 'Moderate', 'High'],
        optionEmojis: ['🐢', '🌿', '🔥'],
        optionQuips: ['Slow & steady', 'Go with the flow', 'All in'],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.scale,
        fieldName: 'activityLevel',
        isMandatory: false,
        category: QuestionCategory.relationship,
        icon: '💕',
        helperText:
            'Match with someone on the same wavelength for better compatibility',
      ),
      const Question(
        text: 'Any ink?',
        options: ['No', 'Planning to get', 'Yes, a few', 'Yes, many'],
        optionEmojis: ['✨', '🤔', '✒️', '🐉'],
        optionQuips: [
          'Clean canvas',
          'Design in mind',
          'A few stories',
          'Walking gallery',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'tattoos',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '🖋️',
        helperText:
            'Express yourself! Some love ink, others prefer clean skin.',
      ),
      const Question(
        text: 'Pets in your life?',
        options: [
          'Yes, dog(s)',
          'Yes, cat(s)',
          'Yes, other',
          'No, but I love them',
          'No',
        ],
        optionEmojis: ['🐶', '🐱', '🐰', '🥰', '🙅'],
        exclusiveOptions: ['No'],
        inputType: QuestionType.multiChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'pets',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '🐾',
        helperText:
            'Pet lovers unite! Or find someone who shares your pet-free lifestyle.',
      ),
      const Question(
        text: 'Do you have children?',
        options: [
          'No',
          'Yes, they live with me',
          'Yes, they don\'t live with me',
          'Prefer not to say',
        ],
        optionEmojis: ['🙂', '🏠', '🤍', '🤫'],
        optionQuips: [
          'Not yet',
          'Family first',
          'Parent at heart',
          'Let\'s talk later',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'hasChildren',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '👨‍👧',
        helperText: 'Being upfront about family builds trust early.',
      ),
      const Question(
        text: 'Kids in your future?',
        options: ['Yes, definitely', 'Yes, someday', 'Not sure', 'No'],
        optionEmojis: ['💯', '🌤️', '🤷', '🙅'],
        optionQuips: [
          'Can\'t wait',
          'When it\'s right',
          'Open book',
          'Happy as is',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'wantsChildren',
        isMandatory: false,
        category: QuestionCategory.preferences,
        icon: '👶',
        helperText:
            'Crucial for long-term relationships - align on future family plans',
      ),
    ];
  }

  // ==================== PERSONALITY SECTION (10 Questions - Optional) ====================
  static List<Question> getPersonalityQuestions() {
    return [
      const Question(
        text: 'Your social battery',
        options: ['Introvert', 'Ambivert', 'Extrovert'],
        optionEmojis: ['🌙', '🌗', '☀️'],
        optionQuips: [
          'Recharges in quiet',
          'Best of both',
          'Lights up a room',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.scale,
        fieldName: 'personalityType',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '🔋',
        helperText:
            'Find someone who energizes you or appreciates your quiet side!',
      ),
      const Question(
        text: 'How do you like to talk?',
        options: [
          'Big texter',
          'Phone caller',
          'Video chatter',
          'Better in person',
        ],
        optionEmojis: ['💬', '📞', '🎥', '☕'],
        optionQuips: [
          'Paragraphs & memes',
          'Just call me',
          'Face to face, online',
          'Let\'s grab coffee',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'communicationStyle',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '💬',
        helperText: 'Sets expectations before the first message.',
      ),
      const Question(
        text: 'Your love language',
        options: [
          'Quality time',
          'Words of affirmation',
          'Physical touch',
          'Acts of service',
          'Gifts',
        ],
        optionEmojis: ['⏳', '💌', '🤗', '🛠️', '🎁'],
        optionQuips: [
          'Be here, fully',
          'Say it out loud',
          'Hugs fix things',
          'Actions speak',
          'Thoughtful surprises',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'loveLanguage',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '💝',
        helperText: 'How you like to give and receive love.',
      ),
      const Question(
        text: 'Your faith',
        options: [
          'Hindu',
          'Muslim',
          'Sikh',
          'Christian',
          'Jain',
          'Buddhist',
          'Spiritual',
          'None',
          'Other',
          'Prefer not to say',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'religion',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '🕊️',
        helperText: 'Share only if you\'re comfortable.',
      ),
      const Question(
        text: 'How religious are you?',
        options: [
          'Very religious',
          'Somewhat religious',
          'Spiritual not religious',
          'Agnostic',
          'Atheist',
          'Prefer not to say',
        ],
        optionEmojis: ['📿', '🪔', '🌌', '❔', '🔬', '🤫'],
        optionQuips: [
          'Faith guides me',
          'Festivals & family',
          'My own path',
          'Still wondering',
          'Science first',
          'Ask me later',
        ],
        inputType: QuestionType.singleChoice,
        fieldName: 'religiousViews',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '🙏',
        helperText:
            'Faith plays a big role in values - find someone who respects yours',
      ),
      const Question(
        text: 'Politics?',
        options: [
          'Liberal',
          'Moderate',
          'Conservative',
          'Apolitical',
          'Prefer not to say',
        ],
        inputType: QuestionType.singleChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'politicalViews',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '🗳️',
        helperText:
            'Avoid awkward debates - find someone on the same page politically',
      ),
      const Question(
        text: 'Languages you date in',
        options: [
          'Hindi',
          'English',
          'Bengali',
          'Marathi',
          'Telugu',
          'Tamil',
          'Gujarati',
          'Urdu',
          'Kannada',
          'Malayalam',
          'Punjabi',
          'Odia',
          'Assamese',
          'Other',
        ],
        maxSelections: 5,
        inputType: QuestionType.multiChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'languages',
        isMandatory: false,
        category: QuestionCategory.personality,
        icon: '🗣️',
        helperText: 'Languages you\'d happily chat and date in.',
      ),
      const Question(
        text: 'Music on repeat',
        options: [
          'Bollywood',
          'Pop',
          'Hip-Hop',
          'Indie',
          'Rock',
          'EDM',
          'Classical',
          'Jazz',
          'Country',
        ],
        maxSelections: 5,
        inputType: QuestionType.multiChoice,
        deckStyle: DeckStyle.stickers,
        fieldName: 'musicGenres',
        isMandatory: false,
        category: QuestionCategory.entertainment,
        icon: '🎧',
        helperText: 'Bond over playlists! Music taste reveals personality.',
      ),
      const Question(
        text: 'Movie night pick?',
        options: [
          'Action',
          'Romance',
          'Comedy',
          'Thriller',
          'Horror',
          'Sci-Fi',
          'Drama',
          'Documentary',
          'Bollywood',
          'Hollywood',
        ],
        maxSelections: 5,
        inputType: QuestionType.multiChoice,
        deckStyle: DeckStyle.stickers,
        deckGroup: 'screen',
        deckLabel: 'Movies',
        fieldName: 'movieGenres',
        isMandatory: false,
        category: QuestionCategory.entertainment,
        icon: '🍿',
        helperText:
            'Plan perfect movie dates with someone who loves the same genres!',
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
        maxSelections: 5,
        inputType: QuestionType.multiChoice,
        deckStyle: DeckStyle.stickers,
        deckGroup: 'screen',
        deckLabel: 'Series',
        fieldName: 'tvGenres',
        isMandatory: false,
        category: QuestionCategory.entertainment,
        icon: '📺',
        helperText:
            'Binge-watch together! Find your perfect Netflix companion.',
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
        title: 'Personality & Values',
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
        title: 'Personality & Values',
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

  /// Avatar properties in the shape DiceBearAvatarService stores.
  static Map<String, dynamic> buildAvatarProperties(
      Map<String, dynamic> answers) {
    return AvatarMapping.buildFromAnswers(answers);
  }
}
