/// Stable, migration-friendly categories for non-search and error responses.
enum FriendlyResponseCategory {
  weather,
  greeting,
  thanks,
  identity,
  capabilities,
  joke,
  alive,
  rallyOpinion,
  unsupported,
  noResults,
  parseFailure,
  networkError,
  timeout,
  serverError,
  emptyVoice,
}

/// Stable machine-readable error codes. Friendly copy must never replace these.
enum SearchErrorCode {
  searchNoResults('SEARCH_NO_RESULTS'),
  queryParseFailed('QUERY_PARSE_FAILED'),
  networkError('NETWORK_ERROR'),
  requestTimeout('REQUEST_TIMEOUT'),
  serverError('SERVER_ERROR'),
  emptyTranscript('EMPTY_TRANSCRIPT'),
  unsupportedQuery('UNSUPPORTED_QUERY');

  const SearchErrorCode(this.value);
  final String value;
}

typedef FriendlyVariantSelector = int Function(
  FriendlyResponseCategory category,
  int variantCount,
);

/// Centralized deterministic catalog for all playful user-facing copy.
class FriendlyResponseService {
  final FriendlyVariantSelector _selector;

  const FriendlyResponseService({FriendlyVariantSelector? selector})
    : _selector = selector ?? _firstVariant;

  static int _firstVariant(FriendlyResponseCategory _, int __) => 0;

  static const Map<FriendlyResponseCategory, List<String>> _catalog = {
    FriendlyResponseCategory.weather: [
      "Hopefully sideways — that makes rallying more interesting. I'm better with stages than forecasts though.",
    ],
    FriendlyResponseCategory.greeting: [
      'Hello! Ready to find a rally, driver, stage, result or video?',
      'Hi, navigator. What rally are we looking for?',
    ],
    FriendlyResponseCategory.thanks: [
      'Any time, navigator. See you at the next stage.',
    ],
    FriendlyResponseCategory.identity: [
      "I'm AI Rally Search — your navigator for rallies, drivers, stages, results and videos.",
    ],
    FriendlyResponseCategory.capabilities: [
      'I can find rallies, drivers, stages, results and rally videos. Try asking for a winner, event or year.',
    ],
    FriendlyResponseCategory.joke: [
      'Why did the rally driver bring a pencil? To draw the perfect racing line.',
    ],
    FriendlyResponseCategory.alive: [
      "Not alive, but the search engine is running. Give me a rally query and we'll hit the stage.",
    ],
    FriendlyResponseCategory.rallyOpinion: [
      "That's how arguments start in a service park. I can show you wins and results and let you decide.",
    ],
    FriendlyResponseCategory.unsupported: [
      'Wrong stage, navigator. I can help with rallies, drivers, stages, results and videos.',
    ],
    FriendlyResponseCategory.noResults: [
      "Even the marshals couldn't find that one. Try another spelling or fewer filters.",
    ],
    FriendlyResponseCategory.parseFailure: [
      'I missed that pace note. Try asking with a rally, driver, stage or year.',
    ],
    FriendlyResponseCategory.networkError: [
      "We've lost radio contact with the service crew. Try again.",
    ],
    FriendlyResponseCategory.timeout: [
      'That search ended up in the gravel trap. Give it another go.',
    ],
    FriendlyResponseCategory.serverError: [
      'The service park has a problem. Try again in a moment.',
    ],
    FriendlyResponseCategory.emptyVoice: [
      'I heard the engine, but not the pace notes. Try that again.',
    ],
  };

  String responseFor(FriendlyResponseCategory category) {
    final variants = _catalog[category]!;
    final selected = _selector(category, variants.length);
    final safeIndex = selected < 0 ? 0 : selected % variants.length;
    return variants[safeIndex];
  }
}
