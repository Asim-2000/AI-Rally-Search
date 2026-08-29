import re
import unicodedata

DIACRITICS_MAP: dict[str, str] = {
    # Vowels
    "á": "a", "à": "a", "â": "a", "ä": "a", "ã": "a", "å": "a", "ā": "a", "ą": "a", "ă": "a", "æ": "ae",
    "é": "e", "è": "e", "ê": "e", "ë": "e", "ē": "e", "ė": "e", "ę": "e", "ě": "e", "ĕ": "e",
    "í": "i", "ì": "i", "î": "i", "ï": "i", "ī": "i", "į": "i", "ĭ": "i",
    "ó": "o", "ò": "o", "ô": "o", "ö": "o", "õ": "o", "ø": "o", "ō": "o", "ő": "o", "ŏ": "o", "œ": "oe",
    "ú": "u", "ù": "u", "û": "u", "ü": "u", "ū": "u", "ų": "u", "ů": "u", "ű": "u", "ŭ": "u",
    "ý": "y", "ÿ": "y", "ŷ": "y",
    # Consonants
    "ç": "c", "ć": "c", "č": "c", "ĉ": "c", "ċ": "c",
    "ď": "d", "đ": "d", "ð": "d",
    "ģ": "g", "ğ": "g", "ġ": "g", "ĝ": "g",
    "ĥ": "h", "ħ": "h",
    "ĵ": "j",
    "ķ": "k",
    "ł": "l", "ľ": "l", "ĺ": "l", "ļ": "l", "ŀ": "l",
    "ñ": "n", "ń": "n", "ň": "n", "ņ": "n", "ŉ": "n", "ŋ": "n",
    "ŕ": "r", "ř": "r", "ŗ": "r",
    "ś": "s", "š": "s", "ș": "s", "ş": "s", "ŝ": "s", "ß": "ss",
    "ť": "t", "ț": "t", "ţ": "t", "ŧ": "t", "þ": "th",
    "ŵ": "w",
    "ź": "z", "ž": "z", "ż": "z", "ẑ": "z",
}

MOTORSPORT_DESCRIPTORS_REGEX = re.compile(
    r"\b(rally|rallies|rallye|rali|rajd|rallijsprints|stages|stage|forestry|championship)\b"
)
YEAR_REGEX = re.compile(r"\b(19|20)\d{2}\b")
DIGIT_LETTER_REGEX_1 = re.compile(r"(\d+)([a-zA-Z]+)")
DIGIT_LETTER_REGEX_2 = re.compile(r"([a-zA-Z]+)(\d+)")
APOSTROPHES_REGEX = re.compile(r"['‘’`´]")
HYPHENS_REGEX = re.compile(r"[-–—]")
DOUBLED_CONSONANTS_REGEX = re.compile(r"([b-df-hj-np-tv-z])\1+", re.IGNORECASE)


def normalize(input_str: str) -> str:
    """Normalizes Unicode string: removes diacritics, standardizes apostrophes/hyphens,
    strips punctuation, folds case across all scripts.
    Identical to Dart PhoneticMatchingHelper.normalize."""
    if not input_str:
        return ""
    # NFC normalize first to ensure composed characters match the map
    text = unicodedata.normalize("NFC", input_str).lower()

    # Map all European Latin diacritics
    for key, val in DIACRITICS_MAP.items():
        if key in text:
            text = text.replace(key, val)

    # Standardize apostrophes & hyphens
    text = APOSTROPHES_REGEX.sub("'", text)
    text = HYPHENS_REGEX.sub(" ", text)

    # Separate digits and letters (e.g. 2powerstage -> 2 powerstage, ss2 -> ss 2)
    text = DIGIT_LETTER_REGEX_1.sub(r"\1 \2", text)
    text = DIGIT_LETTER_REGEX_2.sub(r"\1 \2", text)

    # Remove remaining punctuation & symbols across all Unicode scripts (matching [^\p{L}\p{N}\s])
    cleaned_chars = []
    for c in text:
        cat = unicodedata.category(c)
        if cat.startswith("L") or cat.startswith("N") or c.isspace():
            cleaned_chars.append(c)
        else:
            cleaned_chars.append(" ")
    text = "".join(cleaned_chars)

    # Collapse multiple whitespace
    return re.sub(r"\s+", " ", text).strip()


def collapse_spaces(input_str: str) -> str:
    """Removes all whitespace for word-boundary collapsed comparisons."""
    return re.sub(r"\s+", "", normalize(input_str))


def acoustic_fold(input_str: str) -> str:
    """Conservative acoustic and phonetic comparison form."""
    text = normalize(input_str)
    if not text:
        return ""

    text = text.replace("x", "ks")
    text = text.replace("ph", "f")
    text = text.replace("ck", "k")

    # Collapse doubled consonants
    text = DOUBLED_CONSONANTS_REGEX.sub(r"\1", text)
    return text


def generate_ngram_anchors(input_str: str, n: int = 3, max_anchors: int = 6) -> list[str]:
    clean = collapse_spaces(input_str)
    if len(clean) < n:
        return [clean] if clean else []

    anchors: list[str] = []
    seen: set[str] = set()

    def add_anchor(val: str) -> None:
        if val not in seen and len(anchors) < max_anchors:
            seen.add(val)
            anchors.append(val)

    # Include start anchor
    add_anchor(clean[:n])

    # Internal sliding windows
    for i in range(1, len(clean) - n + 1):
        if len(anchors) >= max_anchors - 1:
            break
        add_anchor(clean[i:i + n])

    # Include end anchor if room
    if len(clean) >= n and len(anchors) < max_anchors:
        add_anchor(clean[len(clean) - n:])

    return anchors[:max_anchors]


def strip_year(input_str: str) -> str:
    """Strips 4-digit years from entity names."""
    norm = normalize(input_str)
    text = YEAR_REGEX.sub("", norm)
    return re.sub(r"\s+", " ", text).strip()


def strip_descriptors(input_str: str) -> str:
    """Conservative descriptor stripping:
    Strips ONLY genuinely generic motorsport descriptors (rally, stages, etc.)"""
    base = strip_year(input_str)
    text = MOTORSPORT_DESCRIPTORS_REGEX.sub("", base)
    return re.sub(r"\s+", " ", text).strip()


def has_motorsport_descriptor(input_str: str) -> bool:
    return bool(MOTORSPORT_DESCRIPTORS_REGEX.search(normalize(input_str)))


def extract_year(text: str) -> int | None:
    match = YEAR_REGEX.search(text)
    if match:
        return int(match.group(0))
    return None
