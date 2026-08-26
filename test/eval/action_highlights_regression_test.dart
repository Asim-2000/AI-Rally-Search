import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/services/speech/voice_entity_recovery_service.dart';
import 'package:ai_rally_search/services/llm/query_understanding_spec.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/transliteration_helper.dart';

void main() {
  group('Action Highlights & Voice Entity Recovery Regression Tests', () {
    const recoveryService = VoiceEntityRecoveryService();

    test('Highlights query must preserve actionType and not trigger clarification', () {
      final prompt = QueryUnderstandingSpec.systemPrompt;
      expect(prompt.contains('actionType'), isTrue);
      expect(prompt.contains('jump highlights'), isTrue);
      expect(prompt.contains('requiresClarification: false'), isTrue);
    });

    test('VoiceEntityRecoveryService recovers genuine linguistic country aliases', () {
      final irishInput = 'Taispeáin ralaithe in Éirinn in 2025';
      final irishResult = recoveryService.recover(irishInput, languageCode: 'ga');
      expect(irishResult.normalizedTranscript.contains('Ireland'), isTrue);

      final welshInput = 'Dangos ralïau yn Iwerddon yn 2025';
      final welshResult = recoveryService.recover(welshInput, languageCode: 'cy');
      expect(welshResult.normalizedTranscript.contains('Ireland'), isTrue);

      final spanishInput = 'Mostrar rallies en Irlanda en 2025';
      final spanishResult = recoveryService.recover(spanishInput, languageCode: 'es');
      expect(spanishResult.normalizedTranscript.contains('Ireland'), isTrue);
    });

    test('TransliterationHelper and PhoneticMatchingHelper recover cross-script Arabic transliterations', () {
      final arabicDriver = 'جوش موفت';
      final translits = TransliterationHelper.transliterateToLatin(arabicDriver);
      expect(translits.isNotEmpty, isTrue);

      final score = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: arabicDriver,
        candidateName: 'Josh Moffett',
      );
      expect(score >= 0.85, isTrue);
    });

    test('TransliterationHelper and PhoneticMatchingHelper recover cross-script Urdu transliterations', () {
      final urduDriver = 'جوش موفیٹ';
      final score = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: urduDriver,
        candidateName: 'Josh Moffett',
      );
      expect(score >= 0.85, isTrue);
    });

    test('PhoneticMatchingHelper recovers acoustic and word-boundary variants', () {
      final moffatScore = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: 'Josh Moffat',
        candidateName: 'Josh Moffett',
      );
      expect(moffatScore >= 0.85, isTrue);

      final moonrakerScore = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: 'Moon Raker',
        candidateName: 'Moonraker Forestry Rally',
      );
      expect(moonrakerScore >= 0.85, isTrue);
    });

    test('VoiceEntityRecoveryService plausibly validates and corrects acoustic year anomalies', () {
      final input = 'Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2215 gadā!';
      final result = recoveryService.recover(input, languageCode: 'lv');

      expect(result.hasRecoveries, isTrue);
      expect(result.normalizedTranscript.contains('2025'), isTrue);
      expect(result.entityRecoveryMappings['2215'], equals('2025'));
    });
  });
}
