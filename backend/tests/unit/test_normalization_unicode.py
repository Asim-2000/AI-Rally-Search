import unicodedata
import pytest
from app.entity_search.normalization import (
    acoustic_fold,
    collapse_spaces,
    generate_ngram_anchors,
    has_motorsport_descriptor,
    normalize,
    strip_descriptors,
    strip_year,
)
from app.entity_search.transliteration import is_arabic_or_urdu, normalize_script, transliterate_to_latin


@pytest.mark.unit
def test_unicode_european_diacritics_mapping():
    # Baltic, Slavic, Nordic, Hungarian, Romance, etc.
    raw = "Rally Alūksne 2026 - Paweł Molgo & Věroslav Cvrček, Hervé Emeriau, José Paula, Šťastný, Łódź"
    expected = "rally aluksne 2026 pawel molgo veroslav cvrcek herve emeriau jose paula stastny lodz"
    assert normalize(raw) == expected


@pytest.mark.unit
def test_unicode_nfc_nfd_equivalence():
    # NFD decomposes characters into base + combining mark
    nfc = "Rally Alūksne"
    nfd = unicodedata.normalize("NFD", nfc)
    assert nfc != nfd
    assert normalize(nfc) == normalize(nfd)
    assert normalize(nfd) == "rally aluksne"


@pytest.mark.unit
def test_apostrophes_and_dashes_standardization():
    raw = "Stephen O'Connor – Fastnet—Stages ‘2025’"
    expected = "stephen o connor fastnet stages 2025"
    assert normalize(raw) == expected


@pytest.mark.unit
def test_digits_and_letters_separation():
    assert normalize("2powerstage") == "2 powerstage"
    assert normalize("ss2") == "ss 2"
    assert normalize("stage12a") == "stage 12 a"


@pytest.mark.unit
def test_collapse_spaces():
    assert collapse_spaces("West Cork Rally") == "westcorkrally"
    assert collapse_spaces("  Rally   Alūksne 2026 ") == "rallyaluksne2026"


@pytest.mark.unit
def test_acoustic_fold():
    assert acoustic_fold("Aluxne") == "aluksne"
    assert acoustic_fold("Kemmelberg") == "kemelberg"
    assert acoustic_fold("Stephen") == "stefen"
    assert acoustic_fold("Blackrock") == "blakrok"


@pytest.mark.unit
def test_strip_year_and_descriptors():
    raw = "Clonakilty Park Hotel West Cork Rally 2026"
    assert strip_year(raw) == "clonakilty park hotel west cork rally"
    assert strip_descriptors(raw) == "clonakilty park hotel west cork"
    assert has_motorsport_descriptor(raw) is True
    assert has_motorsport_descriptor("Craig Breen") is False


@pytest.mark.unit
def test_generate_ngram_anchors():
    anchors = generate_ngram_anchors("Aluksne", n=3, max_anchors=6)
    assert len(anchors) <= 6
    assert anchors[0] == "alu"
    assert anchors[-1] == "sne"


@pytest.mark.unit
def test_arabic_urdu_transliteration():
    arabic = "رالي دبي"
    assert is_arabic_or_urdu(arabic) is True
    norm_script = normalize_script(arabic)
    assert "رالي" in norm_script
    latin = transliterate_to_latin(arabic)
    assert any("rally" in v for v in latin)
