import pytest
from app.domain.search_intent import SearchIntent
from app.domain.search_query import PersonRole, SearchQuery
from app.entity_search.eligibility import is_person_role_eligible
from app.entity_search.models import EntityCandidate, EntityType
from app.entity_search.resolver import DatabaseEntityResolver


class _MockDuplicatePersonRepo:
    async def lookup_drivers(self, phrase, **kwargs):
        return [
            EntityCandidate(
                id="account-1",
                type=EntityType.DRIVER,
                canonical_name="Zubair Fawad",
                metadata={"accountId": "account-1", "driverId": "driver-1", "role": "driver"},
            ),
            EntityCandidate(
                id="account-2",
                type=EntityType.DRIVER,
                canonical_name="Zubair Fawad",
                metadata={"accountId": "account-2", "driverId": "driver-2", "role": "driver"},
            ),
        ]

    async def lookup_rallies(self, phrase, **kwargs):
        return []

    async def lookup_stages(self, phrase, **kwargs):
        return []

    async def lookup_cities(self, phrase, **kwargs):
        return []

    async def lookup_uploaders(self, phrase, **kwargs):
        return []


class _MockScoreGapRepo:
    def __init__(self, cands: list[EntityCandidate]):
        self.cands = cands

    async def lookup_rallies(self, phrase, **kwargs):
        return self.cands

    async def lookup_drivers(self, phrase, **kwargs):
        return self.cands

    async def lookup_stages(self, phrase, **kwargs):
        return self.cands

    async def lookup_cities(self, phrase, **kwargs):
        return self.cands

    async def lookup_uploaders(self, phrase, **kwargs):
        return self.cands


@pytest.mark.unit
def test_person_role_eligibility_matrix():
    driver_only = {"accountId": "a-1", "driverId": "d-1", "codriverId": None, "role": "driver"}
    codriver_only = {"accountId": "a-2", "driverId": None, "codriverId": "c-1", "role": "co_driver"}
    both = {"accountId": "a-3", "driverId": "d-2", "codriverId": "c-2", "role": "both"}

    assert is_person_role_eligible(driver_only, PersonRole.DRIVER) is True
    assert is_person_role_eligible(driver_only, PersonRole.CO_DRIVER) is False
    assert is_person_role_eligible(driver_only, PersonRole.ANY) is True

    assert is_person_role_eligible(codriver_only, PersonRole.DRIVER) is False
    assert is_person_role_eligible(codriver_only, PersonRole.CO_DRIVER) is True
    assert is_person_role_eligible(codriver_only, PersonRole.ANY) is True

    assert is_person_role_eligible(both, PersonRole.DRIVER) is True
    assert is_person_role_eligible(both, PersonRole.CO_DRIVER) is True
    assert is_person_role_eligible(both, PersonRole.ANY) is True


@pytest.mark.unit
async def test_duplicate_person_identity_clarification():
    resolver = DatabaseEntityResolver(repository=_MockDuplicatePersonRepo())
    query = SearchQuery(
        intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
        driver_names=["Zubair Fawad"],
        person_role=PersonRole.ANY,
    )
    result = await resolver.resolve(query)
    assert result.requires_clarification is True
    assert result.resolutions["driver"].strategy == "duplicate_person_identity"
    candidate_account_ids = {c.metadata.get("accountId") for c in result.candidates}
    assert candidate_account_ids == {"account-1", "account-2"}


@pytest.mark.unit
async def test_score_gap_and_confidence_boundary_thresholds():
    # Boundary: top candidate below 0.75 min confidence threshold but >= 0.50 -> plausible_candidates (clarification)
    cand_low = [
        EntityCandidate(id="1", type=EntityType.RALLY, canonical_name="6 Uren van Kortrijk 2024", score=0.72),
    ]
    resolver = DatabaseEntityResolver(repository=_MockScoreGapRepo(cand_low), min_confidence_threshold=0.75)
    res = await resolver.resolve(SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rally_names=["kort"]))
    # Plausible (0.72) but below 0.75 threshold triggers clarification
    assert res.requires_clarification is True
    assert res.resolutions["rally"].strategy == "plausible_candidates"

    # Boundary: gap < 0.15 with runner-up triggers insufficient_gap (clarification)
    cand_close = [
        EntityCandidate(id="1", type=EntityType.RALLY, canonical_name="Rally Alpha 2026", score=0.85),
        EntityCandidate(id="2", type=EntityType.RALLY, canonical_name="Rally Alpine 2026", score=0.80),
    ]
    resolver = DatabaseEntityResolver(repository=_MockScoreGapRepo(cand_close), min_confidence_threshold=0.75, min_score_gap=0.15)
    res = await resolver.resolve(SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Alp"]))
    assert res.requires_clarification is True
    assert res.resolutions["rally"].strategy == "insufficient_gap"

    # Boundary: gap >= 0.15 with runner-up resolves clearly
    cand_clear = [
        EntityCandidate(id="1", type=EntityType.RALLY, canonical_name="Rally Alpha 2026", score=0.95),
        EntityCandidate(id="2", type=EntityType.RALLY, canonical_name="Rally Alpine 2026", score=0.70),
    ]
    resolver = DatabaseEntityResolver(repository=_MockScoreGapRepo(cand_clear), min_confidence_threshold=0.75, min_score_gap=0.15)
    res = await resolver.resolve(SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Alpha"]))
    assert res.requires_clarification is False
    assert res.resolutions["rally"].is_resolved is True
    assert res.resolutions["rally"].resolved_candidate.id == "1"
