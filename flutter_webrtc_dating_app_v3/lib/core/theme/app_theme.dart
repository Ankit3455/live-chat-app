import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';

/// App-wide theme: one Destined palette (dark purple + pink glow).
class AppTheme {
  /// Montserrat loaded through google_fonts (it is not bundled as an asset).
  static final String? fontFamily = GoogleFonts.montserrat().fontFamily;

  /// Main dark theme for the app
  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      
      // Primary colors
      primaryColor: AppColors.purplePrimary,
      scaffoldBackgroundColor: AppColors.appBackground,
      
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandPurple,
        primaryContainer: AppColors.purplePressed,
        onPrimaryContainer: AppColors.white,
        secondary: AppColors.purpleSecondary,
        tertiary: AppColors.brandPink,
        onTertiary: AppColors.white,
        surface: AppColors.surfaceCard,
        surfaceContainerHighest: AppColors.inputBackground,
        onSurfaceVariant: AppColors.lavender,
        background: AppColors.appBackground,
        outline: AppColors.lavender,
        error: AppColors.dangerRed,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.inputTextWhite,
        onBackground: AppColors.inputTextWhite,
        onError: AppColors.white,
      ),
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.white,
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
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandPurpleLight,
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.paddingMedium,
            horizontal: AppDimens.paddingNormal,
          ),
          textStyle: const TextStyle(
            fontSize: AppDimens.textSizeBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandPurpleLight,
          side: const BorderSide(color: AppColors.brandPurpleLight, width: 2),
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
        ),
        labelStyle: const TextStyle(
          color: AppColors.hintPurple,
          fontSize: AppDimens.textSizeBody,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.brandPurpleLight,
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
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: AppDimens.textSizeCaption,
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
        ),
        displayMedium: TextStyle(
          fontSize: AppDimens.textSizeHeadline,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: AppDimens.textSizeTitleLarge,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        titleLarge: TextStyle(
          fontSize: AppDimens.textSizeTitle,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        titleMedium: TextStyle(
          fontSize: AppDimens.textSizeBodyLarge,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: AppDimens.textSizeBodyLarge,
          color: AppColors.inputTextWhite,
        ),
        bodyMedium: TextStyle(
          fontSize: AppDimens.textSizeBody,
          color: AppColors.inputTextWhite,
        ),
        bodySmall: TextStyle(
          fontSize: AppDimens.textSizeCaption,
          color: AppColors.hintPurple,
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.white,
        size: AppDimens.iconSizeNormal,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusSmall),
        ),
        textStyle: const TextStyle(color: AppColors.white, fontSize: 13),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandPurpleLight,
      ),

      fontFamily: fontFamily,
    );

    return base.copyWith(
      textTheme: GoogleFonts.montserratTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.montserratTextTheme(base.primaryTextTheme),
    );
  }
  
  /// Custom text styles (from style.xml)
  static const TextStyle interestTagStyle = TextStyle(
    color: AppColors.white,
    fontSize: AppDimens.textSizeBody,
  );
  
  static const TextStyle settingsSectionTitleStyle = TextStyle(
    color: AppColors.hintPurple,
    fontSize: AppDimens.textSizeTitle,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle settingsCardTitleStyle = TextStyle(
    color: AppColors.inputTextWhite,
    fontSize: AppDimens.textSizeBodyLarge,
  );
  
  static const TextStyle settingsCardSubtitleStyle = TextStyle(
    color: AppColors.hintPurple,
    fontSize: AppDimens.textSizeBody,
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