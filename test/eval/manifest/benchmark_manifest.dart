import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/supported_language.dart';

/// Explicit benchmark categories to ensure synthetic and human results are never combined.
enum BenchmarkType {
  /// Fast, deterministic, offline CI tests (no real audio or API calls).
  mock,

  /// High-fidelity synthesized audio generated across all 19 languages.
  synthetic,

  /// Live human-recorded speech evaluation across native accents.
  human;
}

/// Structured manifest entry defining the ground truth for an audio query sample.
class BenchmarkManifestEntry {
  final String id;
  final BenchmarkType benchmarkType;
  final String audioFile;
  final SupportedLanguage language;
  final String locale;
  final String expectedTranscript;
  final SearchIntent expectedIntent;
  final Map<String, dynamic> expectedFilters;
  final List<String> expectedEntities;
  final List<String> expectedDrivers;
  final List<String> expectedRallies;
  final List<String> expectedStages;
  final List<String> expectedActions;

  const BenchmarkManifestEntry({
    required this.id,
    required this.benchmarkType,
    required this.audioFile,
    required this.language,
    required this.locale,
    required this.expectedTranscript,
    required this.expectedIntent,
    required this.expectedFilters,
    this.expectedEntities = const [],
    this.expectedDrivers = const [],
    this.expectedRallies = const [],
    this.expectedStages = const [],
    this.expectedActions = const [],
  });

  SearchQuery get expectedQuery {
    return SearchQuery(
      intent: expectedIntent,
      driverName: expectedFilters['driverName'] as String?,
      rallyName: expectedFilters['rallyName'] as String?,
      country: expectedFilters['country'] as String?,
      city: expectedFilters['city'] as String?,
      actionType: expectedFilters['actionType'] as String?,
      year: expectedFilters['year'] as int?,
      stageName: expectedFilters['stageName'] as String?,
    );
  }
}

/// Standard 38-sample dataset manifest (2 queries × 19 languages).
class SyntheticSmokeBenchmarkManifest {
  SyntheticSmokeBenchmarkManifest._();

