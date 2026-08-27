import 'dart:math';
import '../../../../models/entity_candidate.dart';
import 'entity_pronunciation_metadata.dart';
import 'algorithmic_pronunciation_encoder.dart';
import 'pronunciation_encoder.dart';

/// Storage-agnostic contract for phonetic candidate retrieval.
///
/// Implementations can back this with in-memory indexes (current branch),
/// server-side indexes (future backend branch), or persistent search caches.
abstract class IPhoneticEntityIndex {
  Future<List<EntityCandidate>> searchRallies(String query, {int limit = 50});
  Future<List<EntityCandidate>> searchPersons(String query, {int limit = 50});
  Future<List<EntityCandidate>> searchStages(String query, {int limit = 50});
  Future<List<EntityCandidate>> retrieveCandidates(
    String query, {
    EntityType? filterType,
    int limit = 50,
  });
}

/// In-memory reference implementation of [IPhoneticEntityIndex] for POC & mobile execution.
class InMemoryPhoneticEntityIndex implements IPhoneticEntityIndex {
  final AlgorithmicPronunciationEncoder encoder;

  // Inverted index: key -> Set of canonical entity names
  final Map<String, Set<String>> _shingleIndex = {};

  // Canonical entity store: canonicalName -> EntityPronunciationMetadata
  final Map<String, EntityPronunciationMetadata> _entityStore = {};

  // Canonical entity candidates: canonicalName -> EntityCandidate
  final Map<String, EntityCandidate> _candidateStore = {};

  InMemoryPhoneticEntityIndex({AlgorithmicPronunciationEncoder? encoder})
      : encoder = encoder ?? AlgorithmicPronunciationEncoder();

  int get entityCount => _entityStore.length;
  int get shingleCount => _shingleIndex.length;

  /// Indexes a canonical entity candidate.
  Future<void> indexEntity(EntityCandidate candidate, {List<String>? languageHints}) async {
    final meta = await encoder.encodeEntity(
      id: candidate.id,
      name: candidate.canonicalName,
      type: candidate.type,
      languageHints: languageHints,
    );

    _entityStore[candidate.canonicalName] = meta;
    _candidateStore[candidate.canonicalName] = candidate;

    // 1. Index all retrieval keys and 3-grams
    for (final key in meta.retrievalKeys) {
      _shingleIndex.putIfAbsent(key, () => {}).add(candidate.canonicalName);
    }

    // 2. Index space-collapsed phonetic representation
    final collapsed = meta.phoneticRepresentations['collapsed'];
    if (collapsed != null && collapsed.isNotEmpty) {
      _shingleIndex.putIfAbsent(collapsed, () => {}).add(candidate.canonicalName);
      if (collapsed.length >= 3) {
        for (var i = 0; i <= collapsed.length - 3; i++) {
          final gram = collapsed.substring(i, i + 3);
          _shingleIndex.putIfAbsent(gram, () => {}).add(candidate.canonicalName);
        }
      }
    }

    // 3. Index word tokens & consonant skeletons (e.g. BREEN -> BRN, MOLGO -> MLG)
    final words = meta.normalizedSpelling.split(' ').where((w) => w.isNotEmpty);
    for (final w in words) {
      final phoneWord = encoder.encodeQuery(w);
      if (phoneWord.isNotEmpty) {
        _shingleIndex.putIfAbsent(phoneWord, () => {}).add(candidate.canonicalName);
        final skel = _consonantSkeleton(phoneWord);
        if (skel.length >= 2) {
          _shingleIndex.putIfAbsent('skel:$skel', () => {}).add(candidate.canonicalName);
        }
      }
    }
  }

  /// Bulk indexes a list of entity candidates.
  Future<void> indexEntities(List<EntityCandidate> candidates) async {
    for (final c in candidates) {
      await indexEntity(c);
    }
  }

  @override
  Future<List<EntityCandidate>> searchRallies(String query, {int limit = 50}) =>
      retrieveCandidates(query, filterType: EntityType.rally, limit: limit);

  @override
  Future<List<EntityCandidate>> searchPersons(String query, {int limit = 50}) =>
      retrieveCandidates(query, filterType: EntityType.driver, limit: limit);

  @override
  Future<List<EntityCandidate>> searchStages(String query, {int limit = 50}) =>
      retrieveCandidates(query, filterType: EntityType.stage, limit: limit);

  @override
  Future<List<EntityCandidate>> retrieveCandidates(
    String query, {
    EntityType? filterType,
    int limit = 50,
  }) async {
    if (query.isEmpty || _entityStore.isEmpty) return const [];

    final queryCollapsed = encoder.encodeCollapsedQuery(query);
    final queryInternational = encoder.encodeQuery(query);
    final queryKeys = await encoder.generateRetrievalKeys(query);

    final matchCounts = <String, int>{};

    // Match n-gram shingles
    for (final key in queryKeys) {
      final matches = _shingleIndex[key];
      if (matches != null) {
        for (final name in matches) {
          matchCounts[name] = (matchCounts[name] ?? 0) + 1;
        }
      }
    }

    // Match exact collapsed representation
    final collapsedMatches = _shingleIndex[queryCollapsed];
    if (collapsedMatches != null) {
      for (final name in collapsedMatches) {
        matchCounts[name] = (matchCounts[name] ?? 0) + 10;
      }
    }

    // Match word tokens & consonant skeletons
    final queryWords = query.toLowerCase().split(' ').where((w) => w.isNotEmpty);
    for (final w in queryWords) {
      final phoneW = encoder.encodeQuery(w);
      final exactMatches = _shingleIndex[phoneW];
      if (exactMatches != null) {
        for (final name in exactMatches) {
          matchCounts[name] = (matchCounts[name] ?? 0) + 5;
        }
      }

      final skel = _consonantSkeleton(phoneW);
      if (skel.length >= 2) {
        final skelMatches = _shingleIndex['skel:$skel'];
        if (skelMatches != null) {
          for (final name in skelMatches) {
            matchCounts[name] = (matchCounts[name] ?? 0) + 3;
          }
        }
      }
    }

    if (matchCounts.isEmpty) return const [];

    // Sort matching entities by overlap score
    final sortedNames = matchCounts.keys.toList()
      ..sort((a, b) => matchCounts[b]!.compareTo(matchCounts[a]!));

    final results = <EntityCandidate>[];
    for (final name in sortedNames) {
      final cand = _candidateStore[name];
      if (cand != null) {
        if (filterType == null || cand.type == filterType) {
          results.add(cand);
          if (results.length >= limit) break;
        }
      }
    }

    return results;
  }

  /// Extracts the consonant skeleton of a phonetic token (e.g. MOLGO -> MLG, BREEN -> BRN).
  static String _consonantSkeleton(String token) {
    return token.toUpperCase().replaceAll(RegExp(r'[AEIOU\s]'), '');
  }
}

// Backward-compatible alias for existing tests
typedef PhoneticEntityIndex = InMemoryPhoneticEntityIndex;
