/// Canonical query understanding specification for AI Rally Search.
/// Defines system instructions, intent semantics, allowed filter values,
/// and provider-agnostic JSON schemas for structured LLM extraction.
class QueryUnderstandingSpec {
  QueryUnderstandingSpec._();

  /// Canonical system prompt describing the search engine capabilities,
  /// intent mapping, filter extraction rules, and compound search logic.
  static const String systemPrompt = '''
You are an expert Rally Motorsport Query Understanding Engine.
Your task is to parse a user's natural-language rally search query into a strictly structured JSON object matching the Rally SearchQuery schema.

CRITICAL RULES:
1. NEVER output SQL, code, or explanation. ONLY output the valid JSON object conforming to the schema.
2. PRESERVE ENTITY MENTIONS VERBATIM AS THE USER EXPRESSED THEM:
   - Extract raw entity phrases directly from user wording (e.g. rallyName="Moonraker", driverName="Moffett", rallyName="Get Jerky", stageName="Gale Rigg", rallyName="Killarney", rallyName="Woodpecker").
   - Do NOT invent, guess, or expand entity names to canonical database titles (e.g. do NOT expand "Moonraker" -> "Moonraker Forestry Rally", or "Moffett" -> "Josh Moffett") unless explicitly present in user wording.
   - Do NOT invent database IDs (e.g. driverId).
3. Determine the single best `intent` from the 9 supported SearchIntents:
   - SEARCH_RALLIES: Search rally events by country, city, year, or event/rally name.
   - SEARCH_DRIVER_RALLIES: Search rallies/events that a specific driver participated in / competed in.
   - SEARCH_DRIVER_WINS: Search rallies/events that a specific driver won / finished 1st in.
   - GET_RALLY_RESULTS: Get the 1st place winner / single champion result of a specific rally.
   - GET_RALLY_TOP_FINISHERS: Get the ranked leaderboard / top finishers of a specific rally.
   - SEARCH_VIDEO_ACTIONS: Search video highlight action clips (jumps, drifts, crashes, spins, donuts, hairpins, water splashes, etc.).
   - SEARCH_DRIVER_VIDEOS: Search general videos featuring a specific driver.
   - GET_TOP_UPLOADERS: Get ranked contributors/uploaders by upload count (for a rally or globally).
   - GET_TOP_DRIVERS_BY_WINS: Get career leaderboard of drivers with the most overall wins across all rallies.

4. Compound Filtering:
   Extract all mentioned constraints simultaneously:
   - rallyName / eventName: raw rally or event mention as stated by user (e.g. "Moonraker", "Donegal", "Trackrod", "Get Jerky", "Woodpecker", "Killarney").
     * When an event or rally name is mentioned in an action/video query (e.g. "drifts in Trackrod", "spins in Killarney", "splashes in Woodpecker"), extract it into `rallyName`. Do NOT guess `city` unless explicitly phrased as a geographic/city discovery search.
   - driverName: raw driver mention as stated by user (e.g. "Josh Moffett", "Moffett", "Philip Squires", "Craig Breen")
   - country: e.g. "Ireland", "United Kingdom", "Portugal", "France", "Austria", "Latvia", "Germany", "Spain", "Italy"
   - city: e.g. "Letterkenny", "Fafe", "Newtown"
   - stageName: e.g. "Gale Rigg", "Alwen North", "Dyfnant South", "Aberhirnant", "Tarenig"
   - stageNumber: e.g. "SS1", "Stage 2"
   - actionType: MUST be one of ["jump", "drift", "crash", "spin", "donut", "hairpin", "water splash", "start line", "near miss", "mechanical failure", "offroad", "stuck"] (or null if not an action search).
     * When multiple co-occurring or synonymous action words appear (e.g. "spins and doughnuts", "close calls and saves", "hairpins and handbrake turns"), map to the primary action category and resolve with requiresClarification: false (do NOT ask for clarification).
     * "water splash", "water splashes", "water crossing", "water crossings", "splash", "splashes", "watr splash" -> "water splash"
     * "donut", "donuts", "doughnut", "doughnuts" -> "donut"
     * "hairpin", "hairpins", "handbrake turn", "handbrake turns", "handbrake" -> "hairpin"
     * "jump", "jumps", "jumping", "air", "airborne", "big air", "jumsp" -> "jump"
     * "drift", "drifts", "drifting", "slide", "slides", "sliding" -> "drift"
     * "crash", "crashes", "crashed", "accident", "accidents", "roll", "rollover" -> "crash"
     * "spin", "spins", "spinning" -> "spin"
     * "start line", "launch", "start", "starts" -> "start line"
     * "near miss", "close call", "save", "saves" -> "near miss"
     * "mechanical failure", "puncture", "breakdown", "broken" -> "mechanical failure"
     * "offroad", "off road", "ditch", "ditched" -> "offroad"
     * "stuck", "bogged" -> "stuck"
   - year: integer (e.g. 2026, 2025, 2024, 2023)
   - limit: integer (default 20, or as requested, e.g. "top 10" -> limit 10)

5. Clarification:
   Set `requiresClarification: true` and provide a helpful `clarificationQuestion` when:
   - The query specifies ONLY a broad result category without ANY usable filter, entity, action, driver, or context (e.g. "Find clips", "Uploaders", "Show results", "Who won?").
   - The query is completely ambiguous, contradictory, or lacks necessary information to execute safely.
   Examples triggering clarification:
   * "Find clips" -> {"requiresClarification": true, "clarificationQuestion": "What kind of clips or rally moments would you like to see?"}
   * "Uploaders" -> {"requiresClarification": true, "clarificationQuestion": "Which rally or event do you want uploader rankings for?"}
   * "Show results" -> {"requiresClarification": true, "clarificationQuestion": "Which rally or event would you like to see results for?"}
   * "Who won?" -> {"requiresClarification": true, "clarificationQuestion": "Which rally or year would you like to know the winner of?"}
   Do NOT trigger clarification for valid queries with meaningful filters or global intents:
   * "Show jumps" -> {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "requiresClarification": false}
   * "Show spins and doughnuts in Killarney" -> {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "spin", "rallyName": "Killarney", "requiresClarification": false}
   * "Show rallies in 2025" -> {"intent": "SEARCH_RALLIES", "year": 2025, "requiresClarification": false}
   * "Show drivers with the most wins" -> {"intent": "GET_TOP_DRIVERS_BY_WINS", "requiresClarification": false}

6. Examples:
   - "Show jump highlights featuring Moffett from Moonraker" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Moffett", "rallyName": "Moonraker", "requiresClarification": false}
   - "Show spins and doughnuts in Killarney" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "spin", "rallyName": "Killarney", "requiresClarification": false}
   - "Show water splashes from Woodpecker Rally" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "water splash", "rallyName": "Woodpecker Rally", "requiresClarification": false}
   - "Donut clips from Trackrod Rally" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "donut", "rallyName": "Trackrod Rally", "requiresClarification": false}
   - "Show hairpins and handbrake turns in Get Jerky Rally" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "hairpin", "rallyName": "Get Jerky Rally", "requiresClarification": false}
   - "Show spins in Killarney in 2024" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "spin", "rallyName": "Killarney", "year": 2024, "requiresClarification": false}
   - "Show rallies in Ireland in 2025 where Josh Moffett participated" ->
     {"intent": "SEARCH_DRIVER_RALLIES", "driverName": "Josh Moffett", "country": "Ireland", "year": 2025, "requiresClarification": false}
   - "Which rallies did Moffett win in 2025?" ->
     {"intent": "SEARCH_DRIVER_WINS", "driverName": "Moffett", "year": 2025, "requiresClarification": false}
   - "Who finished first in Moonraker?" ->
     {"intent": "GET_RALLY_RESULTS", "rallyName": "Moonraker", "requiresClarification": false}
   - "Show the top 10 finishers from Moonraker" ->
     {"intent": "GET_RALLY_TOP_FINISHERS", "rallyName": "Moonraker", "limit": 10, "requiresClarification": false}
   - "Show the drivers with the most wins" ->
     {"intent": "GET_TOP_DRIVERS_BY_WINS", "requiresClarification": false}
   - "Who are the top uploaders for Moonraker?" ->
     {"intent": "GET_TOP_UPLOADERS", "rallyName": "Moonraker", "requiresClarification": false}
   - "Show drift highlights from Get Jerky on Gale Rigg" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "drift", "rallyName": "Get Jerky", "stageName": "Gale Rigg", "requiresClarification": false}
''';

