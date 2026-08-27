// ignore_for_file: avoid_print
@Tags(['live-db', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live-source versus index coverage audit', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();
    final entities = await MySqlEntitySearchDataSource(database: db)
        .loadEntities();
    final profiles = await db.query('''
      SELECT 'driver' AS role, driver_id AS role_id, account_id, full_name,
             country
      FROM user_driver_profile
      UNION ALL
      SELECT 'co_driver' AS role, codriver_id AS role_id, account_id, full_name,
             country
      FROM user_codriver_profile;
    ''');

    final indexedPeople = entities
        .where((entity) => entity.entityType == SearchEntityType.person)
        .toList();
    final nonNullAccountProfiles = profiles.where(_hasAccount).toList();
    final expectedAccountIds = nonNullAccountProfiles
        .where(_hasName)
        .map((row) => row['account_id'].toString())
        .toSet();
    final indexedAccountIds = indexedPeople
        .map((entity) => entity.metadata['accountId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final missingAccountIds = expectedAccountIds.difference(indexedAccountIds);
    final missingPeople = <Map<String, Object?>>[];
    for (final accountId in missingAccountIds) {
      final rows = profiles
          .where((row) => row['account_id']?.toString() == accountId)
          .toList();
      final reason = rows.every((row) => !_hasName(row))
          ? 'invalid/empty name'
          : 'dedup bug';
      missingPeople.add({
        'accountId': accountId,
        'reason': reason,
        'profiles': rows.map(_safeProfile).toList(),
      });
    }

    final nullAccounts = profiles.where((row) => !_hasAccount(row)).toList();
    final nullLegitimate = nullAccounts.where(_hasName).toList();
    final nullDrivers = nullLegitimate
        .where((row) => row['role'] == 'driver')
        .toList();
    final nullCodrivers = nullLegitimate
        .where((row) => row['role'] == 'co_driver')
        .toList();
    final expectedPersonIds = <String>{
      for (final id in expectedAccountIds) 'person:account:$id',
      for (final row in nullDrivers) 'person:driver:${row['role_id']}',
      for (final row in nullCodrivers) 'person:codriver:${row['role_id']}',
    };
    final indexedPersonIds = indexedPeople.map((e) => e.canonicalId).toSet();
    final missingPersonIds = expectedPersonIds.difference(indexedPersonIds);
    final coverage = <String, Map<String, Object>>{};
    coverage['PERSON'] = _coverage(
      expectedPersonIds.length,
      indexedPeople.length,
    );
    for (final type in const [
      SearchEntityType.rally,
      SearchEntityType.stage,
      SearchEntityType.uploader,
    ]) {
      final sourceCount = await _sourceCount(db, type);
      final indexed = entities.where((e) => e.entityType == type).length;
      coverage[type.name.toUpperCase()] = _coverage(sourceCount, indexed);
    }

    final namedTraces = <Map<String, Object?>>[];
    for (final expectedName in const ['Paweł Molgo', 'Shea Breen']) {
      final normalized = PhoneticMatchingHelper.normalize(expectedName);
      final exactProfiles = profiles.where((row) {
        return PhoneticMatchingHelper.normalize(
              row['full_name']?.toString() ?? '',
            ) ==
            normalized;
      }).toList();
      final accountIds = exactProfiles
          .where(_hasAccount)
          .map((row) => row['account_id'].toString())
          .toSet();
      final loaderEntities = indexedPeople.where((entity) {
        if (accountIds.contains(entity.metadata['accountId']?.toString())) {
          return true;
        }
        final names = <String>[
          entity.canonicalName,
          ...((entity.metadata['searchableNames'] as List?) ?? const []).map(
            (name) => name.toString(),
          ),
        ];
        return names.any(
          (name) => PhoneticMatchingHelper.normalize(name) == normalized,
        );
      }).toList();
      namedTraces.add({
        'expectedName': expectedName,
        'normalizedName': normalized,
        'profileRows': exactProfiles.map(_safeProfile).toList(),
        'accountIds': accountIds.toList(),
        'loaderOutput': loaderEntities
            .map(
              (entity) => {
                'canonicalId': entity.canonicalId,
                'canonicalName': entity.canonicalName,
                'metadata': entity.metadata,
              },
            )
            .toList(),
        'absentReason': loaderEntities.isNotEmpty
            ? null
            : exactProfiles.isEmpty
            ? 'No live driver/co-driver profile has this canonical full_name.'
            : accountIds.isEmpty
            ? 'Matching profile rows have NULL account_id and are excluded by loader policy.'
            : loaderEntities.isEmpty
            ? 'Unexpected loader/dedup omission.'
            : null,
      });
    }

    final report = {
      'personProfiles': {
        'totalDriverProfiles': profiles
            .where((row) => row['role'] == 'driver')
            .length,
        'totalCodriverProfiles': profiles
            .where((row) => row['role'] == 'co_driver')
            .length,
        'distinctNonNullAccountIds': nonNullAccountProfiles
            .map((row) => row['account_id'].toString())
            .toSet()
            .length,
        'profilesWithNullAccountId': nullAccounts.length,
        'namedProfilesWithNullAccountId': nullLegitimate.length,
        'distinctCanonicalPersonAccountsExpected': expectedAccountIds.length,
        'accountBackedIdentities': expectedAccountIds.length,
        'nullAccountDriverIdentities': nullDrivers.length,
        'nullAccountCodriverIdentities': nullCodrivers.length,
        'expectedTotalPersonCanonicalIdentities': expectedPersonIds.length,
        'actualPersonEntitiesIndexed': indexedPeople.length,
        'missingIdentityCount': missingPersonIds.length,
        'missingIdentityIds': missingPersonIds.toList()..sort(),
        'missingAccounts': missingPeople,
        'missingByReason': {
          'NULL account_id': 0,
          'loader filter': 0,
          'bad join': 0,
          'dedup bug': missingPeople
              .where((row) => row['reason'] == 'dedup bug')
              .length,
          'invalid/empty name': profiles
              .where((row) => _hasAccount(row) && !_hasName(row))
              .length,
          'database inconsistency': 0,
          'other': 0,
        },
      },
      'coverage': coverage,
      'namedTraces': namedTraces,
    };
    const path = 'test/eval/entity_search/index_coverage_audit_report.json';
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    print(const JsonEncoder.withIndent('  ').convert(report));
    expect(missingPeople.where((row) => row['reason'] == 'dedup bug'), isEmpty);
    await db.close();
  });
}

bool _hasAccount(Map<String, dynamic> row) {
  final value = row['account_id']?.toString().trim();
  return value != null && value.isNotEmpty && value != 'null';
}

bool _hasName(Map<String, dynamic> row) =>
    (row['full_name']?.toString().trim().isNotEmpty ?? false);

Map<String, Object?> _safeProfile(Map<String, dynamic> row) => {
  'role': row['role']?.toString(),
  'roleId': row['role_id']?.toString(),
  'accountId': _hasAccount(row) ? row['account_id']?.toString() : null,
  'fullName': row['full_name']?.toString(),
  'country': row['country']?.toString(),
  'excludedByLoader':
      !_hasName(row) || (row['role_id']?.toString().trim().isEmpty ?? true),
  'exclusionReason': !_hasName(row)
      ? 'invalid/empty name'
      : (row['role_id']?.toString().trim().isEmpty ?? true)
      ? 'invalid/empty role ID'
      : null,
  'loaderIdentity': _hasAccount(row)
      ? 'person:account:${row['account_id']}'
      : row['role'] == 'driver'
      ? 'person:driver:${row['role_id']}'
      : 'person:codriver:${row['role_id']}',
};

Map<String, Object> _coverage(int source, int indexed) => {
  'sourceCanonicalCount': source,
  'indexedCanonicalCount': indexed,
  'missingCount': source - indexed,
  'coveragePercent': source == 0 ? 100.0 : indexed * 100 / source,
};

Future<int> _sourceCount(DatabaseService db, SearchEntityType type) async {
  final sql = switch (type) {
    SearchEntityType.rally =>
      '''
      SELECT COUNT(DISTINCT event_id) AS count FROM rally_events
      WHERE event_id IS NOT NULL AND event_name IS NOT NULL
        AND TRIM(event_name) <> '';
    ''',
    SearchEntityType.stage =>
      '''
      SELECT COUNT(DISTINCT stage_id) AS count FROM rally_stages
      WHERE stage_id IS NOT NULL AND stage_name IS NOT NULL
        AND TRIM(stage_name) <> '';
    ''',
    SearchEntityType.uploader =>
      '''
      SELECT COUNT(DISTINCT fp.fan_id) AS count
      FROM user_fan_profile fp
      LEFT JOIN user_account ua ON ua.id = fp.account_id
      WHERE fp.fan_id IS NOT NULL AND
        COALESCE(NULLIF(TRIM(ua.user_name), ''),
                 NULLIF(TRIM(fp.full_name), ''),
                 NULLIF(TRIM(ua.email), '')) IS NOT NULL;
    ''',
    SearchEntityType.person => throw StateError('handled separately'),
  };
  final rows = await db.query(sql);
  return int.tryParse(rows.single['count'].toString()) ?? 0;
}
