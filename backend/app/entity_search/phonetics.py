import re
from .normalization import normalize

# Acoustic / Phonetic character classes
PLOSIVES = {"P", "B", "T", "D", "K", "G", "C", "Q"}
FRICATIVES = {"F", "V", "S", "Z", "X", "H", "J"}
NASALS = {"M", "N"}
LIQUIDS = {"L", "R", "W", "Y"}
VOWELS = {"A", "E", "I", "O", "U"}


class PhoneticDistance:
    """Articulatory phonetic feature distance calculator.
    Implements feature-weighted phoneme edit distance."""

    @classmethod
    def distance(cls, a: str, b: str) -> float:
        if a == b:
            return 0.0
        if not a:
            return float(len(b))
        if not b:
            return float(len(a))

        s1 = a.upper()
        s2 = b.upper()
        n = len(s1)
        m = len(s2)

        # DP matrix
        dp = [[0.0] * (m + 1) for _ in range(n + 1)]

        for i in range(n + 1):
            dp[i][0] = float(i)
        for j in range(m + 1):
            dp[0][j] = float(j)

        for i in range(1, n + 1):
            c1 = s1[i - 1]
            for j in range(1, m + 1):
                c2 = s2[j - 1]

                sub_cost = cls._substitution_cost(c1, c2)
                del_cost = cls._deletion_cost(c1)
                ins_cost = cls._insertion_cost(c2)

                dp[i][j] = min(
                    dp[i - 1][j] + del_cost,
                    dp[i][j - 1] + ins_cost,
                    dp[i - 1][j - 1] + sub_cost,
                )

        return dp[n][m]

    @classmethod
    def similarity(cls, a: str, b: str) -> float:
        if not a and not b:
            return 1.0
        if not a or not b:
            return 0.0
        if a == b:
            return 1.0

        dist = cls.distance(a, b)
        max_len = float(max(len(a), len(b)))
        if max_len == 0:
            return 1.0

        score = 1.0 - (dist / max_len)
        return max(0.0, min(1.0, score))

    @classmethod
    def _substitution_cost(cls, c1: str, c2: str) -> float:
        if c1 == c2:
            return 0.0

        # Both vowels: slight acoustic timbre shift
        if c1 in VOWELS and c2 in VOWELS:
            if (c1 == "E" and c2 == "I") or (c1 == "I" and c2 == "E"):
                return 0.15
            if (c1 == "A" and c2 == "O") or (c1 == "O" and c2 == "A"):
                return 0.20
            if (c1 == "A" and c2 == "E") or (c1 == "E" and c2 == "A"):
                return 0.20
            if (c1 == "U" and c2 == "O") or (c1 == "O" and c2 == "U"):
                return 0.20
            return 0.30

        # Both plosives (voicing or place shift, e.g. T <-> D, K <-> G, P <-> B)
        if c1 in PLOSIVES and c2 in PLOSIVES:
            if (c1 == "T" and c2 == "D") or (c1 == "D" and c2 == "T"):
                return 0.15
            if (c1 == "K" and c2 == "G") or (c1 == "G" and c2 == "K"):
                return 0.20
            if (c1 == "P" and c2 == "B") or (c1 == "B" and c2 == "P"):
                return 0.20
            if (c1 == "K" and c2 == "C") or (c1 == "C" and c2 == "K"):
                return 0.05
            return 0.40

        # Both fricatives/sibilants (e.g. S <-> Z, S <-> X, F <-> V)
        if c1 in FRICATIVES and c2 in FRICATIVES:
            if (c1 == "S" and c2 == "Z") or (c1 == "Z" and c2 == "S"):
                return 0.10
            if (c1 == "F" and c2 == "V") or (c1 == "V" and c2 == "F"):
                return 0.15
            if (c1 == "S" and c2 == "X") or (c1 == "X" and c2 == "S"):
                return 0.20
            if (c1 == "Z" and c2 == "J") or (c1 == "J" and c2 == "Z"):
                return 0.25
            return 0.35

        # Both nasals (M <-> N)
        if c1 in NASALS and c2 in NASALS:
            return 0.20

        # Both liquids / glides (L <-> R, W <-> Y)
        if c1 in LIQUIDS and c2 in LIQUIDS:
            if (c1 == "L" and c2 == "R") or (c1 == "R" and c2 == "L"):
                return 0.30
            if (c1 == "W" and c2 == "V") or (c1 == "V" and c2 == "W"):
                return 0.20
            return 0.40

        # Acoustic cross-class confusions (e.g. X <-> K S, C <-> S)
        if (c1 == "C" and c2 == "S") or (c1 == "S" and c2 == "C"):
            return 0.15
        if (c1 == "X" and c2 == "K") or (c1 == "K" and c2 == "X"):
            return 0.25

        # Vowel vs Consonant: high acoustic distance
        if (c1 in VOWELS and c2 not in VOWELS) or (c1 not in VOWELS and c2 in VOWELS):
            return 1.0

        return 0.70

    @classmethod
    def _deletion_cost(cls, c: str) -> float:
        if c in VOWELS:
            return 0.6  # unstressed vowels frequently dropped
        if c in ("H", "W", "Y"):
            return 0.5  # weak glides
        return 0.85

    @classmethod
    def _insertion_cost(cls, c: str) -> float:
        if c in VOWELS:
            return 0.6
        if c in ("H", "W", "Y"):
            return 0.5
        return 0.85


