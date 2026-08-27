import 'search_intent.dart';

/// Match mode for multi-entity filters (e.g. "Josh or Sam" -> any, "both Josh and Sam" -> all)
enum MatchMode {
  any,
  all;

  static MatchMode fromString(String? raw) {
    if (raw == null) return MatchMode.any;
    final clean = raw.trim().toLowerCase();
    if (clean == 'all' || clean == 'both') return MatchMode.all;
    return MatchMode.any;
  }

  String toModeString() => name.toUpperCase();
}

/// Person role filter (e.g. "drove in" -> driver, "co-drove in" -> coDriver, default -> any)
enum PersonRole {
  any,
  driver,
  coDriver;

  static PersonRole fromString(String? raw) {
    if (raw == null) return PersonRole.any;
    final clean = raw.trim().toLowerCase();
    if (clean == 'driver' || clean == 'drive') return PersonRole.driver;
    if (clean == 'codriver' || clean == 'co_driver' || clean == 'co-driver' || clean == 'co-drove' || clean == 'codrive') return PersonRole.coDriver;
    return PersonRole.any;
  }

  String toRoleString() => name.toUpperCase();
}

/// General structured search query representation.
/// Plural list fields are canonical across all dimensions (OR within a dimension, AND across dimensions).
/// Singular getters and constructor parameters are provided for backward compatibility.
class SearchQuery {
  final SearchIntent intent;
  final List<String> _rallyNames;
  final String? _rallyName;
  final List<String> _eventNames;
  final String? _eventName;
  final List<String> _countries;
  final String? _country;
  final List<String> _cities;
  final String? _city;
  final List<String> _stageNames;
  final String? _stageName;
  final List<String> _stageNumbers;
  final String? _stageNumber;
  final List<String> _driverNames;
  final String? _driverName;
  final List<String> _driverIds;
  final String? _driverId;
  final List<String> _actionTypes;
  final String? _actionType;
  final List<int> _years;
  final int? _year;
  final int? yearFrom;
  final int? yearTo;
  final List<String> _uploaders;
  final String? _uploader;
  final MatchMode driverMatchMode;
  final PersonRole personRole;
  final int limit;
  final int offset;

  const SearchQuery({
    required this.intent,
    List<String> rallyNames = const [],
    String? rallyName,
    List<String> eventNames = const [],
    String? eventName,
    List<String> countries = const [],
    String? country,
    List<String> cities = const [],
    String? city,
    List<String> stageNames = const [],
    String? stageName,
    List<String> stageNumbers = const [],
    String? stageNumber,
    List<String> driverNames = const [],
    String? driverName,
    List<String> driverIds = const [],
    String? driverId,
    List<String> actionTypes = const [],
    String? actionType,
    List<int> years = const [],
    int? year,
    this.yearFrom,
    this.yearTo,
    List<String> uploaders = const [],
    String? uploader,
    this.driverMatchMode = MatchMode.any,
    this.personRole = PersonRole.any,
    this.limit = 20,
    this.offset = 0,
  })  : _rallyNames = rallyNames,
        _rallyName = rallyName,
        _eventNames = eventNames,
        _eventName = eventName,
        _countries = countries,
        _country = country,
        _cities = cities,
        _city = city,
        _stageNames = stageNames,
        _stageName = stageName,
        _stageNumbers = stageNumbers,
        _stageNumber = stageNumber,
        _driverNames = driverNames,
        _driverName = driverName,
        _driverIds = driverIds,
        _driverId = driverId,
        _actionTypes = actionTypes,
        _actionType = actionType,
        _years = years,
        _year = year,
        _uploaders = uploaders,
        _uploader = uploader;

  // ===========================================================================
  // CANONICAL PLURAL LIST GETTERS
  // ===========================================================================
  List<String> get countries => _countries.isNotEmpty
      ? _countries
      : (_country != null && _country!.trim().isNotEmpty && _country!.toLowerCase() != 'null' ? [_country!.trim()] : const []);

  List<String> get cities => _cities.isNotEmpty
      ? _cities
      : (_city != null && _city!.trim().isNotEmpty && _city!.toLowerCase() != 'null' ? [_city!.trim()] : const []);

  List<String> get rallyNames => _rallyNames.isNotEmpty
      ? _rallyNames
      : (_rallyName != null && _rallyName!.trim().isNotEmpty && _rallyName!.toLowerCase() != 'null' ? [_rallyName!.trim()] : const []);

