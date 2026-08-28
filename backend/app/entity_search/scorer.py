from __future__ import annotations

import math
from typing import Any
from .models import EntitySearchSignals
from .normalization import (
    acoustic_fold,
    collapse_spaces,
    extract_year,
    has_motorsport_descriptor,
    normalize,
    strip_descriptors,
    strip_year,
)
from .phonetics import AlgorithmicPronunciationEncoder, soundex
from .transliteration import is_arabic_or_urdu, transliterate_to_latin

_encoder = AlgorithmicPronunciationEncoder()


def dice_bigram(s1: str, s2: str) -> float:
    n1 = normalize(s1)
    n2 = normalize(s2)

    if n1 == n2:
        return 1.0
    if len(n1) < 2 or len(n2) < 2:
        return 1.0 if n1 == n2 else 0.0

    bigrams1: dict[str, int] = {}
    for i in range(len(n1) - 1):
        bg = n1[i:i + 2]
        bigrams1[bg] = bigrams1.get(bg, 0) + 1

    bigrams2: dict[str, int] = {}
    for i in range(len(n2) - 1):
        bg = n2[i:i + 2]
        bigrams2[bg] = bigrams2.get(bg, 0) + 1

    matches = 0
    for bg, count1 in bigrams1.items():
        count2 = bigrams2.get(bg, 0)
        matches += min(count1, count2)

    total = (len(n1) - 1) + (len(n2) - 1)
    return (2.0 * matches) / total


def dice_trigram(s1: str, s2: str) -> float:
    n1 = normalize(s1)
    n2 = normalize(s2)

    if n1 == n2:
        return 1.0
    if len(n1) < 3 or len(n2) < 3:
        return dice_bigram(s1, s2)

    trigrams1: dict[str, int] = {}
    for i in range(len(n1) - 2):
        tg = n1[i:i + 3]
        trigrams1[tg] = trigrams1.get(tg, 0) + 1

    trigrams2: dict[str, int] = {}
    for i in range(len(n2) - 2):
        tg = n2[i:i + 3]
        trigrams2[tg] = trigrams2.get(tg, 0) + 1

    matches = 0
    for tg, count1 in trigrams1.items():
        count2 = trigrams2.get(tg, 0)
        matches += min(count1, count2)

    total = (len(n1) - 2) + (len(n2) - 2)
    return (2.0 * matches) / total


