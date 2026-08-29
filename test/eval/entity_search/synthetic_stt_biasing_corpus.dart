import 'dart:math';

import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';

const syntheticSttBiasingSeed = 20260829;

enum SyntheticAudioCondition {
  clean,
  lowNoise,
  moderateNoise,
  quiet,
  compressed,
}

class SyntheticSttEntity {
  final String canonicalId;
  final String canonicalName;
  final SearchEntityType entityType;
  final List<String> searchableNames;
  final int? year;
  final Map<String, Object?> metadata;

  const SyntheticSttEntity({
    required this.canonicalId,
    required this.canonicalName,
    required this.entityType,
    required this.searchableNames,
    required this.metadata,
    this.year,
  });

  Map<String, Object?> toJson() => {
    'canonicalId': canonicalId,
    'canonicalName': canonicalName,
    'entityType': entityType.name,
    'searchableNames': searchableNames,
    'year': year,
    'metadata': metadata,
  };
}

class SyntheticSttUtterance {
  final String id;
  final SyntheticSttEntity target;
  final String text;
  final int templateIndex;

  const SyntheticSttUtterance({
    required this.id,
    required this.target,
    required this.text,
    required this.templateIndex,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'targetId': target.canonicalId,
    'targetName': target.canonicalName,
    'entityType': target.entityType.name,
    'text': text,
    'templateIndex': templateIndex,
  };
}

class SyntheticSttCorpus {
  final List<SyntheticSttEntity> entities;
  final List<SyntheticSttUtterance> utterances;

  const SyntheticSttCorpus({required this.entities, required this.utterances});
}

class SyntheticSttCorpusBuilder {
  static const _desired = {
    SearchEntityType.rally: 30,
    SearchEntityType.person: 50,
    SearchEntityType.stage: 30,
    SearchEntityType.uploader: 30,
  };

  static const _historicalNames = {
    'aluksne',
    'rally aluksne',
    'pawel molgo',
    'shea breen',
    'donegal',
    'donegal international rally',
    'kemmelberg',
    'duszniki zieleniec',
  };

  SyntheticSttCorpus build(List<CanonicalSearchEntity> source) {
    final selected = <SyntheticSttEntity>[];
    for (final type in SearchEntityType.values) {
      final eligible = source.where((entity) {
        if (entity.entityType != type) return false;
        final normalized = _normalized(entity.canonicalName);
        return !_historicalNames.any(
          (historical) =>
              normalized == historical || normalized.contains(historical),
        );
      }).toList();
      eligible.sort((a, b) => a.canonicalId.compareTo(b.canonicalId));
      eligible.shuffle(Random(syntheticSttBiasingSeed + type.index));
      final chosen = _withConfusablesFirst(eligible, _desired[type]!);
      selected.addAll(chosen.map(_convert));
    }
    final utterances = <SyntheticSttUtterance>[];
    for (final entity in selected) {
      final templates = _templates(entity);
      for (var i = 0; i < templates.length; i++) {
        utterances.add(
          SyntheticSttUtterance(
            id: '${entity.entityType.name}_${_safeId(entity.canonicalId)}_t$i',
            target: entity,
            text: templates[i],
            templateIndex: i,
          ),
        );
      }
    }
    return SyntheticSttCorpus(entities: selected, utterances: utterances);
  }

  List<CanonicalSearchEntity> _withConfusablesFirst(
    List<CanonicalSearchEntity> eligible,
    int count,
  ) {
    final groups = <String, List<CanonicalSearchEntity>>{};
    for (final entity in eligible) {
      final key = _confusableKey(entity);
      groups.putIfAbsent(key, () => []).add(entity);
    }
    final prioritized = <CanonicalSearchEntity>[];
    final seen = <String>{};
    for (final group in groups.values.where((values) => values.length > 1)) {
      for (final entity in group.take(3)) {
        if (seen.add(entity.canonicalId)) prioritized.add(entity);
      }
    }
    for (final entity in eligible) {
      if (seen.add(entity.canonicalId)) prioritized.add(entity);
    }
    return prioritized.take(count).toList(growable: false);
  }

  String _confusableKey(CanonicalSearchEntity entity) {
    final normalized = _normalized(entity.canonicalName)
        .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '')
        .replaceAll(RegExp(r'\b\d+\b'), '')
        .trim();
    if (entity.entityType == SearchEntityType.person) {
      final parts = normalized.split(' ');
      return parts.isEmpty ? normalized : parts.last;
    }
    return normalized;
  }

  SyntheticSttEntity _convert(CanonicalSearchEntity entity) {
    final stored = entity.metadata['searchableNames'];
    final names = <String>{entity.canonicalName};
    if (stored is Iterable) {
      names.addAll(
        stored.map((value) => value.toString()).where((v) => v.isNotEmpty),
      );
    }
    return SyntheticSttEntity(
      canonicalId: entity.canonicalId,
      canonicalName: entity.canonicalName,
      entityType: entity.entityType,
      searchableNames: names.toList(growable: false),
      year: entity.metadata['year'] as int?,
      metadata: Map<String, Object?>.from(entity.metadata),
    );
  }

  List<String> _templates(SyntheticSttEntity entity) =>
      switch (entity.entityType) {
        SearchEntityType.rally => [
          'show ${entity.canonicalName}',
          entity.year == null
              ? 'videos from ${entity.canonicalName}'
              : 'find ${entity.canonicalName} ${entity.year}',
        ],
        SearchEntityType.person => [
          'show ${entity.canonicalName}',
          'rallies driven by ${entity.canonicalName}',
        ],
        SearchEntityType.stage => [
          'show ${entity.canonicalName}',
          'jumps on ${entity.canonicalName}',
        ],
        SearchEntityType.uploader => [
          'videos uploaded by ${entity.canonicalName}',
          'show videos from uploader ${entity.canonicalName}',
        ],
      };

  static String _normalized(String value) =>
      PhoneticMatchingHelper.stripDescriptors(value);

  static String _safeId(String value) => value
      .replaceAll(RegExp('[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp('^_+|_+\$'), '');
}
