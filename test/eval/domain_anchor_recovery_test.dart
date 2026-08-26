import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/speech/voice_entity_recovery_service.dart';
import 'package:ai_rally_search/services/speech/multilingual_domain_lexicon.dart';

void main() {
  group('Phase 5B.2 — Pre-LLM Domain Anchor Recovery Test Suite', () {
    const recoveryService = VoiceEntityRecoveryService();

    test('19-Language Country Vocabulary Exact and Normalized Recovery', () {
      int totalCases = 0;
      int successfulCases = 0;

      final testPhrases = {
        'en': 'Show rallies in Ireland in 2025',
        'ga': 'Taispeáin railíthe in Éirinn in 2025',
        'cy': 'Dangos ralïau yn Iwerddon yn 2025',
        'de': 'Zeige Rallyes in Irland im Jahr 2025',
        'fr': 'Montrez les rallies en Irlande en 2025',
        'es': 'Mostrar rallies en Irlanda en 2025',
        'it': 'Mostra rally in Irlanda nel 2025',
        'pt': 'Mostrar rallies na Irlanda em 2025',
        'nl': 'Toon rallys in Ierland in 2025',
        'pl': 'Pokaż rajdy w Irlandii w 2025 roku',
        'nb': 'Vis rallyer i Irland i 2025',
        'lv': 'Rādīt rālijus Īrijā 2025 gadā',
        'lt': 'Rodyti ralius Airijoje 2025 metais',
        'cs': 'Ukaž rally v Irsku v roce 2025',
        'hr': 'Prikaži relije u Irskoj u 2025 godini',
        'sk': 'Ukáž rely v Írsku v roku 2025',
        'ur': '2025 میں آئرلینڈ کی ریلیاں دکھائیں',
        'ar': 'أظهر الراليات في أيرلندا في عام 2025',
        'sw': 'Onyesha rali nchini Ayalandi mwaka wa 2025',
      };

      for (final entry in testPhrases.entries) {
        totalCases++;
        final result = recoveryService.recover(entry.value, languageCode: entry.key);
        if (result.normalizedTranscript.contains('Ireland')) {
          successfulCases++;
        }
      }

      final recall = successfulCases / totalCases;
      print('Exact 19-Language Country Recall: ${(recall * 100).toStringAsFixed(1)}% ($successfulCases/$totalCases)');
      expect(recall >= 0.95, isTrue);
    });

    test('Pre-LLM Phonetic Country Anchor Approximate Matching', () {
      final phoneticCorruptions = [
        {'input': 'Vis religiet i Ørland i 2025', 'lang': 'nb', 'expected': 'Ireland'},
        {'input': 'Dangos Ralyeni Werdon in 2025', 'lang': 'cy', 'expected': 'Ireland'},
        {'input': 'Rodyt raliu Seirijoje 25 metais', 'lang': 'lt', 'expected': 'Ireland'},
        {'input': 'Ukáž Relif Irsku v roku 2025', 'lang': 'sk', 'expected': 'Ireland'},
      ];

      for (final tc in phoneticCorruptions) {
        final result = recoveryService.recover(tc['input']!, languageCode: tc['lang']);
        expect(
          result.normalizedTranscript.contains(tc['expected']!),
          isTrue,
          reason: 'Failed to recover ${tc['expected']} from "${tc['input']}"',
        );
      }
    });

    test('Compound Action Word Segmentation across German/Nordic/Dutch', () {
      final compoundCases = [
        'Zeige Sprunghighlights von Josh Moffett',
        'Doen spronghoogtepunten van Moonraker',
        'Vis hopphøydepunkter i 2025',
      ];

      for (final input in compoundCases) {
        final result = recoveryService.recover(input);
        expect(
          result.normalizedTranscript.contains('Highlights') ||
          result.normalizedTranscript.contains('hoogtepunten') ||
          result.normalizedTranscript.contains('høydepunkter'),
          isTrue,
        );
      }
    });

    test('Negative Safety: Unrelated non-domain words MUST NOT be transformed', () {
      final negativeSentences = [
        'Show videos from John Smith in Boston',
        'Find cars driving in Tokyo at night',
        'Search for Toyota Corolla on stage one',
        'Banana pineapple strawberry dessert recipe',
        'Craig Breen driving fast on gravel',
      ];

      for (final s in negativeSentences) {
        final result = recoveryService.recover(s);
        expect(result.domainAnchorRecoveries.where((r) => r.category == 'country').isEmpty, isTrue);
        expect(result.normalizedTranscript, equals(s));
      }
    });

    test('Precision and Recall Benchmark Evaluation', () {
      int truePositives = 0;
      int falsePositives = 0;
      int falseNegatives = 0;

      final benchmarkDataset = [
        // Positive Cases (Countries & Actions)
        {'text': 'Rallies in Irland 2025', 'hasAnchor': true},
        {'text': 'Rallies in Irlande 2025', 'hasAnchor': true},
        {'text': 'Rallies in Iwerddon 2025', 'hasAnchor': true},
        {'text': 'Rallies in Éirinn 2025', 'hasAnchor': true},
        {'text': 'Rallies in Airijoje 2025', 'hasAnchor': true},
        {'text': 'Rallies in Irsku 2025', 'hasAnchor': true},
        {'text': 'Rallies in Irskoj 2025', 'hasAnchor': true},
        {'text': 'Rallies in Ayalandi 2025', 'hasAnchor': true},
        {'text': 'Rallies in آئرلینڈ 2025', 'hasAnchor': true},
        {'text': 'Rallies in أيرلندا 2025', 'hasAnchor': true},
        {'text': 'Rallies in United Kingdom 2025', 'hasAnchor': true},
        {'text': 'Rallies in Portugal 2025', 'hasAnchor': true},
        {'text': 'Rallies in France 2025', 'hasAnchor': true},
        {'text': 'Rallies in Austria 2025', 'hasAnchor': true},
        {'text': 'Rallies in Norway 2025', 'hasAnchor': true},
        {'text': 'Rallies in Sweden 2025', 'hasAnchor': true},
        {'text': 'Rallies in Finland 2025', 'hasAnchor': true},
        {'text': 'Rallies in Germany 2025', 'hasAnchor': true},
        {'text': 'Rallies in Italy 2025', 'hasAnchor': true},
        {'text': 'Rallies in Spain 2025', 'hasAnchor': true},

        // Negative Cases
        {'text': 'Look at this funny cat video', 'hasAnchor': false},
        {'text': 'Craig Breen driving on gravel', 'hasAnchor': false},
        {'text': 'Keith Cronin fast hairpin', 'hasAnchor': false},
        {'text': 'Josh Moffett winning in Donegal', 'hasAnchor': false},
        {'text': 'Callum Devine on stage four', 'hasAnchor': false},
        {'text': 'West Cork rally stage records', 'hasAnchor': false},
        {'text': 'Moonraker forestry rally 2025', 'hasAnchor': false},
        {'text': 'Random podcast episode about cars', 'hasAnchor': false},
        {'text': 'Hello world testing microphone', 'hasAnchor': false},
        {'text': 'Weather forecast for tomorrow', 'hasAnchor': false},
      ];

      for (final item in benchmarkDataset) {
        final text = item['text'] as String;
        final shouldHaveAnchor = item['hasAnchor'] as bool;

        final result = recoveryService.recover(text);
        final detectedAnchor = result.domainAnchorRecoveries.isNotEmpty || result.hasRecoveries;

        if (detectedAnchor && shouldHaveAnchor) {
          truePositives++;
        } else if (detectedAnchor && !shouldHaveAnchor) {
          falsePositives++;
        } else if (!detectedAnchor && shouldHaveAnchor) {
          falseNegatives++;
        }
      }

      final precision = truePositives / (truePositives + falsePositives);
      final recall = truePositives / (truePositives + falseNegatives);

      print('Domain Anchor Precision: ${(precision * 100).toStringAsFixed(1)}% ($truePositives/${truePositives + falsePositives})');
      print('Domain Anchor Recall: ${(recall * 100).toStringAsFixed(1)}% ($truePositives/${truePositives + falseNegatives})');

      expect(precision >= 0.99, isTrue, reason: 'Domain anchor precision must be >= 99%');
      expect(recall >= 0.95, isTrue, reason: 'Domain anchor recall must be >= 95%');
    });
  });
}
