import 'offline_text_scoring.dart';

/// Entity kinds resolvable offline.
enum OfflineEntityType { rally, person, stage, uploader }

/// One canonical entity in the in-memory offline index. Canonical ids are the
/// SAME ids used online, so an offline resolution stays valid if re-run online.
class OfflineEntity {
  final OfflineEntityType type;
  final String canonicalId; // event_id | person:account:* | stage_id | uploader_id
  final String canonicalName;
  final List<String> searchableNames; // driver + codriver aliases for people
  final int? year;
  final String? country;
  final String? driverId;
  final String? codriverId;
  final String? accountId;
  final String? eventId; // for stages
  final String? stageNumber;

  const OfflineEntity({
    required this.type,
    required this.canonicalId,
    required this.canonicalName,
    this.searchableNames = const [],
    this.year,
    this.country,
    this.driverId,
    this.codriverId,
    this.accountId,
    this.eventId,
    this.stageNumber,
  });
}

/// A scored candidate produced during resolution.
class OfflineCandidate {
  final OfflineEntity entity;
  final double score;
  const OfflineCandidate(this.entity, this.score);
}

/// Outcome of resolving one mention. Mirrors the online resolution contract:
/// a confident single match, a genuine ambiguity (clarify), or no match. It
/// NEVER fabricates a canonical id.
class OfflineResolution {
  final OfflineEntityType type;
  final String rawPhrase;
  final OfflineCandidate? resolved; // non-null only on a confident match
  final bool isAmbiguous;
  final List<OfflineCandidate> candidates; // clarification options
  final double confidence;
  final String strategy;

  const OfflineResolution({
    required this.type,
    required this.rawPhrase,
    this.resolved,
    this.isAmbiguous = false,
    this.candidates = const [],
    this.confidence = 0.0,
    required this.strategy,
  });

  bool get isResolved => resolved != null && !isAmbiguous;

  factory OfflineResolution.none(OfflineEntityType type, String phrase) =>
      OfflineResolution(type: type, rawPhrase: phrase, strategy: 'none');
}

/// Deterministic, model-free offline entity resolver. Preserves the online
/// safety ordering exactly:
///   correct confident > correct clarification > safe no-match > wrong confident
/// Thresholds are NEVER lowered to force an offline answer.
class OfflineEntityIndex {
  static const double minConfidenceThreshold = 0.75;
  static const double minScoreGap = 0.15;
  static const double plausibleThreshold = 0.50;

  final List<OfflineEntity> rallies;
  final List<OfflineEntity> people;
  final List<OfflineEntity> stages;
  final List<OfflineEntity> uploaders;

  OfflineEntityIndex({
    this.rallies = const [],
    this.people = const [],
    this.stages = const [],
    this.uploaders = const [],
  });

  List<OfflineEntity> _pool(OfflineEntityType type) {
    switch (type) {
      case OfflineEntityType.rally:
        return rallies;
      case OfflineEntityType.person:
        return people;
      case OfflineEntityType.stage:
        return stages;
      case OfflineEntityType.uploader:
        return uploaders;
    }
  }

