from __future__ import annotations

import time
from dataclasses import dataclass, field
from datetime import timedelta
from typing import Protocol
from .eligibility import is_candidate_role_allowed
from .models import CanonicalSearchEntity, EntitySearchRequest, SearchEntityType
from .normalization import strip_descriptors
from .phonetics import AlgorithmicPronunciationEncoder

_encoder = AlgorithmicPronunciationEncoder()


@dataclass(frozen=True)
class EntityCandidateGenerationResult:
    canonical_ids: list[str]
    pre_ranked_canonical_ids: list[str] = field(default_factory=list)
    full_universe_size: int = 0
    used_full_scan_escape: bool = False
    latency: timedelta = timedelta(0)
    evidence_keys_matched: int = 0


class IEntityCandidateGenerator(Protocol):
    def build(self, entities: list[CanonicalSearchEntity]) -> None:
        ...

    def generate(self, request: EntitySearchRequest) -> EntityCandidateGenerationResult:
        ...

    @property
    def estimated_bytes(self) -> int:
        ...


class FullScanCandidateGenerator:
    """Full scan candidate generator acting as oracle / baseline."""

    def __init__(self) -> None:
        self._entities: list[CanonicalSearchEntity] = []

    @property
    def estimated_bytes(self) -> int:
        return 0

    def build(self, entities: list[CanonicalSearchEntity]) -> None:
        self._entities = list(entities)

    def generate(self, request: EntitySearchRequest) -> EntityCandidateGenerationResult:
        start = time.perf_counter()
        ids = [
            entity.canonical_id
            for entity in self._entities
            if entity.entity_type == request.entity_type
            and is_candidate_role_allowed(entity, request.person_role)
        ]
        elapsed = timedelta(seconds=time.perf_counter() - start)
        return EntityCandidateGenerationResult(
            canonical_ids=ids,
            pre_ranked_canonical_ids=list(ids),
            full_universe_size=len(ids),
            used_full_scan_escape=False,
            latency=elapsed,
            evidence_keys_matched=0,
        )


def _get_entity_names(entity: CanonicalSearchEntity) -> set[str]:
    values = {entity.canonical_name.strip()}
    stored = entity.metadata.get("searchableNames") or entity.metadata.get("searchable_names")
    if isinstance(stored, (list, set, tuple)):
        for val in stored:
            v_str = str(val).strip()
            if v_str:
                values.add(v_str)
    return values


def _get_grams(value: str, length: int) -> set[str]:
    if not value:
        return set()
    if len(value) <= length:
        return {value}
    return {value[i:i + length] for i in range(len(value) - length + 1)}


