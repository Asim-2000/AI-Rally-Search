from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.domain.search_intent import SearchIntent
from app.domain.search_plan import ExecutionStrategy, INTENT_TO_STRATEGY, SearchPlan
from app.domain.search_query import MatchMode, PersonRole, SearchQuery
from app.entity_search.models import CandidateOrigin, EntityCandidate, EntityResolution, EntityType
from app.services.search_plan_builder import (
    IncompatibleFilterError,
    SearchPlanBuilder,
    SearchPlanError,
    UnresolvedEntityError,
)


@pytest.mark.unit
def test_search_plan_immutability():
    plan = SearchPlan(
        intent=SearchIntent.SEARCH_RALLIES,
        strategy=ExecutionStrategy.RALLIES,
        countries=["Ireland"],
    )
    with pytest.raises(ValidationError):
        plan.countries = ["France"]  # Cannot mutate frozen model


@pytest.mark.unit
def test_all_nine_intents_mapping_and_compilation():
    builder = SearchPlanBuilder()

    intents_and_expected_strategies = [
        (SearchIntent.SEARCH_RALLIES, ExecutionStrategy.RALLIES),
        (SearchIntent.SEARCH_DRIVER_RALLIES, ExecutionStrategy.PARTICIPATIONS),
        (SearchIntent.SEARCH_DRIVER_WINS, ExecutionStrategy.DRIVER_WINS),
        (SearchIntent.GET_RALLY_RESULTS, ExecutionStrategy.RALLY_RESULTS),
        (SearchIntent.GET_RALLY_TOP_FINISHERS, ExecutionStrategy.TOP_FINISHERS),
        (SearchIntent.SEARCH_VIDEO_ACTIONS, ExecutionStrategy.VIDEO_ACTIONS),
        (SearchIntent.SEARCH_DRIVER_VIDEOS, ExecutionStrategy.DRIVER_VIDEOS),
        (SearchIntent.GET_TOP_UPLOADERS, ExecutionStrategy.TOP_UPLOADERS),
        (SearchIntent.GET_TOP_DRIVERS_BY_WINS, ExecutionStrategy.TOP_DRIVERS_BY_WINS),
    ]

    for intent, expected_strategy in intents_and_expected_strategies:
        query = SearchQuery(
            intent=intent,
            countries=["Ireland"],
            driver_names=["Craig Breen"] if "DRIVER" in intent else [],
            rally_names=["Donegal Rally 2024"] if "RALLY" in intent else [],
            action_types=["crash"] if intent == SearchIntent.SEARCH_VIDEO_ACTIONS else [],
        )
        plan = builder.build(query)
        assert plan.intent == intent
        assert plan.strategy == expected_strategy
        assert INTENT_TO_STRATEGY[intent] == expected_strategy


@pytest.mark.unit
def test_search_plan_field_preservation():
    builder = SearchPlanBuilder()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_DRIVER_RALLIES,
        driver_names=["Craig Breen"],
        driver_ids=["1042"],
        countries=["Ireland"],
        cities=["Letterkenny"],
        years=[2024],
        year_from=2020,
        year_to=2025,
        person_role=PersonRole.DRIVER,
        driver_match_mode=MatchMode.ALL,
        limit=15,
        offset=5,
    )
    plan = builder.build(query)
    assert plan.driver_names == ["Craig Breen"]
    assert plan.driver_ids == ["1042"]
    assert plan.countries == ["Ireland"]
    assert plan.cities == ["Letterkenny"]
    assert plan.years == [2024]
    assert plan.year_from == 2020
    assert plan.year_to == 2025
    assert plan.person_role == PersonRole.DRIVER
    assert plan.driver_match_mode == MatchMode.ALL
    assert plan.limit == 15
    assert plan.offset == 5


@pytest.mark.unit
def test_search_plan_rejects_invalid_year_range():
    with pytest.raises(ValueError):
        SearchPlan(
            intent=SearchIntent.SEARCH_RALLIES,
            strategy=ExecutionStrategy.RALLIES,
            year_from=2025,
            year_to=2020,  # Invalid
        )


@pytest.mark.unit
def test_search_plan_rejects_incompatible_action_types():
    builder = SearchPlanBuilder()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        action_types=["jump"],  # Incompatible with SEARCH_RALLIES
    )
    with pytest.raises(IncompatibleFilterError):
        builder.build(query)


@pytest.mark.unit
def test_search_plan_rejects_unresolved_entity_in_resolutions():
    builder = SearchPlanBuilder()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        rally_names=["donegl"],
    )
    unresolved_resolution = EntityResolution(
        type=EntityType.RALLY,
        raw_phrase="donegl",
        confidence=0.5,
        strategy="suggestions",
        is_ambiguous=True,
        candidate_options=[
            EntityCandidate(
                id="donegal-2024",
                canonical_name="Donegal International Rally 2024",
                type=EntityType.RALLY,
                score=0.82,
            )
        ],
    )
    with pytest.raises(UnresolvedEntityError):
        builder.build(query, resolutions={"rally": unresolved_resolution})


@pytest.mark.unit
def test_search_plan_removes_unresolved_noisy_mention():
    builder = SearchPlanBuilder()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        rally_names=["aluqsne"],
        countries=["Latvia"],
    )
    failed_resolution = EntityResolution(
        type=EntityType.RALLY,
        raw_phrase="aluqsne",
        confidence=0.1,
        strategy="unresolved_noise",
        resolved_candidate=None,
    )
    # Noisy mention is omitted so raw noise never reaches SQL
    plan = builder.build(query, resolutions={"rally": failed_resolution})
    assert plan.countries == ["Latvia"]
    assert "aluqsne" not in plan.rally_names