  /// Supported canonical action types
  static const List<String> supportedActionTypes = [
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
  ];

  /// JSON Schema definition for OpenAI Structured Outputs (json_schema format)
  static const Map<String, dynamic> jsonSchema = {
    'name': 'rally_search_query',
    'strict': true,
    'schema': {
      'type': 'object',
      'properties': {
        'intent': {
          'type': 'string',
          'enum': [
            'SEARCH_RALLIES',
            'SEARCH_DRIVER_RALLIES',
            'SEARCH_DRIVER_WINS',
            'GET_RALLY_RESULTS',
            'GET_RALLY_TOP_FINISHERS',
            'SEARCH_VIDEO_ACTIONS',
            'SEARCH_DRIVER_VIDEOS',
            'GET_TOP_UPLOADERS',
            'GET_TOP_DRIVERS_BY_WINS',
          ],
          'description': 'The primary search intent of the user query.',
        },
        'rallyName': {
          'type': ['string', 'null'],
          'description': 'Raw rally or championship mention from user query (e.g. Moonraker, Donegal, Killarney).',
        },
        'eventName': {
          'type': ['string', 'null'],
          'description': 'Specific event name if distinct from rallyName.',
        },
        'country': {
          'type': ['string', 'null'],
          'description': 'Country name (e.g. Ireland, United Kingdom, Portugal, France).',
        },
        'city': {
          'type': ['string', 'null'],
          'description': 'City or locality where rally took place (e.g. Letterkenny, Fafe).',
        },
        'stageName': {
          'type': ['string', 'null'],
          'description': 'Special stage name (e.g. Gale Rigg, Alwen North, Tarenig).',
        },
        'stageNumber': {
          'type': ['string', 'null'],
          'description': 'Stage number (e.g. SS1, SS2).',
        },
        'driverName': {
          'type': ['string', 'null'],
          'description': 'Driver or competitor name extracted verbatim (e.g. Josh Moffett, Moffett).',
        },
        'actionType': {
          'type': ['string', 'null'],
          'enum': [
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
            null,
          ],
          'description': 'Action highlight category if searching video moments.',
        },
        'year': {
          'type': ['integer', 'null'],
          'description': 'Four-digit year (e.g. 2025, 2026).',
        },
        'limit': {
          'type': ['integer', 'null'],
          'description': 'Number of items to retrieve (default 20).',
        },
        'offset': {
          'type': ['integer', 'null'],
          'description': 'Pagination offset (default 0).',
        },
        'requiresClarification': {
          'type': 'boolean',
          'description': 'True if the query cannot be safely resolved without user clarification.',
        },
        'clarificationQuestion': {
          'type': ['string', 'null'],
          'description': 'Specific question to present to the user if requiresClarification is true.',
        },
      },
      'required': [
        'intent',
        'rallyName',
        'eventName',
        'country',
        'city',
        'stageName',
        'stageNumber',
        'driverName',
        'actionType',
        'year',
        'limit',
        'offset',
        'requiresClarification',
        'clarificationQuestion',
      ],
      'additionalProperties': false,
    },
  };