  List<String> get eventNames => _eventNames.isNotEmpty
      ? _eventNames
      : (_eventName != null && _eventName!.trim().isNotEmpty && _eventName!.toLowerCase() != 'null' ? [_eventName!.trim()] : const []);

  List<String> get stageNames => _stageNames.isNotEmpty
      ? _stageNames
      : (_stageName != null && _stageName!.trim().isNotEmpty && _stageName!.toLowerCase() != 'null' ? [_stageName!.trim()] : const []);

  List<String> get stageNumbers => _stageNumbers.isNotEmpty
      ? _stageNumbers
      : (_stageNumber != null && _stageNumber!.trim().isNotEmpty && _stageNumber!.toLowerCase() != 'null' ? [_stageNumber!.trim()] : const []);

  List<String> get driverNames => _driverNames.isNotEmpty
      ? _driverNames
      : (_driverName != null && _driverName!.trim().isNotEmpty && _driverName!.toLowerCase() != 'null' ? [_driverName!.trim()] : const []);

  List<String> get driverIds => _driverIds.isNotEmpty
      ? _driverIds
      : (_driverId != null && _driverId!.trim().isNotEmpty && _driverId!.toLowerCase() != 'null' ? [_driverId!.trim()] : const []);

  List<String> get actionTypes => _actionTypes.isNotEmpty
      ? _actionTypes
      : (_actionType != null && _actionType!.trim().isNotEmpty && _actionType!.toLowerCase() != 'null' ? [_actionType!.trim()] : const []);

  List<int> get years => _years.isNotEmpty
      ? _years
      : (_year != null && _year! > 0 ? [_year!] : const []);

  List<String> get uploaders => _uploaders.isNotEmpty
      ? _uploaders
      : (_uploader != null && _uploader!.trim().isNotEmpty ? [_uploader!.trim()] : const []);

  // ===========================================================================
  // BACKWARD-COMPATIBLE SINGULAR GETTERS
  // NOTE: Production search logic must use the canonical list fields!
  // ===========================================================================
  String? get rallyName => rallyNames.isNotEmpty ? rallyNames.first : null;
  String? get eventName => eventNames.isNotEmpty ? eventNames.first : null;
  String? get country => countries.isNotEmpty ? countries.first : null;
  String? get city => cities.isNotEmpty ? cities.first : null;
  String? get stageName => stageNames.isNotEmpty ? stageNames.first : null;
  String? get stageNumber => stageNumbers.isNotEmpty ? stageNumbers.first : null;
  String? get driverName => driverNames.isNotEmpty ? driverNames.first : null;
  String? get driverId => driverIds.isNotEmpty ? driverIds.first : null;
  String? get actionType => actionTypes.isNotEmpty ? actionTypes.first : null;
  int? get year => years.isNotEmpty ? years.first : null;
  String? get uploader => uploaders.isNotEmpty ? uploaders.first : null;

  /// Consolidated rally / event names (plural)
  List<String> get targetRallyNames => rallyNames.isNotEmpty ? rallyNames : eventNames;

  /// Consolidated primary rally / event name (singular backward-compat)
  String? get targetRallyName => targetRallyNames.isNotEmpty ? targetRallyNames.first : null;

  /// Resolves all countries to standardized search terms and code aliases (deduplicated)
  List<String> get resolvedCountryAliases {
    if (countries.isEmpty) return [];

    final aliases = <String>{};

    const Map<String, List<String>> countryMap = {
      'ireland': ['ireland', 'ie', 'irl', 'republic of ireland'],
      'ie': ['ireland', 'ie', 'irl'],
      'portugal': ['portugal', 'pt', 'prt'],
      'pt': ['portugal', 'pt', 'prt'],
      'united kingdom': ['united kingdom', 'uk', 'gb', 'gbr', 'great britain', 'england', 'scotland', 'wales'],
      'uk': ['united kingdom', 'uk', 'gb', 'gbr', 'great britain'],
      'gb': ['united kingdom', 'uk', 'gb', 'gbr', 'great britain'],
      'scotland': ['scotland', 'united kingdom', 'uk', 'gb'],
      'wales': ['wales', 'united kingdom', 'uk', 'gb'],
      'england': ['england', 'united kingdom', 'uk', 'gb'],
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
      'sweden': ['sweden', 'se', 'swe'],
      'se': ['sweden', 'se', 'swe'],
      'finland': ['finland', 'fi', 'fin'],
      'fi': ['finland', 'fi', 'fin'],
      'estonia': ['estonia', 'ee', 'est'],
      'ee': ['estonia', 'ee', 'est'],
    };

    for (final c in countries) {
      if (c.trim().isEmpty || c.trim().toUpperCase() == 'ALL') continue;
      final query = c.trim().toLowerCase();
      aliases.add(query);

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
    }

    return aliases.toList();
  }

