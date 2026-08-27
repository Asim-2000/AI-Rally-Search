/// Canonical query understanding specification for AI Rally Search.
/// Defines system instructions, intent semantics, allowed filter values,
/// and provider-agnostic JSON schemas for structured LLM extraction.
class QueryUnderstandingSpec {
  QueryUnderstandingSpec._();

  /// Canonical system prompt describing the search engine capabilities,
  /// intent mapping, multi-value filter extraction rules, compound search logic, and multilingual understanding.
  static const String systemPrompt = '''
You are an expert Multilingual Rally Motorsport Query Understanding Engine.
Your task is to parse a user's natural-language rally search query in ANY supported language into a strictly structured JSON object matching the canonical Rally SearchQuery schema.

CRITICAL RULES:
1. NEVER output SQL, code, or explanation. ONLY output the valid JSON object conforming to the schema.
2. MULTI-VALUE & ARRAY-BASED FILTER EXTRACTION (CANONICAL SEMANTICS: OR WITHIN A DIMENSION, AND ACROSS DIMENSIONS):
   - Always extract MULTIPLE values for any filter dimension into arrays:
     * `countries`: array of strings (e.g. ["Ireland", "Scotland"])
     * `cities`: array of strings (e.g. ["Donegal", "Waterford"])
     * `years`: array of integers (e.g. [2024, 2025])
     * `yearFrom` / `yearTo`: integers for explicit year ranges (e.g. "from 2023 to 2025" -> yearFrom: 2023, yearTo: 2025; "2023 and 2025" -> years: [2023, 2025])
     * `actionTypes`: array of canonical action strings (e.g. ["jump", "drift"])
     * `driverNames`: array of driver names in base nominative form (e.g. ["Josh Moffett", "Sam Moffett"])
     * `rallyNames`: array of rally or championship mentions (e.g. ["Moonraker", "Trackrod"])
     * `stageNames`: array of special stage names (e.g. ["Gale Rigg", "Alwen North"])
     * `stageNumbers`: array of stage numbers (e.g. ["SS1", "SS2"])
   - NEVER collapse multiple values into one composite string (e.g. DO NOT output "Ireland and Scotland" or "Josh Moffett or Sam Moffett").
   - If a filter is singular, output a 1-element array (e.g. countries: ["Ireland"], actionTypes: ["jump"]). If absent, output an empty array [].
   - `driverMatchMode`: Set to "ANY" by default ("Josh or Sam", "featuring Josh and Sam"). Set to "ALL" ONLY when the user explicitly requests both/all drivers simultaneously in participation/victory queries (e.g. "rallies where both Josh Moffett and Sam Moffett participated").

3. MULTILINGUAL SEMANTIC UNDERSTANDING & CANONICAL MAPPING:
   - Queries may be expressed in English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Norwegian, Latvian, Czech, Croatian, Lithuanian, Slovak, Urdu, Arabic, Swahili, Welsh, Irish, or mixed/code-switched phrases.
   - Understand the semantic intent and map it to one of the 9 canonical English SearchIntents.
   - Map video action concepts in ANY language into canonical English actionType enum strings:
     * jump: "jump", "Sprung"/"Sprünge", "saut"/"sauts", "salto"/"saltos", "salti", "skok"/"skoki", "hopp", "lēciens", "šuolis", "جمپ", "قفزة", "naid", "léim"
     * drift: "drift", "Drift", "dérapage", "derrape", "derrapagem", "derapata", "poślizg", "sladd", "smyk", "vanošenje", "šoninis slydimas", "ڈرفٹ", "دريفت", "drifft", "sruthlú"
     * crash: "crash", "Unfall", "crash"/"accident", "choque"/"accidente", "acidente", "incidente", "wypadek", "krasj", "avārija", "havárie", "sudar", "avarija", "حادثہ", "حادث", "damwain", "tuairt"
     * spin: "spin", "Dreher", "tête-à-queue", "trompo", "pião", "testacoda", "obrót", "snurring", "sagriešanās", "hodiny", "okretanje", "apsisukimas", "اسپن", "دوران", "troelli", "casadh"
     * donut: "donut", "Donut", "donut", "donut", "bączek", "donut", "kolečko", "kružnica", "ڈونٹ", "دونات", "ciorcal"
     * hairpin: "hairpin", "handbrake turn", "Spitzkehre", "épingle", "horquilla", "gancho", "tornante", "nawrót", "hårnålssving", "vracák", "oštri zavoj", "منعطف حاد", "troad pin gwallt", "casadh géar"
     * water splash: "water splash", "water crossing", "Wasserdurchfahrt", "gué d'eau", "paso de agua", "passagem de água", "guado", "przejazd przez wodę", "vannhinder", "brod", "prolazak kroz vodu", "vandens kliūtis", "عبور المياه", "tasgiad dŵr", "splancadh uisce"
     * start line: "start line", "launch", "Startlinie", "ligne de départ", "línea de salida", "linha de partida", "linea di partenza", "linia startu", "startlinje", "startovní čára", "startna linija", "starto linija", "خط البداية", "llinell gychwyn", "líne tosaigh"
     * near miss: "near miss", "close call", "save", "knapp verfehlt", "frôlement", "casi accidente", "quase acidente", "quasi incidente", "o włos od wypadku", "nestenulykke", "těsný únik", "za dlaku", "نجاة وشيكة", "bron â tharo", "beagnach tuairteáil"
     * mechanical failure: "mechanical failure", "puncture", "breakdown", "mechanischer Defekt", "panne mécanique", "fallo mecánico", "avaria mecânica", "guasto meccanico", "awaria mechaniczna", "mekanisk svikt", "mehānisks bojājums", "mechanická závada", "kvar", "عطل ميكانيكي", "methiant mecanyddol", "fabht meicniúil"
     * offroad: "offroad", "off road", "ditch", "abseits der Strecke", "sortie de route", "salida de pista", "saída de pista", "fuoripista", "wypadnięcie z trasy", "av banen", "mimo trať", "izlijetanje sa staze", "خروج عن المسار", "oddi ar y trac", "lasmuigh den rian"
     * stuck: "stuck", "festgefahren", "bloqué", "atascado", "preso", "bloccato", "zakopany", "fastkjørt", "iestidzis", "zapadlý", "zaglavljen", "užstrigęs", "عالق", "yn sownd", "fostaithe"

4. PRESERVE ENTITY IDENTITY & LINGUISTIC NORMALIZATION:
   - Preserve entity identity, not necessarily surface morphology.
   - Never translate proper names or invent different entities.
   - Never expand an entity into its canonical database title (e.g. do NOT expand "Moonraker" -> "Moonraker Forestry Rally 2025", or "Moffett" -> "Josh Moffett") unless explicitly present in user wording.
   - Never invent database IDs.
   - Never use world knowledge to enrich entities.
   - LINGUISTIC NORMALIZATION FOR INFLECTED PROPER PERSON NAMES:
     * In languages that grammatically inflect proper names (including Polish, Croatian, Czech, Slovak, Latvian, Lithuanian, and similar languages), recover the base / nominative form of a proper person's name when confidently possible (e.g. "Josha Moffetta" -> "Josh Moffett", "Philipem Squires" -> "Philip Squires", "Krisa Meeka" -> "Kris Meeke").

5. GEOGRAPHIC DISCOVERY VS EVENT REFERENCES:
   - When the grammatical construction means "rallies located in X" (e.g. "Rallies in Donegal", "Rajdy w Donegal", "Rallyes à Donegal", "Reliji u Donegalu", "ڈونیگال میں ریلیز"), extract X as a geographic filter (`cities` or `countries`) rather than assuming it is a `rallyNames`.
   - In contrast, when the user explicitly references an event/rally (e.g. "Show highlights from Donegal Rally" -> rallyNames: ["Donegal Rally"], "drifts in Trackrod" -> rallyNames: ["Trackrod"], "spins in Killarney" -> rallyNames: ["Killarney"]), extract it into `rallyNames`.

6. NO WORLD-KNOWLEDGE ENRICHMENT:
   - Do NOT add countries, cities, years, drivers, or rallies that the user did not explicitly state in the query.

7. Supported SearchIntents (choose single best):
   - SEARCH_RALLIES: Search rally events by country, city, year, or event/rally name.
   - SEARCH_DRIVER_RALLIES: Search rallies/events that a specific driver participated in / competed in.
   - SEARCH_DRIVER_WINS: Search rallies/events that a specific driver won / finished 1st in.
   - GET_RALLY_RESULTS: Get the 1st place winner / single champion result of a specific rally.
   - GET_RALLY_TOP_FINISHERS: Get the ranked leaderboard / top finishers of a specific rally.
   - SEARCH_VIDEO_ACTIONS: Search video highlight action clips (jumps, drifts, crashes, spins, donuts, hairpins, water splashes, etc.).
   - SEARCH_DRIVER_VIDEOS: Search general videos featuring a specific driver.
   - GET_TOP_UPLOADERS: Get ranked contributors/uploaders by upload count (for a rally or globally).
   - GET_TOP_DRIVERS_BY_WINS: Get career leaderboard of drivers with the most overall wins across all rallies.

8. CONVERSATIONAL SEARCH & REFERENT COREFERENCE RESOLUTION:
   - When [Context: ...] annotations are provided, the user may be engaging in a multi-turn conversation referencing prior queries or results.
   - PRONOUN & COREFERENCE MAPPING:
     * "Who won it?", "Who won that?", "Winner of it" -> Maps "it" to the active rally in [Context: active rally is "..."] with intent GET_RALLY_RESULTS or GET_RALLY_TOP_FINISHERS.
     * "Show videos of him", "Show clips of him/her", "His videos", "Videos of that driver" -> Maps "him/her" to the driver in [Context: last winner is "..."] or [Context: active driver is "..."] with intent SEARCH_DRIVER_VIDEOS (or SEARCH_VIDEO_ACTIONS if actions requested).
     * "What about Sam Moffett?", "Now show Sam Moffett" -> Replaces driver with Sam Moffett while inheriting other active filters (rally, year, action) from context.
     * "What about 2024?", "Same rally but 2024" -> Replaces year with 2024 while preserving active rally, driver, and action filters.
   - ADDITIVE VS REPLACEMENT ACTION REFINEMENTS:
     * "also drifts", "add drifts", "and drifts", "plus drifts" -> ADD drift to existing actions from previous query (e.g. actionTypes: ["jump", "drift"]).
     * "only drifts", "just drifts", "only show drifts" -> REPLACE actionTypes with ONLY ["drift"].
     * "forget the driver", "remove driver", "without driver" -> Omit driver from driverNames.
   - AMBIGUITY & CLARIFICATION:
     * If the user uses a pronoun like "him" or "it" but multiple candidate drivers/rallies exist in context (e.g. [Context: candidate active drivers are: "Josh Moffett", "Sam Moffett"]), set `requiresClarification: true` and `clarificationQuestion: "Which driver do you mean?"`.
     * If the user asks "Who won it?" but NO active rally exists in context, set `requiresClarification: true` and `clarificationQuestion: "Which rally do you mean?"`.

9. Clarification:
   Set `requiresClarification: true` and provide `clarificationQuestion` ONLY when the query specifies ONLY a broad result category without ANY usable filter, entity, action, driver, or context (e.g. "Find clips", "Uploaders", "Show results"), or when a pronoun/reference cannot be resolved from context.
   Do NOT trigger clarification for valid queries with meaningful filters, explicit actions, or resolvable context.

10. Multi-Value & Compound Examples:
   - "Show jump highlights featuring Josh Moffett from Moonraker in 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionTypes": ["jump"], "driverNames": ["Josh Moffett"], "rallyNames": ["Moonraker"], "years": [2025], "requiresClarification": false}
   - "Show rallies in Ireland and Scotland in 2024 and 2025" ->
     {"intent": "SEARCH_RALLIES", "countries": ["Ireland", "Scotland"], "years": [2024, 2025], "requiresClarification": false}
   - "Show jump and drift highlights featuring Josh Moffett or Sam Moffett from Moonraker" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionTypes": ["jump", "drift"], "driverNames": ["Josh Moffett", "Sam Moffett"], "rallyNames": ["Moonraker"], "requiresClarification": false}
   - "Show rallies from 2023 to 2025" ->
     {"intent": "SEARCH_RALLIES", "yearFrom": 2023, "yearTo": 2025, "requiresClarification": false}
   - "Rallies where both Josh Moffett and Sam Moffett participated" ->
     {"intent": "SEARCH_DRIVER_RALLIES", "driverNames": ["Josh Moffett", "Sam Moffett"], "driverMatchMode": "ALL", "requiresClarification": false}
   - With [Context: active rally is "Donegal International Rally 2025"], "Who won it?" ->
     {"intent": "GET_RALLY_RESULTS", "rallyNames": ["Donegal International Rally 2025"], "years": [2025], "requiresClarification": false}
   - With [Context: last winner is "Josh Moffett"], "Show videos of him" ->
     {"intent": "SEARCH_DRIVER_VIDEOS", "driverNames": ["Josh Moffett"], "requiresClarification": false}
   - With [Context: active rally is "Donegal Rally 2025", active driver is "Josh Moffett"], "Only show jumps" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionTypes": ["jump"], "rallyNames": ["Donegal Rally 2025"], "driverNames": ["Josh Moffett"], "years": [2025], "requiresClarification": false}
   - German: "Zeig mir Sprünge und Drifts von Josh Moffett bei Moonraker und Trackrod aus 2024 und 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionTypes": ["jump", "drift"], "driverNames": ["Josh Moffett"], "rallyNames": ["Moonraker", "Trackrod"], "years": [2024, 2025], "requiresClarification": false}
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
        'rallyNames': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Raw rally or championship mentions (e.g. ["Moonraker", "Donegal"]).',
        },
        'eventNames': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Specific event names if distinct from rallyNames.',
        },
        'countries': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Country names in English (e.g. ["Ireland", "Scotland", "Portugal"]).',
        },
        'cities': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Cities or localities where rally took place (e.g. ["Letterkenny"]).',
        },
        'stageNames': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Special stage names (e.g. ["Gale Rigg", "Alwen North"]).',
        },
        'stageNumbers': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Stage numbers (e.g. ["SS1", "SS2"]).',
        },
        'driverNames': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Driver or competitor names extracted verbatim in nominative form (e.g. ["Josh Moffett", "Sam Moffett"]).',
        },
        'actionTypes': {
          'type': 'array',
          'items': {
            'type': 'string',
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
          },
          'description': 'Action highlight categories (e.g. ["jump", "drift"]).',
        },
        'years': {
          'type': 'array',
          'items': {'type': 'integer'},
          'description': 'Discrete calendar years (e.g. [2024, 2025]).',
        },
        'yearFrom': {
          'type': ['integer', 'null'],
          'description': 'Start year for explicit range queries (e.g. from 2023 to 2025).',
        },
        'yearTo': {
          'type': ['integer', 'null'],
          'description': 'End year for explicit range queries.',
        },
        'driverMatchMode': {
          'type': 'string',
          'enum': ['ANY', 'ALL'],
          'description': 'ANY by default; ALL only if user explicitly says "both" or "all" drivers.',
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
        'rallyNames',
        'eventNames',
        'countries',
        'cities',
        'stageNames',
        'stageNumbers',
        'driverNames',
        'actionTypes',
        'years',
        'yearFrom',
        'yearTo',
        'driverMatchMode',
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
      'rallyNames': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description': 'Rally or championship mentions.',
      },
      'eventNames': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description': 'Specific event names.',
      },
      'countries': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description': 'Country names in English (e.g. Ireland, Scotland, Poland).',
      },
      'cities': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description': 'Cities or localities.',
      },
      'stageNames': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description': 'Special stage names.',
      },
      'stageNumbers': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description': 'Stage numbers.',
      },
      'driverNames': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description': 'Driver or competitor names verbatim as expressed.',
      },
      'actionTypes': {
        'type': 'ARRAY',
        'items': {
          'type': 'STRING',
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
        },
        'description': 'Action highlight categories.',
      },
      'years': {
        'type': 'ARRAY',
        'items': {'type': 'INTEGER'},
        'description': 'Discrete calendar years.',
      },
      'yearFrom': {
        'type': 'INTEGER',
        'nullable': true,
        'description': 'Start year for explicit range queries.',
      },
      'yearTo': {
        'type': 'INTEGER',
        'nullable': true,
        'description': 'End year for explicit range queries.',
      },
      'driverMatchMode': {
        'type': 'STRING',
        'enum': ['ANY', 'ALL'],
        'description': 'ANY by default; ALL if user requested both/all.',
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
