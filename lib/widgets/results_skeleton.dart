import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Lightweight animated placeholder shown while results load, using only
/// Flutter primitives (a gentle opacity pulse — no shimmer package). Includes
/// a live-region label so screen readers announce the loading status.
class ResultsSkeleton extends StatefulWidget {
  final String label;
  final int rows;

  const ResultsSkeleton({super.key, required this.label, this.rows = 5});

  @override
  State<ResultsSkeleton> createState() => _ResultsSkeletonState();
}

class _ResultsSkeletonState extends State<ResultsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 0.7).animate(_controller),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: widget.rows,
              itemBuilder: (context, index) => _skeletonCard(palette),
            ),
          ),
        ),
      ],
    );
  }

  Widget _skeletonCard(AppPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          _block(palette, 56, 56, radius: AppRadii.media),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(palette, double.infinity, 14),
                const SizedBox(height: AppSpacing.sm),
                _block(palette, 160, 12),
                const SizedBox(height: AppSpacing.sm),
                _block(palette, 100, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(AppPalette palette, double width, double height,
      {double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
