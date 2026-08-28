from __future__ import annotations

import json
from pathlib import Path
import pytest
from app.db.engine import get_engine
from app.domain.search_intent import SearchIntent
from app.domain.search_query import PersonRole, SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.fallback import (
    ControlledFallbackEntityResolver,
    EntitySearchFallbackConfig,
    EntitySearchFallbackMode,
)
from app.entity_search.models import EntityType
from app.entity_search.normalization import collapse_spaces, strip_descriptors
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.entity_search.telemetry import EntitySearchFallbackMetrics

# 62 Positives from Dart audited_resolver_safety_benchmark_test.dart
POSITIVES = [
    {"canonical": "Rally Alūksne 2026", "input": "aluksnay", "type": EntityType.RALLY},
    {"canonical": "Rally Alūksne 2026", "input": "a looks nay", "type": EntityType.RALLY},
    {"canonical": "Rally Alūksne 2026", "input": "alux new", "type": EntityType.RALLY},
    {"canonical": "Rally Alūksne 2026", "input": "eluksne", "type": EntityType.RALLY},
    {"canonical": "Rally Alūksne 2026", "input": "aluknse", "type": EntityType.RALLY},
    {"canonical": "Rally Alūksne 2026", "input": "aluksney", "type": EntityType.RALLY},
    {"canonical": "Paweł Molgo", "input": "pawel malgo", "type": EntityType.DRIVER},
    {"canonical": "Shea Breen", "input": "shea brain", "type": EntityType.DRIVER},
    {"canonical": "Donegal International Rally", "input": "donny gall rally", "type": EntityType.RALLY},
    {"canonical": "Woodstoxx Kemmelberg 1", "input": "kemel berg", "type": EntityType.STAGE},
    {"canonical": "Duszniki - Zieleniec 2", "input": "dushniki", "type": EntityType.STAGE},
    {"canonical": "6 Uren van Kortrijk 2024", "input": "kortrik", "type": EntityType.RALLY},
    {"canonical": "Rali Serras de Fafe 2025", "input": "Serras de Fafe", "type": EntityType.RALLY},
    {"canonical": "7bet Rally Lazdijai 2025", "input": "lazdiai", "type": EntityType.RALLY},
    {"canonical": "Rali Terras d'Aboboreira 2026", "input": "aboborera", "type": EntityType.RALLY},
    {"canonical": "Polski Rajd Legend 2026", "input": "Polski Raid Legend", "type": EntityType.RALLY},
    {"canonical": "Rally Vranov 2026", "input": "Rally Vranow", "type": EntityType.RALLY},
    {"canonical": "OBM Land der 1000 Hügel Rallye 2026", "input": "1000 Hugel Rallye", "type": EntityType.RALLY},
    {"canonical": "Rallijsprints Cesavine 2026", "input": "Cesavine", "type": EntityType.RALLY},
    {"canonical": "Rallye Régional des Ardennes 2025", "input": "Regional des Ardennes", "type": EntityType.RALLY},
    {"canonical": "Century 21 Portugal Rally Series - Castelo Branco 2025", "input": "Castelo Branco 2025", "type": EntityType.RALLY},
    {"canonical": "Assess Ireland International Rally of the Lakes 2026", "input": "Rally of the Lakes", "type": EntityType.RALLY},
    {"canonical": "Clonakilty Park Hotel West Cork Rally 2026", "input": "West Cork Rally", "type": EntityType.RALLY},
    {"canonical": "Samsonas Rally Fivemiletown 2026", "input": "Fivemiletown Rally", "type": EntityType.RALLY},
    {"canonical": "Modern Tyres Ulster Rally 2025", "input": "Ulster Rally 2025", "type": EntityType.RALLY},
    {"canonical": "Raven's Rock Stages Rally 2025", "input": "Ravens Rock Stages", "type": EntityType.RALLY},
    {"canonical": "Birr Stages Rally 2026", "input": "Birr Stages 2026", "type": EntityType.RALLY},
    {"canonical": "Fastnet Stages Rally 2025", "input": "Fastnet Stages 2025", "type": EntityType.RALLY},
    {"canonical": "HK Cavan Stages Rally 2025", "input": "Cavan Stages 2025", "type": EntityType.RALLY},
    {"canonical": "Jon-Gunnar Støten", "input": "Jon Gunnar Stoten", "type": EntityType.DRIVER},
    {"canonical": "Michal Babička", "input": "Michal Babicka", "type": EntityType.DRIVER},
    {"canonical": "Adam Zelík", "input": "Adam Zelik", "type": EntityType.DRIVER},
    {"canonical": "Věroslav Cvrček", "input": "Veroslav Cvrcek", "type": EntityType.DRIVER},
    {"canonical": "Piotr Krotoszyński", "input": "Piotr Krotoszynski", "type": EntityType.DRIVER},
    {"canonical": "Hervé Emeriau", "input": "Herve Emerio", "type": EntityType.DRIVER},
    {"canonical": "José Paula", "input": "Jose Pawla", "type": EntityType.DRIVER},
    {"canonical": "Sergio Ramón Arrom", "input": "Sergio Ramon", "type": EntityType.DRIVER},
    {"canonical": "Raphaël Czwartkowski", "input": "Raphael Czwartkovski", "type": EntityType.DRIVER},
    {"canonical": "Vítor Matias", "input": "Vitor Mathias", "type": EntityType.DRIVER},
    {"canonical": "Stephen O'Connor", "input": "Steven OConnor", "type": EntityType.DRIVER},
    {"canonical": "Diarmuid O'Toole", "input": "Dermot OToole", "type": EntityType.DRIVER},
    {"canonical": "Tanja Zingelmann-Hartjen", "input": "Tanja Zingelmann", "type": EntityType.DRIVER},
    {"canonical": "Nenad Lončarič", "input": "Nenad Loncarich", "type": EntityType.DRIVER},
    {"canonical": "Matej Bogović", "input": "Matej Bogovich", "type": EntityType.DRIVER},
    {"canonical": "Andrej Medić", "input": "Andrej Medich", "type": EntityType.DRIVER},
    {"canonical": "John Shanahan jnr.", "input": "John Shanahan Jr", "type": EntityType.DRIVER},
    {"canonical": "Max Freeman", "input": "Max Frieman", "type": EntityType.DRIVER},
    {"canonical": "Jan-Erik Mäll", "input": "Jan Erik Mall", "type": EntityType.DRIVER},
    {"canonical": "Catharina Schmidt", "input": "Katarina Schmidt", "type": EntityType.DRIVER},
    {"canonical": "Paweł Molgo", "input": "Pawel Molgo", "type": EntityType.DRIVER},
    {"canonical": "Shea Breen", "input": "Shea Breen", "type": EntityType.DRIVER},
    {"canonical": "Jon-Gunnar Støten", "input": "Stoten", "type": EntityType.DRIVER},
    {"canonical": "Věroslav Cvrček", "input": "Cvrcek", "type": EntityType.DRIVER},
    {"canonical": "Woodstoxx Kemmelberg 1", "input": "Kemmelberg 1", "type": EntityType.STAGE},
    {"canonical": "Duszniki - Zieleniec 2", "input": "Duszniki Zieleniec", "type": EntityType.STAGE},
    {"canonical": "Seixoso 2", "input": "Seiksozo", "type": EntityType.STAGE},
    {"canonical": "Drumhallagh 2", "input": "Drumhalagh", "type": EntityType.STAGE},
    {"canonical": "Dikkebus 1", "input": "Dikebus", "type": EntityType.STAGE},
    {"canonical": "Fafe 2Powerstage", "input": "Fafe Powerstage", "type": EntityType.STAGE},
    {"canonical": "Knockalla 2", "input": "Knokalla", "type": EntityType.STAGE},
    {"canonical": "Dunworley 2", "input": "Dunworly", "type": EntityType.STAGE},
    {"canonical": "Kellymount 1", "input": "Kelley Mount 1", "type": EntityType.STAGE},
]

