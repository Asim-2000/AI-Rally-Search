import 'dart:io';

import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:crypto/crypto.dart';

import 'pcm16_wav.dart';

class HumanVoiceFixtureValidator {
  static const supportedAudioExtensions = {
    '.wav',
    '.mp3',
    '.m4a',
    '.flac',
    '.ogg',
    '.webm',
  };

  const HumanVoiceFixtureValidator();

  Future<Map<String, Object?>> validate({
    required Map<String, dynamic> manifest,
    required List<CanonicalSearchEntity> liveEntities,
  }) async {
    final fixtures = (manifest['fixtures'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final liveById = {
      for (final entity in liveEntities) entity.canonicalId: entity,
    };
    final fixtureResults = <Map<String, Object?>>[];
    final actualShaByFixture = <String, String>{};
    final fixtureById = <String, Map<String, dynamic>>{};
    final allIssues = <Map<String, Object?>>[];

    for (final fixture in fixtures) {
      final fixtureId = fixture['fixtureId']?.toString() ?? '';
      final issues = <Map<String, Object?>>[];
      void error(String code, String message) => issues.add({
        'severity': 'ERROR',
        'fixtureId': fixtureId,
        'code': code,
        'message': message,
      });
      void warning(String code, String message) => issues.add({
        'severity': 'WARNING',
        'fixtureId': fixtureId,
        'code': code,
        'message': message,
      });

      if (fixtureId.trim().isEmpty) {
        error('MISSING_FIXTURE_ID', 'fixtureId is required.');
      } else if (fixtureById.containsKey(fixtureId)) {
        error('DUPLICATE_FIXTURE_ID', 'fixtureId must be unique.');
      } else {
        fixtureById[fixtureId] = fixture;
      }
      _requireText(fixture, 'speakerId', error);
      _requireText(fixture, 'filePath', error);
      _requireText(fixture, 'sha256', error);
      _requireText(fixture, 'referenceTranscriptRaw', error);
      _requireText(fixture, 'referenceTranscriptNormalized', error);
      _requireText(fixture, 'language', error);
      _requireText(fixture, 'expectedIntent', error);
      _requireText(fixture, 'expectedEntityMention', error);
      _requireText(fixture, 'expectedEntityType', error);

      _validateAlias(fixture, 'fixtureId', 'recordingId', error);
      _validateAlias(fixture, 'speakerId', 'speakerLabel', error);
      _validateAlias(fixture, 'filePath', 'audioFile', error);
      _validateAlias(fixture, 'expectedEntityMention', 'entityMention', error);
      _validateAlias(
        fixture,
        'expectedCanonicalId',
        'canonicalEntityId',
        error,
      );
      _validateAlias(
        fixture,
        'expectedCanonicalName',
        'canonicalEntityName',
        error,
      );
      final expectedIntents = (fixture['expectedIntents'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false);
      if (fixture['expectedIntent'] != null &&
          !expectedIntents.contains(fixture['expectedIntent'])) {
        error(
          'INTENT_ALIAS_MISMATCH',
          'expectedIntent must also appear in expectedIntents.',
        );
      }

      final canonicalScorable = fixture['canonicalScorable'];
      if (canonicalScorable is! bool) {
        error('MISSING_CANONICAL_SCORABLE', 'canonicalScorable must be bool.');
      }
      if (canonicalScorable == true) {
        _requireText(fixture, 'expectedCanonicalId', error);
        _requireText(fixture, 'expectedCanonicalName', error);
      } else if ((fixture['ambiguityReason']?.toString().trim() ?? '')
          .isEmpty) {
        error(
          'MISSING_AMBIGUITY_REASON',
          'Unscorable fixtures must explain ambiguityReason.',
        );
      }

      final expectedEntityType =
          fixture['expectedEntityType']?.toString().toUpperCase() ?? '';
      if (!{
        'RALLY',
        'PERSON',
        'STAGE',
        'UPLOADER',
        'CITY',
      }.contains(expectedEntityType)) {
        error(
          'UNSUPPORTED_ENTITY_TYPE',
          'expectedEntityType must be RALLY, PERSON, STAGE, UPLOADER, or CITY.',
        );
      }
      final expectedRole = fixture['expectedPersonRole']
          ?.toString()
          .toUpperCase();
      if (expectedRole != null &&
          !{'ANY', 'DRIVER', 'CO_DRIVER'}.contains(expectedRole)) {
        error(
          'INVALID_PERSON_ROLE',
          'expectedPersonRole must be ANY, DRIVER, CO_DRIVER, or null.',
        );
      }
      if (expectedEntityType != 'PERSON' && expectedRole != null) {
        error(
          'ROLE_ON_NON_PERSON',
          'expectedPersonRole is only valid for PERSON fixtures.',
        );
      }

      final filePath = fixture['filePath']?.toString() ?? '';
      final file = File(filePath);
      String? actualSha;
      int? fileSize;
      String? audioFormat;
      if (filePath.isNotEmpty && !file.existsSync()) {
        error('AUDIO_FILE_MISSING', 'Audio file does not exist: $filePath');
      } else if (filePath.isNotEmpty) {
        final extension = _extension(filePath);
        audioFormat = extension.replaceFirst('.', '').toUpperCase();
        if (!supportedAudioExtensions.contains(extension)) {
          error(
            'UNSUPPORTED_AUDIO_FORMAT',
            'Unsupported audio format: $extension',
          );
        }
        final bytes = await file.readAsBytes();
        fileSize = bytes.length;
        if (bytes.isEmpty) {
          error('EMPTY_AUDIO', 'Audio file is empty.');
        } else {
          actualSha = sha256.convert(bytes).toString();
          actualShaByFixture[fixtureId] = actualSha;
          final declaredSha = fixture['sha256']?.toString().toLowerCase();
          if (declaredSha != actualSha) {
            error(
              'SHA256_MISMATCH',
              'Declared sha256 does not match the audio bytes.',
            );
          }
          if (extension == '.wav') {
            try {
              final wave = Pcm16Wav.decode(bytes);
              if (wave.samples.isEmpty) {
                error('EMPTY_WAV_PAYLOAD', 'WAV contains no PCM samples.');
              }
            } on Object catch (exception) {
              error('INVALID_WAV', 'WAV validation failed: $exception');
            }
          }
        }
      }

      final expectedCanonicalId = fixture['expectedCanonicalId']?.toString();
      final canonical = expectedCanonicalId == null
          ? null
          : liveById[expectedCanonicalId];
      if (canonicalScorable == true && canonical == null) {
        error(
          'CANONICAL_ID_NOT_IN_LIVE_DB',
          'Expected canonical ID is absent from the live DB entity snapshot.',
        );
      }
      if (canonical != null) {
        final actualType = canonical.entityType.name.toUpperCase();
        if (actualType != expectedEntityType) {
          error(
            'CANONICAL_ENTITY_TYPE_MISMATCH',
            'Live canonical type $actualType does not match $expectedEntityType.',
          );
        }
        if (canonical.canonicalName != fixture['expectedCanonicalName']) {
          error(
            'CANONICAL_NAME_MISMATCH',
            'Expected canonical name no longer matches live DB truth.',
          );
        }
        if (expectedEntityType == 'PERSON') {
          _validatePersonRole(canonical, expectedRole, error);
        }
        final expectedYear = fixture['expectedYear'];
        if (expectedYear != null &&
            canonical.metadata['year']?.toString() != expectedYear.toString()) {
          error(
            'EVENT_YEAR_MISMATCH',
            'expectedYear is incompatible with live canonical metadata.',
          );
        }
        final expectedEventId = fixture['expectedEventId']?.toString();
        if (expectedEventId != null &&
            canonical.metadata['eventId']?.toString() != expectedEventId) {
          error(
            'EVENT_CONSTRAINT_MISMATCH',
            'expectedEventId is incompatible with live canonical metadata.',
          );
        }
      }

      final declaredDuplicate = fixture['duplicateAudioOf']?.toString();
      if (declaredDuplicate != null && declaredDuplicate == fixtureId) {
        error(
          'SELF_DUPLICATE_REFERENCE',
          'duplicateAudioOf cannot reference the same fixture.',
        );
      }
      if (fixture['audioCondition'] == null) {
        warning(
          'AUDIO_CONDITION_UNLABELED',
          'audioCondition is optional and not yet labeled.',
        );
      }

      allIssues.addAll(issues);
      fixtureResults.add({
        'fixtureId': fixtureId,
        'valid': issues.every((item) => item['severity'] != 'ERROR'),
        'filePath': filePath,
        'audioFormat': audioFormat,
        'fileSizeBytes': fileSize,
        'declaredSha256': fixture['sha256'],
        'actualSha256': actualSha,
        'issues': issues,
      });
    }

    final duplicateGroups = <Map<String, Object?>>[];
    final fixturesBySha = <String, List<String>>{};
    for (final entry in actualShaByFixture.entries) {
      fixturesBySha.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    for (final entry in fixturesBySha.entries.where(
      (entry) => entry.value.length > 1,
    )) {
      duplicateGroups.add({
        'sha256': entry.key,
        'representative': entry.value.first,
        'members': entry.value,
      });
    }
    duplicateGroups.sort(
      (left, right) => (left['representative'] as String).compareTo(
        right['representative'] as String,
      ),
    );

    for (final fixture in fixtures) {
      final duplicateOf = fixture['duplicateAudioOf']?.toString();
      if (duplicateOf == null) continue;
      final fixtureId = fixture['fixtureId'].toString();
      if (!fixtureById.containsKey(duplicateOf)) {
        allIssues.add({
          'severity': 'ERROR',
          'fixtureId': fixtureId,
          'code': 'DUPLICATE_REFERENCE_MISSING',
          'message': 'duplicateAudioOf references an unknown fixture.',
        });
      } else if (actualShaByFixture[fixtureId] !=
          actualShaByFixture[duplicateOf]) {
        allIssues.add({
          'severity': 'ERROR',
          'fixtureId': fixtureId,
          'code': 'DUPLICATE_SHA_MISMATCH',
          'message': 'duplicateAudioOf fixtures are not byte-identical.',
        });
      }
    }

    final representativeIds = fixturesBySha.values
        .map((members) => members.first)
        .toSet();
    final uniqueFixtures = fixtures
        .where((fixture) => representativeIds.contains(fixture['fixtureId']))
        .toList(growable: false);
    final errorCount = allIssues
        .where((item) => item['severity'] == 'ERROR')
        .length;
    final warningCount = allIssues
        .where((item) => item['severity'] == 'WARNING')
        .length;

    return {
      'schemaVersion': manifest['schemaVersion'],
      'valid': errorCount == 0,
      'errors': errorCount,
      'warnings': warningCount,
      'fixturesValidated': fixtures.length,
      'fixturesSilentlyDropped': 0,
      'fixtureResults': fixtureResults,
      'issues': allIssues,
      'audioInventory': {
        'TOTAL_FILES': fixtures.length,
        'UNIQUE_AUDIO_FILES': uniqueFixtures.length,
        'DUPLICATE_GROUPS': duplicateGroups,
      },
      'coverage': {
        'perFile': _coverage(fixtures),
        'uniqueAudio': _coverage(uniqueFixtures),
      },
      'collectionMilestones': _milestones(uniqueFixtures),
      'entityCoverageGuidance': {
        'requiredTypes': ['RALLY', 'PERSON', 'STAGE', 'UPLOADER'],
        'currentlyMissingTypes': [
          for (final type in ['RALLY', 'PERSON', 'STAGE', 'UPLOADER'])
            if (!uniqueFixtures.any(
              (fixture) => fixture['expectedEntityType'] == type,
            ))
              type,
        ],
        'recommendedMix': [
          'difficult international proper nouns',
          'easy control names',
          'similar or confusable names',
          'same-name people',
          'driver and co-driver cases',
          'different rally editions and years',
        ],
      },
    };
  }

  static void _requireText(
    Map<String, dynamic> fixture,
    String field,
    void Function(String, String) error,
  ) {
    if ((fixture[field]?.toString().trim() ?? '').isEmpty) {
      error('MISSING_${field.toUpperCase()}', '$field is required.');
    }
  }

  static void _validateAlias(
    Map<String, dynamic> fixture,
    String canonicalField,
    String legacyField,
    void Function(String, String) error,
  ) {
    if (fixture[canonicalField] != fixture[legacyField]) {
      error(
        'LEGACY_ALIAS_MISMATCH',
        '$canonicalField and $legacyField must remain identical.',
      );
    }
  }

  static void _validatePersonRole(
    CanonicalSearchEntity canonical,
    String? expectedRole,
    void Function(String, String) error,
  ) {
    if (expectedRole == null) {
      error(
        'MISSING_PERSON_ROLE',
        'PERSON fixtures must label expectedPersonRole.',
      );
      return;
    }
    final driverId = canonical.metadata['driverId']?.toString();
    final codriverId = canonical.metadata['codriverId']?.toString();
    if (expectedRole == 'DRIVER' && (driverId == null || driverId.isEmpty)) {
      error(
        'PERSON_ROLE_INCOMPATIBLE',
        'Expected DRIVER role is absent from live canonical metadata.',
      );
    }
    if (expectedRole == 'CO_DRIVER' &&
        (codriverId == null || codriverId.isEmpty)) {
      error(
        'PERSON_ROLE_INCOMPATIBLE',
        'Expected CO_DRIVER role is absent from live canonical metadata.',
      );
    }
    if (expectedRole == 'ANY' &&
        (driverId == null || driverId.isEmpty) &&
        (codriverId == null || codriverId.isEmpty)) {
      error(
        'PERSON_ROLE_INCOMPATIBLE',
        'ANY role requires at least one live driver/co-driver profile.',
      );
    }
  }

  static Map<String, Object?> _coverage(List<Map<String, dynamic>> fixtures) {
    Map<String, int> count(String Function(Map<String, dynamic>) key) {
      final result = <String, int>{};
      for (final fixture in fixtures) {
        final value = key(fixture);
        result[value] = (result[value] ?? 0) + 1;
      }
      return Map.fromEntries(
        result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
    }

    final audioConditions = fixtures
        .map((fixture) => fixture['audioCondition']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return {
      'recordings': fixtures.length,
      'speakers': count((fixture) => fixture['speakerId'].toString()),
      'languages': count((fixture) => fixture['language'].toString()),
      'entityTypes': count(
        (fixture) => fixture['expectedEntityType'].toString(),
      ),
      'entities': count(
        (fixture) => fixture['canonicalScorable'] == true
            ? fixture['expectedCanonicalName'].toString()
            : 'AMBIGUOUS:${fixture['expectedEntityMention']}',
      ),
      'personRoles': count(
        (fixture) =>
            fixture['expectedPersonRole']?.toString() ?? 'NOT_APPLICABLE',
      ),
      'canonicalLabelStatus': count(
        (fixture) => fixture['canonicalScorable'] == true
            ? 'SCORABLE'
            : 'AMBIGUOUS_UNSCORABLE',
      ),
      'queryIntents': count((fixture) => fixture['expectedIntent'].toString()),
      if (audioConditions.isNotEmpty)
        'audioConditions': count(
          (fixture) => fixture['audioCondition']?.toString() ?? 'UNLABELED',
        ),
      if (audioConditions.isEmpty)
        'audioConditions': {
          'status': 'NOT_YET_LABELED',
          'unlabeled': fixtures.length,
        },
    };
  }

  static List<Map<String, Object?>> _milestones(
    List<Map<String, dynamic>> uniqueFixtures,
  ) {
    final recordings = uniqueFixtures.length;
    final speakers = uniqueFixtures
        .map((fixture) => fixture['speakerId'].toString())
        .toSet()
        .length;
    return [
      _milestone(1, recordings, speakers, 30, 3),
      _milestone(2, recordings, speakers, 50, 5),
      _milestone(3, recordings, speakers, 100, 8),
    ];
  }

  static Map<String, Object?> _milestone(
    int milestone,
    int recordings,
    int speakers,
    int targetRecordings,
    int targetSpeakers,
  ) => {
    'milestone': milestone,
    'engineeringCollectionTargetOnly': true,
    'targetUniqueRecordings': targetRecordings,
    'targetSpeakers': targetSpeakers,
    'currentUniqueRecordings': recordings,
    'currentSpeakers': speakers,
    'uniqueRecordingsRemaining': (targetRecordings - recordings).clamp(
      0,
      targetRecordings,
    ),
    'speakersRemaining': (targetSpeakers - speakers).clamp(0, targetSpeakers),
    'reached': recordings >= targetRecordings && speakers >= targetSpeakers,
  };

  static String _extension(String path) {
    final filename = path.split(Platform.pathSeparator).last.toLowerCase();
    final index = filename.lastIndexOf('.');
    return index < 0 ? '' : filename.substring(index);
  }
}
