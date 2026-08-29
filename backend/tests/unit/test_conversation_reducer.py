import pytest
from app.domain.conversation_reducer import calculate_inherited_and_refined_fields, reduce_turn
from app.domain.conversation_session import SearchConversationSession
from app.domain.referent_context import ResultReferentContext
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery


@pytest.mark.unit
def test_calculate_inherited_and_refined_fields_rally():
    q_prev = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rallyNames=["Donegal Rally 2025"], years=[2025])
    q_new = SearchQuery(intent=SearchIntent.GET_RALLY_RESULTS, rallyNames=["Donegal Rally 2025"], years=[2025])

    inherited, refined = calculate_inherited_and_refined_fields(q_prev, q_new)
    assert "rally" in inherited
    assert "year" in inherited
    assert len(refined) == 0


@pytest.mark.unit
def test_calculate_inherited_and_refined_fields_refinement():
    q_prev = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rallyNames=["Donegal Rally 2025"], years=[2025])
    q_new = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rallyNames=["Donegal Rally 2025"], years=[2024])

    inherited, refined = calculate_inherited_and_refined_fields(q_prev, q_new)
    assert "rally" in inherited
    assert "year" in refined


@pytest.mark.unit
def test_calculate_inherited_and_refined_fields_action():
    q_prev = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rallyNames=["Donegal Rally 2025"])
    q_new = SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, rallyNames=["Donegal Rally 2025"], actionTypes=["jump"])

    inherited, refined = calculate_inherited_and_refined_fields(q_prev, q_new)
    assert "rally" in inherited
    assert "action" in refined


@pytest.mark.unit
def test_reduce_turn_updates_session_history_and_fields():
    session = SearchConversationSession(
        active_query=SearchQuery(
            intent=SearchIntent.SEARCH_RALLIES,
            rallyNames=["Donegal Rally 2025"],
            years=[2025],
        ),
        referents=ResultReferentContext(active_rally="Donegal Rally 2025"),
    )

    q_turn2 = SearchQuery(
        intent=SearchIntent.GET_RALLY_RESULTS,
        rallyNames=["Donegal Rally 2025"],
        years=[2025],
    )
    ref_turn2 = session.referents.copy_with(last_winner="Josh Moffett", active_driver="Josh Moffett")

    updated = reduce_turn(
        session,
        query=q_turn2,
        referents=ref_turn2,
        title="Who won it?",
        interpreted_summary="Getting 1st place rally winner | Rallies: Donegal Rally 2025",
    )

    assert len(updated.history) == 1
    assert updated.active_query == q_turn2
    assert updated.previous_query == session.active_query
    assert updated.referents.last_winner == "Josh Moffett"
    assert "rally" in updated.inherited_fields
    assert "year" in updated.inherited_fields
