import 'dart:math';

import '../llm/entity_resolution/phonetic_matching_helper.dart';
import '../llm/entity_resolution/pronunciation/algorithmic_pronunciation_encoder.dart';
import 'entity_search_models.dart';
import 'entity_search_service.dart';

class _IndexedName {
  final String name;
  final String normalized;
  final String collapsed;
  final Set<String> tokens;
  final Set<String> bigrams;
  final Set<String> trigrams;
  final String phonetic;

  _IndexedName(this.name)
    : normalized = _searchText(name),
      collapsed = _searchText(name).replaceAll(' ', ''),
      tokens = _searchText(name).split(' ').where((e) => e.isNotEmpty).toSet(),
      bigrams = _grams(_searchText(name).replaceAll(' ', ''), 2),
      trigrams = _grams(_searchText(name).replaceAll(' ', ''), 3),
      phonetic = _phonetic(name);
}

class _IndexedEntity {
  final CanonicalSearchEntity source;
  final List<_IndexedName> names;

  _IndexedEntity(this.source)
    : names = _searchableNames(source)
          .map(_IndexedName.new)
          .toList(growable: false);
}

class InMemoryEntitySearchService implements IEntitySearchService {
  final IEntitySearchDataSource dataSource;
  List<_IndexedEntity> _index = const [];
  @override
  EntitySearchIndexStats? indexStats;
  EntitySearchQueryStats? lastQueryStats;

  InMemoryEntitySearchService({required this.dataSource});

  /// Useful for deterministic unit tests and offline benchmarks.
  InMemoryEntitySearchService.fromEntities(List<CanonicalSearchEntity> entities)
    : dataSource = _StaticDataSource(entities) {
    _replaceIndex(entities, Duration.zero);
  }

  @override
  Future<EntitySearchIndexStats> rebuild() async {
    final stopwatch = Stopwatch()..start();
    final entities = await dataSource.loadEntities();
    stopwatch.stop();
    return _replaceIndex(entities, stopwatch.elapsed);
  }

  EntitySearchIndexStats _replaceIndex(
    List<CanonicalSearchEntity> entities,
    Duration elapsed,
  ) {
    final next = entities
        .where(
          (e) => e.canonicalId.isNotEmpty && e.canonicalName.trim().isNotEmpty,
        )
        .map(_IndexedEntity.new)
        .toList(growable: false);
    _index = next;
    final bytes = next.fold<int>(
      0,
      (sum, e) =>
          sum +
          160 +
          2 *
              (e.source.canonicalId.length +
                  e.source.canonicalName.length +
                  e.names.fold<int>(
                    0,
                    (nameSum, name) =>
                        nameSum +
                        name.name.length +
                        name.normalized.length +
                        name.collapsed.length +
                        name.phonetic.length +
                        name.bigrams.join().length +
                        name.trigrams.join().length,
                  )),
    );
    return indexStats = EntitySearchIndexStats(
      entityCount: next.length,
      buildTime: elapsed,
      estimatedBytes: bytes,
    );
  }

