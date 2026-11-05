import 'package:flutter/material.dart';

/// Central color palette for the Marketing Management System.
/// Every color used in the app comes from here — never hardcode hex values elsewhere.
class AppColors {
  AppColors._(); // prevent instantiation

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C4CE8);       // Purple – main accent
  static const Color primaryLight = Color(0xFFEDE7FF);  // Lavender – tinted backgrounds
  static const Color primaryLighter = Color(0xFFF7F4FF); // Light lavender

  // ── Background ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FC);    // Page background
  static const Color surface = Color(0xFFFFFFFF);       // Card / surface background
  static const Color surfaceVariant = Color(0xFFF7F4FF); // Subtle alternate surface

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF24232B);      // Headings / body text
  static const Color textSecondary = Color(0xFF777784); // Sub-labels / captions

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22A06B);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE5484D);
  static const Color info = Color(0xFF0EA5E9);

  // ── Status backgrounds (light tints for badges / chips) ──────────────────
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color dangerBg = Color(0xFFFFF1F2);
  static const Color infoBg = Color(0xFFF0F9FF);

  // ── Border / divider ─────────────────────────────────────────────────────
  static const Color border = Color(0xFFE8E8EF);
  static const Color divider = Color(0xFFF0F0F6);

  // ── Sidebar ───────────────────────────────────────────────────────────────
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color sidebarActive = Color(0xFFEDE7FF);
  static const Color sidebarActiveText = Color(0xFF6C4CE8);
  static const Color sidebarText = Color(0xFF777784);
  static const Color sidebarHover = Color(0xFFF7F4FF);

  // ── Chart palette (used in sequential chart series) ──────────────────────
  static const List<Color> chartPalette = [
    Color(0xFF6C4CE8),
    Color(0xFF22A06B),
    Color(0xFF0EA5E9),
    Color(0xFFF59E0B),
    Color(0xFFE5484D),
    Color(0xFFBB5CF8),
  ];
}
