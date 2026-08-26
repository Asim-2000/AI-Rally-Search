/// Canonical definition of a supported language in AI Rally Search.
/// Version-controlled and derived from rally event countries.
class SupportedLanguage {
  final String languageCode;
  final String localeCode;
  final String displayName;
  final String nativeName;
  final List<String> associatedCountries;
  final bool isRtl;

  const SupportedLanguage({
    required this.languageCode,
    required this.localeCode,
    required this.displayName,
    required this.nativeName,
    required this.associatedCountries,
    this.isRtl = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportedLanguage &&
          runtimeType == other.runtimeType &&
          languageCode == other.languageCode &&
          localeCode == other.localeCode;

  @override
  int get hashCode => languageCode.hashCode ^ localeCode.hashCode;

  @override
  String toString() => '$displayName ($nativeName) [$localeCode]';
}

/// Centralized, version-controlled repository of supported application languages.
class SupportedLanguages {
  SupportedLanguages._();

  static const SupportedLanguage english = SupportedLanguage(
    languageCode: 'en',
    localeCode: 'en-GB',
    displayName: 'English',
    nativeName: 'English',
    associatedCountries: [
      'Ireland',
      'United Kingdom',
      'Barbados',
      'New Zealand',
      'Kenya',
      'Pakistan',
      'Qatar',
    ],
  );

  static const SupportedLanguage german = SupportedLanguage(
    languageCode: 'de',
    localeCode: 'de-DE',
    displayName: 'German',
    nativeName: 'Deutsch',
    associatedCountries: ['Austria', 'Belgium'],
  );

  static const SupportedLanguage french = SupportedLanguage(
    languageCode: 'fr',
    localeCode: 'fr-FR',
    displayName: 'French',
    nativeName: 'Français',
    associatedCountries: ['France', 'Belgium'],
  );

  static const SupportedLanguage spanish = SupportedLanguage(
    languageCode: 'es',
    localeCode: 'es-ES',
    displayName: 'Spanish',
    nativeName: 'Español',
    associatedCountries: ['Spain'],
  );

  static const SupportedLanguage italian = SupportedLanguage(
    languageCode: 'it',
    localeCode: 'it-IT',
    displayName: 'Italian',
    nativeName: 'Italiano',
    associatedCountries: ['Italy'],
  );

  static const SupportedLanguage portuguese = SupportedLanguage(
    languageCode: 'pt',
    localeCode: 'pt-PT',
    displayName: 'Portuguese',
    nativeName: 'Português',
    associatedCountries: ['Portugal'],
  );

  static const SupportedLanguage dutch = SupportedLanguage(
    languageCode: 'nl',
    localeCode: 'nl-NL',
    displayName: 'Dutch',
    nativeName: 'Nederlands',
    associatedCountries: ['Netherlands', 'Belgium'],
  );

  static const SupportedLanguage polish = SupportedLanguage(
    languageCode: 'pl',
    localeCode: 'pl-PL',
    displayName: 'Polish',
    nativeName: 'Polski',
    associatedCountries: ['Poland'],
  );

  static const SupportedLanguage norwegian = SupportedLanguage(
    languageCode: 'nb',
    localeCode: 'nb-NO',
    displayName: 'Norwegian (Bokmål)',
    nativeName: 'Norsk (Bokmål)',
    associatedCountries: ['Norway'],
  );

  static const SupportedLanguage latvian = SupportedLanguage(
    languageCode: 'lv',
    localeCode: 'lv-LV',
    displayName: 'Latvian',
    nativeName: 'Latviešu',
    associatedCountries: ['Latvia'],
  );

  static const SupportedLanguage czech = SupportedLanguage(
    languageCode: 'cs',
    localeCode: 'cs-CZ',
    displayName: 'Czech',
    nativeName: 'Čeština',
    associatedCountries: ['Czech Republic'],
  );

  static const SupportedLanguage croatian = SupportedLanguage(
    languageCode: 'hr',
    localeCode: 'hr-HR',
    displayName: 'Croatian',
    nativeName: 'Hrvatski',
    associatedCountries: ['Croatia'],
  );

  static const SupportedLanguage lithuanian = SupportedLanguage(
    languageCode: 'lt',
    localeCode: 'lt-LT',
    displayName: 'Lithuanian',
    nativeName: 'Lietuvių',
    associatedCountries: ['Lithuania'],
  );

  static const SupportedLanguage slovak = SupportedLanguage(
    languageCode: 'sk',
    localeCode: 'sk-SK',
    displayName: 'Slovak',
    nativeName: 'Slovenčina',
    associatedCountries: ['Slovakia'],
  );

  static const SupportedLanguage urdu = SupportedLanguage(
    languageCode: 'ur',
    localeCode: 'ur-PK',
    displayName: 'Urdu',
    nativeName: 'اردو',
    associatedCountries: ['Pakistan'],
    isRtl: true,
  );

  static const SupportedLanguage arabic = SupportedLanguage(
    languageCode: 'ar',
    localeCode: 'ar-QA',
    displayName: 'Arabic',
    nativeName: 'العربية',
    associatedCountries: ['Qatar'],
    isRtl: true,
  );

  static const SupportedLanguage swahili = SupportedLanguage(
    languageCode: 'sw',
    localeCode: 'sw-KE',
    displayName: 'Swahili',
    nativeName: 'Kiswahili',
    associatedCountries: ['Kenya'],
  );

  static const SupportedLanguage welsh = SupportedLanguage(
    languageCode: 'cy',
    localeCode: 'cy-GB',
    displayName: 'Welsh',
    nativeName: 'Cymraeg',
    associatedCountries: ['United Kingdom'],
  );

  static const SupportedLanguage irish = SupportedLanguage(
    languageCode: 'ga',
    localeCode: 'ga-IE',
    displayName: 'Irish',
    nativeName: 'Gaeilge',
    associatedCountries: ['Ireland'],
  );

  /// Complete deduplicated list of all 19 supported languages.
  static const List<SupportedLanguage> all = [
    english,
    german,
    french,
    spanish,
    italian,
    portuguese,
    dutch,
    polish,
    norwegian,
    latvian,
    czech,
    croatian,
    lithuanian,
    slovak,
    urdu,
    arabic,
    swahili,
    welsh,
    irish,
  ];

  /// Default application language.
  static const SupportedLanguage defaultLanguage = english;

  /// Looks up a supported language by its ISO 639-1 code (e.g. 'de', 'fr', 'nb').
  static SupportedLanguage? findByCode(String? code) {
    if (code == null) return null;
    final lower = code.trim().toLowerCase();
    for (final lang in all) {
      if (lang.languageCode.toLowerCase() == lower) {
        return lang;
      }
    }
    return null;
  }

  /// Looks up a supported language by its BCP-47 locale code (e.g. 'de-DE', 'nb-NO').
  static SupportedLanguage? findByLocale(String? locale) {
    if (locale == null) return null;
    final clean = locale.trim().replaceAll('_', '-').toLowerCase();
    for (final lang in all) {
      if (lang.localeCode.toLowerCase() == clean ||
          lang.languageCode.toLowerCase() == clean) {
        return lang;
      }
    }
    return null;
  }
}
