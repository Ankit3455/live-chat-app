import 'package:flutter/material.dart';

/// App-wide colour constants. The Destined palette below is the single source
/// for screens; legacy names further down alias into it.
class AppColors {
  // Destined palette
  // brandPurple is for fills; use brandPurpleLight for text/icons on dark.
  static const Color brandPurple = Color(0xFF7B2CBF);
  static const Color brandPurpleMid = Color(0xFF9D4EDD);
  static const Color brandPurpleLight = Color(0xFFC77DFF);
  static const Color brandViolet = Color(0xFF9333EA);
  static const Color brandMagenta = Color(0xFF9C27B0);
  static const Color brandPink = Color(0xFFEC4899); // glow accent
  static const Color backgroundDeep = Color(0xFF1A0E2E);
  static const Color backgroundDarkest = Color(0xFF0D0221);
  static const Color surfaceCard = Color(0xFF2D1B4E);
  static const Color surfaceRaised = Color(0xFF1C1033);
  static const Color lavender = Color(0xFFB39DDB); // secondary text, >= 5.8:1
  static const Color lavenderLight = Color(0xFFD1C4E9);
  static const Color textMuted = Color(0xB3FFFFFF); // white70, helper text
  static const Color online = Color(0xFF00E676);
  static const Color onlineDeep = Color(0xFF00C853);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color gold = Color(0xFFFFD700);

  // Purple shades
  static const Color purple200 = Color(0xFFBB86FC);
  static const Color purple500 = Color(0xFF6200EE);
  static const Color purple700 = Color(0xFF3700B3);
  
  // Teal shades
  static const Color teal200 = Color(0xFF03DAC5);
  
  // Basic colors
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  
  // Call colors
  static const Color callRed = Color(0xFFD32F2F);
  static const Color callBgDark = Color(0xFF444444);
  
  // Custom theme colors
  static const Color blackcurrant = Color(0xFF35293A);
  static const Color electricViolet = Color(0xFFA725E7);
  static const Color rum = Color(0xFF755A84);
  static const Color wisteria = Color(0xFF9269A7);
  static const Color mulledWine = Color(0xFF5A4664);
  static const Color manatee = Color(0xFF949497);
  static const Color cinder = Color(0xFF050508);
  static const Color fedora = Color(0xFF6C646C);
  static const Color midGray = Color(0xFF64646B);
  static const Color abbey = Color(0xFF4C4C54);
  
  // App background & primary colors
  static const Color appBackground = backgroundDeep;
  static const Color purplePrimary = brandPurple;
  static const Color purpleSecondary = brandPurpleMid;
  static const Color buttonTextWhite = Color(0xFFFFFFFF);
  
  // Input field colors
  static const Color hintPurple = lavender;
  static const Color inputTextWhite = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFF3A2150);
  static const Color purplePressed = Color(0xFF5A1F8C);
  static const Color outlinePressedBg = Color(0xFF35293A);
  
  // Status colors
  static const Color passColor = Color(0xFFFF5252);
  static const Color connectColor = Color(0xFF4CAF50);
  
  // UI element colors
  static const Color darkGray = Color(0xFF1E1E1E);
  static const Color dividerGray = Color(0x33FFFFFF); // Semi-transparent white
  static const Color dangerRed = Color(0xFFFF3B30);
  static const Color accentPurple = Color(0xFF9C4DFF);
  static const Color navInactive = Color(0xFF9E9E9E);
  static const Color bottomNavRipple = Color(0x33FFFFFF);
  static const Color navPrimary = Color(0xFFFF7DFF);
  
  // Material color shades
  static const Color green500 = Color(0xFF4CAF50);
  static const Color blue500 = Color(0xFF2196F3);
  static const Color red500 = Color(0xFFF44336);
  static const Color orange500 = Color(0xFFFF9800);
  static const Color grey500 = Color(0xFF9E9E9E);
  
  // Chat colors
  static const Color chatBackground = Color(0xFFFAFAFA);
  static const Color messageBubbleSent = Color(0xFFE3F2FD);
  static const Color messageBubbleReceived = Color(0xFFFFFFFF);
  
  // Royal theme colors
  static const Color royalBlueDark = Color(0xFF1A237E);
  static const Color royalBlueMedium = Color(0xFF283593);
  static const Color royalBlueLight = Color(0xFF303F9F);
  static const Color royalGold = gold;
  static const Color royalPurple = Color(0xFF4A148C);
  static const Color royalRed = Color(0xFFB71C1C);
  static const Color royalGreen = Color(0xFF1B5E20);
  
  // Basic palette
  static const Color orange = Color(0xFFFF9800);
  static const Color green = Color(0xFF4CAF50);
  static const Color red = Color(0xFFF44336);
  static const Color blue = Color(0xFF2196F3);
  
  // Bottom navigation
  static const Color bottomNavTopDivider = Color(0x335A4664);
  static const Color bottomNavActive = brandPurpleLight;
  static const Color bottomNavInactive = lavender;
  
  // Google branding
  static const Color googleBlue = Color(0xFF4285F4);
  
  // Gradients
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [brandPurple, brandPurpleMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [brandPurple, brandPurpleMid],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [surfaceCard, backgroundDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Convenience aliases for chat system
  static const Color primary = purplePrimary;
  static const Color secondary = purpleSecondary;
  static const Color background = appBackground;
  static const Color surface = inputBackground;
  static const Color textPrimary = inputTextWhite;
  static const Color textSecondary = hintPurple;
}