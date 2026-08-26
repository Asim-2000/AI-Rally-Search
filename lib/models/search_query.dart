import 'search_intent.dart';

/// General structured search query representation.
/// Can be produced directly from user inputs or parsed from future LLM structured output.
class SearchQuery {
  final SearchIntent intent;
  final String? rallyName;
  final String? eventName;
  final String? country;
  final String? city;
  final String? stageName;
  final String? stageNumber;
  final String? driverName;
  final String? driverId;
  final String? actionType;
  final int? year;
  final int limit;
  final int offset;

  const SearchQuery({
    required this.intent,
    this.rallyName,
    this.eventName,
    this.country,
    this.city,
    this.stageName,
    this.stageNumber,
    this.driverName,
    this.driverId,
    this.actionType,
    this.year,
    this.limit = 20,
    this.offset = 0,
  });

  /// Consolidated rally / event name
  String? get targetRallyName => rallyName ?? eventName;

  /// Resolves country to standardized search terms and code aliases
  List<String> get resolvedCountryAliases {
    if (country == null || country!.trim().isEmpty || country!.trim().toUpperCase() == 'ALL') {
      return [];
    }

    final query = country!.trim().toLowerCase();
    final aliases = <String>{query};

    final Map<String, List<String>> countryMap = {
      'ireland': ['ireland', 'ie', 'irl', 'republic of ireland'],
      'ie': ['ireland', 'ie', 'irl'],
      'portugal': ['portugal', 'pt', 'prt'],
      'pt': ['portugal', 'pt', 'prt'],
      'united kingdom': ['united kingdom', 'uk', 'gb', 'gbr', 'great britain', 'england', 'scotland', 'wales'],
      'uk': ['united kingdom', 'uk', 'gb', 'gbr', 'great britain'],
      'gb': ['united kingdom', 'uk', 'gb', 'gbr', 'great britain'],
      'france': ['france', 'fr', 'fra'],
      'fr': ['france', 'fr', 'fra'],
      'austria': ['austria', 'at', 'aut'],
      'at': ['austria', 'at', 'aut'],
      'norway': ['norway', 'no', 'nor'],
      'no': ['norway', 'no', 'nor'],
      'poland': ['poland', 'pl', 'pol'],
      'pl': ['poland', 'pl', 'pol'],
      'belgium': ['belgium', 'be', 'bel'],
      'be': ['belgium', 'be', 'bel'],
      'spain': ['spain', 'es', 'esp'],
      'es': ['spain', 'es', 'esp'],
      'italy': ['italy', 'it', 'ita'],
      'it': ['italy', 'it', 'ita'],
      'latvia': ['latvia', 'lv', 'lva'],
      'lv': ['latvia', 'lv', 'lva'],
      'czech republic': ['czech republic', 'cz', 'cze', 'czechia'],
      'cz': ['czech republic', 'cz', 'cze', 'czechia'],
      'germany': ['germany', 'de', 'deu'],
      'de': ['germany', 'de', 'deu'],
      'kenya': ['kenya', 'ke', 'ken'],
      'ke': ['kenya', 'ke', 'ken'],
      'croatia': ['croatia', 'hr', 'hrv'],
      'hr': ['croatia', 'hr', 'hrv'],
      'netherlands': ['netherlands', 'nl', 'nld', 'holland'],
      'nl': ['netherlands', 'nl', 'nld'],
      'new zealand': ['new zealand', 'nz', 'nzl'],
      'nz': ['new zealand', 'nz', 'nzl'],
      'lithuania': ['lithuania', 'lt', 'ltu'],
      'lt': ['lithuania', 'lt', 'ltu'],
      'slovakia': ['slovakia', 'sk', 'svk'],
      'sk': ['slovakia', 'sk', 'svk'],
      'qatar': ['qatar', 'qa', 'qat'],
      'qa': ['qatar', 'qa', 'qat'],
      'pakistan': ['pakistan', 'pk', 'pak'],
      'pk': ['pakistan', 'pk', 'pak'],
      'barbados': ['barbados', 'bb', 'brb'],
      'bb': ['barbados', 'bb', 'brb'],
    };

    if (countryMap.containsKey(query)) {
      aliases.addAll(countryMap[query]!);
    } else {
      for (final entry in countryMap.entries) {
        if (entry.value.contains(query)) {
          aliases.addAll(entry.value);
          aliases.add(entry.key);
        }
      }
    }

    return aliases.toList();
  }

