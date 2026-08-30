"""Regression tests for downstream accuracy fixes ACC-1, ACC-2, ACC-3, ACC-4, ACC-6.

These target deterministic behaviour only; no model, DB, or network is involved.
"""

import pytest

from app.domain.referent_context import ResultReferentContext
from app.domain.results import ParticipationItem, SearchResponse
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.services.conversational_search_service import ConversationalSearchService

_svc = ConversationalSearchService  # static helpers only


# ---------------------------------------------------------------------------
# ACC-1: follow-up video/action intent recovery
# ---------------------------------------------------------------------------

def test_acc1_videos_from_that_rally_becomes_video_actions():
    q = SearchQuery(intent=SearchIntent.SEARCH_RALLIES)
    refs = ResultReferentContext(active_rally="Rally Alūksne 2026")
    out = _svc._recover_followup_video_intent(q, "Show videos from that rally", refs)
    assert out.intent == SearchIntent.SEARCH_VIDEO_ACTIONS
    assert out.rally_names == ["Rally Alūksne 2026"]


def test_acc1_jump_highlights_from_that_rally_sets_action():
    q = SearchQuery(intent=SearchIntent.SEARCH_RALLIES)
    refs = ResultReferentContext(active_rally="Rally Alūksne 2026")
    out = _svc._recover_followup_video_intent(q, "Show jump highlights from that rally", refs)
    assert out.intent == SearchIntent.SEARCH_VIDEO_ACTIONS
    assert out.action_types == ["jump"]
    assert out.rally_names == ["Rally Alūksne 2026"]


def test_acc1_rallies_in_ireland_stays_search_rallies():
    q = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Ireland"])
    refs = ResultReferentContext(active_rally="Rally Alūksne 2026")
    out = _svc._recover_followup_video_intent(q, "Rallies in Ireland", refs)
    assert out.intent == SearchIntent.SEARCH_RALLIES


def test_acc1_no_referent_no_rally_not_corrected():
    q = SearchQuery(intent=SearchIntent.SEARCH_RALLIES)
    out = _svc._recover_followup_video_intent(q, "show videos", ResultReferentContext())
    assert out.intent == SearchIntent.SEARCH_RALLIES


# ---------------------------------------------------------------------------
# ACC-2: grounded direct-filter recovery
# ---------------------------------------------------------------------------

def test_acc2_recovers_dropped_country_and_year():
    q = SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, action_types=["crash"])
    out = _svc._recover_grounded_direct_filters(q, "Crashes in Ireland in 2025")
    assert out.countries == ["Ireland"]
    assert out.years == [2025]
    assert out.action_types == ["crash"]


def test_acc2_does_not_overwrite_model_country():
    q = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["France"])
    out = _svc._recover_grounded_direct_filters(q, "rallies in france")
    assert out.countries == ["France"]  # no duplicate, no change


def test_acc2_edition_year_in_entity_phrase_not_a_filter():
    q = SearchQuery(intent=SearchIntent.GET_RALLY_RESULTS, rally_names=["Rally Alūksne 2026"])
    out = _svc._recover_grounded_direct_filters(q, "who won rally aluksne 2026")
    assert out.years == []


def test_acc2_country_inside_entity_phrase_not_double_counted():
    q = SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, rally_names=["Rally Ireland"], action_types=["jump"])
    out = _svc._recover_grounded_direct_filters(q, "jump highlights from rally ireland")
    assert out.countries == []


# ---------------------------------------------------------------------------
# ACC-4: referent fallback before missing-subject clarification
# ---------------------------------------------------------------------------

def test_acc4_who_won_it_reuses_active_rally():
    q = SearchQuery(intent=SearchIntent.GET_RALLY_RESULTS)
    refs = ResultReferentContext(active_rally="Rally Alūksne 2026", active_rally_id="ev-1")
    out = _svc._apply_referent_fallback(q, refs)
    assert out.rally_names == ["Rally Alūksne 2026"]
    assert _svc._missing_required_subject(out) is None


def test_acc4_driver_referent_not_used_as_rally():
    q = SearchQuery(intent=SearchIntent.GET_RALLY_RESULTS)
    refs = ResultReferentContext(active_driver="Max Freeman")  # no active rally
    out = _svc._apply_referent_fallback(q, refs)
    assert out.rally_names == []
    assert _svc._missing_required_subject(out) is not None  # still clarifies


def test_acc4_driver_intent_reuses_active_driver():
    q = SearchQuery(intent=SearchIntent.SEARCH_DRIVER_VIDEOS)
    refs = ResultReferentContext(active_driver="Max Freeman")
    out = _svc._apply_referent_fallback(q, refs)
    assert out.driver_names == ["Max Freeman"]


# ---------------------------------------------------------------------------
# ACC-3: canonical driver referent preservation
# ---------------------------------------------------------------------------

