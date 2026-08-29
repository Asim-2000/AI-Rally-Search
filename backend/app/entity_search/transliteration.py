import re

ARABIC_URDU_REGEX = re.compile(
    r"[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]"
)
TASHKEEL_REGEX = re.compile(
    r"[\u064B-\u065F\u0670\u06D6-\u06ED\u0610-\u061A]"
)
TATWEEL = "\u0640"

ARABIC_DIGITS_MAP = {
    "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
    "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
}


def is_arabic_or_urdu(text: str) -> bool:
    return bool(ARABIC_URDU_REGEX.search(text))


def normalize_script(input_str: str) -> str:
    if not input_str:
        return input_str

    text = TASHKEEL_REGEX.sub("", input_str)
    text = text.replace(TATWEEL, "")

    # Standardize Arabic-Indic digits to ASCII
    for ar, en in ARABIC_DIGITS_MAP.items():
        text = text.replace(ar, en)

    # Standardize Alef variants
    text = re.sub(r"[إأآٱ]", "ا", text)

    # Standardize Taa Marbuta
    text = text.replace("ة", "ه")

    # Standardize Ya / Alef Maksura
    text = text.replace("ى", "ي")
    text = text.replace("ئ", "ي")
    text = text.replace("ؤ", "و")

    # Standardize Persian/Urdu variants to unified phonemes
    text = text.replace("ٹ", "ت")
    text = text.replace("ڈ", "د")
    text = text.replace("ڑ", "ر")
    text = text.replace("ں", "ن")
    text = text.replace("ے", "ي")
    text = text.replace("ہ", "ه")
    text = text.replace("گ", "ك")
    text = text.replace("پ", "ب")
    text = text.replace("چ", "ج")

    return text.strip()


def _get_char_options(char: str, is_first: bool, is_last: bool) -> list[str]:
    match char:
        case "ا":
            return ["a", "e", "o"] if is_first else ["a", ""]
        case "ب":
            return ["b"]
        case "ت":
            return ["t", "tt"]
        case "ث":
            return ["th", "s"]
        case "ج":
            return ["j", "g"]
        case "ح":
            return ["h"]
        case "خ":
            return ["kh", "k"]
        case "د":
            return ["d"]
        case "ذ":
            return ["dh", "z"]
        case "ر":
            return ["rr", "r"]
        case "ز":
            return ["z"]
        case "س":
            return ["s", "ss"]
        case "ش":
            return ["sh"]
        case "ص":
            return ["s"]
        case "ض":
            return ["d"]
        case "ط":
            return ["t", "tt"]
        case "ظ":
            return ["z"]
        case "ع":
            return ["a", ""]
        case "غ":
            return ["g", "gh"]
        case "ف":
            return ["f", "ff", "v"]
        case "ق":
            return ["k", "q", "c"]
        case "ك":
            return ["k", "c"]
        case "ل":
            return ["l", "ll", "lum", "lam"]
        case "م":
            return ["m", "um"] if is_last else ["m"]
        case "ن":
            return ["n"]
        case "ه":
            return ["h"]
        case "و":
            return ["w", "v"] if is_first else ["o", "v", "w", "u", "oo"]
        case "ي":
            if is_first:
                return ["y", "i"]
            elif is_last:
                return ["y", "ee", "i", "e"]
            else:
                return ["e", "ee", "ai", "i", "ay"]
        case _:
            return [char]


def _generate_variants(char_options: list[list[str]], max_variants: int = 50) -> list[str]:
    current = [""]
    for options in char_options:
        next_list: list[str] = []
        for prefix in current:
            for opt in options:
                next_list.append(f"{prefix}{opt}")
        current = next_list[:max_variants]
    return current


def _cartesian_product(lists: list[list[str]]) -> list[list[str]]:
    result: list[list[str]] = [[]]
    for lst in lists:
        temp: list[list[str]] = []
        for r in result:
            for item in lst:
                temp.append(r + [item])
        result = temp[:60]
    return result


def _transliterate_word(word: str) -> list[str]:
    w = word

    # Handle common rally vocabulary words in Arabic/Urdu
    if w in ("رالي", "ريلي", "ريليا", "راليات"):
        return ["rally", "rallies"]

    # Handle definite article 'al-' / 'el-' at word start
    has_al = False
    if w.startswith("ال") and len(w) > 2:
        has_al = True
        w = w[2:]

    char_options = [
        _get_char_options(w[i], i == 0, i == len(w) - 1)
        for i in range(len(w))
    ]

    variants = _generate_variants(char_options, max_variants=50)

    results: list[str] = []
    seen: set[str] = set()
    for v in variants:
        clean = v.strip()
        if clean:
            if clean not in seen:
                seen.add(clean)
                results.append(clean)
            if has_al:
                with_al = f"al-{clean}"
                if with_al not in seen:
                    seen.add(with_al)
                    results.append(with_al)

    return results


def transliterate_to_latin(input_str: str) -> list[str]:
    """Transliterates Arabic/Urdu text to Latin phonetic approximations."""
    if not is_arabic_or_urdu(input_str):
        return [input_str.strip().lower()]

    normalized = normalize_script(input_str)
    words = [w for w in re.split(r"\s+", normalized) if w]
    if not words:
        return []

    word_candidates = [_transliterate_word(w)[:25] for w in words]
    return [" ".join(combo) for combo in _cartesian_product(word_candidates)]
