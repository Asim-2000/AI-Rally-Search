from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.config import get_settings
from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.models import EntitySearchRequest, SearchEntityType
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.mock_provider import MockProvider
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService
from app.voice.openai_provider import OpenAISpeechToTextProvider
from app.voice.models import SpokenAudioContext
from app.voice.provider import SpeechProviderConfig
from app.voice.service import VoiceSearchService

ROOT = Path(__file__).parents[3]
MANIFEST = ROOT / "test/eval/entity_search/human_voice_smoke_manifest.json"
AUDIO_DIR = ROOT / "test/eval/audio/human"
REPORT = Path(__file__).with_name("py5_human_voice_smoke_report.json")
SETTINGS = get_settings()
HAS_LIVE = bool(SETTINGS.openai_api_key.get_secret_value() and SETTINGS.db_host)


def speech_provider():
    return OpenAISpeechToTextProvider(SpeechProviderConfig(
        provider="openai",
        model=SETTINGS.speech_model,
        api_key=SETTINGS.openai_api_key.get_secret_value(),
        base_url=SETTINGS.openai_base_url,
        timeout_seconds=SETTINGS.speech_timeout_seconds,
        dynamic_top3_enabled=False,
        preprocessing_strategy="raw",
    ))


@pytest.mark.live_stt
@pytest.mark.live_db
@pytest.mark.voice
@pytest.mark.skipif(not HAS_LIVE, reason="OpenAI/DB configuration unavailable")
async def test_human_audio_smoke_corpus_reports_safe_resolution():
    manifest = json.loads(MANIFEST.read_text())
    engine = get_engine()
    async with engine.connect() as connection:
        entities = await MySqlEntitySearchDataSource(connection=connection).load_entities()
    entity_search = InMemoryEntitySearchService.from_entities(entities)
    rows = []
    for fixture in manifest["fixtures"]:
        path = ROOT / fixture["audioFile"]
        transcription = await speech_provider().transcribe(
            SpokenAudioContext(bytes=path.read_bytes(), format="wav"),
            filename=path.name,
            language=fixture["language"],
        )
        entity_type = {
            "rally": SearchEntityType.RALLY,
            "person": SearchEntityType.PERSON,
            "city": SearchEntityType.RALLY,
        }[fixture["entityType"]]
        candidates = await entity_search.search(EntitySearchRequest(
            raw_mention=transcription.text,
            entity_type=entity_type,
            limit=5,
        ))
        expected_ids = set(fixture.get("expectedCanonicalIds") or [])
        top = candidates[0] if candidates else None
        if not fixture.get("canonicalScorable", False):
            outcome = "AMBIGUOUS_NOT_SCORED"
        elif top is None:
            outcome = "NO_MATCH"
        elif top.canonical_id in expected_ids or top.canonical_name == fixture.get("expectedCanonicalName"):
            outcome = "RESOLVED"
        elif top.score < .75:
            outcome = "CLARIFICATION"
        else:
            outcome = "WRONG_CONFIDENT"
        rows.append({
            "fixtureId": fixture["fixtureId"],
            "transcript": transcription.text,
            "expectedCanonicalName": fixture.get("expectedCanonicalName"),
            "topCandidateId": top.canonical_id if top else None,
            "topCandidateName": top.canonical_name if top else None,
            "topScore": top.score if top else None,
            "outcome": outcome,
            "model": transcription.model,
        })
        transcription.dispose_audio()
    REPORT.write_text(json.dumps({
        "status": "LABELED_SMOKE_TEST_ONLY",
        "dynamicTop3Enabled": False,
        "preprocessing": "raw_no_op",
        "rows": rows,
    }, indent=2))
    assert all(row["outcome"] != "WRONG_CONFIDENT" for row in rows)


@pytest.mark.live_stt
@pytest.mark.live_db
@pytest.mark.voice
@pytest.mark.skipif(not HAS_LIVE, reason="OpenAI/DB configuration unavailable")
async def test_one_real_audio_through_stt_query_resolver_and_mysql():
    engine = get_engine()
    async with engine.connect() as connection:
        entities = await MySqlEntitySearchDataSource(connection=connection).load_entities()
        entity_search = InMemoryEntitySearchService.from_entities(entities)
        resolver = DatabaseEntityResolver(repository=EntitySearchLookupAdapter(search_service=entity_search))
        conversation = ConversationalSearchService(
            query_parser=QueryUnderstandingService(MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))),
            entity_resolver=resolver,
            repository=SearchRepository(connection),
        )
        voice = VoiceSearchService(speech_provider=speech_provider(), conversation_service=conversation)
        audio_path = AUDIO_DIR / "record_out.wav"
        outcome = await voice.transcribe_and_search(
            audio_path.read_bytes(),
            filename=audio_path.name,
            language="en",
            session=SearchConversationSession(),
        )
        assert outcome.result.is_success
        assert outcome.result.resolved_query.driver_names == ["Max Freeman"]
        assert outcome.result.resolved_query.driver_ids
        assert outcome.result.search_response.total_count > 0
        assert all(item.rally_id for item in outcome.result.search_response.results)
        assert outcome.transcription.audio_context.is_disposed
        report = json.loads(REPORT.read_text()) if REPORT.exists() else {}
        report["fullIntegration"] = {
            "audioFile": "test/eval/audio/human/record_out.wav",
            "transcript": outcome.transcription.text,
            "model": outcome.transcription.model,
            "intent": outcome.result.resolved_query.intent.value,
            "canonicalDriverIds": outcome.result.resolved_query.driver_ids,
            "resultCount": outcome.result.search_response.total_count,
            "representativeRallyIds": [
                item.rally_id for item in outcome.result.search_response.results[:3]
            ],
            "audioDisposed": outcome.transcription.audio_context.is_disposed,
        }
        REPORT.write_text(json.dumps(report, indent=2))
