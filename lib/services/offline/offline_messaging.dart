/// The connectivity / offline product states. Every user-facing offline state
/// follows the rally-personality pattern: playful headline -> literal
/// explanation -> obvious action.
enum OfflineUxState {
  online,
  offlineLocalResults,
  offlineStaleResults,
  lowBandwidthLocalFallback,
  backendUnreachableLocalAvailable,
  backendUnreachableLocalUnsupported,
  noLocalSnapshot,
  syncInProgress,
  syncFailed,
  syncComplete,
  cloudVoiceOffline,
  onDeviceVoiceUnavailable,
  videoMetadataOffline,
  videoPlaybackUnavailable,
  offlineAmbiguity,
  offlineSafeNoMatch,
  offlineQueryUnsupported,
}

/// One product-tone message: a playful rally headline, a literal explanation,
/// and an obvious action. Never let the headline replace the explanation.
class OfflineMessage {
  final String headline;
  final String explanation;
  final String action;
  const OfflineMessage(this.headline, this.explanation, this.action);
}

/// Deterministic catalogue for the User-Facing Messaging Matrix. Copy matches
/// OFFLINE_SEARCH_ARCHITECTURE.md verbatim; the `{age}` token in the stale
/// explanation is filled by [messageFor].
class OfflineMessagingService {
  const OfflineMessagingService();

  static const Map<OfflineUxState, OfflineMessage> _catalog = {
    OfflineUxState.online: OfflineMessage('', '', ''),
    OfflineUxState.offlineLocalResults: OfflineMessage(
      'Still racing — even without signal 🏁',
      'Searching the rally data saved on this device.',
      'Show local results + last-updated',
    ),
    OfflineUxState.offlineStaleResults: OfflineMessage(
      'Running on the latest service-park notes',
      'Updated {age}.',
      'Show results; offer refresh when online',
    ),
    OfflineUxState.lowBandwidthLocalFallback: OfflineMessage(
      'Bit of a slow stage out there…',
      "We're using local rally data while the connection catches up.",
      'Show local now; keep trying online',
    ),
    OfflineUxState.backendUnreachableLocalAvailable: OfflineMessage(
      "The pit crew can't reach HQ right now",
      "You're still searching with the data saved on this device.",
      'Show local results, labelled',
    ),
    OfflineUxState.backendUnreachableLocalUnsupported: OfflineMessage(
      'This one needs a quick radio check with HQ 📡',
      "This search needs an internet connection. Your query is still here — try again when you're back online.",
      'Preserve query; Retry',
    ),
    OfflineUxState.noLocalSnapshot: OfflineMessage(
      "We haven't packed the service notes yet",
      'Connect once to download rally data for offline search.',
      'Sync now (when online)',
    ),
    OfflineUxState.syncInProgress: OfflineMessage(
      'Loading the pace notes…',
      'Downloading rally data for offline search.',
      'Progress; allow background',
    ),
    OfflineUxState.syncFailed: OfflineMessage(
      'Radio dropped mid-message',
      "Couldn't finish the update. Your existing offline data still works.",
      'Retry sync; keep old data',
    ),
    OfflineUxState.syncComplete: OfflineMessage(
      'Service notes are fresh 🏁',
      'Offline rally data is up to date.',
      'Dismiss',
    ),
    OfflineUxState.cloudVoiceOffline: OfflineMessage(
      'Cloud radio is out of range 📡',
      'On-device voice is still available.',
      'Switch to on-device voice',
    ),
    OfflineUxState.onDeviceVoiceUnavailable: OfflineMessage(
      "Can't pick up the pace notes on this device",
      "Voice isn't available offline here — you can still type your search.",
      'Fall back to typing',
    ),
    OfflineUxState.videoMetadataOffline: OfflineMessage(
      'Found the clip in the notes',
      'Details saved on this device.',
      'Show card (playback gated)',
    ),
    OfflineUxState.videoPlaybackUnavailable: OfflineMessage(
      "Found the clip — but the stream's off-stage",
      "You're offline, so the video can't play right now.",
      'Save/queue; play when online',
    ),
    OfflineUxState.offlineAmbiguity: OfflineMessage(
      'Two cars on the same stage 🏁',
      'A few matches fit — which did you mean?',
      'Show clarification chips',
    ),
    OfflineUxState.offlineSafeNoMatch: OfflineMessage(
      "Even the marshals couldn't find that one",
      'No match in the offline data. Try another spelling or fewer filters.',
      'Refine query',
    ),
    OfflineUxState.offlineQueryUnsupported: OfflineMessage(
      "That's a stage we can't run offline yet",
      'This kind of search needs a connection. Offline covers rallies, drivers, years, countries, and cached results.',
      'Retry online later',
    ),
  };

  OfflineMessage messageFor(OfflineUxState state, {Duration? age}) {
    final base = _catalog[state]!;
    if (state == OfflineUxState.offlineStaleResults && age != null) {
      return OfflineMessage(base.headline, 'Updated ${_formatAge(age)}.', base.action);
    }
    return base;
  }

  static String _formatAge(Duration age) {
    if (age.inMinutes < 1) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes} minute${age.inMinutes == 1 ? '' : 's'} ago';
    if (age.inHours < 24) return '${age.inHours} hour${age.inHours == 1 ? '' : 's'} ago';
    return '${age.inDays} day${age.inDays == 1 ? '' : 's'} ago';
  }
}