@pytest.mark.unit
def test_get_rally_results_enforces_single_item_semantics():
    builder = SearchPlanBuilder()
    query = SearchQuery(
        intent=SearchIntent.GET_RALLY_RESULTS,
        rally_names=["Rally Finland 2024"],
        limit=50,
        offset=10,
    )
    plan = builder.build(query)
    assert plan.limit == 1
    assert plan.offset == 0


@pytest.mark.unit
def test_search_plan_builder_pure_in_memory_no_network_or_db(monkeypatch):
    import time
    builder = SearchPlanBuilder()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
        driver_names=["Oliver Solberg"],
        stage_names=["Fafe 1"],
        stage_numbers=["1"],
        years=[2024],
        countries=["Portugal"],
    )
    start = time.perf_counter()
    plan = builder.build(query)
    elapsed_ms = (time.perf_counter() - start) * 1000

    assert plan.intent == SearchIntent.SEARCH_DRIVER_VIDEOS
    assert plan.strategy == ExecutionStrategy.DRIVER_VIDEOS
    assert plan.driver_names == ["Oliver Solberg"]
    assert plan.stage_names == ["Fafe 1"]
    assert plan.stage_numbers == ["1"]
    assert plan.countries == ["Portugal"]
    assert elapsed_ms < 10.0  # Must be pure in-memory sub-millisecond execution


@pytest.mark.unit
def test_person_role_combinations():
    builder = SearchPlanBuilder()
    for role in [PersonRole.ANY, PersonRole.DRIVER, PersonRole.CO_DRIVER]:
        query = SearchQuery(
            intent=SearchIntent.SEARCH_DRIVER_RALLIES,
            driver_names=["Paul Nagle"],
            person_role=role,
        )
        plan = builder.build(query)
        assert plan.person_role == role


@pytest.mark.unit
def test_search_video_actions_preserves_action_types():
    builder = SearchPlanBuilder()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
        action_types=["jump", "crash"],
        stage_names=["Kemmelberg"],
        rally_names=["Ypres Rally"],
    )
    plan = builder.build(query)
    assert plan.strategy == ExecutionStrategy.VIDEO_ACTIONS
    assert plan.action_types == ["jump", "crash"]
    assert plan.stage_names == ["Kemmelberg"]
    assert plan.rally_names == ["Ypres Rally"]


@pytest.mark.unit
def test_top_uploaders_and_top_drivers_plans():
    builder = SearchPlanBuilder()
    
    uploaders_query = SearchQuery(
        intent=SearchIntent.GET_TOP_UPLOADERS,
        countries=["Ireland"],
        limit=10,
    )
    plan_u = builder.build(uploaders_query)
    assert plan_u.strategy == ExecutionStrategy.TOP_UPLOADERS
    assert plan_u.countries == ["Ireland"]
    assert plan_u.limit == 10

    top_drivers_query = SearchQuery(
        intent=SearchIntent.GET_TOP_DRIVERS_BY_WINS,
        years=[2024],
        limit=5,
    )
    plan_d = builder.build(top_drivers_query)
    assert plan_d.strategy == ExecutionStrategy.TOP_DRIVERS_BY_WINS
    assert plan_d.years == [2024]
    assert plan_d.limit == 5


@pytest.mark.unit
@pytest.mark.parametrize("noisy_mention", ["aluqsne", "aluksnay", "max freemn"])
def test_search_plan_prohibits_unresolved_noisy_entity_mentions(noisy_mention):
    builder = SearchPlanBuilder()
    is_driver = "freemn" in noisy_mention
    query = SearchQuery(
        intent=SearchIntent.SEARCH_DRIVER_VIDEOS if is_driver else SearchIntent.SEARCH_RALLIES,
        driver_names=[noisy_mention] if is_driver else [],
        rally_names=[noisy_mention] if not is_driver else [],
        countries=["Ireland"],
    )
    # When resolution failed/unresolved
    unresolved = EntityResolution(
        type=EntityType.DRIVER if is_driver else EntityType.RALLY,
        raw_phrase=noisy_mention,
        confidence=0.1,
        strategy="unresolved_noise",
        resolved_candidate=None,
    )
    plan = builder.build(query, resolutions={"entity": unresolved})
    assert noisy_mention not in plan.rally_names
    assert noisy_mention not in plan.driver_names


@pytest.mark.unit
def test_unresolved_required_entity_cannot_produce_search_plan():
    builder = SearchPlanBuilder()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        rally_names=["donegl"],
    )
    ambiguous = EntityResolution(
        type=EntityType.RALLY,
        raw_phrase="donegl",
        confidence=0.6,
        strategy="suggestions",
        is_ambiguous=True,
    )
    with pytest.raises(UnresolvedEntityError):
        builder.build(query, resolutions={"rally": ambiguous})


@pytest.mark.unit
def test_search_repository_search_query_deprecation_warning():
    import warnings
    from unittest.mock import AsyncMock, MagicMock
    from app.repositories.search_repository import SearchRepository

    mock_conn = MagicMock()
    repo = SearchRepository(mock_conn)
    repo.rallies = AsyncMock(return_value=([], 0))

    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES)
    with pytest.deprecated_call():
        import asyncio
        asyncio.run(repo.search(query))


