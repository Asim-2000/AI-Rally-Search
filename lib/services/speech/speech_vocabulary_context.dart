import '../../models/supported_language.dart';
import 'multilingual_domain_lexicon.dart';

/// Contract for providing dynamic rally domain vocabulary context to STT prompts/models.
abstract class SpeechVocabularyContext {
  /// Returns high-priority driver names for recognition prompting.
  List<String> getDriverNames();

  /// Returns high-priority rally names for recognition prompting.
  List<String> getRallyNames();

  /// Returns high-priority stage names for recognition prompting.
  List<String> getStageNames();

  /// Returns common rally action keywords (jumps, drifts, crashes, etc.).
  List<String> getDomainActionTerms();

  /// Formats the contextual vocabulary into a prompt string suitable for STT decoders.
  String buildVocabularyPrompt({SupportedLanguage? language, int maxTerms = 30});
}

/// Default implementation providing dynamic vocabulary with fallback rally domain terms.
class DefaultSpeechVocabularyContext implements SpeechVocabularyContext {
  final List<String> _customDrivers;
  final List<String> _customRallies;
  final List<String> _customStages;

  static const List<String> _defaultRallyActions = [
    'jump',
    'drift',
    'crash',
    'spin',
    'water splash',
    'donut',
    'highlights',
    'hairpin',
    'near miss',
    'mechanical failure',
    'offroad',
    'results',
    'winner',
    'top finishers',
  ];

  static const List<String> _defaultDrivers = [
    'Josh Moffett',
    'Sam Moffett',
    'Philip Squires',
    'Kris Meeke',
    'Keith Cronin',
    'Callum Devine',
    'Craig Breen',
    'Alastair Fisher',
    'Desi Henry',
    'Cathan McCourt',
    'Garry Jennings',
    'Declan Boyle',
    'Sébastien Ogier',
    'Kalle Rovanperä',
    'Thierry Neuville',
    'Elfyn Evans',
  ];

  static const List<String> _defaultRallies = [
    'Moonraker',
    'Donegal',
    'Trackrod',
    'Gale Rigg',
    'Woodpecker',
    'Tarenig',
    'West Cork Rally',
    'Cork 20',
    'Killarney Historic Rally',
    'Rally of the Lakes',
    'Circuit of Ireland',
    'Mayo Stages',
    'Monaghan Stages',
    'Clare Stages',
    'Sligo Stages',
    'Mid Ulster Stages',
    'Limerick Forest Rally',
  ];

  static const List<String> _defaultStages = [
    'Ring Stage',
    'Ardfield Stage',
    'Molls Gap',
    'Healy Pass',
    'Atlantic Drive',
    'Fanad Head',
    'Knockalla',
    'SS1',
    'SS2',
    'Power Stage',
  ];

  DefaultSpeechVocabularyContext({
    List<String>? customDrivers,
    List<String>? customRallies,
    List<String>? customStages,
  })  : _customDrivers = customDrivers ?? _defaultDrivers,
        _customRallies = customRallies ?? _defaultRallies,
        _customStages = customStages ?? _defaultStages;

  @override
  List<String> getDriverNames() => List.unmodifiable(_customDrivers);

  @override
  List<String> getRallyNames() => List.unmodifiable(_customRallies);

  @override
  List<String> getStageNames() => List.unmodifiable(_customStages);

  @override
  List<String> getDomainActionTerms() => List.unmodifiable(_defaultRallyActions);

  @override
  String buildVocabularyPrompt({SupportedLanguage? language, int maxTerms = 30}) {
    final terms = <String>[];

    // Priority 1: High-value proper nouns (Drivers & Rallies)
    terms.add('Josh Moffett');
    terms.add('Moonraker');
    terms.add('Donegal');
    terms.add('Trackrod');
    terms.add('Gale Rigg');
    terms.add('Woodpecker');
    terms.add('Tarenig');

    // Priority 2: Localized country and action terminology from MultilingualDomainLexicon
    if (language != null) {
      final langCode = language.languageCode;
      // Add localized country terms
      for (final countryEntry in MultilingualDomainLexicon.countries.values) {
        final localizedList = countryEntry[langCode];
        if (localizedList != null) {
          for (final term in localizedList) {
            if (term.length >= 3 && !terms.contains(term)) {
              terms.add(term);
            }
          }
        }
      }
      // Add localized action terms
      for (final actionEntry in MultilingualDomainLexicon.actions.values) {
        final localizedList = actionEntry[langCode];
        if (localizedList != null) {
          for (final term in localizedList) {
            if (term.length >= 3 && !terms.contains(term)) {
              terms.add(term);
            }
          }
        }
      }
    }

    // Priority 3: English Action Terms
    terms.add('jump');
    terms.add('drift');
    terms.add('crash');
    terms.add('water splash');
    terms.add('highlights');

    // Priority 4: Supported Years
    terms.add('2025');
    terms.add('2024');
    terms.add('2026');

    // Priority 5: Additional custom drivers & rallies
    for (final driver in _customDrivers) {
      if (!terms.contains(driver)) terms.add(driver);
    }
    for (final rally in _customRallies) {
      if (!terms.contains(rally)) terms.add(rally);
    }

    return terms.take(maxTerms).join(', ');
  }
}
