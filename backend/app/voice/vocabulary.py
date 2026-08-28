from __future__ import annotations

# Canonical vocabulary terms mirroring lib/services/speech/speech_vocabulary_context.dart
# and lib/services/speech/multilingual_domain_lexicon.dart.

DEFAULT_DRIVERS = [
    "Josh Moffett",
    "Sam Moffett",
    "Philip Squires",
    "Kris Meeke",
    "Keith Cronin",
    "Callum Devine",
    "Craig Breen",
    "Alastair Fisher",
    "Desi Henry",
    "Cathan McCourt",
    "Garry Jennings",
    "Declan Boyle",
    "Sébastien Ogier",
    "Kalle Rovanperä",
    "Thierry Neuville",
    "Elfyn Evans",
]

DEFAULT_RALLIES = [
    "Moonraker",
    "Donegal",
    "Trackrod",
    "Gale Rigg",
    "Woodpecker",
    "Tarenig",
    "West Cork Rally",
    "Cork 20",
    "Killarney Historic Rally",
    "Rally of the Lakes",
    "Circuit of Ireland",
    "Mayo Stages",
    "Monaghan Stages",
    "Clare Stages",
    "Sligo Stages",
    "Mid Ulster Stages",
    "Limerick Forest Rally",
]

DEFAULT_STAGES = [
    "Ring Stage",
    "Ardfield Stage",
    "Molls Gap",
    "Healy Pass",
    "Atlantic Drive",
    "Fanad Head",
    "Knockalla",
    "SS1",
    "SS2",
    "Power Stage",
]

DEFAULT_ACTIONS = [
    "jump",
    "drift",
    "crash",
    "spin",
    "water splash",
    "donut",
    "highlights",
    "hairpin",
    "near miss",
    "mechanical failure",
    "offroad",
    "results",
    "winner",
    "top finishers",
]

MULTILINGUAL_ACTIONS: dict[str, dict[str, list[str]]] = {
    "jump": {
        "de": ["Sprung", "Sprünge"],
        "fr": ["saut", "sauts"],
        "es": ["salto", "saltos"],
        "it": ["salto", "salti"],
        "pl": ["skok", "skoki"],
        "no": ["hopp"],
        "lv": ["lēciens", "lēcieni"],
        "lt": ["šuolis", "šuoliai"],
        "ur": ["جمپ"],
        "ar": ["قفزة", "قفزات"],
    },
    "drift": {
        "de": ["Drift", "Drifts"],
        "fr": ["dérapage", "dérapages"],
        "es": ["derrape", "derrapes"],
        "it": ["derapata", "derapate"],
        "pl": ["poślizg", "drifty"],
        "no": ["sladd"],
        "lv": ["sānslīde", "drifts"],
        "lt": ["šoninis slydimas"],
        "ur": ["ڈرفٹ"],
        "ar": ["دريفت", "انزلاق"],
    },
}

WHISPER_SUPPORTED_LANGUAGES = {
    "af", "am", "ar", "as", "az", "ba", "be", "bg", "bn", "bo", "br", "bs",
    "ca", "cs", "cy", "da", "de", "el", "en", "es", "et", "eu", "fa", "fi",
    "fo", "fr", "gl", "gu", "ha", "haw", "he", "hi", "hr", "ht", "hu", "hy",
    "id", "is", "it", "ja", "jw", "ka", "kk", "km", "kn", "ko", "la", "lb",
    "ln", "lo", "lt", "lv", "mg", "mi", "mk", "ml", "mn", "mr", "ms", "mt",
    "my", "ne", "nl", "nn", "no", "oc", "pa", "pl", "ps", "pt", "ro", "ru",
    "sa", "sd", "si", "sk", "sl", "sn", "so", "sq", "sr", "su", "sv", "sw",
    "ta", "te", "tg", "th", "tk", "tl", "tr", "tt", "uk", "ur", "uz", "vi",
    "yi", "yo", "zh",
}


def map_to_whisper_language(code: str) -> str | None:
    if not code:
        return None
    clean = code.lower().strip().replace("_", "-")
    primary_subtag = clean.split("-")[0]
    if primary_subtag in ("nb", "nn"):
        return "no"
    if primary_subtag in WHISPER_SUPPORTED_LANGUAGES:
        return primary_subtag
    return None



def build_vocabulary_prompt(
    *,
    language: str | None = None,
    active_rally: str | None = None,
    active_driver: str | None = None,
    country: str | None = None,
    year: int | None = None,
    max_terms: int = 30,
) -> str:
    terms: list[str] = []

    # Priority 0: Active context terms
    if active_rally and active_rally.strip():
        terms.append(active_rally.strip())
    if active_driver and active_driver.strip():
        terms.append(active_driver.strip())
    if country and country.strip() and country.strip().upper() != "ALL":
        terms.append(country.strip())
    if year and year > 0:
        terms.append(str(year))

    # Priority 1: High-value proper nouns (Drivers & Rallies)
    priority_names = [
        "Josh Moffett",
        "Moonraker",
        "Donegal",
        "Trackrod",
        "Gale Rigg",
        "Woodpecker",
        "Tarenig",
    ]
    for name in priority_names:
        if name not in terms:
            terms.append(name)

    # Priority 2: Localized action terminology
    if language:
        lang_code = language.lower().strip().split("-")[0].split("_")[0]
        for action_entry in MULTILINGUAL_ACTIONS.values():
            localized_list = action_entry.get(lang_code)
            if localized_list:
                for term in localized_list:
                    if len(term) >= 3 and term not in terms:
                        terms.append(term)

    # Priority 3: English Action Terms
    action_terms = ["jump", "drift", "crash", "water splash", "highlights"]
    for a in action_terms:
        if a not in terms:
            terms.append(a)

    # Priority 4: Supported Years
    year_terms = ["2025", "2024", "2026"]
    for y in year_terms:
        if y not in terms:
            terms.append(y)

    # Priority 5: Additional custom drivers & rallies
    for driver in DEFAULT_DRIVERS:
        if driver not in terms:
            terms.append(driver)
    for rally in DEFAULT_RALLIES:
        if rally not in terms:
            terms.append(rally)

    return ", ".join(terms[:max_terms])
