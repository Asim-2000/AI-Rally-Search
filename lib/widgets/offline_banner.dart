import 'package:flutter/material.dart';

import '../services/offline/offline_messaging.dart';

/// A subtle-but-visible offline/connectivity banner following the product-tone
/// pattern: playful rally headline + literal explanation (+ optional action).
///
/// Deliberately not styled as an error — offline results are still results.
class OfflineBanner extends StatelessWidget {
  final OfflineUxState state;
  final Duration? age;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onDismiss;

  const OfflineBanner({
    super.key,
    required this.state,
    this.age,
    this.onAction,
    this.actionLabel,
    this.onDismiss,
  });

  static const _messaging = OfflineMessagingService();

  bool get _isError =>
      state == OfflineUxState.syncFailed ||
      state == OfflineUxState.backendUnreachableLocalUnsupported ||
      state == OfflineUxState.offlineQueryUnsupported;

  @override
  Widget build(BuildContext context) {
    if (state == OfflineUxState.online) return const SizedBox.shrink();
    final msg = _messaging.messageFor(state, age: age);
    final scheme = Theme.of(context).colorScheme;
    final bg = _isError
        ? scheme.errorContainer.withValues(alpha: 0.5)
        : scheme.secondaryContainer.withValues(alpha: 0.55);
    final fg = _isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_isError ? Icons.wifi_off_rounded : Icons.cloud_off_rounded, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg.headline,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(msg.explanation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.9))),
                if (onAction != null && actionLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: fg,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: fg),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