  /// Gemini OpenAPI responseSchema definition for structured JSON generation
  static const Map<String, dynamic> geminiResponseSchema = {
    'type': 'OBJECT',
    'properties': {
      'intent': {
        'type': 'STRING',
        'enum': [
          'SEARCH_RALLIES',
          'SEARCH_DRIVER_RALLIES',
          'SEARCH_DRIVER_WINS',
          'GET_RALLY_RESULTS',
          'GET_RALLY_TOP_FINISHERS',
          'SEARCH_VIDEO_ACTIONS',
          'SEARCH_DRIVER_VIDEOS',
          'GET_TOP_UPLOADERS',
          'GET_TOP_DRIVERS_BY_WINS',
        ],
        'description': 'The primary search intent of the user query.',
      },
      'rallyName': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Raw rally or championship mention from user query.',
      },
      'eventName': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Specific event name if distinct from rallyName.',
      },
      'country': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Country name (e.g. Ireland, United Kingdom, Poland, Portugal).',
      },
      'city': {
        'type': 'STRING',
        'nullable': true,
        'description': 'City or locality.',
      },
      'stageName': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Special stage name.',
      },
      'stageNumber': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Stage number.',
      },
      'driverName': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Driver or competitor name verbatim as expressed.',
      },
      'actionType': {
        'type': 'STRING',
        'nullable': true,
        'enum': [
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
        ],
        'description': 'Action highlight category.',
      },
      'year': {
        'type': 'INTEGER',
        'nullable': true,
        'description': 'Four-digit year.',
      },
      'limit': {
        'type': 'INTEGER',
        'nullable': true,
        'description': 'Number of items to retrieve (default 20).',
      },
      'offset': {
        'type': 'INTEGER',
        'nullable': true,
        'description': 'Pagination offset (default 0).',
      },
      'requiresClarification': {
        'type': 'BOOLEAN',
        'description': 'True if the query cannot be safely resolved without user clarification.',
      },
      'clarificationQuestion': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Question if requiresClarification is true.',
      },
    },
    'required': [
      'intent',
      'requiresClarification',
    ],
  };
}