# 106 Negatives from Dart audited_resolver_safety_benchmark_test.dart
NEGATIVES = []
for name in [
    "Josh Smith", "Sam Williams", "Keith O'Connor", "Craig McErlean",
    "Callum Breen", "Paul Moffett", "David Cronin", "Michael Devine",
    "Mark Freeman", "John Breen", "Brain", "Breenan", "Moffitt",
    "Moffat", "Cronan", "Devaney", "Molgow", "Stotenberg", "Zelinski", "Babic",
]:
    NEGATIVES.append({"input": name, "type": EntityType.DRIVER})

for name in [
    "Rally of the Mountains", "International Stages", "West Coast Rally",
    "Cork 25 Stages", "Donegal 1972", "Galway 1981", "Lakes Rally 1990",
    "Ulster Stages 1965", "Aluksne 1999", "Fafe Classic 1985",
]:
    NEGATIVES.append({"input": name, "type": EntityType.RALLY})

for name in [
    "Super Stage 1", "Powerstage Final", "Mountain Pass 2",
    "Forest Stage 3", "Sprint Stage 1", "Town Stage 2",
]:
    NEGATIVES.append({"input": name, "type": EntityType.STAGE})

for i in range(1, 71):
    NEGATIVES.append({
        "input": f"FictionalEntity{i} PseudoName",
        "type": EntityType.DRIVER if i % 2 == 0 else EntityType.RALLY,
    })


