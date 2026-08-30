import '../../models/search_intent.dart';
import '../../models/search_query.dart';
import '../friendly_response_service.dart';
import '../special_query_matcher.dart';
import 'offline_entity_index.dart';
import 'offline_text_scoring.dart';

/// What the deterministic offline parser concluded.
enum OfflineParseKind {
  /// A grounded, executable SearchQuery.
  results,

  /// A genuine ambiguity — show clarification chips (never a silent guess).
  clarification,

  /// A special / easter-egg personality response.
  special,

  /// The wording is beyond safe deterministic coverage — decline, don't guess.
  unsupported,

  /// Understood the shape, but no entity could be grounded in local data.
  noMatch,
}

class OfflineParseResult {
  final OfflineParseKind kind;
  final SearchQuery? query;
  final SearchIntent? intent;
  final String? clarificationQuestion;
  final List<OfflineCandidate> candidates;
  final FriendlyResponseCategory? specialCategory;
  final String? unresolvedMention;

  const OfflineParseResult({
    required this.kind,
    this.query,
    this.intent,
    this.clarificationQuestion,
    this.candidates = const [],
    this.specialCategory,
    this.unresolvedMention,
  });

  factory OfflineParseResult.results(SearchQuery q) =>
      OfflineParseResult(kind: OfflineParseKind.results, query: q, intent: q.intent);
  factory OfflineParseResult.special(FriendlyResponseCategory c) =>
      OfflineParseResult(kind: OfflineParseKind.special, specialCategory: c);
  factory OfflineParseResult.unsupported() =>
      const OfflineParseResult(kind: OfflineParseKind.unsupported);
  factory OfflineParseResult.noMatch(String mention) =>
      OfflineParseResult(kind: OfflineParseKind.noMatch, unresolvedMention: mention);
  factory OfflineParseResult.clarify(
    SearchIntent intent,
    String question,
    List<OfflineCandidate> candidates,
  ) =>
      OfflineParseResult(
        kind: OfflineParseKind.clarification,
        intent: intent,
        clarificationQuestion: question,
        candidates: candidates,
      );
}

/// A narrow, deterministic, model-free parser that emits the SAME `SearchQuery`
/// IR the online pipeline uses. It handles the canonical and common phrasings
/// and SAFELY DECLINES anything it cannot ground — it never guesses an intent.
class OfflineQueryParser {
  final OfflineEntityIndex index;
  final SpecialQueryMatcher specialMatcher;
  final int limit;

  OfflineQueryParser({
    required this.index,
    this.specialMatcher = const SpecialQueryMatcher(),
    this.limit = 20,
  });

  // Country alias -> canonical, mirroring backend COUNTRIES / SearchQuery map.
  static const Map<String, String> _countryAlias = {
    'ireland': 'ireland', 'ie': 'ireland', 'irl': 'ireland', 'republic of ireland': 'ireland',
    'portugal': 'portugal', 'pt': 'portugal', 'prt': 'portugal',
    'united kingdom': 'united kingdom', 'uk': 'united kingdom', 'gb': 'united kingdom',
    'gbr': 'united kingdom', 'great britain': 'united kingdom', 'england': 'england',
    'scotland': 'scotland', 'wales': 'wales',
    'france': 'france', 'fr': 'france', 'fra': 'france',
    'austria': 'austria', 'norway': 'norway', 'poland': 'poland', 'belgium': 'belgium',
    'spain': 'spain', 'italy': 'italy', 'latvia': 'latvia', 'germany': 'germany',
    'kenya': 'kenya', 'croatia': 'croatia', 'netherlands': 'netherlands', 'holland': 'netherlands',
    'new zealand': 'new zealand', 'lithuania': 'lithuania', 'slovakia': 'slovakia',
    'qatar': 'qatar', 'pakistan': 'pakistan', 'barbados': 'barbados', 'sweden': 'sweden',
    'finland': 'finland', 'estonia': 'estonia', 'czech republic': 'czech republic',
    'czechia': 'czech republic',
  };

  // Action keyword -> canonical action_type (matches online action routing).
  static const Map<String, String> _actionAlias = {
    'jump': 'jump', 'jumps': 'jump', 'jumping': 'jump',
    'crash': 'crash', 'crashes': 'crash', 'crashing': 'crash', 'accident': 'crash', 'accidents': 'crash',
    'drift': 'drift', 'drifts': 'drift', 'drifting': 'drift',
    'spin': 'spin', 'spins': 'spin', 'spinning': 'spin',
    'offroad': 'offroad', 'off road': 'offroad', 'off-road': 'offroad',
    'near miss': 'near_miss', 'near misses': 'near_miss', 'nearmiss': 'near_miss',
    'stuck': 'stuck', 'mechanical': 'mechanical_failure', 'mechanical failure': 'mechanical_failure',
    'start line': 'start_line', 'startline': 'start_line',
  };

