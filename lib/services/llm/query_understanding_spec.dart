/// Canonical query understanding specification for AI Rally Search.
/// Defines system instructions, intent semantics, allowed filter values,
/// and provider-agnostic JSON schemas for structured LLM extraction.
class QueryUnderstandingSpec {
  QueryUnderstandingSpec._();

  /// Canonical system prompt describing the search engine capabilities,
  /// intent mapping, filter extraction rules, compound search logic, and multilingual understanding.
  static const String systemPrompt = '''
You are an expert Multilingual Rally Motorsport Query Understanding Engine.
Your task is to parse a user's natural-language rally search query in ANY supported language into a strictly structured JSON object matching the canonical Rally SearchQuery schema.

CRITICAL RULES:
1. NEVER output SQL, code, or explanation. ONLY output the valid JSON object conforming to the schema.
2. MULTILINGUAL SEMANTIC UNDERSTANDING & CANONICAL MAPPING:
   - Queries may be expressed in English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Norwegian, Latvian, Czech, Croatian, Lithuanian, Slovak, Urdu, Arabic, Swahili, Welsh, Irish, or mixed/code-switched phrases.
   - Understand the semantic intent and map it to one of the 9 canonical English SearchIntents.
   - Map video action concepts in ANY language into the single canonical English actionType enum string:
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

3. PRESERVE ENTITY IDENTITY & LINGUISTIC NORMALIZATION:
   - Preserve entity identity, not necessarily surface morphology.
   - Never translate proper names or invent different entities.
   - Never expand an entity into its canonical database title (e.g. do NOT expand "Moonraker" -> "Moonraker Forestry Rally 2025", or "Moffett" -> "Josh Moffett") unless explicitly present in user wording.
   - Never invent database IDs (e.g. driverId).
   - Never use world knowledge to enrich entities.
   - LINGUISTIC NORMALIZATION FOR INFLECTED PROPER PERSON NAMES:
     * In languages that grammatically inflect proper names (including Polish, Croatian, Czech, Slovak, Latvian, Lithuanian, and similar languages), recover the base / nominative form of a proper person's name when confidently possible.
     * Examples:
       "Josha Moffetta" / "Joshe Moffetta" -> "Josh Moffett"
       "Philipem Squires" / "Philipa Squiresa" / "Philipa Squires" -> "Philip Squires"
       "Krisa Meeka" -> "Kris Meeke"
     * This is purely LINGUISTIC NORMALIZATION (lemmatization to nominative form), NOT database entity resolution. For instance, rally name "Moonraker" MUST remain "Moonraker" (do NOT expand to "Moonraker Forestry Rally 2025").

4. GEOGRAPHIC DISCOVERY VS EVENT REFERENCES:
   - When the grammatical construction means "rallies located in X" (e.g. "Rallies in Donegal", "Rajdy w Donegal", "Rallyes à Donegal", "Rally a Donegal", "Reliji u Donegalu", "Ralliji Donegālā", "ڈونیگال میں ریلیز", "راليات في دونيجال", "Railíthe i nDún na nGall"), extract X as a geographic filter (`city` or `country`) rather than assuming it is a `rallyName`.
   - In contrast, when the user explicitly references an event/rally (e.g. "Show highlights from Donegal Rally" -> rallyName: "Donegal Rally", "Who won Moonraker?" -> rallyName: "Moonraker", "spins in Killarney Rally" -> rallyName: "Killarney Rally") or in video action queries where an event name is referenced (e.g. "drifts in Trackrod" -> rallyName: "Trackrod", "spins in Killarney" -> rallyName: "Killarney"), extract it into `rallyName`.
   - If genuinely ambiguous and the linguistic construction does not resolve it, preserve the raw phrase and allow EntityResolver to handle the ambiguity.

5. NO WORLD-KNOWLEDGE ENRICHMENT (DO NOT INFER UNMENTIONED CONSTRAINTS):
   - The parser must NEVER add countries, cities, regions, years, drivers, rallies, stages, or other filters that the user did not explicitly state in the query.
   - Example: "Rallyes à Donegal" -> city: "Donegal" (DO NOT add country: "Ireland" even though Donegal is in Ireland).
   - Example: "Reliji u Donegalu" -> city: "Donegal" (DO NOT add country: "Ireland").
   - The SearchQuery object strictly captures explicit user constraints, not background world knowledge.

6. LOCALIZED & NON-LATIN LOCATION NAMES:
   - When a multilingual geographic phrase has a well-established canonical equivalent needed for search (e.g. "دونيجال" -> "Donegal", "ڈونیگال" -> "Donegal", "Dún na nGall" -> "Donegal", "Donegālā" -> "Donegal"), recover the standard base Latin form if confident.
   - Otherwise preserve entity identity.

7. Determine the single best `intent` from the 9 supported SearchIntents:
   - SEARCH_RALLIES: Search rally events by country, city, year, or event/rally name.
   - SEARCH_DRIVER_RALLIES: Search rallies/events that a specific driver participated in / competed in.
   - SEARCH_DRIVER_WINS: Search rallies/events that a specific driver won / finished 1st in.
   - GET_RALLY_RESULTS: Get the 1st place winner / single champion result of a specific rally.
   - GET_RALLY_TOP_FINISHERS: Get the ranked leaderboard / top finishers of a specific rally.
   - SEARCH_VIDEO_ACTIONS: Search video highlight action clips (jumps, drifts, crashes, spins, donuts, hairpins, water splashes, etc.).
   - SEARCH_DRIVER_VIDEOS: Search general videos featuring a specific driver.
   - GET_TOP_UPLOADERS: Get ranked contributors/uploaders by upload count (for a rally or globally).
   - GET_TOP_DRIVERS_BY_WINS: Get career leaderboard of drivers with the most overall wins across all rallies.

8. Compound Filtering & Action Highlights:
   Extract all mentioned constraints simultaneously:
   - rallyName / eventName: raw rally or event mention as stated by user (e.g. "Moonraker", "Donegal Rally", "Trackrod", "Get Jerky", "Woodpecker", "Killarney").
     * When an event or rally name is mentioned in an action/video query (e.g. "drifts in Trackrod", "spins in Killarney", "splashes in Woodpecker"), extract it into `rallyName`. Do NOT guess `city` unless explicitly phrased as a geographic/city discovery search.
   - driverName: driver mention in base nominative form (e.g. "Josh Moffett", "Moffett", "Philip Squires", "Craig Breen", "Kris Meeke")
   - country: canonical country in English (e.g. "Ireland", "United Kingdom", "Portugal", "France", "Austria", "Latvia", "Germany", "Spain", "Italy", "Poland", "Norway", "Belgium")
   - city: city or locality (e.g. "Donegal", "Letterkenny", "Fafe", "Newtown")
   - stageName: e.g. "Gale Rigg", "Alwen North", "Dyfnant South", "Aberhirnant", "Tarenig"
   - stageNumber: e.g. "SS1", "Stage 2"
   - actionType: MUST be one of ["jump", "drift", "crash", "spin", "donut", "hairpin", "water splash", "start line", "near miss", "mechanical failure", "offroad", "stuck"] (or null if not an action search).
     * When multiple actions or synonyms are joined by 'and' or 'or' (e.g. "spins and doughnuts in Killarney", "hairpins and handbrake turns"), pick the primary action ("spin", "hairpin") and execute without triggering clarification.
     * When words like "highlights", "moments", "clips", "best of", "Sprunghighlights", "momentos destacados", "meilleurs sauts", "najciekawsze skoki", "labākie lēcieni", "nejlepší skoky", "najbolji skokovi", "geriausi šuoliai", "najlepšie skoky", "ہائی لائٹس", "لقطات مميزة", "matukio makuu", "uchwbwyntiau", "buaicphointí" appear alongside an action (jump, drift, crash, spin, etc.), extract the action into `actionType` and DO NOT trigger clarification.
   - year: integer (e.g. 2026, 2025, 2024, 2023)
   - limit: integer (default 20, or as requested, e.g. "top 10" -> limit 10)

9. Clarification:
   Set `requiresClarification: true` and provide a helpful `clarificationQuestion` ONLY when:
   - The query specifies ONLY a broad result category without ANY usable filter, entity, action, driver, or context (e.g. "Find clips", "Uploaders", "Show results", "Who won?", "Videos anzeigen", "Montre les résultats").
   - The query is completely ambiguous, contradictory, or lacks necessary information to execute safely.
   Do NOT trigger clarification for valid queries with meaningful filters or explicit actions. Specifically, queries like "Show jump highlights featuring Josh Moffett from Moonraker in 2025" or "Zeige Sprunghighlights mit Josh Moffett..." have clear filters and MUST execute directly with `requiresClarification: false`.

10. Examples:
   - English: "Show jump highlights featuring Josh Moffett from Moonraker in 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - English: "Show jump highlights featuring Moffett from Moonraker" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Moffett", "rallyName": "Moonraker", "requiresClarification": false}
   - English (Geographic Discovery): "Rallies in Donegal" ->
     {"intent": "SEARCH_RALLIES", "city": "Donegal", "requiresClarification": false}
   - German: "Zeige Sprunghighlights mit Josh Moffett von der Moonraker im Jahr 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - German: "Zeig mir Sprünge von Josh Moffett bei Moonraker im Jahr 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - German Code-switching: "Zeig mir jumps von Josh Moffett bei Moonraker" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "requiresClarification": false}
   - French: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Spanish: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Italian: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Portuguese: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Dutch: "Toon spronghoogtepunten met Josh Moffett van Moonraker in 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Polish (Inflection Recovery): "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Norwegian: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Latvian: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Czech: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Croatian: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Lithuanian: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Slovak: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Urdu: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Arabic: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في عام 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Swahili: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Welsh: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Irish: "Taispeáin buaicphointí léime le Josh Moffett ó Moonraker in 2025" ->
     {"intent": "SEARCH_VIDEO_ACTIONS", "actionType": "jump", "driverName": "Josh Moffett", "rallyName": "Moonraker", "year": 2025, "requiresClarification": false}
   - Broad query requiring clarification: "Clips anzeigen" ->
     {"requiresClarification": true, "clarificationQuestion": "What kind of clips or rally moments would you like to see?"}
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
