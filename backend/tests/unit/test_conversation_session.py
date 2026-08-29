import pytest
from app.domain.conversation_session import SearchConversationSession
from app.domain.referent_context import ResultReferentContext
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery


@pytest.mark.unit
def test_session_initial_state():
    session = SearchConversationSession()
    assert session.active_query.intent == SearchIntent.SEARCH_RALLIES
    assert session.previous_query is None
    assert session.referents.active_rally is None
    assert len(session.history) == 0
    assert session.active_request_id == 0


@pytest.mark.unit
def test_session_next_request_increments_active_request_id():
    s0 = SearchConversationSession()
    s1 = s0.next_request()
    assert s1.active_request_id == 1
    s2 = s1.next_request()
    assert s2.active_request_id == 2


@pytest.mark.unit
def test_session_record_turn():
    s0 = SearchConversationSession()
    q1 = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rallyNames=["Donegal International Rally 2025"])
    ref1 = ResultReferentContext(active_rally="Donegal International Rally 2025")
    s1 = s0.record_turn(
        query=q1,
        referents=ref1,
        title="Show Donegal Rally 2025",
        interpreted_summary="Searching rally events | Rallies: Donegal International Rally 2025",
        inherited={"year"},
        refinements={"rally"},
    )
    assert len(s1.history) == 1
    assert s1.active_query == q1
    assert s1.previous_query == s0.active_query
    assert s1.referents == ref1
    assert s1.inherited_fields == {"year"}
    assert s1.current_refinement_fields == {"rally"}
    assert s1.history[0].title == "Show Donegal Rally 2025"


@pytest.mark.unit
def test_session_rollback_to():
    s0 = SearchConversationSession()
    q1 = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rallyNames=["Moonraker"])
    ref1 = ResultReferentContext(active_rally="Moonraker")
    s1 = s0.record_turn(query=q1, referents=ref1, title="Moonraker")

    q2 = SearchQuery(intent=SearchIntent.GET_RALLY_RESULTS, rallyNames=["Moonraker"])
    ref2 = ResultReferentContext(active_rally="Moonraker", last_winner="Jordan Hone")
    s2 = s1.record_turn(query=q2, referents=ref2, title="Winner")

    assert len(s2.history) == 2
    assert s2.referents.last_winner == "Jordan Hone"

    # Rollback to turn 0 (Moonraker)
    rolled_back = s2.rollback_to(0)
    assert len(rolled_back.history) == 1
    assert rolled_back.active_query.intent == SearchIntent.SEARCH_RALLIES
    assert rolled_back.active_query.target_rally_name == "Moonraker"
    assert rolled_back.referents.last_winner is None
    assert rolled_back.previous_query is None


@pytest.mark.unit
def test_session_remove_filter_multi_value():
    session = SearchConversationSession(
        active_query=SearchQuery(
            intent=SearchIntent.SEARCH_RALLIES,
            countries=["Ireland", "Scotland"],
            years=[2024, 2025],
        )
    )
    updated = session.remove_filter(field="country", value="Scotland")
    assert updated.active_query.countries == ["Ireland"]
    assert updated.active_query.years == [2024, 2025]
    assert updated.active_request_id == session.active_request_id + 1


@pytest.mark.unit
def test_session_remove_filter_clears_matched_referents():
    session = SearchConversationSession(
        active_query=SearchQuery(
            intent=SearchIntent.SEARCH_RALLIES,
            rallyNames=["Donegal International Rally"],
            driverNames=["Josh Moffett"],
        ),
        referents=ResultReferentContext(
            active_rally="Donegal International Rally",
            active_driver="Josh Moffett",
            last_winner="Josh Moffett",
        ),
    )
    # Remove driver
    u1 = session.remove_filter(field="driver", value="Josh Moffett")
    assert u1.active_query.driver_names == []
    assert u1.referents.active_driver is None
    assert u1.referents.last_winner is None
    assert u1.referents.active_rally == "Donegal International Rally"

    # Remove rally
    u2 = u1.remove_filter(field="rally", value="Donegal International Rally")
    assert u2.active_query.rally_names == []
    assert u2.referents.active_rally is None


@pytest.mark.unit
def test_session_add_filter():
    session = SearchConversationSession(
        active_query=SearchQuery(
            intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
            actionTypes=["jump"],
            driverNames=["Josh Moffett"],
        )
    )
    updated = session.add_filter(field="action", value="drift")
    assert updated.active_query.action_types == ["jump", "drift"]
    assert "action" in updated.current_refinement_fields
    assert updated.active_request_id == session.active_request_id + 1


@pytest.mark.unit
def test_session_clear_all():
    session = SearchConversationSession(
        active_query=SearchQuery(
            intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
            driverNames=["Josh Moffett"],
            actionTypes=["jump"],
        ),
        referents=ResultReferentContext(
            active_driver="Josh Moffett",
            last_winner="Josh Moffett",
        ),
    )
    cleared = session.clear_all()
    assert cleared.active_query.intent == SearchIntent.SEARCH_RALLIES
    assert cleared.active_query.driver_names == []
    assert cleared.active_query.action_types == []
    assert cleared.referents.active_driver is None
    assert cleared.referents.last_winner is None
    assert len(cleared.history) == 0
    assert cleared.active_request_id == session.active_request_id + 1
