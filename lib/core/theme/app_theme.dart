import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Builds the Material 3 themes from [AppColors].
///
/// Typography note: the web stack is `'Inter', -apple-system, …, Roboto`.
/// Rather than bundling Inter (an extra ~800KB per weight and a licence to
/// track), mobile uses the platform face that stack already falls back to —
/// SF Pro on iOS, Roboto on Android. That is both the native-feeling choice
/// and faithful to the declared font stack. Swap in Inter via `fontFamily`
/// here if brand wants byte-identical glyphs on both platforms.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final surface = isDark ? AppColors.bgSurfaceDark : AppColors.bgSurface;
    final scaffold = isDark ? AppColors.bgAppDark : AppColors.bgApp;
    final muted = isDark ? AppColors.bgMutedDark : AppColors.bgMuted;
    final border = isDark ? AppColors.borderDark : AppColors.border;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiary;

    // Brand stays blue in dark mode but lifts to brand-400/500 so it keeps
    // contrast against a near-black ground.
    final primary = isDark ? AppColors.brand400 : AppColors.brand600;
    final onPrimary = isDark ? AppColors.slate950 : Colors.white;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark ? AppColors.brand900 : AppColors.brand50,
      onPrimaryContainer: isDark ? AppColors.brand100 : AppColors.brand800,
      secondary: isDark ? AppColors.slate400 : AppColors.slate600,
      onSecondary: isDark ? AppColors.slate950 : Colors.white,
      secondaryContainer: muted,
      onSecondaryContainer: textPrimary,
      tertiary: AppColors.teal,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF450A0A) : AppColors.dangerSoft,
      onErrorContainer: isDark ? AppColors.dangerSoft : const Color(0xFF7F1D1D),
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: scaffold,
      surfaceContainerLow: surface,
      surfaceContainer: muted,
      surfaceContainerHigh: muted,
      surfaceContainerHighest: muted,
      outline: border,
      outlineVariant:
          isDark ? AppColors.borderStrongDark : AppColors.borderStrong,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: isDark ? AppColors.slate100 : AppColors.slate900,
      onInverseSurface: isDark ? AppColors.slate900 : AppColors.slate50,
      inversePrimary: isDark ? AppColors.brand700 : AppColors.brand300,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: textSecondary,
          height: 1.4,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          color: textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        shape: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.slate900 : surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: textTertiary, fontSize: 15),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: muted,
        side: BorderSide(color: border),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rSm),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark ? AppColors.brand900 : AppColors.brand50,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? primary : textTertiary,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: isDark ? AppColors.slate700 : AppColors.slate300,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.slate100 : AppColors.slate900,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.slate900 : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: muted,
        circularTrackColor: muted,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textTertiary,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: border,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