def _same_target(actual: str, expected: str) -> bool:
    a = collapse_spaces(strip_descriptors(actual))
    e = collapse_spaces(strip_descriptors(expected))
    return a == e or (e in a) or (a in e)


def _query(input_str: str, entity_type: EntityType) -> SearchQuery:
    intent = (
        SearchIntent.SEARCH_DRIVER_VIDEOS
        if entity_type == EntityType.DRIVER
        else (SearchIntent.SEARCH_RALLIES if entity_type == EntityType.RALLY else SearchIntent.SEARCH_VIDEO_ACTIONS)
    )
    return SearchQuery(
        intent=intent,
        driver_names=[input_str] if entity_type == EntityType.DRIVER else [],
        rally_names=[input_str] if entity_type == EntityType.RALLY else [],
        stage_names=[input_str] if entity_type == EntityType.STAGE else [],
        person_role=PersonRole.ANY,
    )


class _DummyLegacyRepo:
    async def lookup_rallies(self, phrase, **kwargs): return []
    async def lookup_drivers(self, phrase, **kwargs): return []
    async def lookup_stages(self, phrase, **kwargs): return []
    async def lookup_cities(self, phrase, **kwargs): return []
    async def lookup_uploaders(self, phrase, **kwargs): return []


@pytest.mark.live_db
@pytest.mark.benchmark
async def test_audited_168_safety_benchmark():
    engine = get_engine()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        entities = await source.load_entities()

    service = InMemoryEntitySearchService.from_entities(entities)
    fallback_metrics = EntitySearchFallbackMetrics()

    new_resolver = DatabaseEntityResolver(
        repository=EntitySearchLookupAdapter(
            search_service=service,
            city_fallback=_DummyLegacyRepo(),
            metrics=fallback_metrics,
        )
    )

    resolver = ControlledFallbackEntityResolver(
        legacy_resolver=DatabaseEntityResolver(repository=_DummyLegacyRepo()),
        entity_search_resolver=new_resolver,
        config=EntitySearchFallbackConfig(mode=EntitySearchFallbackMode.FALLBACK),
        metrics=fallback_metrics,
    )

    assert len(POSITIVES) == 62
    assert len(NEGATIVES) == 106

    correct_confident = 0
    wrong_positive_confident = 0
    positive_clarification = 0
    positive_no_match = 0

    negative_wrong_confident = 0
    negative_clarification = 0
    negative_rejection = 0

    positive_details = []
    negative_details = []

    for item in POSITIVES:
        query = _query(item["input"], item["type"])
        result = await resolver.resolve(query)
        resolved_cand = next(
            (r.resolved_candidate for r in result.resolutions.values() if r.is_resolved and r.resolved_candidate),
            None,
        )
        resolved_name = resolved_cand.canonical_name if resolved_cand else None
        correct = resolved_name is not None and _same_target(resolved_name, item["canonical"])

        if correct:
            correct_confident += 1
        elif resolved_name is not None:
            wrong_positive_confident += 1
        elif result.requires_clarification:
            positive_clarification += 1
        else:
            positive_no_match += 1

        positive_details.append({
            "input": item["input"],
            "canonical": item["canonical"],
            "type": item["type"].value,
            "resolved": resolved_name,
            "correct": correct,
            "clarification": result.requires_clarification,
            "error": result.error,
        })

    for item in NEGATIVES:
        query = _query(item["input"], item["type"])
        result = await resolver.resolve(query)
        resolved_cand = next(
            (r.resolved_candidate for r in result.resolutions.values() if r.is_resolved and r.resolved_candidate),
            None,
        )
        resolved_name = resolved_cand.canonical_name if resolved_cand else None

        if resolved_name is not None:
            negative_wrong_confident += 1
        elif result.requires_clarification:
            negative_clarification += 1
        else:
            negative_rejection += 1

        negative_details.append({
            "input": item["input"],
            "type": item["type"].value,
            "resolved": resolved_name,
            "clarification": result.requires_clarification,
            "error": result.error,
        })

    null_account_safety = []
    null_cases = [
        ("Shea Breen", PersonRole.ANY, "same visible name / different IDs"),
        ("Paweł Molgo", PersonRole.CO_DRIVER, "wrong PersonRole"),
        ("David Young", PersonRole.ANY, "common surname collision"),
        ("Paweł", PersonRole.ANY, "partial person name"),
        ("John O'Sullivan", PersonRole.DRIVER, "duplicate person names"),
    ]

    for name, role, desc in null_cases:
        q = SearchQuery(
            intent=SearchIntent.SEARCH_DRIVER_RALLIES,
            driver_names=[name],
            person_role=role,
        )
        res = await resolver.resolve(q)
        resolved = next(
            (r.resolved_candidate for r in res.resolutions.values() if r.is_resolved and r.resolved_candidate),
            None,
        )
        null_account_safety.append({
            "case": desc,
            "input": name,
            "role": role.value,
            "resolvedCanonicalId": resolved.id if resolved else None,
            "clarification": res.requires_clarification,
            "error": res.error,
            "safe": resolved is None,
        })

    report = {
        "totalQueries": len(POSITIVES) + len(NEGATIVES),
        "positive": {
            "queries": len(POSITIVES),
            "correctConfident": correct_confident,
            "wrongConfident": wrong_positive_confident,
            "clarification": positive_clarification,
            "noMatch": positive_no_match,
            "details": positive_details,
        },
        "negativeConfusable": {
            "queries": len(NEGATIVES),
            "wrongConfident": negative_wrong_confident,
            "clarification": negative_clarification,
            "rejection": negative_rejection,
            "details": negative_details,
        },
        "falseConfidentAutoResolution": wrong_positive_confident + negative_wrong_confident,
        "fallbackTelemetry": fallback_metrics.to_map(),
        "nullAccountSafety": null_account_safety,
    }

    report_path = Path(__file__).parent / "py_audited_resolver_safety_report.json"
    report_path.write_text(json.dumps(report, indent=2))

    # Hard Gates
    assert wrong_positive_confident == 0, f"Wrong positive confident count: {wrong_positive_confident}"
    assert negative_wrong_confident == 0, f"Negative wrong confident count: {negative_wrong_confident}"
    assert (wrong_positive_confident + negative_wrong_confident) == 0, "FALSE_CONFIDENT MUST BE 0"
    assert all(entry["safe"] for entry in null_account_safety), "All null account safety cases must be safe"
