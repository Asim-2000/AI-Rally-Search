import '../../models/supported_language.dart';

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
    'donut',
    'hairpin',
    'water splash',
    'start line',
    'near miss',
    'mechanical failure',
    'offroad',
    'stuck',
    'stage',
    'results',
    'winner',
    'top finishers',
    'highlights',
  ];

  static const List<String> _defaultDrivers = [
    'Josh Moffett',
    'Sam Moffett',
    'Craig Breen',
    'Keith Cronin',
    'Callum Devine',
    'Alastair Fisher',
    'Desi Henry',
    'Cathan McCourt',
    'Garry Jennings',
    'Declan Boyle',
    'Roy White',
    'Donagh Kelly',
    'Sébastien Ogier',
    'Kalle Rovanperä',
    'Thierry Neuville',
    'Elfyn Evans',
    'Ott Tänak',
  ];

  static const List<String> _defaultRallies = [
    'Donegal International Rally',
    'Galway International Rally',
    'West Cork Rally',
    'Killarney Rally of the Lakes',
    'Jim Clark Rally',
    'Ulster Rally',
    'Cork 20 International Rally',
    'Moonraker Forestry Rally',
    'Rallye Monte-Carlo',
    'Rally Sweden',
    'Safari Rally Kenya',
    'Rally Portugal',
    'Rally Finland',
    'Acropolis Rally Greece',
    'Rally Japan',
  ];

  static const List<String> _defaultStages = [
    'Atlantic Drive',
    'Knockalla',
    'Fanad Head',
    'Molls Gap',
    'Healy Pass',
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

    // Priority 1: Generic Rally context
    terms.add('Rally motorsport search');

    // Priority 2: Key driver names
    for (final driver in _customDrivers.take(10)) {
      terms.add(driver);
    }

    // Priority 3: Key rally names
    for (final rally in _customRallies.take(10)) {
      terms.add(rally);
    }

    // Priority 4: Action terms
    for (final action in _defaultRallyActions.take(8)) {
      terms.add(action);
    }

    return terms.take(maxTerms).join(', ');
  }
}