  static final RegExp _wordRe = RegExp(r"[a-z0-9']+");

  OfflineParseResult parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return OfflineParseResult.unsupported();

    // 1) Special / easter-egg queries run FIRST (shared entry point).
    final special = specialMatcher.match(trimmed);
    if (special != null) return OfflineParseResult.special(special.category);

    var norm = OfflineTextScoring.normalize(trimmed);
    if (norm.isEmpty) return OfflineParseResult.unsupported();

    // 2) Years / ranges.
    final years = <int>[];
    int? yearFrom, yearTo;
    // "2023-2025" / "2023 to 2025"
    final rangeMatch = RegExp(r'\b((?:19|20)\d{2})\s*(?:-|to|through|until|and)\s*((?:19|20)\d{2})\b').firstMatch(norm);
    if (rangeMatch != null) {
      final a = int.parse(rangeMatch.group(1)!);
      final b = int.parse(rangeMatch.group(2)!);
      yearFrom = a <= b ? a : b;
      yearTo = a <= b ? b : a;
      norm = norm.replaceFirst(rangeMatch.group(0)!, ' ');
    } else {
      final since = RegExp(r'\b(?:since|after|from)\s+((?:19|20)\d{2})\b').firstMatch(norm);
      final before = RegExp(r'\b(?:before|until|up to)\s+((?:19|20)\d{2})\b').firstMatch(norm);
      if (since != null) {
        yearFrom = int.parse(since.group(1)!);
        norm = norm.replaceFirst(since.group(0)!, ' ');
      }
      if (before != null) {
        yearTo = int.parse(before.group(1)!);
        norm = norm.replaceFirst(before.group(0)!, ' ');
      }
      if (yearFrom == null && yearTo == null) {
        for (final m in RegExp(r'\b(19|20)\d{2}\b').allMatches(norm)) {
          years.add(int.parse(m.group(0)!));
        }
        norm = norm.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ');
      }
    }

