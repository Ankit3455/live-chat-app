import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';

/// App-wide theme converted from themes.xml and style.xml
class AppTheme {
  /// Main dark theme for the app
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Primary colors
      primaryColor: AppColors.purplePrimary,
      scaffoldBackgroundColor: AppColors.appBackground,
      
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.purplePrimary,
        secondary: AppColors.purpleSecondary,
        surface: AppColors.inputBackground,
        background: AppColors.appBackground,
        error: AppColors.dangerRed,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.inputTextWhite,
        onBackground: AppColors.inputTextWhite,
        onError: AppColors.white,
      ),
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.purpleSecondary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        iconTheme: IconThemeData(
          color: AppColors.white,
          size: AppDimens.iconSizeNormal,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontSize: AppDimens.textSizeTitleLarge,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
      ),
      
      // Card theme
      cardTheme: CardThemeData (
        color: AppColors.inputBackground,
        elevation: AppDimens.cardElevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
        ),
        margin: const EdgeInsets.symmetric(
          vertical: AppDimens.marginSmall,
          horizontal: AppDimens.marginNormal,
        ),
      ),
      
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purplePrimary,
          foregroundColor: AppColors.buttonTextWhite,
          disabledBackgroundColor: AppColors.purplePressed,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.paddingNormal,
            horizontal: AppDimens.paddingLarge,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: AppDimens.textSizeBodyLarge,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.purpleSecondary,
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.paddingMedium,
            horizontal: AppDimens.paddingNormal,
          ),
          textStyle: const TextStyle(
            fontSize: AppDimens.textSizeBody,
            fontWeight: FontWeight.w600,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.purpleSecondary,
          side: const BorderSide(color: AppColors.purpleSecondary, width: 2),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.paddingNormal,
            horizontal: AppDimens.paddingLarge,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
          ),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        hintStyle: const TextStyle(
          color: AppColors.hintPurple,
          fontSize: AppDimens.textSizeBody,
          fontFamily: 'Montserrat',
        ),
        labelStyle: const TextStyle(
          color: AppColors.hintPurple,
          fontSize: AppDimens.textSizeBody,
          fontFamily: 'Montserrat',
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.purpleSecondary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.dangerRed,
            width: 2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.dangerRed,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppDimens.paddingNormal,
          horizontal: AppDimens.paddingNormal,
        ),
      ),
      
      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.inputBackground,
        selectedItemColor: AppColors.bottomNavActive,
        unselectedItemColor: AppColors.bottomNavInactive,
        selectedLabelStyle: TextStyle(
          fontSize: AppDimens.textSizeCaption,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: AppDimens.textSizeCaption,
          fontFamily: 'Montserrat',
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Drawer theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.appBackground,
        elevation: 16,
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerGray,
        thickness: AppDimens.dividerThickness,
        space: 1,
      ),
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: AppDimens.textSizeDisplay,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
          fontFamily: 'Montserrat',
        ),
        displayMedium: TextStyle(
          fontSize: AppDimens.textSizeHeadline,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
          fontFamily: 'Montserrat',
        ),
        headlineMedium: TextStyle(
          fontSize: AppDimens.textSizeTitleLarge,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
          fontFamily: 'Montserrat',
        ),
        titleLarge: TextStyle(
          fontSize: AppDimens.textSizeTitle,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
          fontFamily: 'Montserrat',
        ),
        titleMedium: TextStyle(
          fontSize: AppDimens.textSizeBodyLarge,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
          fontFamily: 'Montserrat',
        ),
        bodyLarge: TextStyle(
          fontSize: AppDimens.textSizeBodyLarge,
          color: AppColors.inputTextWhite,
          fontFamily: 'Montserrat',
        ),
        bodyMedium: TextStyle(
          fontSize: AppDimens.textSizeBody,
          color: AppColors.inputTextWhite,
          fontFamily: 'Montserrat',
        ),
        bodySmall: TextStyle(
          fontSize: AppDimens.textSizeCaption,
          color: AppColors.hintPurple,
          fontFamily: 'Montserrat',
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.white,
        size: AppDimens.iconSizeNormal,
      ),
      
      // Font family
      fontFamily: 'Montserrat',
    );
  }
  
  /// Custom text styles (from style.xml)
  static const TextStyle interestTagStyle = TextStyle(
    color: AppColors.white,
    fontSize: AppDimens.textSizeBody,
    fontFamily: 'Montserrat',
  );
  
  static const TextStyle settingsSectionTitleStyle = TextStyle(
    color: AppColors.hintPurple,
    fontSize: AppDimens.textSizeTitle,
    fontWeight: FontWeight.bold,
    fontFamily: 'Montserrat',
  );
  
  static const TextStyle settingsCardTitleStyle = TextStyle(
    color: AppColors.inputTextWhite,
    fontSize: AppDimens.textSizeBodyLarge,
    fontFamily: 'Montserrat',
  );
  
  static const TextStyle settingsCardSubtitleStyle = TextStyle(
    color: AppColors.hintPurple,
    fontSize: AppDimens.textSizeBody,
    fontFamily: 'Montserrat',
  );
  
  /// Custom decoration for interest tags
  static BoxDecoration get interestTagDecoration {
    return BoxDecoration(
      gradient: AppColors.purpleGradient,
      borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
    );
  }
  
  /// Custom decoration for settings cards
  static BoxDecoration get settingsCardDecoration {
    return BoxDecoration(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
    );
  }
}