def _driver_rallies_response():
    return SearchResponse(
        intent=SearchIntent.SEARCH_DRIVER_RALLIES,
        results=[ParticipationItem(rally_id="ev-1", event_name="Rally Alūksne 2026", driver_name="Max Freeman")],
        total_count=1, has_more=False, limit=20, offset=0,
    )


def test_acc3_active_driver_id_pinned_from_resolution():
    refs = ResultReferentContext.from_search_response(
        _driver_rallies_response(),
        query_drivers=["Max Freeman"],
        query_driver_ids=["person:driver:123"],
    )
    assert refs.active_driver == "Max Freeman"
    assert refs.active_driver_id == "person:driver:123"


def test_acc3_new_driver_without_id_clears_stale_id():
    prev = ResultReferentContext(active_driver="Old", active_driver_id="person:driver:old")
    refs = ResultReferentContext.from_search_response(
        _driver_rallies_response(),
        previous=prev,
        query_drivers=["Max Freeman"],
        query_driver_ids=[],
    )
    assert refs.active_driver_id is None


# ---------------------------------------------------------------------------
# ACC-6: ambiguous rally beats cross-type person recovery
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_acc6_ambiguous_rally_clarifies_not_person():
    from app.entity_search.adapter import EntitySearchLookupAdapter
    from app.entity_search.models import CanonicalSearchEntity, SearchEntityType
    from app.entity_search.resolver import DatabaseEntityResolver
    from app.entity_search.service import InMemoryEntitySearchService

    entities = [
        CanonicalSearchEntity(
            canonical_id="r-2024", canonical_name="Donegal Rally 2024",
            entity_type=SearchEntityType.RALLY,
            metadata={"eventId": "r-2024", "year": 2024, "searchableNames": ["Donegal Rally 2024", "Donegal Rally"]},
        ),
        CanonicalSearchEntity(
            canonical_id="r-2025", canonical_name="Donegal Rally 2025",
            entity_type=SearchEntityType.RALLY,
            metadata={"eventId": "r-2025", "year": 2025, "searchableNames": ["Donegal Rally 2025", "Donegal Rally"]},
        ),
    ]
    resolver = DatabaseEntityResolver(
        repository=EntitySearchLookupAdapter(
            search_service=InMemoryEntitySearchService.from_entities(entities)
        )
    )
    # SEARCH_RALLIES permits person recovery in its capability matrix; an
    # ambiguous rally must still clarify as a RALLY, not be hijacked to PERSON.
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Donegal Rally"])
    res = await resolver.resolve(query)
    assert res.requires_clarification
    assert res.candidates  # rally editions offered


# ---------------------------------------------------------------------------
# ACC-6 REFINEMENT: gate cross-type PERSON recovery on rally-match STRENGTH,
# not the raw ambiguity flag.
#
# A rally is only *genuinely* ambiguous when at least one rally candidate is a
# STRONG match (clears the confidence threshold) — e.g. multiple real editions
# of the same event. When every rally candidate is weak/spurious retrieval
# noise, a phrase the model misfiled into rallyNames that is really a PERSON
# must be recoverable via a confident PERSON match.
#
# Distinguishing signal captured from the frozen benchmark trace:
#   act_0344 "Aaron Duville" : rally top 0.543 (<0.75, spurious) + driver 1.0
#   act_0352 "Aaron Nau"     : rally top 0.518 (<0.75, spurious) + driver 1.0
#   nsy_0207 "Mayo Forestry" : rally top 0.94  (>=0.75, genuine) + driver 0.846
#   nsy_0208 "Mayo Stages"   : rally top 0.94  (>=0.75, genuine) + driver 0.846
# ---------------------------------------------------------------------------

from app.domain.search_query import PersonRole  # noqa: E402
from app.entity_search.models import EntityCandidate, EntityType  # noqa: E402
from app.entity_search.resolver import DatabaseEntityResolver  # noqa: E402


class _StubLookupRepo:
    """Returns fixed candidate lists; the resolver re-scores them by name so the
    score band is controlled purely by the candidate names vs the query phrase.
    """

    def __init__(self, *, rallies=None, drivers=None):
        self._rallies = rallies or []
        self._drivers = drivers or []

    async def lookup_rallies(self, phrase, **kwargs):
        return list(self._rallies)

    async def lookup_drivers(self, phrase, **kwargs):
        return list(self._drivers)

    async def lookup_stages(self, phrase, **kwargs):
        return []

    async def lookup_cities(self, phrase, **kwargs):
        return []

    async def lookup_uploaders(self, phrase, **kwargs):
        return []


def _rally(name: str) -> EntityCandidate:
    return EntityCandidate(id=f"rally:{name}", type=EntityType.RALLY, canonical_name=name, metadata={})


def _driver(name: str, driver_id: str = "d1") -> EntityCandidate:
    return EntityCandidate(
        id=f"driver:{name}", type=EntityType.DRIVER, canonical_name=name,
        metadata={"driverId": driver_id},
    )


