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
