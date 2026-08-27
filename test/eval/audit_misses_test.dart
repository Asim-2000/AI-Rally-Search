import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Audit exact misses and non-top-1 cases', () async {
    await dotenv.load(fileName: '.env');
    final dbService = DatabaseService();
    final lookupRepo = DatabaseEntityLookupRepository(dbService: dbService);
    final resolver = DatabaseEntityResolver(
      repository: lookupRepo,
      minConfidenceThreshold: 0.75,
      minScoreGap: 0.15,
    );

    final rallyCases = [
      {'canonical': 'Rally Alūksne 2026', 'perturbations': ['Rally Aluske', 'aluxne', 'aluksne', 'Rally Aluksne']},
      {'canonical': '6 Uren van Kortrijk 2024', 'perturbations': ['kortrik', '6 Uren van Kortrik', 'Kortrijk 2024', 'Uren van Kortrijk']},
      {'canonical': 'Rali Serras de Fafe 2025', 'perturbations': ['Rali Serras de Faf', 'Serras de Fafe', 'Rally Fafe', 'Fafe 2025']},
      {'canonical': '7bet Rally Lazdijai 2025', 'perturbations': ['lazdiai', '7bet Rally Lazdiai', 'Rally Lazdijai', 'Lazdijai 2025']},
      {'canonical': "Rali Terras d'Aboboreira 2026", 'perturbations': ["aboborera", "Terras d'Aboboreira", "Rali Terras d Aboboreira 2026", "Aboboreira 2026"]},
      {'canonical': 'Polski Rajd Legend 2026', 'perturbations': ['Polski Raid Legend', 'Rajd Legend', 'Polski Rajd Legend', 'Polanica Legend']},
      {'canonical': 'Rally Vranov 2026', 'perturbations': ['Rally Vranow', 'Vranov 2026', 'Rally Vranov', 'Vranov Nad Toplou']},
      {'canonical': 'OBM Land der 1000 Hügel Rallye 2026', 'perturbations': ['1000 Hugel Rallye', 'Land der 1000 Hugel', '1000 Hügel', 'Hugel Rallye 2026']},
      {'canonical': 'Rallijsprints Cesavine 2026', 'perturbations': ['Cesavine', 'Rallijsprint Cesavine', 'Cesavine 2026', 'Cesavine Rally']},
      {'canonical': 'Rallye Régional des Ardennes 2025', 'perturbations': ['Regional des Ardennes', 'Rally Ardennes', 'Ardennes 2025', 'Rallye des Ardennes']},
      {'canonical': 'Century 21 Portugal Rally Series - Castelo Branco 2025', 'perturbations': ['Castelo Branco', 'Castelo Branco 2025', 'Rally Castelo Branco', 'Portugal Rally Series Castelo Branco']},
      {'canonical': 'Corrib Oil Galway International Rally 2026', 'perturbations': ['Galway Rally', 'Galway International 2026', 'Corrib Oil Galway', 'Galway 2026']},
      {'canonical': 'Assess Ireland International Rally of the Lakes 2026', 'perturbations': ['Rally of the Lakes', 'Rally of the Lakes 2026', 'International Rally of the Lakes', 'Lakes Rally 2026']},
      {'canonical': 'Clonakilty Park Hotel West Cork Rally 2026', 'perturbations': ['West Cork Rally', 'Westcork 2026', 'West Cork 2026', 'Clonakilty West Cork']},
      {'canonical': 'Samsonas Rally Fivemiletown 2026', 'perturbations': ['Fivemiletown', 'Fivemiletown Rally', 'Samsonas Fivemiletown', 'Fivemiletown 2026']},
      {'canonical': 'Modern Tyres Ulster Rally 2025', 'perturbations': ['Ulster Rally', 'Ulster Rally 2025', 'Modern Tyres Ulster', 'Ulster 2025']},
      {'canonical': 'Raven\'s Rock Stages Rally 2025', 'perturbations': ['Ravens Rock', 'Ravens Rock Stages', 'Ravens Rock 2025', 'Raven Rock Rally']},
      {'canonical': 'Birr Stages Rally 2026', 'perturbations': ['Birr Stages', 'Birr Rally', 'Birr Stages 2026', 'Birr 2026']},
      {'canonical': 'Fastnet Stages Rally 2025', 'perturbations': ['Fastnet Stages', 'Fastnet Rally', 'Fastnet 2025', 'Fastnet Stages 2025']},
      {'canonical': 'HK Cavan Stages Rally 2025', 'perturbations': ['Cavan Stages', 'Cavan Stages 2025', 'Cavan Rally', 'HK Cavan 2025']},
    ];

    final driverCases = [
      {'canonical': 'Jon-Gunnar Støten', 'role': 'driver', 'perturbations': ['Jon Gunnar Stoten', 'Jon Gunnar Støten', 'Jon-Gunnar Stoten', 'Stoten']},
      {'canonical': 'Michal Babička', 'role': 'driver', 'perturbations': ['Michal Babicka', 'Michal Babicka', 'Babicka', 'Michal Babicka']},
      {'canonical': 'Adam Zelík', 'role': 'driver', 'perturbations': ['Adam Zelik', 'Adam Zelik', 'Zelik', 'Adam Zelik']},
      {'canonical': 'Věroslav Cvrček', 'role': 'driver', 'perturbations': ['Veroslav Cvrcek', 'Věroslav Cvrcek', 'Veroslav Cvrček', 'Cvrcek']},
      {'canonical': 'Piotr Krotoszyński', 'role': 'driver', 'perturbations': ['Piotr Krotoszynski', 'Piotr Krotoszynski', 'Krotoszynski', 'Piotr Krotoszynski']},
      {'canonical': 'Hervé Emeriau', 'role': 'driver', 'perturbations': ['Herve Emeriau', 'Hervé Emeriau', 'Herve Emerio', 'Emeriau']},
      {'canonical': 'José Paula', 'role': 'driver', 'perturbations': ['Jose Paula', 'José Paula', 'Jose Pawla', 'Paula']},
      {'canonical': 'Sergio Ramón Arrom', 'role': 'driver', 'perturbations': ['Sergio Ramon Arrom', 'Sergio Ramon', 'Ramon Arrom', 'Sergio Arrom']},
      {'canonical': 'Raphaël Czwartkowski', 'role': 'driver', 'perturbations': ['Raphael Czwartkowski', 'Raphael Czwartkovski', 'Czwartkowski', 'Raphaël Czwartkovski']},
      {'canonical': 'Vítor Matias', 'role': 'driver', 'perturbations': ['Vitor Matias', 'Vítor Matias', 'Vitor Mathias', 'Matias']},
      {'canonical': 'Stephen O\'Connor', 'role': 'driver', 'perturbations': ['Stephen OConnor', 'Stephen O\'Connor', 'Steven OConnor', 'Stephen O Connor']},
      {'canonical': 'Diarmuid O\'Toole', 'role': 'driver', 'perturbations': ['Diarmuid OToole', 'Diarmuid O\'Toole', 'Dermot OToole', 'Diarmuid O Toole']},
      {'canonical': 'Tanja Zingelmann-Hartjen', 'role': 'driver', 'perturbations': ['Tanja Zingelmann', 'Tanja Zingelmann Hartjen', 'Tanja Hartjen', 'Zingelmann-Hartjen']},
      {'canonical': 'Paweł Molgo', 'role': 'driver', 'perturbations': ['Pawel Molgo', 'Paweł Molgo', 'Pawel Malgo', 'Molgo']},
      {'canonical': 'Nenad Lončarič', 'role': 'driver', 'perturbations': ['Nenad Loncaric', 'Nenad Lončaric', 'Nenad Loncarich', 'Loncaric']},
      {'canonical': 'Matej Bogović', 'role': 'driver', 'perturbations': ['Matej Bogovic', 'Matej Bogović', 'Matej Bogovich', 'Bogovic']},
      {'canonical': 'Andrej Medić', 'role': 'driver', 'perturbations': ['Andrej Medic', 'Andrej Medić', 'Andrej Medich', 'Medic']},
      {'canonical': 'John Shanahan jnr.', 'role': 'driver', 'perturbations': ['John Shanahan', 'John Shanahan Jr', 'John Shanahan jnr', 'Shanahan']},
      {'canonical': 'Shea Breen', 'role': 'driver', 'perturbations': ['Shea Brean', 'Shea Breen', 'Shea Brain', 'Shay Breen']},
      {'canonical': 'Max Freeman', 'role': 'co_driver', 'perturbations': ['Max Freeman', 'Max Freman', 'Max Frieman', 'Freeman']},
      {'canonical': 'Jan-Erik Mäll', 'role': 'co_driver', 'perturbations': ['Jan Erik Mall', 'Jan-Erik Mall', 'Jan Erik Mäll', 'Mall']},
      {'canonical': 'Catharina Schmidt', 'role': 'co_driver', 'perturbations': ['Catharina Schmidt', 'Catherina Schmidt', 'Katarina Schmidt', 'Schmidt']},
    ];

    final stageCases = [
      {'canonical': 'Woodstoxx Kemmelberg 1', 'perturbations': ['Kemelberg', 'Woodstoxx Kemelberg', 'Kemmelberg 1', 'Kemmelberg']},
      {'canonical': 'Duszniki - Zieleniec 2', 'perturbations': ['Dushniki', 'Duszniki Zieleniec', 'Duszniki', 'Zieleniec 2']},
      {'canonical': 'Seixoso 2', 'perturbations': ['Seixoso', 'Seixoso 2', 'Seiksozo', 'SS Seixoso']},
      {'canonical': 'Drumhallagh 2', 'perturbations': ['Drumhallagh', 'Drumhallagh 2', 'Drumhalagh', 'SS Drumhallagh']},
      {'canonical': 'Dikkebus 1', 'perturbations': ['Dikkebus', 'Dikebus', 'Dikkebus 1', 'SS Dikkebus']},
      {'canonical': 'Fafe 2Powerstage', 'perturbations': ['Fafe Powerstage', 'Fafe 2', 'Fafe', 'Powerstage Fafe']},
      {'canonical': 'Knockalla 2', 'perturbations': ['Knockalla', 'Knokalla', 'Knockalla 2', 'SS Knockalla']},
      {'canonical': 'Dunworley 2', 'perturbations': ['Dunworley', 'Dunworley 2', 'Dunworly', 'SS Dunworley']},
      {'canonical': 'Kellymount 1', 'perturbations': ['Kellymount', 'Kellymount 1', 'Kelley Mount', 'SS Kellymount']},
      {'canonical': 'Scart Mountain 1', 'perturbations': ['Scart Mountain', 'Scart Mountain 1', 'Scart Mt', 'SS Scart Mountain']},
    ];

    print('AUDITING RECALL MISSES AND NON-TOP-1 CASES...');

    // Audit driver misses specifically
    for (final item in driverCases) {
      final canonical = item['canonical'] as String;
      final role = item['role'] as String;
      final perturbations = item['perturbations'] as List<String>;

      for (final p in perturbations) {
        final candidates = await lookupRepo.lookupDrivers(p, limit: 50);
        final scoredCandidates = candidates.map((c) {
          final score = PhoneticMatchingHelper.computeCompositeScore(
            queryPhrase: p,
            candidateName: c.canonicalName,
            isPerson: true,
          );
          return c.copyWith(score: score);
        }).toList()
          ..sort((a, b) => (b.score ?? 0.0).compareTo(a.score ?? 0.0));

        final inTop5 = scoredCandidates.take(5).any((c) => _matchesCanonical(c.canonicalName, canonical));
        final res = await resolver.resolve(SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: p));
        final resolvedName = res.resolutions['driver']?.resolvedCandidate?.canonicalName;
        final isResolvedCorrect = resolvedName != null && _matchesCanonical(resolvedName, canonical);
        final clarContains = res.candidates.any((c) => _matchesCanonical(c.canonicalName, canonical)) ||
            (res.resolutions['driver']?.candidateOptions.any((c) => _matchesCanonical(c.canonicalName, canonical)) ?? false);

        if (!inTop5) {
          print('\n[RECALL@5 MISS - $role]');
          print('  Canonical: "$canonical"');
          print('  Query/Perturbation: "$p"');
          print('  Top 5 Scored: ${scoredCandidates.take(5).map((c) => "${c.canonicalName} (${c.score?.toStringAsFixed(2)})").toList()}');
          print('  Total candidates returned: ${candidates.length}');
          print('  In full candidates list: ${candidates.any((c) => _matchesCanonical(c.canonicalName, canonical))}');
        }

        if (!isResolvedCorrect && !clarContains) {
          print('\n[NON-TOP-1 MISS - $role]');
          print('  Canonical: "$canonical"');
          print('  Query: "$p"');
          print('  Resolution: resolved="$resolvedName", amb=${res.resolutions['driver']?.isAmbiguous}, strat=${res.resolutions['driver']?.strategy}, conf=${res.resolutions['driver']?.confidence}');
        }
      }
    }

    // Audit stage misses
    for (final item in stageCases) {
      final canonical = item['canonical'] as String;
      final perturbations = item['perturbations'] as List<String>;

      for (final p in perturbations) {
        final candidates = await lookupRepo.lookupStages(p, limit: 35);
        final scoredCandidates = candidates.map((c) {
          final score = PhoneticMatchingHelper.computeCompositeScore(
            queryPhrase: p,
            candidateName: c.canonicalName,
          );
          return c.copyWith(score: score);
        }).toList()
          ..sort((a, b) => (b.score ?? 0.0).compareTo(a.score ?? 0.0));

        final inTop5 = scoredCandidates.take(5).any((c) => _matchesCanonical(c.canonicalName, canonical));
        final res = await resolver.resolve(SearchQuery(intent: SearchIntent.searchVideoActions, stageName: p));
        final resolvedName = res.resolutions['stage']?.resolvedCandidate?.canonicalName;
        final isResolvedCorrect = resolvedName != null && _matchesCanonical(resolvedName, canonical);
        final clarContains = res.candidates.any((c) => _matchesCanonical(c.canonicalName, canonical)) ||
            (res.resolutions['stage']?.candidateOptions.any((c) => _matchesCanonical(c.canonicalName, canonical)) ?? false);

        if (!inTop5) {
          print('\n[STAGE RECALL@5 MISS]');
          print('  Canonical: "$canonical"');
          print('  Query: "$p"');
          print('  Top 5 Scored: ${scoredCandidates.take(5).map((c) => "${c.canonicalName} (${c.score?.toStringAsFixed(2)})").toList()}');
        }

        if (!isResolvedCorrect && !clarContains) {
          print('\n[STAGE NON-TOP-1 MISS]');
          print('  Canonical: "$canonical"');
          print('  Query: "$p"');
          print('  Resolution: resolved="$resolvedName", amb=${res.resolutions['stage']?.isAmbiguous}, strat=${res.resolutions['stage']?.strategy}, conf=${res.resolutions['stage']?.confidence}');
        }
      }
    }

    await dbService.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}

bool _matchesCanonical(String candidate, String target) {
  final cNorm = PhoneticMatchingHelper.normalize(candidate);
  final tNorm = PhoneticMatchingHelper.normalize(target);
  if (cNorm == tNorm) return true;

  final cBase = PhoneticMatchingHelper.stripYear(cNorm);
  final tBase = PhoneticMatchingHelper.stripYear(tNorm);
  if (cBase == tBase && cBase.isNotEmpty) return true;

  final cCore = PhoneticMatchingHelper.collapseSpaces(PhoneticMatchingHelper.stripDescriptors(cNorm));
  final tCore = PhoneticMatchingHelper.collapseSpaces(PhoneticMatchingHelper.stripDescriptors(tNorm));
  if (cCore == tCore && cCore.isNotEmpty) return true;

  return cNorm.contains(tBase) || tNorm.contains(cBase) || (tCore.isNotEmpty && cCore.contains(tCore)) || (cCore.isNotEmpty && tCore.contains(cCore));
}
