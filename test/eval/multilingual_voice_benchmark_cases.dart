import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'voice_benchmark_models.dart';

/// Multilingual Voice Benchmark dataset covering all 19 supported languages.
class MultilingualVoiceBenchmarkCases {
  MultilingualVoiceBenchmarkCases._();

  static const List<VoiceBenchmarkCase> all = [
    // 1. English (en-GB)
    VoiceBenchmarkCase(
      id: 'voice-en-01',
      language: SupportedLanguages.english,
      expectedTranscript: 'Show jumps featuring Moffett in Donegal 2025',
      expectedDrivers: ['Moffett', 'Josh Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),
    VoiceBenchmarkCase(
      id: 'voice-en-02',
      language: SupportedLanguages.english,
      expectedTranscript: 'Who won the Moonraker Rally in 2024?',
      expectedRallies: ['Moonraker'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.getRallyResults,
        rallyName: 'Moonraker Forestry Rally',
        year: 2024,
      ),
    ),

    // 2. German (de-DE)
    VoiceBenchmarkCase(
      id: 'voice-de-01',
      language: SupportedLanguages.german,
      expectedTranscript: 'Zeige Sprünge mit Moffett bei der Donegal Rallye 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['Sprünge', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 3. French (fr-FR)
    VoiceBenchmarkCase(
      id: 'voice-fr-01',
      language: SupportedLanguages.french,
      expectedTranscript: 'Montrez les sauts de Moffett au rallye de Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['sauts', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 4. Spanish (es-ES)
    VoiceBenchmarkCase(
      id: 'voice-es-01',
      language: SupportedLanguages.spanish,
      expectedTranscript: 'Mostrar saltos de Moffett en el Rally de Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['saltos', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 5. Italian (it-IT)
    VoiceBenchmarkCase(
      id: 'voice-it-01',
      language: SupportedLanguages.italian,
      expectedTranscript: 'Mostra i salti di Moffett al Rally di Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['salti', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 6. Portuguese (pt-PT)
    VoiceBenchmarkCase(
      id: 'voice-pt-01',
      language: SupportedLanguages.portuguese,
      expectedTranscript: 'Mostrar saltos de Moffett no Rally de Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['saltos', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 7. Dutch (nl-NL)
    VoiceBenchmarkCase(
      id: 'voice-nl-01',
      language: SupportedLanguages.dutch,
      expectedTranscript: 'Toon sprongen met Moffett in Donegal Rally 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['sprongen', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 8. Polish (pl-PL)
    VoiceBenchmarkCase(
      id: 'voice-pl-01',
      language: SupportedLanguages.polish,
      expectedTranscript: 'Pokaż skoki Moffetta w Rajdzie Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['skoki', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 9. Norwegian (nb-NO)
    VoiceBenchmarkCase(
      id: 'voice-nb-01',
      language: SupportedLanguages.norwegian,
      expectedTranscript: 'Vis hopp med Moffett i Donegal Rally 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['hopp', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 10. Latvian (lv-LV)
    VoiceBenchmarkCase(
      id: 'voice-lv-01',
      language: SupportedLanguages.latvian,
      expectedTranscript: 'Rādīt lēcienus ar Moffett Donegalas rallijā 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['lēcienus', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 11. Czech (cs-CZ)
    VoiceBenchmarkCase(
      id: 'voice-cs-01',
      language: SupportedLanguages.czech,
      expectedTranscript: 'Ukaž skoky Moffetta na Rally Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['skoky', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 12. Croatian (hr-HR)
    VoiceBenchmarkCase(
      id: 'voice-hr-01',
      language: SupportedLanguages.croatian,
      expectedTranscript: 'Prikaži skokove s Moffettom na reliju Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['skokove', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 13. Lithuanian (lt-LT)
    VoiceBenchmarkCase(
      id: 'voice-lt-01',
      language: SupportedLanguages.lithuanian,
      expectedTranscript: 'Rodyti šuolius su Moffett Donegal ralyje 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['šuolius', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 14. Slovak (sk-SK)
    VoiceBenchmarkCase(
      id: 'voice-sk-01',
      language: SupportedLanguages.slovak,
      expectedTranscript: 'Ukáž skoky Moffetta na rely Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['skoky', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 15. Urdu (ur-PK) [RTL]
    VoiceBenchmarkCase(
      id: 'voice-ur-01',
      language: SupportedLanguages.urdu,
      expectedTranscript: 'ڈونیگل ریلی 2025 میں موفیٹ کی جمپس دکھائیں',
      expectedDrivers: ['موفیٹ', 'Moffett'],
      expectedRallies: ['ڈونیگل', 'Donegal'],
      expectedActions: ['جمپس', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 16. Arabic (ar-QA) [RTL]
    VoiceBenchmarkCase(
      id: 'voice-ar-01',
      language: SupportedLanguages.arabic,
      expectedTranscript: 'أظهر قفزات موفيت في رالي دونيجال 2025',
      expectedDrivers: ['موفيت', 'Moffett'],
      expectedRallies: ['دونيجال', 'Donegal'],
      expectedActions: ['قفزات', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 17. Swahili (sw-KE)
    VoiceBenchmarkCase(
      id: 'voice-sw-01',
      language: SupportedLanguages.swahili,
      expectedTranscript: 'Onyesha miruko ya Moffett katika Rali ya Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['miruko', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 18. Welsh (cy-GB)
    VoiceBenchmarkCase(
      id: 'voice-cy-01',
      language: SupportedLanguages.welsh,
      expectedTranscript: 'Dangos neidiau gyda Moffett yn Rali Donegal 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Donegal'],
      expectedActions: ['neidiau', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),

    // 19. Irish (ga-IE)
    VoiceBenchmarkCase(
      id: 'voice-ga-01',
      language: SupportedLanguages.irish,
      expectedTranscript: 'Taispeáin léimeanna le Moffett i Rally Dhún na nGall 2025',
      expectedDrivers: ['Moffett'],
      expectedRallies: ['Dhún na nGall', 'Donegal'],
      expectedActions: ['léimeanna', 'jump'],
      expectedQuery: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        rallyName: 'Donegal International Rally',
        actionType: 'jump',
        year: 2025,
      ),
    ),
  ];
}
