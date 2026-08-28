import pytest
from app.entity_search.phonetics import (
    AlgorithmicPronunciationEncoder,
    PhoneticDistance,
    soundex,
)


@pytest.mark.unit
def test_phonetic_distance_symmetric_and_zero_diagonal():
    assert PhoneticDistance.distance("ALUKSNE", "ALUKSNE") == 0.0
    assert PhoneticDistance.distance("ALUKSNE", "ELUKSNE") == PhoneticDistance.distance("ELUKSNE", "ALUKSNE")
    assert PhoneticDistance.similarity("ALUKSNE", "ALUKSNE") == 1.0


@pytest.mark.unit
def test_phonetic_distance_acoustic_classes():
    # Vowels near-homophones (E <-> I) cost 0.15 vs Vowel <-> Consonant cost 1.0
    vowel_shift = PhoneticDistance.distance("E", "I")
    assert vowel_shift == 0.15

    # Plosives (T <-> D) cost 0.15
    plosive_shift = PhoneticDistance.distance("T", "D")
    assert plosive_shift == 0.15

    # Fricatives (S <-> Z) cost 0.10
    fricative_shift = PhoneticDistance.distance("S", "Z")
    assert fricative_shift == 0.10


@pytest.mark.unit
def test_soundex():
    assert soundex("Robert") == "R163"
    assert soundex("Rupert") == "R163"
    assert soundex("Ashcraft") == "A226"
    assert soundex("Aluksne") == "A425"


@pytest.mark.unit
def test_algorithmic_pronunciation_encoder():
    encoder = AlgorithmicPronunciationEncoder()
    # European diacritics encoding
    native = encoder._encode_native_phonetic("Paweł Molgo")
    assert "W" in native or "M" in native
    collapsed = encoder.encode_collapsed_query("Alūksne")
    assert collapsed.startswith("AL")