class AlgorithmicPronunciationEncoder:
    """Algorithmic multilingual pronunciation encoder and scorer."""

    def encode_query(self, text: str) -> str:
        return self._encode_international_phonetic(text)

    def encode_collapsed_query(self, text: str) -> str:
        return self._encode_collapsed_phonetic(text)

    def _encode_native_phonetic(self, text: str) -> str:
        s = text.lower().strip()
        replacements = [
            ("ł", "w"), ("ū", "u"), ("ø", "o"), ("å", "o"), ("ä", "e"),
            ("ö", "o"), ("ü", "u"), ("é", "e"), ("è", "e"), ("ê", "e"),
            ("ë", "e"), ("á", "a"), ("à", "a"), ("ã", "an"), ("â", "a"),
            ("í", "i"), ("ó", "o"), ("õ", "o"), ("ú", "u"), ("ç", "s"),
            ("č", "ch"), ("š", "sh"), ("ž", "zh"), ("ć", "ch"), ("ź", "z"),
            ("ż", "z"), ("ß", "ss"),
        ]
        for src, dst in replacements:
            s = s.replace(src, dst)

        # Strip non-letters
        s = re.sub(r"[^a-z0-9\s]", " ", s)
        tokens = [t for t in re.split(r"\s+", s) if t]
        return " ".join(self._phonetic_token(t) for t in tokens)

    def _encode_international_phonetic(self, text: str) -> str:
        s = normalize(text.lower().strip())
        tokens = [t for t in re.split(r"\s+", s) if t]
        return " ".join(self._phonetic_token(t) for t in tokens)

    def _encode_collapsed_phonetic(self, text: str) -> str:
        s = normalize(text.lower().strip())
        tokens = [t for t in re.split(r"\s+", s) if t]
        return "".join(self._phonetic_token(t) for t in tokens)

    def _phonetic_token(self, token: str) -> str:
        if not token:
            return ""

        t = token.lower()
        replacements = [
            ("ph", "f"), ("gh", "g"), ("ck", "k"), ("qu", "kw"),
            ("x", "ks"), ("c", "k"), ("z", "s"), ("v", "f"),
            ("oo", "u"), ("ee", "i"), ("ea", "i"), ("ay", "e"),
            ("ey", "e"), ("ai", "e"), ("ei", "e"), ("ou", "u"),
            ("ow", "o"), ("aw", "o"),
        ]
        for src, dst in replacements:
            t = t.replace(src, dst)

        # Deduplicate consecutive identical characters
        chars: list[str] = []
        prev: str | None = None
        for c in t:
            if c != prev:
                chars.append(c)
            prev = c

        return "".join(chars).upper()


def soundex(s: str) -> str:
    """Simple Soundex encoder for weak tiebreaking."""
    clean = re.sub(r"[^a-z]", "", normalize(s))
    if not clean:
        return ""

    first = clean[0].upper()
    code_map = {
        "b": "1", "f": "1", "p": "1", "v": "1",
        "c": "2", "g": "2", "j": "2", "k": "2", "q": "2", "s": "2", "x": "2", "z": "2",
        "d": "3", "t": "3",
        "l": "4",
        "m": "5", "n": "5",
        "r": "6",
    }

    out = [first]
    last_code = code_map.get(clean[0], "0")

    for i in range(1, len(clean)):
        if len(out) >= 4:
            break
        code = code_map.get(clean[i], "0")
        if code != "0" and code != last_code:
            out.append(code)
        last_code = code

    while len(out) < 4:
        out.append("0")

    return "".join(out)