class InvertedIndexCandidateGenerator:
    """Inverted index candidate generator for fast and accurate candidate retrieval."""

    def __init__(
        self,
        *,
        person_pool_limit: int = 1200,
        other_pool_limit: int = 600,
        minimum_pool: int = 25,
    ) -> None:
        self.person_pool_limit = person_pool_limit
        self.other_pool_limit = other_pool_limit
        self.minimum_pool = minimum_pool

        self._entities: dict[str, CanonicalSearchEntity] = {}
        self._ordinals: dict[str, int] = {}
        self._by_type: dict[SearchEntityType, list[str]] = {}

        self._canonical_exact: dict[SearchEntityType, dict[str, set[str]]] = {}
        self._exact: dict[SearchEntityType, dict[str, set[str]]] = {}
        self._tokens: dict[SearchEntityType, dict[str, set[str]]] = {}
        self._bigrams: dict[SearchEntityType, dict[str, set[str]]] = {}
        self._trigrams: dict[SearchEntityType, dict[str, set[str]]] = {}
        self._phonetic: dict[SearchEntityType, dict[str, set[str]]] = {}
        self._prefixes: dict[SearchEntityType, dict[str, set[str]]] = {}
        self._estimated_bytes = 0

    @property
    def estimated_bytes(self) -> int:
        return self._estimated_bytes

    def build(self, entities: list[CanonicalSearchEntity]) -> None:
        self._entities.clear()
        self._ordinals.clear()
        self._by_type.clear()
        for family in (
            self._canonical_exact,
            self._exact,
            self._tokens,
            self._bigrams,
            self._trigrams,
            self._phonetic,
            self._prefixes,
        ):
            family.clear()

        bytes_count = 0
        for ordinal, entity in enumerate(entities):
            self._entities[entity.canonical_id] = entity
            self._ordinals[entity.canonical_id] = ordinal
            self._by_type.setdefault(entity.entity_type, []).append(entity.canonical_id)

            self._add_to_index(
                self._canonical_exact,
                entity.entity_type,
                entity.canonical_name.strip().lower(),
                entity.canonical_id,
            )

            for name in _get_entity_names(entity):
                normalized = strip_descriptors(name)
                collapsed = normalized.replace(" ", "")
                tokens = [t for t in normalized.split() if t]

                self._add_to_index(self._exact, entity.entity_type, normalized, entity.canonical_id)
                for token in tokens:
                    self._add_to_index(self._tokens, entity.entity_type, token, entity.canonical_id)
                    for length in range(2, min(6, len(token) + 1)):
                        self._add_to_index(
                            self._prefixes,
                            entity.entity_type,
                            token[:length],
                            entity.canonical_id,
                        )

                for gram in _get_grams(collapsed, 2):
                    self._add_to_index(self._bigrams, entity.entity_type, gram, entity.canonical_id)

                for gram in _get_grams(collapsed, 3):
                    self._add_to_index(self._trigrams, entity.entity_type, gram, entity.canonical_id)

                self._add_to_index(
                    self._phonetic,
                    entity.entity_type,
                    _encoder.encode_collapsed_query(normalized),
                    entity.canonical_id,
                )

        for family in (
            self._canonical_exact,
            self._exact,
            self._tokens,
            self._bigrams,
            self._trigrams,
            self._phonetic,
            self._prefixes,
        ):
            for typed_map in family.values():
                for key, val_set in typed_map.items():
                    bytes_count += 48 + len(key) * 2 + len(val_set) * 16

        self._estimated_bytes = bytes_count

    def generate(self, request: EntitySearchRequest) -> EntityCandidateGenerationResult:
        start = time.perf_counter()
        universe = [
            cid
            for cid in self._by_type.get(request.entity_type, [])
            if is_candidate_role_allowed(self._entities[cid], request.person_role)
        ]

        normalized = strip_descriptors(request.raw_mention)
        collapsed = normalized.replace(" ", "")
        scores: dict[str, int] = {}
        evidence = 0

        def collect(
            family: dict[SearchEntityType, dict[str, set[str]]],
            key: str,
            weight: int,
        ) -> None:
            nonlocal evidence
            ids = family.get(request.entity_type, {}).get(key)
            if not ids:
                return
            evidence += 1
            for cid in ids:
                entity = self._entities.get(cid)
                if entity is not None and is_candidate_role_allowed(entity, request.person_role):
                    scores[cid] = scores.get(cid, 0) + weight

        collect(self._canonical_exact, request.raw_mention.strip().lower(), 12000)
        collect(self._exact, normalized, 10000)

        for token in [t for t in normalized.split() if t]:
            collect(self._tokens, token, 200)
            for length in range(2, min(6, len(token) + 1)):
                collect(self._prefixes, token[:length], 5 * length)

        for gram in _get_grams(collapsed, 3):
            collect(self._trigrams, gram, 20)

        for gram in _get_grams(collapsed, 2):
            collect(self._bigrams, gram, 4)

        collect(self._phonetic, _encoder.encode_collapsed_query(normalized), 300)

        # Sort descending by score, tie-break ascending by canonical_id
        ordered = sorted(scores.items(), key=lambda item: (-item[1], item[0]))

        limit = (
            self.person_pool_limit
            if request.entity_type == SearchEntityType.PERSON
            else self.other_pool_limit
        )
        suspicious = evidence == 0 or len(ordered) < self.minimum_pool

        pre_ranked = universe if suspicious else [item[0] for item in ordered[:limit]]
        ids = sorted(pre_ranked, key=lambda cid: self._ordinals[cid])

        elapsed = timedelta(seconds=time.perf_counter() - start)
        return EntityCandidateGenerationResult(
            canonical_ids=ids,
            pre_ranked_canonical_ids=pre_ranked,
            full_universe_size=len(universe),
            used_full_scan_escape=suspicious,
            latency=elapsed,
            evidence_keys_matched=evidence,
        )

    @staticmethod
    def _add_to_index(
        family: dict[SearchEntityType, dict[str, set[str]]],
        entity_type: SearchEntityType,
        key: str,
        entity_id: str,
    ) -> None:
        if not key:
            return
        typed_map = family.setdefault(entity_type, {})
        key_set = typed_map.setdefault(key, set())
        key_set.add(entity_id)
