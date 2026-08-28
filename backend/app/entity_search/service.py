from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from datetime import timedelta
from typing import Any, Protocol
from .candidate_generator import (
    IEntityCandidateGenerator,
    InvertedIndexCandidateGenerator,
    _get_grams,
)
from .data_source import IEntitySearchDataSource, StaticDataSource
from .eligibility import is_candidate_role_allowed
from .models import (
    CanonicalSearchEntity,
    EntitySearchCandidate,
    EntitySearchIndexStats,
    EntitySearchQueryStats,
    EntitySearchRequest,
    SearchEntityType,
)
from .normalization import normalize, strip_descriptors
from .phonetics import AlgorithmicPronunciationEncoder
from .scorer import score_name

_encoder = AlgorithmicPronunciationEncoder()


class _IndexedName:
    def __init__(self, name: str) -> None:
        self.name = name
        self.normalized = strip_descriptors(name)
        self.collapsed = self.normalized.replace(" ", "")
        self.tokens = {t for t in self.normalized.split() if t}
        self.bigrams = _get_grams(self.collapsed, 2)
        self.trigrams = _get_grams(self.collapsed, 3)
        self.phonetic = _encoder.encode_collapsed_query(self.normalized)


def _searchable_names(entity: CanonicalSearchEntity) -> list[str]:
    names = {entity.canonical_name.strip()}
    stored = entity.metadata.get("searchableNames") or entity.metadata.get("searchable_names")
    if isinstance(stored, (list, set, tuple)):
        for val in stored:
            v_str = str(val).strip()
            if v_str:
                names.add(v_str)
    return list(names)


class _IndexedEntity:
    def __init__(self, source: CanonicalSearchEntity) -> None:
        self.source = source
        self.names = [_IndexedName(n) for n in _searchable_names(source)]


class IEntitySearchService(Protocol):
    async def search(self, request: EntitySearchRequest) -> list[EntitySearchCandidate]:
        ...

    async def rebuild(self) -> EntitySearchIndexStats:
        ...

    @property
    def index_stats(self) -> EntitySearchIndexStats | None:
        ...


