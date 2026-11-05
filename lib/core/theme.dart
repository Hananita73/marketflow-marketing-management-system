import 'package:flutter/material.dart';
import 'colors.dart';

/// Builds the Material 3 ThemeData for the Marketing Management System.
/// Import this in main.dart and pass it to MaterialApp.theme / darkTheme.
class AppTheme {
  AppTheme._();

  // ── Dark palette tokens ───────────────────────────────────────────────────
  // These are used only inside AppTheme.dark. All other code continues to
  // reference AppColors (light tokens) directly; in dark mode Material will
  // override scaffold/surface/card colours via the theme.
  static const Color _darkBackground    = Color(0xFF0F0E14);
  static const Color _darkSurface       = Color(0xFF1C1A27);
  static const Color _darkSurfaceVar    = Color(0xFF252235);
  static const Color _darkBorder        = Color(0xFF312E47);
  static const Color _darkDivider       = Color(0xFF2A2740);
  static const Color _darkTextPrimary   = Color(0xFFECEAF4);
  static const Color _darkTextSecondary = Color(0xFF9E9BB5);
  static const Color _darkInputFill     = Color(0xFF1C1A27);
  static const Color _darkTopBarBg      = Color(0xFF1C1A27);
  static const Color _darkSidebarBg     = Color(0xFF161423);
  static const Color _darkCardBorder    = Color(0xFF2E2B43);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.textSecondary,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto', // Ships with Flutter; swap to Inter/Poppins if added to pubspec

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── ElevatedButton ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // ── InputDecoration ───────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryLighter,
        labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── DataTable ─────────────────────────────────────────────────────────
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
        headingTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: const TextStyle(
          color: AppColors.textDark,
          fontSize: 13,
        ),
        dividerThickness: 1,
        columnSpacing: 24,
      ),

      // ── Text ──────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textDark),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textDark),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textDark),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textDark),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textDark),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textDark),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
    );
  }

  // ── Dark theme ────────────────────────────────────────────────────────────

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF3D2C8A),
      onPrimaryContainer: const Color(0xFFD6CAFF),
      secondary: _darkTextSecondary,
      onSecondary: Colors.white,
      surface: _darkSurface,
      onSurface: _darkTextPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBackground,
      fontFamily: 'Roboto',

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: _darkTopBarBg,
        foregroundColor: _darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _darkBorder,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _darkCardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── ElevatedButton ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // ── InputDecoration ───────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        hintStyle: TextStyle(color: _darkTextSecondary, fontSize: 14),
        labelStyle: TextStyle(color: _darkTextSecondary, fontSize: 14),
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2A2650),
        labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: _darkDivider,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── DataTable ─────────────────────────────────────────────────────────
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(_darkSurfaceVar),
        headingTextStyle: TextStyle(
          color: _darkTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: TextStyle(
          color: _darkTextPrimary,
          fontSize: 13,
        ),
        dividerThickness: 1,
        columnSpacing: 24,
      ),

      // ── Text ──────────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _darkTextPrimary),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _darkTextPrimary),
        displaySmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _darkTextPrimary),
        titleSmall:    TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _darkTextPrimary),
        bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: _darkTextPrimary),
        bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _darkTextPrimary),
        bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: _darkTextSecondary),
        labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _darkTextSecondary),
        labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _darkTextSecondary),
      ),
    );
  }

  // ── Convenience accessors for non-theme-resolved colours ─────────────────
  // Used by widgets (sidebar, topbar) that need surface/border colours that
  // are NOT already covered by ThemeData (because they are hardcoded).

  /// Background colour for the sidebar panel.
  static Color sidebarBg(Brightness b) =>
      b == Brightness.dark ? _darkSidebarBg : AppColors.sidebarBg;

  /// Background colour for the top-bar container.
  static Color topBarBg(Brightness b) =>
      b == Brightness.dark ? _darkTopBarBg : AppColors.surface;

  /// General surface colour (cards, containers).
  static Color surfaceColor(Brightness b) =>
      b == Brightness.dark ? _darkSurface : AppColors.surface;

  /// Subtle variant surface (hover states, table headers).
  static Color surfaceVariant(Brightness b) =>
      b == Brightness.dark ? _darkSurfaceVar : AppColors.surfaceVariant;

  /// Elevated surface — for modals, dialogs, dropdowns on top of surface.
  static Color elevatedSurface(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF252531) : AppColors.surface;

  /// Page / scaffold background colour.
  static Color backgroundFill(Brightness b) =>
      b == Brightness.dark ? _darkBackground : AppColors.background;

  /// Card fill colour (explicit, same as surfaceColor but semantically named for cards).
  static Color cardColor(Brightness b) =>
      b == Brightness.dark ? _darkSurface : AppColors.surface;

  /// Table header row background.
  static Color tableHeaderColor(Brightness b) =>
      b == Brightness.dark ? _darkSurfaceVar : AppColors.surfaceVariant;

  /// Table row hover background.
  static Color tableRowHover(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF211F35) : const Color(0xFFF7F4FF);

  /// Primary lighter — used for active nav items and hover tints.
  static Color primaryLighter(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2A2650) : AppColors.primaryLighter;

  /// Border colour.
  static Color border(Brightness b) =>
      b == Brightness.dark ? _darkBorder : AppColors.border;

  /// Divider colour.
  static Color divider(Brightness b) =>
      b == Brightness.dark ? _darkDivider : AppColors.divider;

  /// Primary body text colour.
  static Color textPrimary(Brightness b) =>
      b == Brightness.dark ? _darkTextPrimary : AppColors.textDark;

  /// Secondary / muted text colour.
  static Color textSecondary(Brightness b) =>
      b == Brightness.dark ? _darkTextSecondary : AppColors.textSecondary;

  /// Input / search-bar fill.
  static Color inputFill(Brightness b) =>
      b == Brightness.dark ? _darkInputFill : AppColors.background;

  /// Icon colour (same as secondary text, semantic alias).
  static Color iconColor(Brightness b) =>
      b == Brightness.dark ? _darkTextSecondary : AppColors.textSecondary;

  /// Hover tint colour for icon buttons and tiles.
  static Color hoverFill(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF252235) : AppColors.primaryLighter;

  /// Status badge background — success tint, adapts for dark mode readability.
  static Color successBg(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF0D2E1F) : AppColors.successBg;

  /// Status badge background — warning tint.
  static Color warningBg(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2E2010) : AppColors.warningBg;

  /// Status badge background — danger tint.
  static Color dangerBg(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2E1010) : AppColors.dangerBg;

  /// Status badge background — info tint.
  static Color infoBg(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF0D1E2E) : AppColors.infoBg;
}
