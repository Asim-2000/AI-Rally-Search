class VideoActionSearchQuery {
  final String? actionType;
  final List<String>? actionTypes;
  final String? country;
  final String? eventName;
  final String? stageName;
  final String? stageNumber;
  final int limit;
  final int offset;

  const VideoActionSearchQuery({
    this.actionType,
    this.actionTypes,
    this.country,
    this.eventName,
    this.stageName,
    this.stageNumber,
    this.limit = 20,
    this.offset = 0,
  });

  /// Deterministic action type mapping dictionary
  static const Map<String, String> _actionNameMap = {
    'jump': 'jump_segments',
    'jumps': 'jump_segments',
    'jump_segment': 'jump_segments',
    'jump_segments': 'jump_segments',
    'drift': 'drift_segments',
    'drifts': 'drift_segments',
    'drift_segment': 'drift_segments',
    'drift_segments': 'drift_segments',
    'crash': 'crash_segments',
    'crashes': 'crash_segments',
    'crash_segment': 'crash_segments',
    'crash_segments': 'crash_segments',
    'spin': 'spin_segments',
    'spins': 'spin_segments',
    'spin_segment': 'spin_segments',
    'spin_segments': 'spin_segments',
    'start_line': 'start_line_segments',
    'start line': 'start_line_segments',
    'start_lines': 'start_line_segments',
    'start_line_segments': 'start_line_segments',
    'near_miss': 'near_miss_segments',
    'near miss': 'near_miss_segments',
    'near_misses': 'near_miss_segments',
    'near_miss_segments': 'near_miss_segments',
    'mechanical_failure': 'mechanical_failure_segments',
    'mechanical failure': 'mechanical_failure_segments',
    'mechanical_failure_segments': 'mechanical_failure_segments',
    'offroad': 'offroad_segments',
    'off road': 'offroad_segments',
    'off_road': 'offroad_segments',
    'offroad_segments': 'offroad_segments',
    'stuck': 'stuck_segments',
    'stuck_segments': 'stuck_segments',
  };

  /// Deterministic country alias mapping dictionary (code <-> names)
  static const Map<String, List<String>> _countryAliases = {
    'at': ['at', 'austria', 'österreich'],
    'austria': ['at', 'austria', 'österreich'],
    'gb': ['gb', 'uk', 'united kingdom', 'great britain', 'britain', 'wales', 'scotland', 'england'],
    'uk': ['gb', 'uk', 'united kingdom', 'great britain', 'britain', 'wales', 'scotland', 'england'],
    'united kingdom': ['gb', 'uk', 'united kingdom', 'great britain', 'britain', 'wales', 'scotland', 'england'],
    'scotland': ['scotland', 'gb', 'uk', 'united kingdom'],
    'wales': ['wales', 'gb', 'uk', 'united kingdom'],
    'england': ['england', 'gb', 'uk', 'united kingdom'],
    'ie': ['ie', 'ireland', 'éire'],
    'ireland': ['ie', 'ireland', 'éire'],
    'de': ['de', 'germany', 'deutschland'],
    'germany': ['de', 'germany', 'deutschland'],
    'fr': ['fr', 'france'],
    'france': ['fr', 'france'],
    'pt': ['pt', 'portugal'],
    'portugal': ['pt', 'portugal'],
    'no': ['no', 'norway', 'norge'],
    'norway': ['no', 'norway', 'norge'],
    'lv': ['lv', 'latvia', 'latvija'],
    'latvia': ['lv', 'latvia', 'latvija'],
    'pl': ['pl', 'poland', 'polska'],
    'poland': ['pl', 'poland', 'polska'],
    'be': ['be', 'belgium', 'belgique', 'belgië'],
    'belgium': ['be', 'belgium', 'belgique', 'belgië'],
    'qa': ['qa', 'qatar'],
    'qatar': ['qa', 'qatar'],
    'ke': ['ke', 'kenya'],
    'kenya': ['ke', 'kenya'],
    'hr': ['hr', 'croatia', 'hrvatska'],
    'croatia': ['hr', 'croatia', 'hrvatska'],
    'es': ['es', 'spain', 'españa'],
    'spain': ['es', 'spain', 'españa'],
    'it': ['it', 'italy', 'italia'],
    'italy': ['it', 'italy', 'italia'],
    'lt': ['lt', 'lithuania', 'lietuva'],
    'lithuania': ['lt', 'lithuania', 'lietuva'],
    'sk': ['sk', 'slovakia', 'slovensko'],
    'slovakia': ['sk', 'slovakia', 'slovensko'],
    'cz': ['cz', 'czech republic', 'czechia', 'česká republika'],
    'czech republic': ['cz', 'czech republic', 'czechia', 'česká republika'],
    'nl': ['nl', 'netherlands', 'holland', 'nederland'],
    'netherlands': ['nl', 'netherlands', 'holland', 'nederland'],
    'nz': ['nz', 'new zealand'],
    'new zealand': ['nz', 'new zealand'],
    'bb': ['bb', 'barbados'],
    'barbados': ['bb', 'barbados'],
    'pk': ['pk', 'pakistan'],
    'pakistan': ['pk', 'pakistan'],
  };

  /// Normalizes an action type string to its DB representation (e.g. 'jump' -> 'jump_segments')
  static String? normalizeActionType(String? rawAction) {
    if (rawAction == null) return null;
    final cleaned = rawAction.trim().toLowerCase();
    if (cleaned.isEmpty || cleaned == 'all' || cleaned == 'all actions') {
      return null;
    }
    if (_actionNameMap.containsKey(cleaned)) {
      return _actionNameMap[cleaned];
    }
    if (cleaned.endsWith('_segments')) {
      return cleaned;
    }
    return '${cleaned}_segments';
  }

  /// Returns resolved list of DB action names for query
  List<String> get resolvedActionTypes {
    final types = <String>{};
    if (actionType != null) {
      final normalized = normalizeActionType(actionType);
      if (normalized != null) {
        types.add(normalized);
      }
    }
    if (actionTypes != null) {
      for (final t in actionTypes!) {
        final normalized = normalizeActionType(t);
        if (normalized != null) {
          types.add(normalized);
        }
      }
    }
    return types.toList();
  }

  /// Resolves country aliases to match both ISO codes and full names
  static List<String> resolveCountryAliases(String? rawCountry) {
    if (rawCountry == null) return const [];
    final cleaned = rawCountry.trim().toLowerCase();
    if (cleaned.isEmpty || cleaned == 'all' || cleaned == 'all countries') {
      return const [];
    }
    if (_countryAliases.containsKey(cleaned)) {
      return _countryAliases[cleaned]!;
    }
    return [cleaned];
  }

  List<String> get resolvedCountryAliases {
    return resolveCountryAliases(country);
  }

  bool get isEmpty {
    return (actionType == null || actionType!.trim().isEmpty || actionType!.toLowerCase() == 'all') &&
        (actionTypes == null || actionTypes!.isEmpty) &&
        (country == null || country!.trim().isEmpty || country!.toLowerCase() == 'all') &&
        (eventName == null || eventName!.trim().isEmpty) &&
        (stageName == null || stageName!.trim().isEmpty) &&
        (stageNumber == null || stageNumber!.trim().isEmpty);
  }

  VideoActionSearchQuery copyWith({
    String? actionType,
    List<String>? actionTypes,
    String? country,
    String? eventName,
    String? stageName,
    String? stageNumber,
    int? limit,
    int? offset,
  }) {
    return VideoActionSearchQuery(
      actionType: actionType ?? this.actionType,
      actionTypes: actionTypes ?? this.actionTypes,
      country: country ?? this.country,
      eventName: eventName ?? this.eventName,
      stageName: stageName ?? this.stageName,
      stageNumber: stageNumber ?? this.stageNumber,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actionType': actionType,
      'actionTypes': actionTypes,
      'country': country,
      'eventName': eventName,
      'stageName': stageName,
      'stageNumber': stageNumber,
      'limit': limit,
      'offset': offset,
    };
  }

  @override
  String toString() {
    return 'VideoActionSearchQuery(actionType: $actionType, actionTypes: $actionTypes, country: $country, eventName: $eventName, stageName: $stageName, stageNumber: $stageNumber, limit: $limit, offset: $offset)';
  }
}
