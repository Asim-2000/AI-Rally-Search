import '../llm/entity_resolution/phonetic_matching_helper.dart';
import '../llm/entity_resolution/pronunciation/algorithmic_pronunciation_encoder.dart';
import 'entity_search_models.dart';

class EntityCandidateGenerationResult {
  final List<String> canonicalIds;
  final List<String> preRankedCanonicalIds;
  final int fullUniverseSize;
  final bool usedFullScanEscape;
  final Duration latency;
  final int evidenceKeysMatched;

  const EntityCandidateGenerationResult({
    required this.canonicalIds,
    this.preRankedCanonicalIds = const [],
    required this.fullUniverseSize,
    required this.usedFullScanEscape,
    required this.latency,
    required this.evidenceKeysMatched,
  });
}

abstract class IEntityCandidateGenerator {
  void build(List<CanonicalSearchEntity> entities);
  EntityCandidateGenerationResult generate(EntitySearchRequest request);
  int get estimatedBytes;
}

class FullScanCandidateGenerator implements IEntityCandidateGenerator {
  List<CanonicalSearchEntity> _entities = const [];

  @override
  int get estimatedBytes => 0;

  @override
  void build(List<CanonicalSearchEntity> entities) => _entities = entities;

  @override
  EntityCandidateGenerationResult generate(EntitySearchRequest request) {
    final watch = Stopwatch()..start();
    final ids = _entities
        .where(
          (entity) =>
              entity.entityType == request.entityType &&
              _roleAllowed(entity, request.personRole),
        )
        .map((entity) => entity.canonicalId)
        .toList(growable: false);
    watch.stop();
    return EntityCandidateGenerationResult(
      canonicalIds: ids,
      fullUniverseSize: ids.length,
      usedFullScanEscape: false,
      latency: watch.elapsed,
      evidenceKeysMatched: 0,
    );
  }
}

class InvertedIndexCandidateGenerator implements IEntityCandidateGenerator {
  final int personPoolLimit;
  final int otherPoolLimit;
  final int minimumPool;
  final _entities = <String, CanonicalSearchEntity>{};
  final _ordinals = <String, int>{};
  final _byType = <SearchEntityType, List<String>>{};
  final _canonicalExact = <SearchEntityType, Map<String, Set<String>>>{};
  final _exact = <SearchEntityType, Map<String, Set<String>>>{};
  final _tokens = <SearchEntityType, Map<String, Set<String>>>{};
  final _bigrams = <SearchEntityType, Map<String, Set<String>>>{};
  final _trigrams = <SearchEntityType, Map<String, Set<String>>>{};
  final _phonetic = <SearchEntityType, Map<String, Set<String>>>{};
  final _prefixes = <SearchEntityType, Map<String, Set<String>>>{};
  int _estimatedBytes = 0;

  InvertedIndexCandidateGenerator({
    this.personPoolLimit = 1200,
    this.otherPoolLimit = 600,
    this.minimumPool = 25,
  });

  @override
  int get estimatedBytes => _estimatedBytes;

  @override
  void build(List<CanonicalSearchEntity> entities) {
    _entities.clear();
    _ordinals.clear();
    _byType.clear();
    for (final map in [
      _canonicalExact,
      _exact,
      _tokens,
      _bigrams,
      _trigrams,
      _phonetic,
      _prefixes,
    ]) {
      map.clear();
    }
    var bytes = 0;
    for (var ordinal = 0; ordinal < entities.length; ordinal++) {
      final entity = entities[ordinal];
      _entities[entity.canonicalId] = entity;
      _ordinals[entity.canonicalId] = ordinal;
      _byType.putIfAbsent(entity.entityType, () => []).add(entity.canonicalId);
      _add(
        _canonicalExact,
        entity.entityType,
        entity.canonicalName.trim().toLowerCase(),
        entity.canonicalId,
      );
      for (final name in _names(entity)) {
        final normalized = _text(name);
        final collapsed = normalized.replaceAll(' ', '');
        final tokens = normalized.split(' ').where((token) => token.isNotEmpty);
        _add(_exact, entity.entityType, normalized, entity.canonicalId);
        for (final token in tokens) {
          _add(_tokens, entity.entityType, token, entity.canonicalId);
          for (
            var length = 2;
            length <= 5 && length <= token.length;
            length++
          ) {
            _add(
              _prefixes,
              entity.entityType,
              token.substring(0, length),
              entity.canonicalId,
            );
          }
        }
        for (final gram in _grams(collapsed, 2)) {
          _add(_bigrams, entity.entityType, gram, entity.canonicalId);
        }
        for (final gram in _grams(collapsed, 3)) {
          _add(_trigrams, entity.entityType, gram, entity.canonicalId);
        }
        _add(
          _phonetic,
          entity.entityType,
          _encoder.encodeCollapsedQuery(normalized),
          entity.canonicalId,
        );
      }
    }
    for (final family in [
      _canonicalExact,
      _exact,
      _tokens,
      _bigrams,
      _trigrams,
      _phonetic,
      _prefixes,
    ]) {
      for (final typed in family.values) {
        for (final entry in typed.entries) {
          bytes += 48 + entry.key.length * 2 + entry.value.length * 16;
        }
      }
    }
    _estimatedBytes = bytes;
  }

