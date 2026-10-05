import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';

/// App-wide theme built on the Destined design system
/// (destined-ui-design/css/design-system.css): night-purple surfaces,
/// violet → pink gradient CTAs, gold only for zodiac/compatibility,
/// Montserrat headings and Inter body text.
class AppTheme {
  AppTheme._();

  // Built once: each build creates dozens of GoogleFonts TextStyles.
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    const scheme = ColorScheme.dark(
      primary: AppColors.brandPurple,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.purplePressed,
      onPrimaryContainer: AppColors.white,
      secondary: AppColors.brandPurpleMid,
      onSecondary: AppColors.white,
      tertiary: AppColors.brandPink,
      onTertiary: AppColors.white,
      surface: AppColors.surfaceCard,
      onSurface: AppColors.white,
      surfaceContainerHighest: AppColors.surface2,
      onSurfaceVariant: AppColors.lavender,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: AppColors.backgroundDeep,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: AppColors.backgroundDeep,
      canvasColor: AppColors.backgroundDeep,
      splashFactory: InkSparkle.splashFactory,
    );

    // Inter for body, Montserrat for display/headline/title roles.
    final body = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.white,
      displayColor: AppColors.white,
    );
    final heading = GoogleFonts.montserratTextTheme(base.textTheme).apply(
      bodyColor: AppColors.white,
      displayColor: AppColors.white,
    );
    final textTheme = body.copyWith(
      displayLarge: heading.displayLarge?.copyWith(fontWeight: FontWeight.w800),
      displayMedium:
          heading.displayMedium?.copyWith(fontWeight: FontWeight.w800),
      displaySmall: heading.displaySmall
          ?.copyWith(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2),
      headlineLarge:
          heading.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: heading.headlineMedium
          ?.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25),
      headlineSmall: heading.headlineSmall
          ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
      titleLarge: heading.titleLarge
          ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.35,
        color: AppColors.textSubtle,
      ),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    final buttonText = GoogleFonts.montserrat(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.15,
    );
    final mdRadius = BorderRadius.circular(AppDimens.borderRadiusMedium);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        iconTheme: const IconThemeData(color: AppColors.white, size: 22),
        titleTextStyle: GoogleFonts.montserrat(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          vertical: AppDimens.marginSmall,
          horizontal: AppDimens.marginNormal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusLarge),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPurple,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.surface2,
          disabledForegroundColor: AppColors.textSubtle,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandPurple,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.surface2,
          disabledForegroundColor: AppColors.textSubtle,
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.surfaceCard,
          disabledForegroundColor: AppColors.textSubtle,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandPurpleLight,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.white,
          highlightColor: AppColors.brandPurpleLight.withOpacity(0.12),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        isDense: false,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        hintStyle: GoogleFonts.inter(color: AppColors.textSubtle, fontSize: 15),
        labelStyle: GoogleFonts.inter(color: AppColors.lavender, fontSize: 14),
        floatingLabelStyle:
            GoogleFonts.inter(color: AppColors.brandPurpleLight, fontSize: 14),
        helperStyle:
            GoogleFonts.inter(color: AppColors.textSubtle, fontSize: 12),
        errorStyle: GoogleFonts.inter(color: AppColors.error, fontSize: 12),
        prefixIconColor: AppColors.textSubtle,
        suffixIconColor: AppColors.textSubtle,
        border: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide:
              const BorderSide(color: AppColors.brandPurpleMid, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceCard,
        selectedColor: AppColors.brandPurple.withOpacity(0.18),
        disabledColor: AppColors.surface2,
        checkmarkColor: AppColors.brandPurpleLight,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.inter(
          color: AppColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: AppColors.brandPurpleLight,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceRaised,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.borderRadiusXLarge),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: GoogleFonts.montserrat(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.lavender,
          fontSize: 14,
          height: 1.45,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface2,
        contentTextStyle:
            GoogleFonts.inter(color: AppColors.white, fontSize: 14),
        actionTextColor: AppColors.brandPurpleLight,
        shape: RoundedRectangleBorder(
          borderRadius: mdRadius,
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.lavender,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandPurple
              : AppColors.surface2,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandPurpleMid
              : AppColors.borderStrong,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandPurple
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brandPurpleMid
              : AppColors.borderStrong,
        ),
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.brandPurpleMid,
        inactiveTrackColor: AppColors.surface2,
        thumbColor: AppColors.white,
        overlayColor: Color(0x338B5CF6),
        valueIndicatorColor: AppColors.surface2,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.lavender,
        indicatorColor: AppColors.brandPink,
        dividerColor: AppColors.border,
        labelStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        selectedItemColor: AppColors.pinkLight,
        unselectedItemColor: AppColors.textSubtle,
        selectedLabelStyle:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: AppColors.lavender,
        textColor: AppColors.white,
        minVerticalPadding: 12,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle:
            GoogleFonts.inter(color: AppColors.lavender, fontSize: 13),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: mdRadius,
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: GoogleFonts.inter(color: AppColors.white, fontSize: 14),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
      ),

      iconTheme: const IconThemeData(color: AppColors.white, size: 22),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppDimens.borderRadiusSmall),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: GoogleFonts.inter(color: AppColors.white, fontSize: 13),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandPurpleLight,
        linearTrackColor: AppColors.surface2,
        circularTrackColor: Colors.transparent,
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.brandPurpleLight,
        selectionColor: Color(0x558B5CF6),
        selectionHandleColor: AppColors.brandPurpleMid,
      ),

      // Platform-native route transitions; dark fill avoids a black flash.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
            backgroundColor: AppColors.backgroundDeep,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
