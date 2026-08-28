import pytest
from app.entity_search.scorer import (
    compute_composite_score,
    dice_bigram,
    dice_trigram,
    jaro_winkler,
    normalized_levenshtein,
    token_score,
    token_set_similarity,
)


@pytest.mark.unit
def test_dice_bigram_and_trigram():
    assert dice_bigram("aluksne", "aluksne") == 1.0
    assert dice_bigram("aluksne", "eluksne") > 0.6
    assert dice_bigram("abc", "xyz") == 0.0

    assert dice_trigram("aluksne", "aluksne") == 1.0
    assert dice_trigram("aluksne", "aluknse") >= 0.4
    assert dice_trigram("ab", "ab") == 1.0  # falls back to bigram


@pytest.mark.unit
def test_jaro_winkler():
    assert jaro_winkler("aluksne", "aluksne") == 1.0
    assert jaro_winkler("", "") == 1.0
    assert jaro_winkler("aluksne", "") == 0.0
    # Jaro-Winkler prefix bonus
    jw1 = jaro_winkler("martha", "marhta")
    assert jw1 > 0.90
    jw2 = jaro_winkler("dwayne", "duane")
    assert jw2 > 0.80


@pytest.mark.unit
def test_normalized_levenshtein():
    assert normalized_levenshtein("aluksne", "aluksne") == 1.0
    assert normalized_levenshtein("aluksne", "aluksney") == 1.0 - (1.0 / 8.0)
    assert normalized_levenshtein("", "abc") == 0.0


@pytest.mark.unit
def test_token_set_similarity():
    assert token_set_similarity("West Cork Rally", "Rally West Cork") == 1.0
    assert token_set_similarity("West Cork", "East Cork") == 1.0 / 3.0


@pytest.mark.unit
def test_token_score_order_insensitive():
    tokens_a = {"west", "cork"}
    tokens_b = {"cork", "west"}
    score = token_score(tokens_a, tokens_b, "west cork", "cork west")
    assert score == 1.0


@pytest.mark.unit
def test_composite_score_exact_and_collapsed():
    # Exact
    assert compute_composite_score(query_phrase="Rally Alūksne", candidate_name="Rally Alūksne") == 1.0
    # Base match ignoring years
    assert compute_composite_score(query_phrase="Rally Alūksne", candidate_name="Rally Alūksne 2026") == 0.96
    # Space collapsed
    assert compute_composite_score(query_phrase="Westcork Rally", candidate_name="West Cork Rally") == 0.95
    # Descriptor stripped
    assert compute_composite_score(query_phrase="West Cork Stages", candidate_name="West Cork Rally") == 0.94
    # Acoustic fold
    assert compute_composite_score(query_phrase="Kemelberg", candidate_name="Kemmelberg") == 0.93


@pytest.mark.unit
def test_composite_score_year_mismatch_hard_penalty():
    # Year mismatch drops score to 0.25
    score = compute_composite_score(
        query_phrase="Rally Aluksne",
        candidate_name="Rally Aluksne 2026",
        query_year=1999,
        candidate_year=2026,
    )
    assert score == 0.25


@pytest.mark.unit
def test_composite_score_person_safety():
    # Surnames matching vs first name mismatch
    sam_josh = compute_composite_score(
        query_phrase="Sam Moffett",
        candidate_name="Josh Moffett",
        is_person=True,
    )
    # Differing first name should be capped to prevent confident auto-resolution
    assert sam_josh < 0.75

    # Completely different surname
    diff_sur = compute_composite_score(
        query_phrase="Josh Smith",
        candidate_name="Josh Moffett",
        is_person=True,
    )
    assert diff_sur < 0.60
