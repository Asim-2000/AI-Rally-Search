import 'package:flutter/material.dart';

/// Lightweight shared design tokens for AI Rally Search.
///
/// Phase 1 scope: these tokens are applied to the search/home shell and the
/// components it directly composes (hero field, voice controls, example
/// queries). Result cards and leaderboards are intentionally NOT migrated yet
/// (that is Phase 2). Keep this layer small and additive — it centralizes the
/// values the new shell needs rather than performing a full style migration.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadii {
  AppRadii._();

  /// Chips, badges, small controls.
  static const double control = 8;

  /// Inner media / nested surfaces.
  static const double media = 12;

  /// Cards, sheets, the hero field.
  static const double card = 16;
}

/// The single restrained motorsport accent used across the shell.
const Color kRallyAccent = Color(0xFF1E88E5);

/// Resolves surface/text/border roles for the current brightness.
///
/// Modern-search-utility direction: flat surfaces, hairline borders, one
/// accent. No gradients or glass here.
class AppPalette {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primaryText;
  final Color secondaryText;
  final Color border;
  final Color accent;
  final Color success;
  final Color warning;
  final Color destructive;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primaryText,
    required this.secondaryText,
    required this.border,
    required this.accent,
    required this.success,
    required this.warning,
    required this.destructive,
  });

  static AppPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }

  static const AppPalette _light = AppPalette(
    background: Color(0xFFF7F9FC),
    surface: Colors.white,
    surfaceVariant: Color(0xFFF1F4F9),
    primaryText: Color(0xFF1A1C1E),
    secondaryText: Color(0xFF5B6470),
    border: Color(0x1A000000),
    accent: kRallyAccent,
    success: Color(0xFF2E9E5B),
    warning: Color(0xFFB7791F),
    destructive: Color(0xFFD64545),
  );

  static const AppPalette _dark = AppPalette(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceVariant: Color(0xFF252525),
    primaryText: Color(0xFFECEDEE),
    secondaryText: Color(0xFF9BA1A8),
    border: Color(0x1FFFFFFF),
    accent: Color(0xFF4CA3F0),
    success: Color(0xFF3FB56A),
    warning: Color(0xFFD9A441),
    destructive: Color(0xFFE5736B),
  );
}