  /// Resolves all action type aliases (e.g. ['jump', 'drift'] -> ['jump', 'jump_segments', 'drift', 'drift_segments'])
  List<String> get resolvedActionTypes {
    if (actionTypes.isEmpty) return [];

    final result = <String>{};
    for (final action in actionTypes) {
      if (action.trim().isEmpty || action.trim().toUpperCase() == 'ALL') continue;
      final query = action.trim().toLowerCase();
      final clean = query.endsWith('_segments')
          ? query.substring(0, query.length - '_segments'.length)
          : query;
      result.add(clean);
      result.add('${clean}_segments');
    }

    return result.toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'intent': intent.toIntentString(),
      if (countries.isNotEmpty) 'countries': countries,
      if (country != null) 'country': country,
      if (cities.isNotEmpty) 'cities': cities,
      if (city != null) 'city': city,
      if (years.isNotEmpty) 'years': years,
      if (year != null) 'year': year,
      if (yearFrom != null) 'yearFrom': yearFrom,
      if (yearTo != null) 'yearTo': yearTo,
      if (rallyNames.isNotEmpty) 'rallyNames': rallyNames,
      if (rallyName != null) 'rallyName': rallyName,
      if (eventNames.isNotEmpty) 'eventNames': eventNames,
      if (eventName != null) 'eventName': eventName,
      if (stageNames.isNotEmpty) 'stageNames': stageNames,
      if (stageName != null) 'stageName': stageName,
      if (stageNumbers.isNotEmpty) 'stageNumbers': stageNumbers,
      if (stageNumber != null) 'stageNumber': stageNumber,
      if (driverNames.isNotEmpty) 'driverNames': driverNames,
      if (driverName != null) 'driverName': driverName,
      if (driverIds.isNotEmpty) 'driverIds': driverIds,
      if (driverId != null) 'driverId': driverId,
      if (actionTypes.isNotEmpty) 'actionTypes': actionTypes,
      if (actionType != null) 'actionType': actionType,
      if (uploaders.isNotEmpty) 'uploaders': uploaders,
      'driverMatchMode': driverMatchMode.toModeString(),
      'personRole': personRole.toRoleString(),
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

    // Parse countries
    final countriesList = _extractStringList(map['countries'] ?? map['country']);

    // Parse cities
    final citiesList = _extractStringList(map['cities'] ?? map['city']);

    // Parse years
    final yearsList = _extractIntList(map['years'] ?? map['year']);

    // Parse year range
    final rawYearFrom = map['yearFrom'] ?? map['year_from'];
    final yearFromVal = rawYearFrom is int ? rawYearFrom : int.tryParse(rawYearFrom?.toString() ?? '');
    final rawYearTo = map['yearTo'] ?? map['year_to'];
    final yearToVal = rawYearTo is int ? rawYearTo : int.tryParse(rawYearTo?.toString() ?? '');

    // Parse rallies / events
    final rallyNamesList = _extractStringList(map['rallyNames'] ?? map['rally_names'] ?? map['rallyName'] ?? map['rally_name']);
    final eventNamesList = _extractStringList(map['eventNames'] ?? map['event_names'] ?? map['eventName'] ?? map['event_name']);

    // Parse stages
    final stageNamesList = _extractStringList(map['stageNames'] ?? map['stage_names'] ?? map['stageName'] ?? map['stage_name']);
    final stageNumbersList = _extractStringList(map['stageNumbers'] ?? map['stage_numbers'] ?? map['stageNumber'] ?? map['stage_number']);

    // Parse drivers
    final driverNamesList = _extractStringList(map['driverNames'] ?? map['driver_names'] ?? map['driverName'] ?? map['driver_name']);
    final driverIdsList = _extractStringList(map['driverIds'] ?? map['driver_ids'] ?? map['driverId'] ?? map['driver_id']);

    // Parse action types
    final actionTypesList = _extractStringList(map['actionTypes'] ?? map['action_types'] ?? map['actionType'] ?? map['action_type']);

    // Parse uploaders
    final uploadersList = _extractStringList(map['uploaders'] ?? map['uploader']);

    // Parse match mode & person role
    final matchModeVal = MatchMode.fromString(map['driverMatchMode']?.toString() ?? map['driver_match_mode']?.toString());
    final personRoleVal = PersonRole.fromString(map['personRole']?.toString() ?? map['person_role']?.toString() ?? map['role']?.toString());

    return SearchQuery(
      intent: parsedIntent,
      rallyNames: rallyNamesList,
      eventNames: eventNamesList,
      countries: countriesList,
      cities: citiesList,
      stageNames: stageNamesList,
      stageNumbers: stageNumbersList,
      driverNames: driverNamesList,
      driverIds: driverIdsList,
      actionTypes: actionTypesList,
      years: yearsList,
      yearFrom: yearFromVal,
      yearTo: yearToVal,
      uploaders: uploadersList,
      driverMatchMode: matchModeVal,
      personRole: personRoleVal,
      limit: limitVal,
      offset: offsetVal,
    );
  }