  static const List<BenchmarkManifestEntry> entries = [
    // 1. English (en-GB)
    BenchmarkManifestEntry(
      id: 'synth-en-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/en_01.mp3',
      language: SupportedLanguages.english,
      locale: 'en-GB',
      expectedTranscript: 'Show rallies in Ireland in 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Ireland'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-en-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/en_02.mp3',
      language: SupportedLanguages.english,
      locale: 'en-GB',
      expectedTranscript: 'Show jump highlights featuring Josh Moffett from Moonraker in 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['jump'],
    ),

    // 2. German (de-DE)
    BenchmarkManifestEntry(
      id: 'synth-de-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/de_01.mp3',
      language: SupportedLanguages.german,
      locale: 'de-DE',
      expectedTranscript: 'Zeige Rallyes in Irland im Jahr 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irland'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-de-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/de_02.mp3',
      language: SupportedLanguages.german,
      locale: 'de-DE',
      expectedTranscript: 'Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['Sprung', 'jump'],
    ),

    // 3. French (fr-FR)
    BenchmarkManifestEntry(
      id: 'synth-fr-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/fr_01.mp3',
      language: SupportedLanguages.french,
      locale: 'fr-FR',
      expectedTranscript: 'Montrez les rallyes en Irlande en 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irlande'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-fr-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/fr_02.mp3',
      language: SupportedLanguages.french,
      locale: 'fr-FR',
      expectedTranscript: 'Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['sauts', 'jump'],
    ),

    // 4. Spanish (es-ES)
    BenchmarkManifestEntry(
      id: 'synth-es-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/es_01.mp3',
      language: SupportedLanguages.spanish,
      locale: 'es-ES',
      expectedTranscript: 'Mostrar rallies en Irlanda en 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irlanda'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-es-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/es_02.mp3',
      language: SupportedLanguages.spanish,
      locale: 'es-ES',
      expectedTranscript: 'Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['saltos', 'jump'],
    ),

    // 5. Italian (it-IT)
    BenchmarkManifestEntry(
      id: 'synth-it-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/it_01.mp3',
      language: SupportedLanguages.italian,
      locale: 'it-IT',
      expectedTranscript: 'Mostra i rally in Irlanda nel 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irlanda'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-it-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/it_02.mp3',
      language: SupportedLanguages.italian,
      locale: 'it-IT',
      expectedTranscript: 'Mostra i salti migliori di Josh Moffett al Moonraker nel 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['salti', 'jump'],
    ),

    // 6. Portuguese (pt-PT)
    BenchmarkManifestEntry(
      id: 'synth-pt-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/pt_01.mp3',
      language: SupportedLanguages.portuguese,
      locale: 'pt-PT',
      expectedTranscript: 'Mostrar ralis na Irlanda em 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irlanda'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-pt-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/pt_02.mp3',
      language: SupportedLanguages.portuguese,
      locale: 'pt-PT',
      expectedTranscript: 'Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['saltos', 'jump'],
    ),

    // 7. Dutch (nl-NL)
    BenchmarkManifestEntry(
      id: 'synth-nl-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/nl_01.mp3',
      language: SupportedLanguages.dutch,
      locale: 'nl-NL',
      expectedTranscript: "Toon rally's in Ierland in 2025.",
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Ierland'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-nl-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/nl_02.mp3',
      language: SupportedLanguages.dutch,
      locale: 'nl-NL',
      expectedTranscript: 'Toon spronghoogtepunten met Josh Moffett van Moonraker in 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['sprong', 'jump'],
    ),

    // 8. Polish (pl-PL)
    BenchmarkManifestEntry(
      id: 'synth-pl-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/pl_01.mp3',
      language: SupportedLanguages.polish,
      locale: 'pl-PL',
      expectedTranscript: 'Pokaż rajdy w Irlandii w 2025 roku.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irlandii'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-pl-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/pl_02.mp3',
      language: SupportedLanguages.polish,
      locale: 'pl-PL',
      expectedTranscript: 'Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josha Moffetta', 'Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josha Moffetta', 'Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['skoki', 'jump'],
    ),

    // 9. Norwegian (nb-NO)
    BenchmarkManifestEntry(
      id: 'synth-nb-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/nb_01.mp3',
      language: SupportedLanguages.norwegian,
      locale: 'nb-NO',
      expectedTranscript: 'Vis rallyer i Irland i 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irland'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-nb-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/nb_02.mp3',
      language: SupportedLanguages.norwegian,
      locale: 'nb-NO',
      expectedTranscript: 'Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['hopp', 'jump'],
    ),

    // 10. Latvian (lv-LV)
    BenchmarkManifestEntry(
      id: 'synth-lv-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/lv_01.mp3',
      language: SupportedLanguages.latvian,
      locale: 'lv-LV',
      expectedTranscript: 'Rādīt rallijus Īrijā 2025. gadā.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Īrijā'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-lv-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/lv_02.mp3',
      language: SupportedLanguages.latvian,
      locale: 'lv-LV',
      expectedTranscript: 'Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['lēcienus', 'jump'],
    ),

    // 11. Czech (cs-CZ)
    BenchmarkManifestEntry(
      id: 'synth-cs-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/cs_01.mp3',
      language: SupportedLanguages.czech,
      locale: 'cs-CZ',
      expectedTranscript: 'Ukaž rally v Irsku v roce 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irsku'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-cs-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/cs_02.mp3',
      language: SupportedLanguages.czech,
      locale: 'cs-CZ',
      expectedTranscript: 'Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Joshem Moffettem', 'Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Joshem Moffettem', 'Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['skoky', 'jump'],
    ),

    // 12. Croatian (hr-HR)
    BenchmarkManifestEntry(
      id: 'synth-hr-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/hr_01.mp3',
      language: SupportedLanguages.croatian,
      locale: 'hr-HR',
      expectedTranscript: 'Prikaži relije u Irskoj u 2025. godini.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Irskoj'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-hr-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/hr_02.mp3',
      language: SupportedLanguages.croatian,
      locale: 'hr-HR',
      expectedTranscript: 'Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Joshem Moffettom', 'Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Joshem Moffettom', 'Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['skokove', 'jump'],
    ),

    // 13. Lithuanian (lt-LT)
    BenchmarkManifestEntry(
      id: 'synth-lt-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/lt_01.mp3',
      language: SupportedLanguages.lithuanian,
      locale: 'lt-LT',
      expectedTranscript: 'Rodyti ralius Airijoje 2025 metais.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Airijoje'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-lt-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/lt_02.mp3',
      language: SupportedLanguages.lithuanian,
      locale: 'lt-LT',
      expectedTranscript: 'Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['šuolius', 'jump'],
    ),

    // 14. Slovak (sk-SK)
    BenchmarkManifestEntry(
      id: 'synth-sk-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/sk_01.mp3',
      language: SupportedLanguages.slovak,
      locale: 'sk-SK',
      expectedTranscript: 'Ukáž rely v Írsku v roku 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Írsku'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-sk-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/sk_02.mp3',
      language: SupportedLanguages.slovak,
      locale: 'sk-SK',
      expectedTranscript: 'Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Joshom Moffettom', 'Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Joshom Moffettom', 'Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['skoky', 'jump'],
    ),

    // 15. Urdu (ur-PK) [RTL]
    BenchmarkManifestEntry(
      id: 'synth-ur-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/ur_01.mp3',
      language: SupportedLanguages.urdu,
      locale: 'ur-PK',
      expectedTranscript: '2025 میں آئرلینڈ کی ریلیاں دکھائیں۔',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['آئرلینڈ'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-ur-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/ur_02.mp3',
      language: SupportedLanguages.urdu,
      locale: 'ur-PK',
      expectedTranscript: '2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['جمپس', 'jump'],
    ),

    // 16. Arabic (ar-QA) [RTL]
    BenchmarkManifestEntry(
      id: 'synth-ar-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/ar_01.mp3',
      language: SupportedLanguages.arabic,
      locale: 'ar-QA',
      expectedTranscript: 'أظهر الراليات في أيرلندا في عام 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['أيرلندا'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-ar-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/ar_02.mp3',
      language: SupportedLanguages.arabic,
      locale: 'ar-QA',
      expectedTranscript: 'أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['القفزات', 'jump'],
    ),

    // 17. Swahili (sw-KE)
    BenchmarkManifestEntry(
      id: 'synth-sw-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/sw_01.mp3',
      language: SupportedLanguages.swahili,
      locale: 'sw-KE',
      expectedTranscript: 'Onyesha rali nchini Ayalandi mwaka wa 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Ayalandi'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-sw-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/sw_02.mp3',
      language: SupportedLanguages.swahili,
      locale: 'sw-KE',
      expectedTranscript: 'Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['miruko', 'jump'],
    ),

    // 18. Welsh (cy-GB)
    BenchmarkManifestEntry(
      id: 'synth-cy-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/cy_01.mp3',
      language: SupportedLanguages.welsh,
      locale: 'cy-GB',
      expectedTranscript: 'Dangos ralïau yn Iwerddon yn 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Iwerddon'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-cy-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/cy_02.mp3',
      language: SupportedLanguages.welsh,
      locale: 'cy-GB',
      expectedTranscript: 'Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['neidiau', 'jump'],
    ),

    // 19. Irish (ga-IE)
    BenchmarkManifestEntry(
      id: 'synth-ga-01',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/ga_01.mp3',
      language: SupportedLanguages.irish,
      locale: 'ga-IE',
      expectedTranscript: 'Taispeáin railíthe in Éirinn in 2025.',
      expectedIntent: SearchIntent.searchRallies,
      expectedFilters: {'country': 'Ireland', 'year': 2025},
      expectedEntities: ['Éirinn'],
    ),
    BenchmarkManifestEntry(
      id: 'synth-ga-02',
      benchmarkType: BenchmarkType.synthetic,
      audioFile: 'test/eval/audio/synthetic/ga_02.mp3',
      language: SupportedLanguages.irish,
      locale: 'ga-IE',
      expectedTranscript: 'Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025.',
      expectedIntent: SearchIntent.searchVideoActions,
      expectedFilters: {
        'driverName': 'Josh Moffett',
        'rallyName': 'Moonraker',
        'actionType': 'jump',
        'year': 2025,
      },
      expectedEntities: ['Josh Moffett', 'Moonraker'],
      expectedDrivers: ['Josh Moffett', 'Moffett'],
      expectedRallies: ['Moonraker'],
      expectedActions: ['léimeanna', 'jump'],
    ),
  ];
}