  @override
  EntityCandidateGenerationResult generate(EntitySearchRequest request) {
    final watch = Stopwatch()..start();
    final universe = (_byType[request.entityType] ?? const <String>[])
        .where((id) => _roleAllowed(_entities[id]!, request.personRole))
        .toList(growable: false);
    final normalized = _text(request.rawMention);
    final collapsed = normalized.replaceAll(' ', '');
    final scores = <String, int>{};
    var evidence = 0;

    void collect(
      Map<SearchEntityType, Map<String, Set<String>>> family,
      String key,
      int weight,
    ) {
      final ids = family[request.entityType]?[key];
      if (ids == null) return;
      evidence++;
      for (final id in ids) {
        final entity = _entities[id];
        if (entity != null && _roleAllowed(entity, request.personRole)) {
          scores.update(id, (value) => value + weight, ifAbsent: () => weight);
        }
      }
    }

    collect(_canonicalExact, request.rawMention.trim().toLowerCase(), 12000);
    collect(_exact, normalized, 10000);
    for (final token
        in normalized.split(' ').where((token) => token.isNotEmpty)) {
      collect(_tokens, token, 200);
      for (var length = 2; length <= 5 && length <= token.length; length++) {
        collect(_prefixes, token.substring(0, length), 5 * length);
      }
    }
    for (final gram in _grams(collapsed, 3)) {
      collect(_trigrams, gram, 20);
    }
    for (final gram in _grams(collapsed, 2)) {
      collect(_bigrams, gram, 4);
    }
    collect(_phonetic, _encoder.encodeCollapsedQuery(normalized), 300);

    final ordered = scores.entries.toList()
      ..sort((a, b) {
        final score = b.value.compareTo(a.value);
        return score != 0 ? score : a.key.compareTo(b.key);
      });
    final limit = request.entityType == SearchEntityType.person
        ? personPoolLimit
        : otherPoolLimit;
    final suspicious = evidence == 0 || ordered.length < minimumPool;
    final preRanked = suspicious
        ? universe
        : ordered.take(limit).map((entry) => entry.key).toList(growable: false);
    final ids = List<String>.from(preRanked)
      ..sort((a, b) => _ordinals[a]!.compareTo(_ordinals[b]!));
    watch.stop();
    return EntityCandidateGenerationResult(
      canonicalIds: ids,
      preRankedCanonicalIds: preRanked,
      fullUniverseSize: universe.length,
      usedFullScanEscape: suspicious,
      latency: watch.elapsed,
      evidenceKeysMatched: evidence,
    );
  }

  static void _add(
    Map<SearchEntityType, Map<String, Set<String>>> family,
    SearchEntityType type,
    String key,
    String id,
  ) {
    if (key.isEmpty) return;
    family.putIfAbsent(type, () => {}).putIfAbsent(key, () => {}).add(id);
  }
}

final _encoder = AlgorithmicPronunciationEncoder();

String _text(String value) => PhoneticMatchingHelper.stripDescriptors(value);

Set<String> _names(CanonicalSearchEntity entity) {
  final values = <String>{entity.canonicalName.trim()};
  final stored = entity.metadata['searchableNames'];
  if (stored is Iterable) {
    values.addAll(
      stored
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty),
    );
  }
  return values;
}

Set<String> _grams(String value, int length) {
  if (value.isEmpty) return {};
  if (value.length <= length) return {value};
  return {
    for (var i = 0; i <= value.length - length; i++)
      value.substring(i, i + length),
  };
}

bool _roleAllowed(CanonicalSearchEntity entity, dynamic requested) {
  if (requested == null || requested.toString().endsWith('.any')) return true;
  final driverId = entity.metadata['driverId']?.toString();
  final codriverId = entity.metadata['codriverId']?.toString();
  return requested.toString().endsWith('.driver')
      ? driverId != null && driverId.isNotEmpty && driverId != 'null'
      : codriverId != null && codriverId.isNotEmpty && codriverId != 'null';
}
