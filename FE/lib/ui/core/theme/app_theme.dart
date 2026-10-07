import 'package:flutter/material.dart';
import '../widgets/design_reference_page.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'CapstoneUI',
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: Colors.white,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: AppColors.text,
          surfaceTint: Colors.transparent,
        ),
    scaffoldBackgroundColor: Colors.white,
    textTheme: TextTheme(
      titleLarge: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
      titleMedium: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
      titleSmall: ReferenceStyle.text(14, 21, weight: FontWeight.w500),
      bodyLarge: ReferenceStyle.text(14, 21),
      bodyMedium: ReferenceStyle.text(14, 21),
      bodySmall: ReferenceStyle.text(12, 18, color: AppColors.muted),
      labelLarge: ReferenceStyle.text(14, 21, weight: FontWeight.w500),
      labelMedium: ReferenceStyle.text(12, 18),
      labelSmall: ReferenceStyle.text(11, 17),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      titleTextStyle: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primarySoft,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
      contentTextStyle: ReferenceStyle.text(14, 21, color: AppColors.muted),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      modalBackgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppColors.border,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxWidth: 520),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? AppColors.primary : Colors.white,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: AppColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: ReferenceStyle.text(14, 21, weight: FontWeight.w500),
        minimumSize: const Size(44, 44),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        textStyle: ReferenceStyle.text(15, 23, weight: FontWeight.w500),
        minimumSize: const Size(44, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      minVerticalPadding: 12,
      iconColor: AppColors.primary,
      textColor: AppColors.text,
      titleTextStyle: ReferenceStyle.text(14, 21),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.all(16),
      hintStyle: ReferenceStyle.text(14, 21, color: AppColors.muted),
      labelStyle: ReferenceStyle.text(14, 21),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: ReferenceStyle.text(13, 20, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
