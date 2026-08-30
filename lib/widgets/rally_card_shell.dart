import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared visual shell for list result cards.
///
/// Unifies radius, hairline border, flat elevation and clipping across the
/// intent-specific cards (rally, participation, video, video-action) so they
/// read as one family while keeping their distinct internal layouts.
class RallyCardShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Clip the child to the card radius (used by cards with edge-to-edge media).
  final bool clip;

  /// Optional accent-tinted left edge (e.g. winner highlight).
  final Color? edgeColor;

  const RallyCardShell({
    super.key,
    required this.child,
    this.onTap,
    this.clip = false,
    this.edgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final radius = BorderRadius.circular(AppRadii.card);

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: radius,
        border: Border.all(
          color: edgeColor ?? palette.border,
          width: edgeColor != null ? 1.5 : 1,
        ),
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: child,
        ),
      ),
    );
  }
}