def _jaro(s1: str, s2: str) -> float:
    len1 = len(s1)
    len2 = len(s2)
    match_distance = (max(len1, len2) // 2) - 1

    s1_matches = [False] * len1
    s2_matches = [False] * len2

    matches = 0
    for i in range(len1):
        start = max(0, i - match_distance)
        end = min(i + match_distance + 1, len2)

        for j in range(start, end):
            if s2_matches[j]:
                continue
            if s1[i] != s2[j]:
                continue
            s1_matches[i] = True
            s2_matches[j] = True
            matches += 1
            break

    if matches == 0:
        return 0.0

    transpositions = 0
    k = 0
    for i in range(len1):
        if not s1_matches[i]:
            continue
        while not s2_matches[k]:
            k += 1
        if s1[i] != s2[k]:
            transpositions += 1
        k += 1

    m = float(matches)
    return (m / len1 + m / len2 + (m - (transpositions / 2.0)) / m) / 3.0


def jaro_winkler(s1: str, s2: str) -> float:
    n1 = normalize(s1)
    n2 = normalize(s2)

    if not n1 and not n2:
        return 1.0
    if not n1 or not n2:
        return 0.0
    if n1 == n2:
        return 1.0

    jaro_sim = _jaro(n1, n2)
    if jaro_sim < 0.70:
        return jaro_sim

    prefix_len = 0
    max_prefix = min(4, min(len(n1), len(n2)))
    for i in range(max_prefix):
        if n1[i] == n2[i]:
            prefix_len += 1
        else:
            break

    return jaro_sim + (prefix_len * 0.1 * (1.0 - jaro_sim))


def levenshtein_distance(s1: str, s2: str) -> int:
    m = len(s1)
    n = len(s2)

    prev = list(range(n + 1))
    curr = [0] * (n + 1)

    for i in range(m):
        curr[0] = i + 1
        for j in range(n):
            cost = 0 if s1[i] == s2[j] else 1
            curr[j + 1] = min(
                curr[j] + 1,
                prev[j + 1] + 1,
                prev[j] + cost,
            )
        prev = list(curr)

    return prev[n]


def normalized_levenshtein(s1: str, s2: str) -> float:
    n1 = normalize(s1)
    n2 = normalize(s2)

    if n1 == n2:
        return 1.0
    if not n1 or not n2:
        return 0.0

    max_len = max(len(n1), len(n2))
    dist = levenshtein_distance(n1, n2)
    return max(0.0, min(1.0, 1.0 - (dist / max_len)))


def token_set_similarity(s1: str, s2: str) -> float:
    n1 = normalize(s1)
    n2 = normalize(s2)

    set1 = {w for w in n1.split() if w}
    set2 = {w for w in n2.split() if w}

    if not set1 or not set2:
        return 0.0
    intersection = set1 & set2
    union = set1 | set2

    return len(intersection) / len(union)


def _set_dice(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return 2.0 * len(a & b) / (len(a) + len(b))


def token_score(a: set[str], b: set[str], an: str, bn: str) -> float:
    if not a or not b:
        return 0.0
    intersection = len(a & b)
    set_score = (2.0 * intersection) / (len(a) + len(b))

    prefix_hits = sum(
        1 for x in a
        if any(len(x) >= 3 and len(y) >= 3 and (x.startswith(y) or y.startswith(x)) for y in b)
    )
    prefix_score = prefix_hits / max(len(a), len(b))
    ordered_insensitive = 1.0 if (len(a) == len(b) and a == b) else 0.0
    phrase_prefix = (min(len(an), len(bn)) / max(len(an), len(bn))) if (an.startswith(bn) or bn.startswith(an)) else 0.0

    return max(
        max(set_score, prefix_score),
        max(ordered_insensitive, phrase_prefix),
    )


def score_name(
    raw: str,
    normalized: str,
    collapsed: str,
    tokens: set[str],
    bigrams: set[str],
    trigrams: set[str],
    phonetic: str,
    name_str: str,
    name_normalized: str,
    name_collapsed: str,
    name_tokens: set[str],
    name_bigrams: set[str],
    name_trigrams: set[str],
    name_phonetic: str,
    context: float,
) -> tuple[float, float, EntitySearchSignals]:
    exact = 1.0 if raw.lower() == name_str.lower() else 0.0
    normalized_exact = 1.0 if normalized == name_normalized else 0.0
    tok = token_score(tokens, name_tokens, normalized, name_normalized)
    ngram = 0.4 * _set_dice(bigrams, name_bigrams) + 0.6 * _set_dice(trigrams, name_trigrams)
    lexical = max(
        jaro_winkler(collapsed, name_collapsed),
        dice_trigram(collapsed, name_collapsed),
    )
    phonetic_score = max(
        jaro_winkler(phonetic, name_phonetic),
        dice_bigram(phonetic, name_phonetic),
    )
    signals = EntitySearchSignals(
        exact_score=exact,
        normalized_exact_score=normalized_exact,
        token_score=tok,
        ngram_score=ngram,
        lexical_score=lexical,
        phonetic_score=phonetic_score,
        context_score=context,
    )
    strongest_list = sorted([
        exact,
        normalized_exact,
        tok,
        ngram,
        lexical,
        phonetic_score,
    ])
    score = (
        0.62 * strongest_list[-1]
        + 0.23 * strongest_list[-2]
        + 0.10 * tok
        + 0.05 * context
    )
    score = max(0.0, min(1.0, score))
    return score, strongest_list[-1], signals


def _apply_context_boosts(
    base_score: float,
    *,
    query_year: int | None = None,
    candidate_year: int | None = None,
    in_context: bool = False,
) -> float:
    score = base_score

    # Contextual year alignment boost / penalty
    if query_year is not None and candidate_year is not None:
        if query_year == candidate_year:
            score += 0.20
        else:
            # Year mismatch hard penalty
            score = min(score * 0.40, 0.35)

    # Contextual event participation boost (+0.15)
    if in_context:
        score += 0.15

    return round(max(0.0, min(1.0, score)), 3)


def compute_composite_score(
    *,
    query_phrase: str,
    candidate_name: str,
    query_year: int | None = None,
    candidate_year: int | None = None,
    in_context: bool = False,
    is_person: bool = False,
) -> float:
    """Computes composite deterministic similarity score between query phrase and canonical candidate.
    Exact reproduction of Dart PhoneticMatchingHelper.computeCompositeScore."""
    p_norm = normalize(query_phrase)
    c_norm = normalize(candidate_name)

    if not p_norm or not c_norm:
        return 0.0

    q_year = query_year if query_year is not None else extract_year(query_phrase)
    c_year = candidate_year if candidate_year is not None else extract_year(candidate_name)

    # Hard Constraint on Explicit Year Mismatch:
    if q_year is not None and c_year is not None and q_year != c_year:
        return 0.25

    # 1. Exact string match
    if p_norm == c_norm:
        return _apply_context_boosts(1.0, query_year=q_year, candidate_year=c_year, in_context=in_context)

    # 2. Base name exact match (ignoring years)
    p_base = strip_year(p_norm)
    c_base = strip_year(c_norm)
    if p_base == c_base and p_base:
        return _apply_context_boosts(0.96, query_year=q_year, candidate_year=c_year, in_context=in_context)

    # 3. Collapsed-space exact match
    p_collapsed = collapse_spaces(p_norm)
    c_collapsed = collapse_spaces(c_norm)
    if p_collapsed == c_collapsed and p_collapsed:
        return _apply_context_boosts(0.95, query_year=q_year, candidate_year=c_year, in_context=in_context)

    # 4. Core descriptor stripped match
    p_core = collapse_spaces(strip_descriptors(p_norm))
    c_core = collapse_spaces(strip_descriptors(c_norm))
    if p_core == c_core and p_core:
        return _apply_context_boosts(0.94, query_year=q_year, candidate_year=c_year, in_context=in_context)

    # 4b. Conservative acoustic folded exact match
    p_acoustic = acoustic_fold(p_collapsed)
    c_acoustic = acoustic_fold(c_collapsed)
    p_ac_core = acoustic_fold(p_core)
    c_ac_core = acoustic_fold(c_core)
    if (p_ac_core == c_ac_core and p_ac_core) or (p_acoustic == c_acoustic and p_acoustic):
        return _apply_context_boosts(0.93, query_year=q_year, candidate_year=c_year, in_context=in_context)

    # 5. Cross-script transliteration match
    transliteration_score = 0.0
    if is_arabic_or_urdu(query_phrase):
        latin_variants = transliterate_to_latin(query_phrase)
        for variant in latin_variants:
            v_norm = normalize(variant)
            v_base_norm = strip_year(v_norm)
            v_core = collapse_spaces(strip_descriptors(v_norm))
            v_collapsed = collapse_spaces(variant)

            if v_norm == c_norm or v_base_norm == c_base or (v_core == c_core and v_core):
                transliteration_score = max(transliteration_score, 0.94)
            elif v_collapsed == c_collapsed or (len(v_collapsed) >= 6 and v_collapsed in c_collapsed):
                transliteration_score = max(transliteration_score, 0.93)
            else:
                jw = jaro_winkler(v_norm, c_norm)
                lev = normalized_levenshtein(v_norm, c_norm)
                dice = dice_bigram(v_norm, c_norm)
                jw_base = jaro_winkler(v_base_norm, c_base)
                jw_core = jaro_winkler(v_core, c_core) if (v_core and c_core) else 0.0
                jw_collapsed = jaro_winkler(v_collapsed, c_collapsed)

                sim = max(
                    max((jw * 0.40) + (lev * 0.30) + (dice * 0.30), jw_base * 0.90),
                    max(jw_core * 0.90, jw_collapsed * 0.85),
                )
                transliteration_score = max(transliteration_score, sim)

    p_tokens = [w for w in p_norm.split() if w]
    c_tokens = [w for w in c_norm.split() if w]
    has_motorsport_words = has_motorsport_descriptor(query_phrase) or has_motorsport_descriptor(candidate_name)

    lexical_score = 0.0

    # 6. Token-window sub-sequence alignment & space-collapsed cross-token alignment
    token_window_score = 0.0
    if p_tokens and c_tokens:
        p_tokens_core = [t for t in p_tokens if not has_motorsport_descriptor(t)]
        c_tokens_core = [t for t in c_tokens if not has_motorsport_descriptor(t)]
        query_tokens = p_tokens_core if p_tokens_core else p_tokens
        cand_tokens = c_tokens_core if c_tokens_core else c_tokens

        if len(query_tokens) == 1:
            q = query_tokens[0]
            for ct in cand_tokens:
                if len(ct) >= 3 and len(q) >= 3:
                    jw = jaro_winkler(q, ct)
                    lev = normalized_levenshtein(q, ct)
                    dice = dice_bigram(q, ct)
                    sim = (0.55 * jw) + (0.30 * lev) + (0.15 * dice)
                    token_window_score = max(token_window_score, sim)
        elif len(query_tokens) <= len(cand_tokens):
            window_size = len(query_tokens)
            for i in range(len(cand_tokens) - window_size + 1):
                window = " ".join(cand_tokens[i:i + window_size])
                q_str = " ".join(query_tokens)
                jw = jaro_winkler(q_str, window)
                lev = normalized_levenshtein(q_str, window)
                dice = dice_bigram(q_str, window)
                sim = (0.55 * jw) + (0.30 * lev) + (0.15 * dice)
                token_window_score = max(token_window_score, sim)

        # Space-collapsed query vs single candidate tokens
        if len(query_tokens) >= 2:
            q_collapsed = collapse_spaces(" ".join(query_tokens))
            q_acoustic = acoustic_fold(q_collapsed)
            for ct in cand_tokens:
                if len(ct) >= 4:
                    ct_acoustic = acoustic_fold(ct)
                    jw_ac = jaro_winkler(q_acoustic, ct_acoustic)
                    lev_ac = normalized_levenshtein(q_acoustic, ct_acoustic)
                    dice_ac = dice_bigram(q_acoustic, ct_acoustic)
                    ac_sim = (0.50 * jw_ac) + (0.30 * lev_ac) + (0.20 * dice_ac)
                    token_window_score = max(token_window_score, ac_sim * 0.95)

    # 7. Multi-token person name alignment scoring
    gen_suffixes = {"jnr", "snr", "jr", "sr", "ii", "iii", "iv"}
    clean_p_tokens = [t for t in p_tokens if t not in gen_suffixes]
    clean_c_tokens = [t for t in c_tokens if t not in gen_suffixes]

    if is_person and not has_motorsport_words and len(clean_p_tokens) >= 2 and len(clean_c_tokens) >= 2:
        first_jw = jaro_winkler(clean_p_tokens[0], clean_c_tokens[0])
        first_lev = normalized_levenshtein(clean_p_tokens[0], clean_c_tokens[0])
        first_dice = dice_bigram(clean_p_tokens[0], clean_c_tokens[0])
        first_combined = (0.50 * first_jw) + (0.30 * first_lev) + (0.20 * first_dice)

        p_sur = clean_p_tokens[-1]
        c_sur = clean_c_tokens[-1]

        if c_sur == p_sur:
            sur_combined = 1.0
        elif p_sur in c_sur or c_sur in p_sur:
            sur_combined = 0.95
        else:
            sur_jw = jaro_winkler(p_sur, c_sur)
            sur_lev = normalized_levenshtein(p_sur, c_sur)
            sur_dice = dice_bigram(p_sur, c_sur)
            sur_ac_jw = jaro_winkler(acoustic_fold(p_sur), acoustic_fold(c_sur))
            sur_ac_lev = normalized_levenshtein(acoustic_fold(p_sur), acoustic_fold(c_sur))
            standard_sur = (0.50 * sur_jw) + (0.30 * sur_lev) + (0.20 * sur_dice)
            acoustic_sur = (0.50 * sur_ac_jw) + (0.50 * sur_ac_lev)
            sur_combined = max(standard_sur, acoustic_sur * 0.95)

        if sur_combined < 0.78:
            lexical_score = min(0.55, first_combined * sur_combined)
        elif first_combined < 0.75:
            lexical_score = min(0.60, (0.60 * sur_combined) + (0.40 * first_combined))
        else:
            lexical_score = (0.65 * sur_combined) + (0.35 * first_combined)

    elif is_person and not has_motorsport_words and len(clean_p_tokens) == 1 and len(clean_c_tokens) >= 2:
        q_token = clean_p_tokens[0]
        sur_token = clean_c_tokens[-1]
        sur_jw = jaro_winkler(q_token, sur_token)
        sur_lev = normalized_levenshtein(q_token, sur_token)
        sur_dice = dice_bigram(q_token, sur_token)
        sur_combined = (0.50 * sur_jw) + (0.30 * sur_lev) + (0.20 * sur_dice)
        if sur_combined >= 0.80 or sur_token == q_token:
            lexical_score = max(lexical_score, sur_combined * 0.90)

    else:
        # 8. General Lexical & Phonetic composite calculation for rallies, stages, locations
        jw = jaro_winkler(p_norm, c_norm)
        lev = normalized_levenshtein(p_norm, c_norm)
        dice = dice_bigram(p_norm, c_norm)
        tri_dice = dice_trigram(p_norm, c_norm)
        token_sim = token_set_similarity(p_norm, c_norm)

        jw_base = jaro_winkler(p_base, c_base)
        lev_base = normalized_levenshtein(p_base, c_base)
        dice_base = dice_bigram(p_base, c_base)

        jw_core = jaro_winkler(p_core, c_core) if (p_core and c_core) else 0.0
        lev_core = normalized_levenshtein(p_core, c_core) if (p_core and c_core) else 0.0
        dice_core = dice_bigram(p_core, c_core) if (p_core and c_core) else 0.0

        jw_collapsed = jaro_winkler(p_collapsed, c_collapsed)
        dice_collapsed = dice_bigram(p_collapsed, c_collapsed)

        jw_acoustic = jaro_winkler(p_acoustic, c_acoustic)
        lev_acoustic = normalized_levenshtein(p_acoustic, c_acoustic)
        dice_acoustic = dice_bigram(p_acoustic, c_acoustic)
        acoustic_score = (0.50 * jw_acoustic) + (0.30 * lev_acoustic) + (0.20 * dice_acoustic)

        jw_ac_core = jaro_winkler(p_ac_core, c_ac_core) if (p_ac_core and c_ac_core) else 0.0
        lev_ac_core = normalized_levenshtein(p_ac_core, c_ac_core) if (p_ac_core and c_ac_core) else 0.0
        dice_ac_core = dice_bigram(p_ac_core, c_ac_core) if (p_ac_core and c_ac_core) else 0.0
        ac_core_score = (0.50 * jw_ac_core) + (0.30 * lev_ac_core) + (0.20 * dice_ac_core)

        soundex_bonus = 0.03 if (soundex(p_norm) == soundex(c_norm) and soundex(p_norm)) else 0.0

        containment_bonus = 0.0
        if len(p_tokens) == 1 or len(c_tokens) == 1:
            if c_norm.startswith(p_norm) or p_norm.startswith(c_norm) or c_base.startswith(p_base) or p_base.startswith(c_base):
                containment_bonus = 0.12
            elif p_norm in c_norm or p_base in c_base:
                containment_bonus = 0.08 * (len(p_norm) / max(1, min(100, len(c_norm))))

        full_score = (0.35 * jw) + (0.25 * lev) + (0.20 * dice) + (0.10 * tri_dice) + (0.10 * token_sim) + soundex_bonus + containment_bonus
        base_score_val = (0.45 * jw_base) + (0.30 * lev_base) + (0.25 * dice_base)
        core_score = (0.45 * jw_core) + (0.30 * lev_core) + (0.25 * dice_core)
        collapsed_score = (0.60 * jw_collapsed) + (0.40 * dice_collapsed)

        lexical_score = max(
            full_score,
            max(
                base_score_val,
                max(
                    core_score,
                    max(
                        collapsed_score * 0.90,
                        max(token_window_score * 0.98, max(acoustic_score * 0.92, ac_core_score * 0.94)),
                    ),
                ),
            ),
        )

    if transliteration_score > lexical_score:
        lexical_score = transliteration_score

    lexical_score = max(0.0, min(1.0, lexical_score))

    if lexical_score >= 0.45:
        return _apply_context_boosts(lexical_score, query_year=q_year, candidate_year=c_year, in_context=in_context)

    return round(lexical_score, 3)