    // 3) Action-type cue.
    String? actionType;
    for (final entry in _actionAlias.entries) {
      if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(norm)) {
        actionType = entry.value;
        norm = norm.replaceAll(RegExp('\\b${RegExp.escape(entry.key)}\\b'), ' ');
        break;
      }
    }

    // 4) Role cue.
    PersonRole role = PersonRole.any;
    if (RegExp(r'\bco[ -]?driver(s)?\b|\bco[ -]?drove\b|\bnavigator\b').hasMatch(norm)) {
      role = PersonRole.coDriver;
      norm = norm.replaceAll(RegExp(r'\bco[ -]?driver(s)?\b|\bco[ -]?drove\b|\bnavigator\b'), ' ');
    } else if (RegExp(r'\bdriver(s)?\b|\bdrove\b').hasMatch(norm) && !RegExp(r'top driver').hasMatch(norm)) {
      role = PersonRole.driver;
    }

    // 5) Countries.
    final countries = <String>{};
    final sortedAliases = _countryAlias.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final alias in sortedAliases) {
      if (RegExp('\\b${RegExp.escape(alias)}\\b').hasMatch(norm)) {
        countries.add(_countryAlias[alias]!);
        norm = norm.replaceAll(RegExp('\\b${RegExp.escape(alias)}\\b'), ' ');
      }
    }

    // 6) Intent cue detection (over the ORIGINAL normalized text).
    final full = OfflineTextScoring.normalize(trimmed);
    bool has(String pattern) => RegExp(pattern).hasMatch(full);
    // A rally-name marker is "rally <name>" (singular, followed by a word) — NOT
    // the plural category word "rallies", which is an intent cue, not a name cue.
    final rallyMarker = has(r'\brally\s+\S|\brallye\s+\S');
    final videoCue = has(r'\bvideo(s)?\b|\bclip(s)?\b|\bfootage\b|\bonboard\b|\bwatch\b');
    final topUploadersCue = has(r'\btop uploader|\bbest uploader|\bmost upload|\buploaders?\b|\bcontributors?\b|\bwho uploaded');
    final topDriversCue = has(r'\btop driver|\bmost (career )?win|\bmost rally win|\bdrivers by win|\bwinningest|\bbest drivers by win|\bmost successful driver');
    final winnerCue = has(r'\bwho won\b|\bwho win\b|\bwinner\b|\bwho is the winner\b|\bwho took\b');
    final resultsCue = has(r'\bresult(s)?\b|\bleaderboard\b|\bstandings\b|\btop finish|\bfinishers\b|\bclassification\b|\bpodium\b|\bpositions\b');
    final winsCue = has(r'\bwins\b|\bwon\b|\bvictories\b');
    final participationCue = has(r'\bparticipat|\bdrove in\b|\bcompeted\b|\bentries\b|\bentered\b|\btook part\b|\braced in\b');

    // 7) Residual entity mention: strip cue/connector words.
    var residual = norm;
    const stripWords = [
      'rally', 'rallye', 'rallies', 'rali', 'video', 'videos', 'clip', 'clips', 'footage',
      'onboard', 'watch', 'top', 'best', 'most', 'career', 'win', 'wins', 'won', 'victories',
      'winner', 'winners', 'result', 'results', 'leaderboard', 'standings', 'finisher',
      'finishers', 'classification', 'podium', 'positions', 'uploader', 'uploaders',
      'contributor', 'contributors', 'uploaded', 'drivers', 'driver', 'by', 'who', 'won',
      'in', 'on', 'at', 'of', 'from', 'for', 'the', 'a', 'an', 'show', 'me', 'list', 'find',
      'get', 'all', 'and', 'with', 'did', 'does', 'was', 'were', 'is', 'are', 'to', 'took',
      'part', 'participated', 'participate', 'competed', 'compete', 'entered', 'entries',
      'raced', 'drove', 'take', 'that', 'this', 'give', 'about', 'search', 'ranked', 'ranking',
      'most', 'have', 'has', 'their', 'his', 'her', 'they',
      // Question / filler words so they never pollute an entity mention.
      'what', 'whats', 'which', 'where', 'when', 'how', 'why', 'happened', 'happen',
      'successful', 'career', 'competing', 'between', 'through', 'until', 'up',
    ];
    final stripSet = stripWords.toSet();
    final residualTokens =
        _wordRe.allMatches(residual).map((m) => m.group(0)!).where((t) => !stripSet.contains(t)).toList();
    residual = residualTokens.join(' ').trim();

    // 8) Choose intent + resolve entity.
    return _resolveAndBuild(
      residual: residual,
      rallyMarker: rallyMarker,
      videoCue: videoCue,
      topUploadersCue: topUploadersCue,
      topDriversCue: topDriversCue,
      winnerCue: winnerCue,
      resultsCue: resultsCue,
      winsCue: winsCue,
      participationCue: participationCue,
      actionType: actionType,
      role: role,
      countries: countries.toList(),
      years: years,
      yearFrom: yearFrom,
      yearTo: yearTo,
    );
  }

  OfflineParseResult _resolveAndBuild({
    required String residual,
    required bool rallyMarker,
    required bool videoCue,
    required bool topUploadersCue,
    required bool topDriversCue,
    required bool winnerCue,
    required bool resultsCue,
    required bool winsCue,
    required bool participationCue,
    required String? actionType,
    required PersonRole role,
    required List<String> countries,
    required List<int> years,
    int? yearFrom,
    int? yearTo,
  }) {
    final hasResidual = residual.isNotEmpty;
    final hasFilters = countries.isNotEmpty || years.isNotEmpty || yearFrom != null || yearTo != null;

    // --- Aggregate/leaderboard intents (no entity needed) ---
    // The pre-computed aggregates are GLOBAL. If the user asked to filter them by
    // country/year, offline cannot honour that safely -> decline rather than
    // return a wrong-scope global leaderboard.
    if (topUploadersCue && !hasResidual) {
      return hasFilters
          ? OfflineParseResult.unsupported()
          : OfflineParseResult.results(const SearchQuery(intent: SearchIntent.getTopUploaders));
    }
    if (topDriversCue && !hasResidual) {
      return hasFilters
          ? OfflineParseResult.unsupported()
          : OfflineParseResult.results(const SearchQuery(intent: SearchIntent.getTopDriversByWins));
    }

    // Resolve the residual as rally and/or person.
    OfflineResolution? rallyRes;
    OfflineResolution? personRes;
    if (hasResidual) {
      rallyRes = index.resolveRally(residual, years: years);
      personRes = index.resolvePerson(residual, years: years);
    }

    // Prefer person when the phrasing is clearly person-oriented.
    final personOriented = (videoCue || winsCue || participationCue || role != PersonRole.any) &&
        !rallyMarker &&
        !winnerCue &&
        !resultsCue;
    // Prefer rally when a rally marker / winner / results cue is present.
    final rallyOriented = rallyMarker || winnerCue || resultsCue;

    OfflineResolution? chosen;
    bool chosePerson = false;
    if (hasResidual) {
      if (personOriented) {
        chosen = _bestOf(personRes, rallyRes);
        chosePerson = identical(chosen, personRes);
      } else if (rallyOriented) {
        chosen = _bestOf(rallyRes, personRes);
        chosePerson = identical(chosen, personRes);
      } else {
        // Neutral: pick the higher-confidence resolution.
        if ((personRes?.confidence ?? 0) > (rallyRes?.confidence ?? 0)) {
          chosen = personRes;
          chosePerson = true;
        } else {
          chosen = rallyRes;
          chosePerson = false;
        }
      }
    }

    // --- Video actions: an action cue routes here regardless of entity. ---
    if (actionType != null) {
      final q = _videoActionsQuery(
        actionType: actionType,
        chosen: chosen,
        chosePerson: chosePerson,
        role: role,
        countries: countries,
        years: years,
        yearFrom: yearFrom,
        yearTo: yearTo,
        residual: residual,
      );
      return q;
    }

    // --- No residual entity: fall back to filtered intents. ---
    if (!hasResidual) {
      if (videoCue) {
        return OfflineParseResult.results(SearchQuery(
          intent: SearchIntent.searchDriverVideos,
          countries: countries,
          years: years,
          yearFrom: yearFrom,
          yearTo: yearTo,
          personRole: role,
          limit: limit,
        ));
      }
      if (hasFilters) {
        return OfflineParseResult.results(SearchQuery(
          intent: SearchIntent.searchRallies,
          countries: countries,
          years: years,
          yearFrom: yearFrom,
          yearTo: yearTo,
          limit: limit,
        ));
      }
      // Nothing to ground safely.
      return OfflineParseResult.unsupported();
    }

    // --- Residual present: require a SAFELY GROUNDED resolution. ---
    // "Grounded" = a confident match, or a genuine ambiguity whose top candidate
    // is itself a strong match (>= confidence threshold). A merely-plausible top
    // (< threshold) is treated as ungrounded: we decline or fall back to filters
    // rather than clarify on noise. Thresholds are never lowered here.
    final grounded = chosen != null &&
        (chosen.isResolved ||
            (chosen.isAmbiguous &&
                chosen.candidates.isNotEmpty &&
                chosen.candidates.first.score >= OfflineEntityIndex.minConfidenceThreshold));

    if (!grounded) {
      if (topDriversCue && !hasFilters) {
        return OfflineParseResult.results(const SearchQuery(intent: SearchIntent.getTopDriversByWins));
      }
      if (topUploadersCue && !hasFilters) {
        return OfflineParseResult.results(const SearchQuery(intent: SearchIntent.getTopUploaders));
      }
      // A country/year filter with an ungrounded residual -> broad rally filter.
      if (hasFilters && !videoCue && !winnerCue && !resultsCue) {
        return OfflineParseResult.results(SearchQuery(
          intent: SearchIntent.searchRallies,
          countries: countries,
          years: years,
          yearFrom: yearFrom,
          yearTo: yearTo,
          limit: limit,
        ));
      }
      return OfflineParseResult.noMatch(residual);
    }

    if (chosen.isAmbiguous) {
      final intent = _intentForResolved(
        chosePerson: chosePerson,
        videoCue: videoCue,
        winnerCue: winnerCue,
        resultsCue: resultsCue,
        winsCue: winsCue,
      );
      final question = chosePerson
          ? 'Which "${chosen.rawPhrase}" do you mean?'
          : chosen.strategy == 'multi_year_ambiguity'
              ? 'Which year or edition of "${chosen.rawPhrase}" are you looking for?'
              : 'Which rally named "${chosen.rawPhrase}" do you mean?';
      return OfflineParseResult.clarify(intent, question, chosen.candidates);
    }

    // Confident resolution.
    final entity = chosen.resolved!.entity;
    if (chosePerson) {
      return _personQuery(
        entity: entity,
        videoCue: videoCue,
        winsCue: winsCue,
        role: role,
        countries: countries,
        years: years,
        yearFrom: yearFrom,
        yearTo: yearTo,
      );
    } else {
      return _rallyQuery(
        entity: entity,
        winnerCue: winnerCue,
        resultsCue: resultsCue,
        videoCue: videoCue,
        countries: countries,
        years: years,
        yearFrom: yearFrom,
        yearTo: yearTo,
      );
    }
  }

  OfflineResolution? _bestOf(OfflineResolution? a, OfflineResolution? b) {
    if (a == null) return b;
    if (b == null) return a;
    // A confident/ambiguous resolution on the preferred type wins if it grounds.
    if (a.isResolved || a.isAmbiguous) return a;
    if (b.isResolved || b.isAmbiguous) return b;
    return a.confidence >= b.confidence ? a : b;
  }

  SearchIntent _intentForResolved({
    required bool chosePerson,
    required bool videoCue,
    required bool winnerCue,
    required bool resultsCue,
    required bool winsCue,
  }) {
    if (chosePerson) {
      if (videoCue) return SearchIntent.searchDriverVideos;
      if (winsCue) return SearchIntent.searchDriverWins;
      return SearchIntent.searchDriverRallies;
    }
    if (winnerCue) return SearchIntent.getRallyResults;
    if (resultsCue) return SearchIntent.getRallyTopFinishers;
    if (videoCue) return SearchIntent.searchDriverVideos;
    return SearchIntent.searchRallies;
  }

  OfflineParseResult _personQuery({
    required OfflineEntity entity,
    required bool videoCue,
    required bool winsCue,
    required PersonRole role,
    required List<String> countries,
    required List<int> years,
    int? yearFrom,
    int? yearTo,
  }) {
    final ids = _driverIdsFor(entity, role);
    if (ids.isEmpty) return OfflineParseResult.noMatch(entity.canonicalName);
    final intent = videoCue
        ? SearchIntent.searchDriverVideos
        : winsCue
            ? SearchIntent.searchDriverWins
            : SearchIntent.searchDriverRallies;
    return OfflineParseResult.results(SearchQuery(
      intent: intent,
      driverIds: ids,
      driverNames: [entity.canonicalName],
      personRole: role,
      countries: countries,
      years: years,
      yearFrom: yearFrom,
      yearTo: yearTo,
      limit: limit,
    ));
  }

  OfflineParseResult _rallyQuery({
    required OfflineEntity entity,
    required bool winnerCue,
    required bool resultsCue,
    required bool videoCue,
    required List<String> countries,
    required List<int> years,
    int? yearFrom,
    int? yearTo,
  }) {
    final intent = winnerCue
        ? SearchIntent.getRallyResults
        : resultsCue
            ? SearchIntent.getRallyTopFinishers
            : videoCue
                ? SearchIntent.searchDriverVideos
                : SearchIntent.searchRallies;
    return OfflineParseResult.results(SearchQuery(
      intent: intent,
      rallyNames: [entity.canonicalId],
      eventNames: [entity.canonicalId],
      countries: countries,
      years: years,
      yearFrom: yearFrom,
      yearTo: yearTo,
      limit: limit,
    ));
  }

  OfflineParseResult _videoActionsQuery({
    required String actionType,
    required OfflineResolution? chosen,
    required bool chosePerson,
    required PersonRole role,
    required List<String> countries,
    required List<int> years,
    int? yearFrom,
    int? yearTo,
    required String residual,
  }) {
    final driverIds = <String>[];
    final rallyNames = <String>[];
    final strongAmbiguity = chosen != null &&
        chosen.isAmbiguous &&
        chosen.candidates.isNotEmpty &&
        chosen.candidates.first.score >= OfflineEntityIndex.minConfidenceThreshold;
    if (strongAmbiguity) {
      return OfflineParseResult.clarify(
        SearchIntent.searchVideoActions,
        chosePerson
            ? 'Which "${chosen.rawPhrase}" do you mean?'
            : 'Which rally named "${chosen.rawPhrase}" do you mean?',
        chosen.candidates,
      );
    }
    if (chosen != null && chosen.isResolved) {
      final entity = chosen.resolved!.entity;
      if (chosePerson) {
        driverIds.addAll(_driverIdsFor(entity, role));
      } else {
        rallyNames.add(entity.canonicalId);
      }
    }
    return OfflineParseResult.results(SearchQuery(
      intent: SearchIntent.searchVideoActions,
      actionTypes: [actionType],
      driverIds: driverIds,
      rallyNames: rallyNames,
      eventNames: rallyNames,
      countries: countries,
      years: years,
      yearFrom: yearFrom,
      yearTo: yearTo,
      personRole: role,
      limit: limit,
    ));
  }

  List<String> _driverIdsFor(OfflineEntity entity, PersonRole role) {
    final ids = <String>[];
    switch (role) {
      case PersonRole.driver:
        if (entity.driverId != null) ids.add(entity.driverId!);
        break;
      case PersonRole.coDriver:
        if (entity.codriverId != null) ids.add(entity.codriverId!);
        break;
      case PersonRole.any:
        if (entity.driverId != null) ids.add(entity.driverId!);
        if (entity.codriverId != null) ids.add(entity.codriverId!);
        break;
    }
    return ids;
  }
}