async def _recover(phrase: str, *, rallies, drivers, intent=SearchIntent.SEARCH_VIDEO_ACTIONS):
    resolver = DatabaseEntityResolver(
        repository=_StubLookupRepo(rallies=rallies, drivers=drivers)
    )
    query = SearchQuery(intent=intent, rally_names=[phrase])
    return await resolver.resolve(query)


@pytest.mark.asyncio
async def test_acc6r_A_spurious_rally_confident_person_recovers():
    # act_0344 equivalent: weak/spurious rally ambiguity + confident PERSON.
    res = await _recover(
        "Aaron Duville",
        rallies=[_rally("Ronde della Val Merula 2025")],  # ~0.54, spurious
        drivers=[_driver("Aaron Duville")],               # 1.0, clear winner
    )
    assert not res.requires_clarification
    assert res.resolved_query.driver_names == ["Aaron Duville"]
    assert res.resolved_query.rally_names == []


@pytest.mark.asyncio
async def test_acc6r_B_spurious_rally_confident_person_recovers_variant():
    # act_0352 equivalent.
    res = await _recover(
        "Aaron Nau",
        rallies=[_rally("Rallye National du Pays de Fayence 2025")],  # ~0.5, spurious
        drivers=[_driver("Aaron Nau")],                               # 1.0
    )
    assert not res.requires_clarification
    assert res.resolved_query.driver_names == ["Aaron Nau"]


@pytest.mark.asyncio
async def test_acc6r_C_genuine_rally_ambiguity_clarifies_not_person():
    # nsy_0207 equivalent: two STRONG rally editions + coincidental strong person.
    res = await _recover(
        "Mayo Rally",
        rallies=[_rally("Mayo Forestry Rally 2025"), _rally("Mayo Stages Rally 2026")],  # both 0.94
        drivers=[_driver("Simon May")],  # ~0.85, coincidental
    )
    assert res.requires_clarification
    assert res.candidates
    # never hijacked into the coincidental person
    assert not (res.resolved_query and res.resolved_query.driver_names)


@pytest.mark.asyncio
async def test_acc6r_D_genuine_rally_ambiguity_clarifies_variant():
    # nsy_0208 equivalent.
    res = await _recover(
        "Mayo Rally",
        rallies=[_rally("Mayo Forestry Rally 2025"), _rally("Mayo Stages Rally 2026")],
        drivers=[_driver("Simon May")],
    )
    assert res.requires_clarification
    assert not (res.resolved_query and res.resolved_query.driver_names)


@pytest.mark.asyncio
async def test_acc6r_E_rally_no_match_strong_person_recovers():
    # True rally no-match + strong PERSON -> recover PERSON (intent permits).
    res = await _recover(
        "Aaron Nau",
        rallies=[],                        # no rally candidates at all
        drivers=[_driver("Aaron Nau")],    # 1.0
    )
    assert not res.requires_clarification
    assert res.resolved_query.driver_names == ["Aaron Nau"]


@pytest.mark.asyncio
async def test_acc6r_F_genuine_rally_ambiguity_weak_person_clarifies():
    # Genuine strong rally ambiguity + weak PERSON -> clarify RALLY, no recovery.
    res = await _recover(
        "Donegal Rally",
        rallies=[_rally("Donegal Rally 2024"), _rally("Donegal Rally 2025")],  # 0.96 each
        drivers=[_driver("Danny Odell")],  # ~0.5, weak
    )
    assert res.requires_clarification
    assert not (res.resolved_query and res.resolved_query.driver_names)


@pytest.mark.asyncio
async def test_acc6r_G_genuine_rally_ambiguity_strong_person_still_clarifies():
    # Genuine strong rally ambiguity + STRONG PERSON -> RALLY clarification MUST
    # still win. This is the core safety invariant that eliminates the nsy_*
    # wrong-entity executions.
    res = await _recover(
        "Donegal Rally",
        rallies=[_rally("Donegal Rally 2024"), _rally("Donegal Rally 2025")],  # 0.96 each
        drivers=[_driver("Donegal Ryan")],  # ~0.98, strong coincidental person
    )
    assert res.requires_clarification
    assert not (res.resolved_query and res.resolved_query.driver_names)


@pytest.mark.asyncio
async def test_acc6r_H_weak_rally_weak_person_safe_no_wrong_confident():
    # Weak rally ambiguity + weak PERSON -> safe clarification, never a wrong
    # confident PERSON execution.
    res = await _recover(
        "Aaron Duville",
        rallies=[_rally("Rally Auville 2025")],  # ~0.72, spurious/weak
        drivers=[_driver("Aron Smithy")],        # ~0.23, weak
    )
    # no confident winner anywhere -> must not resolve to the weak person
    assert not (res.resolved_query and res.resolved_query.driver_names)