  /// Resolves action type aliases (e.g. 'jump' -> ['jump', 'jump_segments'])
  List<String> get resolvedActionTypes {
    if (actionType == null || actionType!.trim().isEmpty || actionType!.trim().toUpperCase() == 'ALL') {
      return [];
    }

    final query = actionType!.trim().toLowerCase();
    final clean = query.endsWith('_segments')
        ? query.substring(0, query.length - '_segments'.length)
        : query;

    return [clean, '${clean}_segments'];
  }

  Map<String, dynamic> toMap() {
    return {
      'intent': intent.toIntentString(),
      if (rallyName != null) 'rallyName': rallyName,
      if (eventName != null) 'eventName': eventName,
      if (country != null) 'country': country,
      if (city != null) 'city': city,
      if (stageName != null) 'stageName': stageName,
      if (stageNumber != null) 'stageNumber': stageNumber,
      if (driverName != null) 'driverName': driverName,
      if (driverId != null) 'driverId': driverId,
      if (actionType != null) 'actionType': actionType,
      if (year != null) 'year': year,
      'limit': limit,
      'offset': offset,
    };
  }

  factory SearchQuery.fromMap(Map<String, dynamic> map) {
    final rawIntent = map['intent']?.toString() ?? 'SEARCH_RALLIES';
    final parsedIntent = SearchIntent.fromString(rawIntent);

    final rawLimit = map['limit'];
    final limitVal = rawLimit is int
        ? rawLimit
        : (int.tryParse(rawLimit?.toString() ?? '') ?? 20);

    final rawOffset = map['offset'];
    final offsetVal = rawOffset is int
        ? rawOffset
        : (int.tryParse(rawOffset?.toString() ?? '') ?? 0);

    final rawYear = map['year'];
    final yearVal = rawYear is int
        ? rawYear
        : (int.tryParse(rawYear?.toString() ?? ''));

    return SearchQuery(
      intent: parsedIntent,
      rallyName: map['rallyName']?.toString() ?? map['rally_name']?.toString(),
      eventName: map['eventName']?.toString() ?? map['event_name']?.toString(),
      country: map['country']?.toString(),
      city: map['city']?.toString(),
      stageName: map['stageName']?.toString() ?? map['stage_name']?.toString(),
      stageNumber: map['stageNumber']?.toString() ?? map['stage_number']?.toString(),
      driverName: map['driverName']?.toString() ?? map['driver_name']?.toString(),
      driverId: map['driverId']?.toString() ?? map['driver_id']?.toString(),
      actionType: map['actionType']?.toString() ?? map['action_type']?.toString(),
      year: yearVal,
      limit: limitVal,
      offset: offsetVal,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory SearchQuery.fromJson(Map<String, dynamic> json) => SearchQuery.fromMap(json);

  SearchQuery copyWith({
    SearchIntent? intent,
    String? rallyName,
    String? eventName,
    String? country,
    String? city,
    String? stageName,
    String? stageNumber,
    String? driverName,
    String? driverId,
    String? actionType,
    int? year,
    int? limit,
    int? offset,
  }) {
    return SearchQuery(
      intent: intent ?? this.intent,
      rallyName: rallyName ?? this.rallyName,
      eventName: eventName ?? this.eventName,
      country: country ?? this.country,
      city: city ?? this.city,
      stageName: stageName ?? this.stageName,
      stageNumber: stageNumber ?? this.stageNumber,
      driverName: driverName ?? this.driverName,
      driverId: driverId ?? this.driverId,
      actionType: actionType ?? this.actionType,
      year: year ?? this.year,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}