  List<OfflineCandidate> _score(
    OfflineEntityType type,
    String phrase, {
    List<int> years = const [],
    String? eventId,
  }) {
    final isPerson = type == OfflineEntityType.person;
    final scored = <OfflineCandidate>[];
    for (final e in _pool(type)) {
      if (eventId != null && type == OfflineEntityType.stage && e.eventId != eventId) {
        continue;
      }
      // People are scored against every searchable name (driver + codriver).
      final names = (isPerson && e.searchableNames.isNotEmpty)
          ? e.searchableNames
          : [e.canonicalName];
      double best = 0.0;
      for (final name in names) {
        final s = OfflineTextScoring.computeCompositeScore(
          queryPhrase: phrase,
          candidateName: name,
          queryYear: years.length == 1 ? years.first : null,
          candidateYear: e.year,
          isPerson: isPerson,
        );
        if (s > best) best = s;
      }
      if (best > 0) scored.add(OfflineCandidate(e, best));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  OfflineResolution resolveRally(String phrase, {List<int> years = const []}) {
    final scored = _score(OfflineEntityType.rally, phrase, years: years);
    if (scored.isEmpty) return OfflineResolution.none(OfflineEntityType.rally, phrase);

    final phraseYear = OfflineTextScoring.extractYear(phrase);
    final hasExplicitYears = phraseYear != null || years.isNotEmpty;
    if (!hasExplicitYears && scored.length > 1) {
      final baseTop = OfflineTextScoring.stripYear(scored[0].entity.canonicalName);
      final baseSecond = OfflineTextScoring.stripYear(scored[1].entity.canonicalName);
      // Only a genuine multi-edition ambiguity (both editions are real matches).
      if (baseTop.isNotEmpty &&
          baseTop == baseSecond &&
          scored[1].score >= plausibleThreshold) {
        return OfflineResolution(
          type: OfflineEntityType.rally,
          rawPhrase: phrase,
          confidence: 0.5,
          strategy: 'multi_year_ambiguity',
          isAmbiguous: true,
          candidates: scored.take(5).toList(),
        );
      }
    }
    return _select(OfflineEntityType.rally, phrase, scored);
  }

  OfflineResolution resolvePerson(String phrase, {List<int> years = const []}) {
    final scored = _score(OfflineEntityType.person, phrase, years: years);
    if (scored.isEmpty) return OfflineResolution.none(OfflineEntityType.person, phrase);

    final cleanLower = phrase.trim().toLowerCase();
    final isPartialName = !cleanLower.contains(' ');
    if (isPartialName && scored.length > 1 && scored[1].score >= plausibleThreshold) {
      return OfflineResolution(
        type: OfflineEntityType.person,
        rawPhrase: phrase,
        confidence: 0.5,
        strategy: 'partial_name_ambiguity',
        isAmbiguous: true,
        candidates: scored.take(5).toList(),
      );
    }
    return _select(OfflineEntityType.person, phrase, scored);
  }

  OfflineResolution resolveStage(String phrase, {String? eventId}) {
    final scored = _score(OfflineEntityType.stage, phrase, eventId: eventId);
    if (scored.isEmpty) return OfflineResolution.none(OfflineEntityType.stage, phrase);
    return _select(OfflineEntityType.stage, phrase, scored);
  }

  OfflineResolution resolveUploader(String phrase) {
    final scored = _score(OfflineEntityType.uploader, phrase);
    if (scored.isEmpty) return OfflineResolution.none(OfflineEntityType.uploader, phrase);
    return _select(OfflineEntityType.uploader, phrase, scored);
  }

  /// Faithful port of `DatabaseEntityResolver._evaluate_candidate_selection`.
  OfflineResolution _select(
    OfflineEntityType type,
    String phrase,
    List<OfflineCandidate> scored,
  ) {
    final top = scored.first;
    final topScore = top.score;

    // Distinct account identities that share the same effective name -> clarify.
    if (type == OfflineEntityType.person && topScore >= minConfidenceThreshold) {
      final topIdentity = top.entity.accountId ?? top.entity.canonicalId;
      final dupes = <OfflineCandidate>[];
      for (final c in scored) {
        final identity = c.entity.accountId ?? c.entity.canonicalId;
        if (identity != topIdentity &&
            OfflineTextScoring.normalize(c.entity.canonicalName) ==
                OfflineTextScoring.normalize(top.entity.canonicalName) &&
            (c.score - topScore).abs() <= 1e-6) {
          dupes.add(c);
        }
      }
      if (dupes.isNotEmpty) {
        return OfflineResolution(
          type: type,
          rawPhrase: phrase,
          confidence: topScore,
          strategy: 'duplicate_person_identity',
          isAmbiguous: true,
          candidates: ([top, ...dupes]).take(5).toList(),
        );
      }
    }

    if (topScore < minConfidenceThreshold) {
      final isPlausible = topScore >= plausibleThreshold;
      return OfflineResolution(
        type: type,
        rawPhrase: phrase,
        confidence: topScore,
        strategy: isPlausible ? 'plausible_candidates' : 'below_threshold',
        isAmbiguous: isPlausible,
        candidates: isPlausible ? scored.take(5).toList() : const [],
      );
    }

    if (scored.length == 1) {
      return OfflineResolution(
        type: type,
        rawPhrase: phrase,
        resolved: top,
        confidence: topScore,
        strategy: 'unique_match',
      );
    }

    final runnerUp = scored[1];
    final gap = topScore - runnerUp.score;
    if (gap >= minScoreGap) {
      return OfflineResolution(
        type: type,
        rawPhrase: phrase,
        resolved: top,
        confidence: topScore,
        strategy: 'clear_winner',
      );
    }
    return OfflineResolution(
      type: type,
      rawPhrase: phrase,
      confidence: topScore,
      strategy: 'insufficient_gap',
      isAmbiguous: true,
      candidates: scored
          .where((c) => c.score >= minConfidenceThreshold - 0.10)
          .take(5)
          .toList(),
    );
  }
}
