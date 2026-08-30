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

/// Single gold token for winner / top-3 states (replaces scattered raw ambers).
const Color kRallyGold = Color(0xFFCC9A2E);

/// Restrained, icon-led visual for a video-action type. Colour variation is
/// deliberately narrow (accent / warning / destructive) so the action *name and
/// icon* — not a rainbow of colours — carry the meaning.
class RallyActionVisual {
  final Color color;
  final IconData icon;
  const RallyActionVisual(this.color, this.icon);

  /// Normalizes both `start_line` and `start line` (etc.) to one key.
  static String normalizeType(String type) =>
      type.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');

  static RallyActionVisual forType(String type, {required bool isDark}) {
    final palette = isDark ? AppPalette._dark : AppPalette._light;
    final key = normalizeType(type);
    switch (key) {
      case 'crash':
      case 'mechanical_failure':
      case 'stuck':
        return RallyActionVisual(palette.destructive, _iconFor(key));
      case 'jump':
      case 'near_miss':
        return RallyActionVisual(palette.warning, _iconFor(key));
      default:
        return RallyActionVisual(palette.accent, _iconFor(key));
    }
  }

  static IconData _iconFor(String key) {
    switch (key) {
      case 'jump':
        return Icons.flight_takeoff_rounded;
      case 'drift':
        return Icons.turn_sharp_right_rounded;
      case 'crash':
        return Icons.warning_amber_rounded;
      case 'spin':
        return Icons.rotate_right_rounded;
      case 'donut':
        return Icons.data_usage_rounded;
      case 'hairpin':
        return Icons.u_turn_left_rounded;
      case 'water_splash':
        return Icons.water_drop_rounded;
      case 'start_line':
        return Icons.flag_rounded;
      case 'near_miss':
        return Icons.bolt_rounded;
      case 'offroad':
        return Icons.terrain_rounded;
      case 'mechanical_failure':
        return Icons.build_rounded;
      case 'stuck':
        return Icons.report_problem_rounded;
      default:
        return Icons.play_circle_outline_rounded;
    }
  }
}

/// Colour role for a rally status badge (UI only; stored status untouched).
Color rallyStatusColor(String? status, {required bool isDark}) {
  final palette = isDark ? AppPalette._dark : AppPalette._light;
  switch (status?.toLowerCase()) {
    case 'active':
    case 'live':
      return palette.success;
    case 'complete':
    case 'completed':
    case 'finished':
      return palette.accent;
    case 'cancelled':
    case 'failed':
      return palette.destructive;
    default:
      return palette.secondaryText;
  }
}

/// Formats a raw seconds string (e.g. "3600.0") as a readable race time
/// (e.g. "1:00:00" or "2:05.5"). UI presentation only — never mutates stored
/// values. Returns "—" when the value is missing or non-positive.
String formatRaceTime(String? rawSeconds) {
  if (rawSeconds == null || rawSeconds.trim().isEmpty) return '—';
  final total = double.tryParse(rawSeconds.trim());
  if (total == null || total <= 0) return '—';
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(num v) => v.toInt().toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}';
  }
  // Preserve one decimal for sub-hour stage/total times.
  final secStr = seconds.toStringAsFixed(1).padLeft(4, '0');
  return '$minutes:$secStr';
}