class InMemoryEntitySearchService:
    """In-memory entity search engine with indexed multi-signal retrieval and ranking."""

    def __init__(
        self,
        *,
        data_source: IEntitySearchDataSource,
        candidate_generator: IEntityCandidateGenerator | None = None,
    ) -> None:
        self.data_source = data_source
        self.candidate_generator = (
            candidate_generator
            if candidate_generator is not None
            else InvertedIndexCandidateGenerator()
        )
        self._index_by_id: dict[str, _IndexedEntity] = {}
        self._index_stats: EntitySearchIndexStats | None = None
        self.last_query_stats: EntitySearchQueryStats | None = None
        self._initial_load_task: asyncio.Task[EntitySearchIndexStats] | None = None
        self._lock = asyncio.Lock()

    @classmethod
    def from_entities(
        cls,
        entities: list[CanonicalSearchEntity],
        *,
        candidate_generator: IEntityCandidateGenerator | None = None,
    ) -> InMemoryEntitySearchService:
        service = cls(
            data_source=StaticDataSource(entities),
            candidate_generator=candidate_generator,
        )
        service._replace_index(entities, timedelta(0))
        return service

    @property
    def index_stats(self) -> EntitySearchIndexStats | None:
        return self._index_stats

    async def rebuild(self) -> EntitySearchIndexStats:
        async with self._lock:
            start = time.perf_counter()
            entities = await self.data_source.load_entities()
            elapsed = timedelta(seconds=time.perf_counter() - start)
            return self._replace_index(entities, elapsed)

    def _replace_index(
        self,
        entities: list[CanonicalSearchEntity],
        elapsed: timedelta,
    ) -> EntitySearchIndexStats:
        next_entities = [
            _IndexedEntity(e)
            for e in entities
            if e.canonical_id and e.canonical_name.strip()
        ]
        self._index_by_id = {
            entity.source.canonical_id: entity for entity in next_entities
        }
        self.candidate_generator.build([entity.source for entity in next_entities])

        canonical_bytes = 0
        for e in next_entities:
            name_sum = sum(
                len(n.name)
                + len(n.normalized)
                + len(n.collapsed)
                + len(n.phonetic)
                + len("".join(n.bigrams))
                + len("".join(n.trigrams))
                for n in e.names
            )
            canonical_bytes += (
                160
                + 2
                * (
                    len(e.source.canonical_id)
                    + len(e.source.canonical_name)
                    + name_sum
                )
            )

        total_bytes = canonical_bytes + self.candidate_generator.estimated_bytes
        self._index_stats = EntitySearchIndexStats(
            entity_count=len(next_entities),
            build_time=elapsed,
            estimated_bytes=total_bytes,
            canonical_estimated_bytes=canonical_bytes,
            posting_list_estimated_bytes=self.candidate_generator.estimated_bytes,
        )
        return self._index_stats

    async def search(self, request: EntitySearchRequest) -> list[EntitySearchCandidate]:
        if self._index_stats is None:
            async with self._lock:
                if self._index_stats is None:
                    await self.rebuild()

        start = time.perf_counter()
        raw = request.raw_mention.strip()
        if not raw or request.limit <= 0:
            elapsed = timedelta(seconds=time.perf_counter() - start)
            self.last_query_stats = EntitySearchQueryStats(
                entity_type=request.entity_type,
                raw_candidates_evaluated=0,
                surviving_candidates=0,
                returned_candidates=0,
                latency=elapsed,
            )
            return []

        generated = self.candidate_generator.generate(request)
        scoring_start = time.perf_counter()

        normalized = strip_descriptors(raw)
        collapsed = normalized.replace(" ", "")
        tokens = {t for t in normalized.split() if t}
        bigrams = _get_grams(collapsed, 2)
        trigrams = _get_grams(collapsed, 3)
        phonetic = _encoder.encode_collapsed_query(normalized)

        results: list[EntitySearchCandidate] = []
        evaluated = 0

        for cid in generated.canonical_ids:
            entity = self._index_by_id.get(cid)
            if (
                entity is None
                or entity.source.entity_type != request.entity_type
                or not is_candidate_role_allowed(entity, request.person_role)
            ):
                continue

            evaluated += 1
            context = self._context_score(entity, request)

            best_score = -1.0
            best_strongest = -1.0
            best_signals = None
            best_name = ""

            for name in entity.names:
                sc, strongest, sigs = score_name(
                    raw,
                    normalized,
                    collapsed,
                    tokens,
                    bigrams,
                    trigrams,
                    phonetic,
                    name.name,
                    name.normalized,
                    name.collapsed,
                    name.tokens,
                    name.bigrams,
                    name.trigrams,
                    name.phonetic,
                    context,
                )
                if sc > best_score:
                    best_score = sc
                    best_strongest = strongest
                    best_signals = sigs
                    best_name = name.name

            if best_signals is None or best_strongest < 0.18:
                continue

            exact = best_signals.exact_score
            normalized_exact = best_signals.normalized_exact_score
            tok = best_signals.token_score
            ngram = best_signals.ngram_score
            lexical = best_signals.lexical_score
            phonetic_score = best_signals.phonetic_score

            matched: set[str] = set()
            if exact > 0:
                matched.add("exact")
            if normalized_exact > 0:
                matched.add("normalized_exact")
            if tok >= 0.5:
                matched.add("token")
            if ngram >= 0.45:
                matched.add("character_ngram")
            if lexical >= 0.65:
                matched.add("lexical")
            if phonetic_score >= 0.65:
                matched.add("phonetic")
            if context > 0:
                matched.add("context")

            meta = dict(entity.source.metadata)
            meta["matchedSearchableName"] = best_name
            results.append(
                EntitySearchCandidate(
                    canonical_id=entity.source.canonical_id,
                    canonical_name=entity.source.canonical_name,
                    entity_type=entity.source.entity_type,
                    score=best_score,
                    signals=best_signals,
                    matched_by=matched,
                    metadata=meta,
                )
            )

        # Sort descending by score, tie-break ascending by canonical_name
        results.sort(key=lambda c: (-c.score, c.canonical_name))

        surviving = len(results)
        returned = results[:request.limit]
        scoring_elapsed = timedelta(seconds=time.perf_counter() - scoring_start)
        total_elapsed = timedelta(seconds=time.perf_counter() - start)

        self.last_query_stats = EntitySearchQueryStats(
            entity_type=request.entity_type,
            raw_candidates_evaluated=evaluated,
            surviving_candidates=surviving,
            returned_candidates=len(returned),
            latency=total_elapsed,
            candidate_generation_latency=generated.latency,
            scoring_latency=scoring_elapsed,
            full_universe_size=generated.full_universe_size,
            generated_candidate_pool=len(generated.canonical_ids),
            used_full_scan_escape=generated.used_full_scan_escape,
        )

        return returned

    @staticmethod
    def _context_score(entity: _IndexedEntity, request: EntitySearchRequest) -> float:
        tested = 0
        matched = 0

        if request.year is not None:
            tested += 1
            if entity.source.metadata.get("year") == request.year:
                matched += 1

        if request.country is not None and request.country.strip():
            tested += 1
            e_country = normalize(str(entity.source.metadata.get("country") or ""))
            r_country = normalize(request.country)
            if e_country == r_country:
                matched += 1

        event_id = request.context.get("eventId")
        if event_id is not None and str(event_id).strip():
            tested += 1
            if str(entity.source.metadata.get("eventId") or "") == str(event_id):
                matched += 1

        return 0.0 if tested == 0 else matched / tested
