import pytest
from app.domain.referent_context import ResultReferentContext
from app.domain.results import (
    ClassificationItem,
    DriverWinsItem,
    ParticipationItem,
    RallyResultItem,
    SearchResponse,
    VideoItem,
)
from app.domain.search_intent import SearchIntent
from app.domain.search_query import PersonRole


@pytest.mark.unit
def test_referent_copy_with_and_clear_flags():
    ref = ResultReferentContext(
        active_rally="Donegal Rally",
        active_rally_id="e-donegal-2025",
        active_rallies=["Donegal Rally", "Moonraker"],
        active_driver="Josh Moffett",
        active_driver_id="d-101",
        active_drivers=["Josh Moffett", "Sam Moffett"],
        active_person_role=PersonRole.DRIVER,
        active_stage="Gale Rigg",
        active_stage_number="3",
        last_winner="Josh Moffett",
        last_winner_driver_id="d-101",
    )

    # Clear driver
    c1 = ref.copy_with(clear_active_driver=True)
    assert c1.active_driver is None
    assert c1.active_driver_id is None
    assert c1.active_drivers == []
    assert c1.active_rally == "Donegal Rally"
    assert c1.last_winner == "Josh Moffett"

    # Clear winner and rally
    c2 = ref.copy_with(clear_active_rally=True, clear_last_winner=True)
    assert c2.active_rally is None
    assert c2.active_rally_id is None
    assert c2.active_rallies == []
    assert c2.last_winner is None
    assert c2.last_winner_driver_id is None
    assert c2.active_driver == "Josh Moffett"

    # Clear role
    c3 = ref.copy_with(clear_active_person_role=True)
    assert c3.active_person_role is None


@pytest.mark.unit
def test_from_search_response_rally_results_extracts_winner_and_leaderboard():
    resp = SearchResponse(
        intent=SearchIntent.GET_RALLY_RESULTS,
        results=[
            ClassificationItem(
                id=1,
                rally_id="e-donegal-2025",
                event_name="Donegal International Rally 2025",
                driver_id="d-101",
                driver_name="Josh Moffett",
                pos_overall=1,
            ),
            ClassificationItem(
                id=2,
                rally_id="e-donegal-2025",
                event_name="Donegal International Rally 2025",
                driver_id="d-102",
                driver_name="Sam Moffett",
                pos_overall=2,
            ),
        ],
        total_count=2,
        has_more=False,
        limit=20,
        offset=0,
    )

    referents = ResultReferentContext.from_search_response(resp)
    assert referents.last_winner == "Josh Moffett"
    assert referents.last_winner_driver_id == "d-101"
    assert referents.active_driver == "Josh Moffett"
    assert referents.active_rally == "Donegal International Rally 2025"
    assert referents.active_rally_id == "e-donegal-2025"
    assert referents.active_drivers == ["Josh Moffett", "Sam Moffett"]
    assert "Donegal International Rally 2025" in referents.active_rallies


@pytest.mark.unit
def test_from_search_response_single_rally_extracts_active_rally():
    resp = SearchResponse(
        intent=SearchIntent.SEARCH_RALLIES,
        results=[
            RallyResultItem(
                event_id="e-donegal-2025",
                event_name="Donegal International Rally 2025",
                country="Ireland",
                city="Letterkenny",
            ),
        ],
        total_count=1,
        has_more=False,
        limit=20,
        offset=0,
    )

    referents = ResultReferentContext.from_search_response(resp)
    assert referents.active_rally == "Donegal International Rally 2025"
    assert referents.active_rally_id == "e-donegal-2025"
    assert referents.active_rallies == ["Donegal International Rally 2025"]


@pytest.mark.unit
def test_from_search_response_driver_rallies_extracts_participation_rallies():
    resp = SearchResponse(
        intent=SearchIntent.SEARCH_DRIVER_RALLIES,
        results=[
            ParticipationItem(
                rally_id="e-donegal-2025",
                event_name="Donegal International Rally 2025",
                person_id="p-101",
                driver_name="Max Freeman",
                role="CO_DRIVER",
            ),
            ParticipationItem(
                rally_id="e-moonraker-2025",
                event_name="Moonraker Forestry Rally 2025",
                person_id="p-101",
                driver_name="Max Freeman",
                role="CO_DRIVER",
            ),
        ],
        total_count=2,
        has_more=False,
        limit=20,
        offset=0,
    )

    referents = ResultReferentContext.from_search_response(
        resp,
        query_driver="Max Freeman",
        query_person_role=PersonRole.CO_DRIVER,
    )
    assert referents.active_driver == "Max Freeman"
    assert referents.active_person_role == PersonRole.CO_DRIVER
    assert len(referents.active_rallies) == 2
    assert "Donegal International Rally 2025" in referents.active_rallies
    assert "Moonraker Forestry Rally 2025" in referents.active_rallies


@pytest.mark.unit
def test_from_search_response_driver_wins():
    resp = SearchResponse(
        intent=SearchIntent.GET_TOP_DRIVERS_BY_WINS,
        results=[
            DriverWinsItem(person_id="p-1", driver_name="Josh Moffett", win_count=15),
            DriverWinsItem(person_id="p-2", driver_name="Sam Moffett", win_count=12),
        ],
        total_count=2,
        has_more=False,
        limit=20,
        offset=0,
    )
    referents = ResultReferentContext.from_search_response(resp)
    assert referents.last_winner == "Josh Moffett"
    assert referents.active_driver == "Josh Moffett"
    assert referents.active_drivers == ["Josh Moffett", "Sam Moffett"]
