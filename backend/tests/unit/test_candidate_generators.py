import pytest
from app.domain.search_query import PersonRole
from app.entity_search.candidate_generator import (
    FullScanCandidateGenerator,
    InvertedIndexCandidateGenerator,
)
from app.entity_search.models import (
    CanonicalSearchEntity,
    EntitySearchRequest,
    SearchEntityType,
)


@pytest.fixture
def sample_entities() -> list[CanonicalSearchEntity]:
    return [
        CanonicalSearchEntity(
            canonical_id="rally-1",
            canonical_name="Rally Alūksne 2026",
            entity_type=SearchEntityType.RALLY,
            metadata={"year": 2026, "country": "Latvia"},
        ),
        CanonicalSearchEntity(
            canonical_id="person-1",
            canonical_name="Paweł Molgo",
            entity_type=SearchEntityType.PERSON,
            metadata={"driverId": "d-1", "codriverId": None, "role": "driver", "searchableNames": ["Paweł Molgo"]},
        ),
        CanonicalSearchEntity(
            canonical_id="person-2",
            canonical_name="Shea Breen",
            entity_type=SearchEntityType.PERSON,
            metadata={"driverId": None, "codriverId": "c-1", "role": "co_driver", "searchableNames": ["Shea Breen"]},
        ),
        CanonicalSearchEntity(
            canonical_id="stage-1",
            canonical_name="Kemmelberg 1",
            entity_type=SearchEntityType.STAGE,
            metadata={"stageNumber": "1", "eventId": "rally-1"},
        ),
    ]


@pytest.mark.unit
def test_full_scan_candidate_generator(sample_entities):
    generator = FullScanCandidateGenerator()
    generator.build(sample_entities)

    res_rally = generator.generate(
        EntitySearchRequest(raw_mention="aluksnay", entity_type=SearchEntityType.RALLY)
    )
    assert res_rally.canonical_ids == ["rally-1"]

    res_driver = generator.generate(
        EntitySearchRequest(
            raw_mention="molgo",
            entity_type=SearchEntityType.PERSON,
            person_role=PersonRole.DRIVER,
        )
    )
    assert res_driver.canonical_ids == ["person-1"]

    res_codriver = generator.generate(
        EntitySearchRequest(
            raw_mention="breen",
            entity_type=SearchEntityType.PERSON,
            person_role=PersonRole.CO_DRIVER,
        )
    )
    assert res_codriver.canonical_ids == ["person-2"]


@pytest.mark.unit
def test_inverted_index_candidate_generator_exact_and_ngram(sample_entities):
    generator = InvertedIndexCandidateGenerator(minimum_pool=1)
    generator.build(sample_entities)

    res_rally = generator.generate(
        EntitySearchRequest(raw_mention="Aluksne", entity_type=SearchEntityType.RALLY)
    )
    assert "rally-1" in res_rally.canonical_ids
    assert res_rally.used_full_scan_escape is False

    res_driver = generator.generate(
        EntitySearchRequest(raw_mention="Pawel", entity_type=SearchEntityType.PERSON)
    )
    assert "person-1" in res_driver.canonical_ids


@pytest.mark.unit
def test_inverted_index_candidate_generator_escape_on_low_evidence(sample_entities):
    # When evidence is low, generator falls back to the full eligible universe
    generator = InvertedIndexCandidateGenerator(minimum_pool=25)
    generator.build(sample_entities)

    res = generator.generate(
        EntitySearchRequest(raw_mention="unknown mention zzzzz", entity_type=SearchEntityType.RALLY)
    )
    assert res.used_full_scan_escape is True
    assert "rally-1" in res.canonical_ids