  static List<String> _extractStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      final res = <String>{};
      for (final e in raw) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty && s.toLowerCase() != 'null' && s.toLowerCase() != 'none') {
          res.add(s);
        }
      }
      return res.toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null' || trimmed.toLowerCase() == 'none') return [];
      return [trimmed];
    }
    return [raw.toString()];
  }

  static List<int> _extractIntList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      final res = <int>{};
      for (final item in raw) {
        if (item is int && item > 0) {
          res.add(item);
        } else if (item is num && item > 0) {
          res.add(item.toInt());
        } else if (item is String) {
          final p = int.tryParse(item.trim());
          if (p != null && p > 0) res.add(p);
        }
      }
      return res.toList();
    }
    if (raw is int && raw > 0) return [raw];
    if (raw is num && raw > 0) return [raw.toInt()];
    if (raw is String) {
      final p = int.tryParse(raw.trim());
      if (p != null && p > 0) return [p];
    }
    return [];
  }

  Map<String, dynamic> toJson() => toMap();

  factory SearchQuery.fromJson(Map<String, dynamic> json) => SearchQuery.fromMap(json);

  SearchQuery copyWith({
    SearchIntent? intent,
    List<String>? rallyNames,
    String? rallyName,
    List<String>? eventNames,
    String? eventName,
    List<String>? countries,
    String? country,
    List<String>? cities,
    String? city,
    List<String>? stageNames,
    String? stageName,
    List<String>? stageNumbers,
    String? stageNumber,
    List<String>? driverNames,
    String? driverName,
    List<String>? driverIds,
    String? driverId,
    List<String>? actionTypes,
    String? actionType,
    List<int>? years,
    int? year,
    int? yearFrom,
    int? yearTo,
    List<String>? uploaders,
    String? uploader,
    MatchMode? driverMatchMode,
    PersonRole? personRole,
    int? limit,
    int? offset,
  }) {
    return SearchQuery(
      intent: intent ?? this.intent,
      rallyNames: rallyNames ?? (rallyName != null ? [rallyName] : this.rallyNames),
      eventNames: eventNames ?? (eventName != null ? [eventName] : this.eventNames),
      countries: countries ?? (country != null ? [country] : this.countries),
      cities: cities ?? (city != null ? [city] : this.cities),
      stageNames: stageNames ?? (stageName != null ? [stageName] : this.stageNames),
      stageNumbers: stageNumbers ?? (stageNumber != null ? [stageNumber] : this.stageNumbers),
      driverNames: driverNames ?? (driverName != null ? [driverName] : this.driverNames),
      driverIds: driverIds ?? (driverId != null ? [driverId] : this.driverIds),
      actionTypes: actionTypes ?? (actionType != null ? [actionType] : this.actionTypes),
      years: years ?? (year != null ? [year] : this.years),
      yearFrom: yearFrom ?? this.yearFrom,
      yearTo: yearTo ?? this.yearTo,
      uploaders: uploaders ?? (uploader != null ? [uploader] : this.uploaders),
      driverMatchMode: driverMatchMode ?? this.driverMatchMode,
      personRole: personRole ?? this.personRole,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}