  @override
  Future<List<EntitySearchCandidate>> search(
    EntitySearchRequest request,
  ) async {
    final stopwatch = Stopwatch()..start();
    final raw = request.rawMention.trim();
    if (raw.isEmpty || request.limit <= 0) {
      stopwatch.stop();
      lastQueryStats = EntitySearchQueryStats(
        entityType: request.entityType,
        rawCandidatesEvaluated: 0,
        survivingCandidates: 0,
        returnedCandidates: 0,
        latency: stopwatch.elapsed,
      );
      return const [];
    }
    final normalized = _searchText(raw);
    final collapsed = normalized.replaceAll(' ', '');
    final tokens = normalized.split(' ').where((e) => e.isNotEmpty).toSet();
    final bigrams = _grams(collapsed, 2);
    final trigrams = _grams(collapsed, 3);
    final phonetic = _phonetic(raw);
    final results = <EntitySearchCandidate>[];
    var evaluated = 0;

    for (final entity in _index) {
      if (entity.source.entityType != request.entityType ||
          !_roleAllowed(entity, request.personRole)) {
        continue;
      }
      evaluated++;
      final context = _contextScore(entity, request);
      _ScoredName? best;
      for (final name in entity.names) {
        final scored = _scoreName(
          raw,
          normalized,
          collapsed,
          tokens,
          bigrams,
          trigrams,
          phonetic,
          name,
          context,
        );
        if (best == null || scored.score > best.score) best = scored;
      }
      if (best == null || best.strongest < 0.18) {
        continue;
      }
      final exact = best.signals.exactScore;
      final normalizedExact = best.signals.normalizedExactScore;
      final token = best.signals.tokenScore;
      final ngram = best.signals.ngramScore;
      final lexical = best.signals.lexicalScore;
      final phoneticScore = best.signals.phoneticScore;
      final matched = <String>{
        if (exact > 0) 'exact',
        if (normalizedExact > 0) 'normalized_exact',
        if (token >= .5) 'token',
        if (ngram >= .45) 'character_ngram',
        if (lexical >= .65) 'lexical',
        if (phoneticScore >= .65) 'phonetic',
        if (context > 0) 'context',
      };
      results.add(
        EntitySearchCandidate(
          canonicalId: entity.source.canonicalId,
          canonicalName: entity.source.canonicalName,
          entityType: entity.source.entityType,
          score: best.score,
          signals: best.signals,
          matchedBy: matched,
          metadata: Map<String, Object?>.from(entity.source.metadata)
            ..['matchedSearchableName'] = best.name,
        ),
      );
    }
    results.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.canonicalName.compareTo(b.canonicalName);
    });
    final surviving = results.length;
    final returned = results.take(request.limit).toList(growable: false);
    stopwatch.stop();
    lastQueryStats = EntitySearchQueryStats(
      entityType: request.entityType,
      rawCandidatesEvaluated: evaluated,
      survivingCandidates: surviving,
      returnedCandidates: returned.length,
      latency: stopwatch.elapsed,
    );
    return returned;
  }

  static _ScoredName _scoreName(
    String raw,
    String normalized,
    String collapsed,
    Set<String> tokens,
    Set<String> bigrams,
    Set<String> trigrams,
    String phonetic,
    _IndexedName name,
    double context,
  ) {
    final exact = raw.toLowerCase() == name.name.toLowerCase() ? 1.0 : 0.0;
    final normalizedExact = normalized == name.normalized ? 1.0 : 0.0;
    final token = _tokenScore(tokens, name.tokens, normalized, name.normalized);
    final ngram =
        0.4 * _dice(bigrams, name.bigrams) +
        0.6 * _dice(trigrams, name.trigrams);
    final lexical = max(
      PhoneticMatchingHelper.jaroWinkler(collapsed, name.collapsed),
      PhoneticMatchingHelper.diceTrigram(collapsed, name.collapsed),
    );
    final phoneticScore = max(
      PhoneticMatchingHelper.jaroWinkler(phonetic, name.phonetic),
      PhoneticMatchingHelper.diceBigram(phonetic, name.phonetic),
    );
    final signals = EntitySearchSignals(
      exactScore: exact,
      normalizedExactScore: normalizedExact,
      tokenScore: token,
      ngramScore: ngram,
      lexicalScore: lexical,
      phoneticScore: phoneticScore,
      contextScore: context,
    );
    final strongest = [
      exact,
      normalizedExact,
      token,
      ngram,
      lexical,
      phoneticScore,
    ]..sort();
    final score =
        (0.62 * strongest.last +
                0.23 * strongest[strongest.length - 2] +
                0.10 * token +
                0.05 * context)
            .clamp(0.0, 1.0);
    return _ScoredName(name.name, score, strongest.last, signals);
  }

  static bool _roleAllowed(_IndexedEntity entity, dynamic requested) {
    if (requested == null || requested.toString().endsWith('.any')) return true;
    final role = entity.source.metadata['role']?.toString();
    if (role == 'both') return true;
    return requested.toString().endsWith('.driver')
        ? role == 'driver'
        : role == 'co_driver';
  }

  static double _contextScore(
    _IndexedEntity entity,
    EntitySearchRequest request,
  ) {
    var tested = 0, matched = 0;
    if (request.year != null) {
      tested++;
      if (entity.source.metadata['year'] == request.year) matched++;
    }
    if (request.country != null && request.country!.trim().isNotEmpty) {
      tested++;
      if (PhoneticMatchingHelper.normalize(
            entity.source.metadata['country']?.toString() ?? '',
          ) ==
          PhoneticMatchingHelper.normalize(request.country!)) {
        matched++;
      }
    }
    final eventId = request.context['eventId']?.toString();
    if (eventId != null && eventId.isNotEmpty) {
      tested++;
      if (entity.source.metadata['eventId']?.toString() == eventId) matched++;
    }
    return tested == 0 ? 0 : matched / tested;
  }

  static double _tokenScore(
    Set<String> a,
    Set<String> b,
    String an,
    String bn,
  ) {
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    final setScore = (2 * intersection) / (a.length + b.length);
    final prefixHits = a
        .where(
          (x) => b.any(
            (y) =>
                x.length >= 3 &&
                y.length >= 3 &&
                (x.startsWith(y) || y.startsWith(x)),
          ),
        )
        .length;
    final prefixScore = prefixHits / max(a.length, b.length);
    final orderedInsensitive = (a.length == b.length && a.containsAll(b))
        ? 1.0
        : 0.0;
    final phrasePrefix = (an.startsWith(bn) || bn.startsWith(an))
        ? min(an.length, bn.length) / max(an.length, bn.length)
        : 0.0;
    return max(
      max(setScore, prefixScore),
      max(orderedInsensitive, phrasePrefix),
    );
  }
}

class _ScoredName {
  final String name;
  final double score;
  final double strongest;
  final EntitySearchSignals signals;
  const _ScoredName(this.name, this.score, this.strongest, this.signals);
}

final _pronunciationEncoder = AlgorithmicPronunciationEncoder();

String _searchText(String value) =>
    PhoneticMatchingHelper.stripDescriptors(value);

String _phonetic(String value) =>
    _pronunciationEncoder.encodeCollapsedQuery(_searchText(value));

Set<String> _searchableNames(CanonicalSearchEntity entity) {
  final names = <String>{entity.canonicalName.trim()};
  final stored = entity.metadata['searchableNames'];
  if (stored is Iterable) {
    names.addAll(
      stored.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
    );
  }
  return names;
}

Set<String> _grams(String value, int n) {
  if (value.isEmpty) return {};
  if (value.length <= n) return {value};
  return {
    for (var i = 0; i <= value.length - n; i++) value.substring(i, i + n),
  };
}

double _dice(Set<String> a, Set<String> b) => a.isEmpty || b.isEmpty
    ? 0
    : 2 * a.intersection(b).length / (a.length + b.length);

class _StaticDataSource implements IEntitySearchDataSource {
  final List<CanonicalSearchEntity> entities;
  const _StaticDataSource(this.entities);
  @override
  Future<List<CanonicalSearchEntity>> loadEntities() async => entities;
}
