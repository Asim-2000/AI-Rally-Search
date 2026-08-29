import pytest
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.entity_search.fallback import (
    ControlledFallbackEntityResolver,
    EntitySearchFallbackConfig,
    EntitySearchFallbackMode,
)
from app.entity_search.models import (
    CandidateOrigin,
    EntityCandidate,
    EntityResolution,
    EntityResolutionResult,
    EntityType,
)
from app.entity_search.telemetry import EntitySearchFallbackMetrics


class _CountingResolver:
    def __init__(self, result: EntityResolutionResult):
        self.result = result
        self.calls = 0

    async def resolve(self, query: SearchQuery, *, context=None) -> EntityResolutionResult:
        self.calls += 1
        return self.result


class _TelemetryRecorder:
    def __init__(self):
        self.records = []

    def record(self, diagnostic):
        self.records.append(diagnostic)


_RALLY = EntityCandidate(
    id="event-1",
    type=EntityType.RALLY,
    canonical_name="Rally Alūksne 2026",
    metadata={"candidateOrigin": "entitySearch", "retrievalSignals": {"exact": 0.0, "normalizedExact": 0.0}},
)


def _resolved(query: SearchQuery, candidate: EntityCandidate) -> EntityResolutionResult:
    return EntityResolutionResult(
        parsed_query=query,
        resolved_query=query.model_copy(
            update={
                "rally_names": [candidate.canonical_name] if candidate.type == EntityType.RALLY else query.rally_names,
                "driver_names": [candidate.canonical_name] if candidate.type == EntityType.DRIVER else query.driver_names,
            }
        ),
        resolutions={
            "rally" if candidate.type == EntityType.RALLY else "driver": EntityResolution(
                type=candidate.type,
                raw_phrase=query.target_rally_names[0] if query.target_rally_names else (query.driver_names[0] if query.driver_names else ""),
                resolved_candidate=candidate,
                confidence=0.95,
                strategy="unique_match",
            )
        },
    )


def _no_match(query: SearchQuery) -> EntityResolutionResult:
    return EntityResolutionResult.failure("not found", parsed_query=query)


@pytest.mark.unit
async def test_fallback_mode_off():
    query = SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, rally_names=["aluksni"])
    legacy = _CountingResolver(_no_match(query))
    recovered = _CountingResolver(_resolved(query, _RALLY))

    resolver = ControlledFallbackEntityResolver(
        legacy_resolver=legacy,
        entity_search_resolver=recovered,
        config=EntitySearchFallbackConfig(mode=EntitySearchFallbackMode.OFF),
    )
    result = await resolver.resolve(query)
    assert result.error is not None
    assert legacy.calls == 1
    assert recovered.calls == 0


@pytest.mark.unit
async def test_fallback_mode_shadow():
    query = SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, rally_names=["aluksni"])
    legacy = _CountingResolver(_no_match(query))
    recovered = _CountingResolver(_resolved(query, _RALLY))
    telemetry = _TelemetryRecorder()

    resolver = ControlledFallbackEntityResolver(
        legacy_resolver=legacy,
        entity_search_resolver=recovered,
        config=EntitySearchFallbackConfig(mode=EntitySearchFallbackMode.SHADOW),
        telemetry=telemetry,
    )
    result = await resolver.resolve(query)
    assert result.error is not None
    assert legacy.calls == 1
    assert recovered.calls == 1
    assert len(telemetry.records) == 1
    assert telemetry.records[0].raw_mention == "aluksni"
    assert telemetry.records[0].entity_search_candidate_ids == ["event-1"]
    assert telemetry.records[0].candidate_origins["event-1"] == CandidateOrigin.ENTITY_SEARCH


@pytest.mark.unit
async def test_safe_legacy_winner_bypasses_entity_search():
    query = SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, rally_names=["Rally Aluksne 2026"])
    legacy = _CountingResolver(_resolved(query, _RALLY))
    recovered = _CountingResolver(_resolved(query, _RALLY))

    resolver = ControlledFallbackEntityResolver(
        legacy_resolver=legacy,
        entity_search_resolver=recovered,
        config=EntitySearchFallbackConfig(mode=EntitySearchFallbackMode.FALLBACK),
    )
    result = await resolver.resolve(query)
    assert result.is_success is True
    assert legacy.calls == 1
    assert recovered.calls == 0


@pytest.mark.unit
async def test_legacy_no_match_with_es_recovery():
    query = SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, rally_names=["aluksnay"])
    legacy = _CountingResolver(_no_match(query))
    recovered = _CountingResolver(_resolved(query, _RALLY))
    metrics = EntitySearchFallbackMetrics()

    resolver = ControlledFallbackEntityResolver(
        legacy_resolver=legacy,
        entity_search_resolver=recovered,
        config=EntitySearchFallbackConfig(mode=EntitySearchFallbackMode.FALLBACK),
        metrics=metrics,
    )
    result = await resolver.resolve(query)
    assert result.is_success is True
    assert result.resolutions["rally"].resolved_candidate.id == "event-1"
    assert legacy.calls == 1
    assert recovered.calls == 1
    assert metrics.entity_search_recovered_legacy_failure == 1


@pytest.mark.unit
async def test_legacy_clarification_preserved_when_es_no_match():
    query = SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, rally_names=["aluksni"])
    legacy_clarification = EntityResolutionResult.clarification(
        parsed_query=query,
        clarification_question="Which rally?",
        candidates=[_RALLY],
    )
    legacy = _CountingResolver(legacy_clarification)
    recovered = _CountingResolver(_no_match(query))

    resolver = ControlledFallbackEntityResolver(
        legacy_resolver=legacy,
        entity_search_resolver=recovered,
        config=EntitySearchFallbackConfig(mode=EntitySearchFallbackMode.FALLBACK),
    )
    result = await resolver.resolve(query)
    assert result.requires_clarification is True
    assert result.clarification_question == "Which rally?"
