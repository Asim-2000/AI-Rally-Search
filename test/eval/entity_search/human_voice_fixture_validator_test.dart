import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'human_voice_fixture_validator.dart';

void main() {
  const validator = HumanVoiceFixtureValidator();
  final liveEntities = [
    const CanonicalSearchEntity(
      canonicalId: '0cea6942-72e3-4257-a8c1-0f8148747d82',
      canonicalName: 'Rally Alūksne 2026',
      entityType: SearchEntityType.rally,
      metadata: {'year': 2026},
    ),
    const CanonicalSearchEntity(
      canonicalId: 'person:account:cf3ddf9c-a64b-4f59-a5e4-5230c44b4d87',
      canonicalName: 'Max Freeman',
      entityType: SearchEntityType.person,
      metadata: {
        'driverId': null,
        'codriverId': '7a633b52-950e-49ef-8cab-34cd43e99366',
      },
    ),
  ];

  test(
    'validates current corpus, duplicates, coverage, and milestones',
    () async {
      final manifest = jsonDecode(
        await File('test/eval/entity_search/human_voice_smoke_manifest.json')
            .readAsString(),
      ) as Map<String, dynamic>;
      final report = await validator.validate(
        manifest: manifest,
        liveEntities: liveEntities,
      );

      expect(report['valid'], isTrue);
      expect(report['errors'], 0);
      expect(report['fixturesSilentlyDropped'], 0);
      final inventory = report['audioInventory'] as Map;
      expect(inventory['TOTAL_FILES'], 5);
      expect(inventory['UNIQUE_AUDIO_FILES'], 4);
      expect(inventory['DUPLICATE_GROUPS'], hasLength(1));
      final coverage = (report['coverage'] as Map)['uniqueAudio'] as Map;
      expect(coverage['recordings'], 4);
      expect(coverage['speakers'], {'speaker-anon-01': 4});
      final milestones = report['collectionMilestones'] as List;
      expect((milestones.first as Map)['uniqueRecordingsRemaining'], 26);
      expect((milestones.first as Map)['speakersRemaining'], 2);

      final fixtures = (manifest['fixtures'] as List).whereType<Map>();
      final asim1 = fixtures.singleWhere(
        (fixture) => fixture['fixtureId'] == 'human-smoke-001',
      );
      final permanentRegression = asim1['permanentRegression'] as Map;
      expect(
        permanentRegression,
        containsPair('regressionId', 'ES8A_ASIM1_DYNAMIC_TOP3_RECOVERY'),
      );
      expect(
        permanentRegression,
        containsPair(
          'frozenRawTranscript',
          "Drivers that participated in Alex's rally.",
        ),
      );
      expect(permanentRegression, containsPair('frozenRawOutcome', 'NO_MATCH'));
      expect(
        permanentRegression,
        containsPair(
          'dynamicTop3Transcript',
          'Drivers that participated in Alūksne Rally.',
        ),
      );
      expect(
        permanentRegression,
        containsPair('dynamicTop3Outcome', 'CORRECT_CLARIFICATION'),
      );
      expect(
        permanentRegression,
        containsPair('circularEvidenceConfirmationRequired', true),
      );
    },
  );

  test('reports invalid fixtures without silently dropping them', () async {
    final manifest = jsonDecode(
      await File('test/eval/entity_search/human_voice_smoke_manifest.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    final fixtures = (manifest['fixtures'] as List).cast<Map>();
    fixtures.first['speakerId'] = '';
    fixtures.first['sha256'] =
        '0000000000000000000000000000000000000000000000000000000000000000';
    fixtures.first['expectedYear'] = 2025;

    final report = await validator.validate(
      manifest: manifest,
      liveEntities: liveEntities,
    );
    final codes = (report['issues'] as List)
        .whereType<Map>()
        .map((item) => item['code'])
        .toSet();

    expect(report['valid'], isFalse);
    expect(report['fixturesValidated'], 5);
    expect(report['fixturesSilentlyDropped'], 0);
    expect(codes, contains('MISSING_SPEAKERID'));
    expect(codes, contains('LEGACY_ALIAS_MISMATCH'));
    expect(codes, contains('SHA256_MISMATCH'));
    expect(codes, contains('EVENT_YEAR_MISMATCH'));
  });
}
