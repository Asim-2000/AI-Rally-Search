import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_output_validator.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'package:ai_rally_search/services/llm/query_understanding_spec.dart';
import 'eval_models.dart';
import 'eval_report_formatter.dart';
import 'multilingual_benchmark_cases.dart';
import 'provider_evaluator.dart';

void main() {
  group('1. SupportedLanguage & Registry Tests', () {
    test('Contains exactly 19 unique deduplicated supported languages', () {
      expect(SupportedLanguages.all.length, 19);

      final codes = SupportedLanguages.all.map((l) => l.languageCode).toSet();
      expect(codes.length, 19, reason: 'All language codes must be unique');

      final locales = SupportedLanguages.all.map((l) => l.localeCode).toSet();
      expect(locales.length, 19, reason: 'All locale codes must be unique');
    });

    test('Includes canonical codes for key languages', () {
      final norwegian = SupportedLanguages.findByCode('nb');
      expect(norwegian, isNotNull);
      expect(norwegian!.displayName, 'Norwegian (Bokmål)');
      expect(norwegian.localeCode, 'nb-NO');

      final german = SupportedLanguages.findByCode('de');
      expect(german, isNotNull);
      expect(german!.associatedCountries, contains('Austria'));
      expect(german.associatedCountries, contains('Belgium'));

      final urdu = SupportedLanguages.findByCode('ur');
      expect(urdu, isNotNull);
      expect(urdu!.isRtl, isTrue);

      final arabic = SupportedLanguages.findByCode('ar');
      expect(arabic, isNotNull);
      expect(arabic!.isRtl, isTrue);

      final welsh = SupportedLanguages.findByCode('cy');
      expect(welsh, isNotNull);
      expect(welsh!.nativeName, 'Cymraeg');

      final irish = SupportedLanguages.findByCode('ga');
      expect(irish, isNotNull);
      expect(irish!.nativeName, 'Gaeilge');
    });

    test('Lookup by code and locale works case-insensitively', () {
      expect(SupportedLanguages.findByCode('DE'), SupportedLanguages.german);
      expect(SupportedLanguages.findByLocale('de-de'), SupportedLanguages.german);
      expect(SupportedLanguages.findByLocale('de_DE'), SupportedLanguages.german);
      expect(SupportedLanguages.findByCode('unknown'), isNull);
    });
  });

  group('2. Multilingual Benchmark Dataset Integrity Tests', () {
    test('Dataset contains 304 test cases across all 19 supported languages', () {
      final cases = MultilingualBenchmarkCases.allCases;
      expect(cases.length, 304);

      final langCounts = <String, int>{};
      for (final c in cases) {
        expect(c.languageCode, isNotNull);
        langCounts[c.languageCode!] = (langCounts[c.languageCode!] ?? 0) + 1;
      }

      expect(langCounts.length, 19);
      for (final lang in SupportedLanguages.all) {
        expect(langCounts[lang.languageCode], 16,
            reason: 'Language ${lang.languageCode} must have 16 test cases');
      }
    });

    test('All 16 semantic case IDs exist across every language', () {
      final cases = MultilingualBenchmarkCases.allCases;
      final expectedSemanticIds = {
        'sem_ral_country_year_01',
        'sem_ral_city_02',
        'sem_ral_name_03',
        'sem_driver_rallies_04',
        'sem_driver_wins_05',
        'sem_rally_winner_06',
        'sem_top_finishers_07',
        'sem_driver_videos_08',
        'sem_action_jump_09',
        'sem_action_drift_10',
        'sem_action_crash_11',
        'sem_action_compound_12',
        'sem_top_uploaders_13',
        'sem_career_wins_14',
        'sem_clarification_broad_15',
        'sem_code_switching_16',
      };

      for (final lang in SupportedLanguages.all) {
        final langCases =
            cases.where((c) => c.languageCode == lang.languageCode).toList();
        final langSemanticIds =
            langCases.map((c) => c.semanticCaseId).toSet();

        expect(langSemanticIds, expectedSemanticIds,
            reason: 'Language ${lang.languageCode} missing some semantic IDs');
      }
    });

    test('Entities in benchmark queries match expected filter values verbatim', () {
      final compoundCases = MultilingualBenchmarkCases.allCases
          .where((c) => c.semanticCaseId == 'sem_action_compound_12')
          .toList();

      for (final c in compoundCases) {
        expect(c.expectedFilters['driverName'], 'Josh Moffett');
        expect(c.expectedFilters['rallyName'], 'Moonraker');
        expect(c.expectedFilters['actionType'], 'jump');
        expect(c.expectedFilters['year'], 2025);
        expect(c.expectedIntent, SearchIntent.searchVideoActions);
      }
    });
  });

  group('3. SearchContext Locale Propagation Tests', () {
    test('SearchContext holds locale and languageCode gracefully', () {
      const ctx = SearchContext(
        currentYear: 2026,
        locale: 'de-DE',
        languageCode: 'de',
        activeRally: 'Moonraker',
      );

      expect(ctx.currentYear, 2026);
      expect(ctx.locale, 'de-DE');
      expect(ctx.languageCode, 'de');
      expect(ctx.activeRally, 'Moonraker');
    });
  });

  group('4. Multilingual System Prompt & Schema Validation', () {
    test('System prompt mentions all canonical action types and entity preservation', () {
      final prompt = QueryUnderstandingSpec.systemPrompt;
      expect(prompt, contains('Multilingual'));
      expect(prompt, contains('PRESERVE ENTITY IDENTITY'));
      expect(prompt, contains('jump'));
      expect(prompt, contains('drift'));
      expect(prompt, contains('crash'));
      expect(prompt, contains('spin'));
      expect(prompt, contains('Sprünge'));
      expect(prompt, contains('sauts'));
      expect(prompt, contains('saltos'));
    });

    test('JSON schema preserves canonical structure without provider breakage', () {
      final schema = QueryUnderstandingSpec.jsonSchema;
      expect(schema['name'], 'rally_search_query');
      expect(schema['schema']['required'], contains('intent'));
      expect(schema['schema']['required'], contains('requiresClarification'));
    });
  });

  group('5. Offline Multilingual Evaluation Simulation', () {
    test('Evaluates synthetic parser across multilingual test cases and groups by language', () async {
      final evaluator = const ProviderEvaluator();
      final sampleCases = MultilingualBenchmarkCases.allCases.take(32).toList(); // 2 full languages (16 each)

      final parser = _MultilingualEchoParser();
      final report = await evaluator.evaluate(
        parser: parser,
        cases: sampleCases,
      );

      expect(report.numberOfCases, 32);
      expect(report.intentAccuracyPct, 100.0);
      expect(report.exactMatchRatePct, 100.0);
      expect(report.languageMetrics.length, 2);


      final enMetrics = report.languageMetrics['en'];
      expect(enMetrics, isNotNull);
      expect(enMetrics!.exactMatchPct, 100.0);

      final deMetrics = report.languageMetrics['de'];
      expect(deMetrics, isNotNull);
      expect(deMetrics!.exactMatchPct, 100.0);

      // Verify formatting with per-language table
      final md = EvalReportFormatter.formatMarkdownReport(report);
      expect(md, contains('Per-Language Performance Breakdown'));
      expect(md, contains('| `EN` |'));
      expect(md, contains('| `DE` |'));
    });
  });
}

class _MultilingualEchoParser implements LlmQueryParser {
  @override
  LlmProvider get provider => LlmProvider.mock;

  @override
  Future<QueryParseResult> parse(String userQuery, {SearchContext? context}) async {
    // Find matching case in benchmark dataset to simulate 100% accurate parser output
    final matchingCase = MultilingualBenchmarkCases.allCases.firstWhere(
      (c) => c.query.trim().toLowerCase() == userQuery.trim().toLowerCase(),
      orElse: () => MultilingualBenchmarkCases.allCases.first,
    );

    if (matchingCase.expectedClarification) {
      return QueryParseResult.clarification(
        clarificationQuestion: 'What kind of clips would you like to see?',
        provider: LlmProvider.mock,
        model: 'multilingual-echo-v1',
        latencyMs: 15,
      );
    }


    final query = matchingCase.expectedQuery!;
    final summary = QueryOutputValidator.generateInterpretedSummary(query);

    return QueryParseResult(
      query: query,
      requiresClarification: false,
      interpretedSummary: summary,
      provider: LlmProvider.mock,
      model: 'multilingual-echo-v1',
      latencyMs: 25,
      promptTokens: 30,
      completionTokens: 20,
    );
  }
}
