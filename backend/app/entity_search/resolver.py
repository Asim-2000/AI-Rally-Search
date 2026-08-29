from __future__ import annotations

from typing import Any, Protocol
from ..domain.search_intent import SearchIntent
from ..domain.search_query import PersonRole, SearchQuery
from .eligibility import is_person_role_eligible
from .models import (
    CandidateOrigin,
    EntityCandidate,
    EntityResolution,
    EntityResolutionResult,
    EntityType,
    SearchEntityType,
)
from .normalization import extract_year, normalize, strip_year
from .scorer import compute_composite_score


class IEntityLookupRepository(Protocol):
    async def lookup_rallies(
        self,
        phrase: str,
        *,
        year: int | None = None,
        country: str | None = None,
        city: str | None = None,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        ...

    async def lookup_drivers(
        self,
        phrase: str,
        *,
        event_id: str | None = None,
        event_name: str | None = None,
        year: int | None = None,
        person_role: PersonRole = PersonRole.ANY,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        ...

    async def lookup_stages(
        self,
        phrase: str,
        *,
        event_id: str | None = None,
        event_name: str | None = None,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        ...

    async def lookup_cities(
        self,
        phrase: str,
        *,
        country: str | None = None,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        ...

    async def lookup_uploaders(
        self,
        phrase: str,
        *,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        ...


class DatabaseEntityResolver:
    """Database-backed deterministic Entity Resolution Service."""

    def __init__(
        self,
        *,
        repository: IEntityLookupRepository,
        min_confidence_threshold: float = 0.75,
        min_score_gap: float = 0.15,
    ) -> None:
        self.repository = repository
        self.min_confidence_threshold = min_confidence_threshold
        self.min_score_gap = min_score_gap
        self._resolution_cache: dict[str, EntityResolution] = {}

    def clear_cache(self) -> None:
        self._resolution_cache.clear()

    async def resolve(
        self,
        query: SearchQuery,
        *,
        context: Any = None,
    ) -> EntityResolutionResult:
        working_query = query.model_copy()
        resolutions: dict[str, EntityResolution] = {}

        primary_resolved_rally: EntityCandidate | None = None
        resolved_rallies: list[str] = []
        resolved_drivers: list[str] = []
        resolved_driver_ids: list[str] = []
        resolved_stages: list[str] = []
        resolved_stage_numbers: list[str] = []
        resolved_cities: list[str] = []

        # =========================================================================
        # STEP 1: RESOLVE RALLIES / EVENTS
        # =========================================================================
        raw_rallies = list(query.target_rally_names)

        # Empty entity recovery: if no entity fields were populated, check context/routing for unresolved mentions
        if not raw_rallies and not query.driver_names and not query.stage_names and not query.cities:
            unresolved = []
            routing_plan = None
            if isinstance(context, dict):
                unresolved = context.get("unresolved_mentions", [])
                routing_plan = context.get("routing_plan")
            elif hasattr(context, "extra") and isinstance(context.extra, dict):
                unresolved = context.extra.get("unresolved_mentions", [])
                routing_plan = context.extra.get("routing_plan")
            elif hasattr(context, "unresolved_mentions"):
                unresolved = getattr(context, "unresolved_mentions", [])
            rally_mentions = {
                str(route.raw_value)
                for route in getattr(routing_plan, "entity_routes", [])
                if route.field_name == "unresolved_text"
                and route.entity_type == SearchEntityType.RALLY
            }
            for mention in unresolved:
                if mention and mention.strip() and mention.strip() in rally_mentions:
                    raw_rallies.append(mention.strip())

        if raw_rallies:
            is_video_search = query.intent in (
                SearchIntent.SEARCH_VIDEO_ACTIONS,
                SearchIntent.SEARCH_DRIVER_VIDEOS,
            )
            for raw_rally in raw_rallies:
                if not raw_rally.strip():
                    continue
                rally_res = await self._resolve_rally(
                    raw_rally.strip(),
                    year=query.years[0] if len(query.years) == 1 else None,
                    years=query.years,
                    country=query.countries[0] if len(query.countries) == 1 else None,
                    countries=query.countries,
                    city=query.cities[0] if len(query.cities) == 1 else None,
                    is_video_search=is_video_search,
                )

                # Cross-type recovery: If rally match is weak/missing, check if it is a driver (if intent capability allows it)
                from ..domain.router import INTENT_CAPABILITIES
                capability = INTENT_CAPABILITIES.get(query.intent)
                can_recover_person = (
                    capability is not None
                    and capability.allow_cross_type_recovery
                    and (
                        SearchEntityType.PERSON in capability.allowed_primary_entity_types
                        or SearchEntityType.PERSON in capability.allowed_filter_entity_types
                        or capability.allowed_recovery_transitions.get(SearchEntityType.RALLY) == SearchEntityType.PERSON
                    )
                )
                if (
                    (rally_res.resolved_candidate is None or rally_res.is_ambiguous)
                    and can_recover_person
                    and not query.driver_names
                ):
                    driver_check = await self._resolve_driver(
                        raw_rally.strip(),
                        year=query.years[0] if len(query.years) == 1 else None,
                        years=query.years,
                        person_role=query.person_role,
                    )
                    if driver_check.resolved_candidate is not None and driver_check.confidence >= self.min_confidence_threshold:
                        cand = driver_check.resolved_candidate
                        meta = cand.metadata or {}
                        driver_id = meta.get("driverId") or meta.get("driver_id")
                        codriver_id = meta.get("codriverId") or meta.get("codriver_id")
                        driver_id_clean = str(driver_id).strip() if driver_id is not None and str(driver_id).strip().lower() != "null" else None
                        codriver_id_clean = str(codriver_id).strip() if codriver_id is not None and str(codriver_id).strip().lower() != "null" else None

                        match working_query.person_role:
                            case PersonRole.DRIVER:
                                if driver_id_clean:
                                    resolved_driver_ids.append(driver_id_clean)
                            case PersonRole.CO_DRIVER:
                                if codriver_id_clean:
                                    resolved_driver_ids.append(codriver_id_clean)
                            case PersonRole.ANY:
                                if driver_id_clean:
                                    resolved_driver_ids.append(driver_id_clean)
                                if codriver_id_clean:
                                    resolved_driver_ids.append(codriver_id_clean)
                                if not resolved_driver_ids:
                                    resolved_driver_ids.append(cand.id)

                        resolved_drivers.append(cand.canonical_name)
                        resolutions[f"driver:{raw_rally}"] = driver_check
                        resolutions["driver"] = driver_check
                        new_intent = SearchIntent.SEARCH_DRIVER_RALLIES if working_query.intent == SearchIntent.SEARCH_RALLIES else working_query.intent
                        working_query = working_query.model_copy(
                            update={
                                "intent": new_intent,
                                "driver_names": resolved_drivers,
                                "driver_ids": resolved_driver_ids,
                                "rally_names": [],
                                "event_names": [],
                            }
                        )
                        continue

                resolutions[f"rally:{raw_rally}"] = rally_res
                if len(raw_rallies) == 1:
                    resolutions["rally"] = rally_res

                if rally_res.is_ambiguous:
                    has_strong_country = bool(query.countries)
                    is_broad_rallies_intent = query.intent == SearchIntent.SEARCH_RALLIES
                    is_low_confidence_noise = rally_res.confidence < 0.40

                    if not (is_broad_rallies_intent and has_strong_country and is_low_confidence_noise):
                        if rally_res.strategy == "plausible_candidates" and rally_res.candidate_options:
                            question = f'Did you mean "{rally_res.candidate_options[0].canonical_name}"?'
                        elif len(raw_rallies) > 1:
                            question = f'Which rally event named "{raw_rally.strip()}" do you mean?'
                        elif rally_res.strategy == "multi_year_ambiguity":
                            question = f'Which year or edition of "{raw_rally.strip()}" are you looking for?'
                        else:
                            question = f'Which rally event named "{raw_rally.strip()}" do you mean?'

                        return EntityResolutionResult.clarification(
                            parsed_query=query,
                            clarification_question=question,
                            candidates=rally_res.candidate_options,
                            resolutions=resolutions,
                        )

                if rally_res.resolved_candidate is not None:
                    if primary_resolved_rally is None:
                        primary_resolved_rally = rally_res.resolved_candidate
                    resolved_rallies.append(rally_res.resolved_candidate.canonical_name)
                else:
                    is_entity_required_intent = query.intent in (
                        SearchIntent.GET_RALLY_RESULTS,
                        SearchIntent.GET_RALLY_TOP_FINISHERS,
                    )
                    if is_entity_required_intent:
                        return EntityResolutionResult.failure(
                            f'We couldn\'t confidently identify that rally ("{raw_rally.strip()}").',
                            parsed_query=query,
                        )
                    resolved_rallies.append(raw_rally.strip())

            working_query = working_query.model_copy(
                update={"rally_names": resolved_rallies, "event_names": resolved_rallies}
            )

        # =========================================================================
        # STEP 2: RESOLVE STAGES USING RALLY CONTEXT
        # =========================================================================
        raw_stages = query.stage_names
        if raw_stages:
            for raw_stage in raw_stages:
                if not raw_stage.strip():
                    continue
                stage_res = await self._resolve_stage(
                    raw_stage.strip(),
                    event_id=primary_resolved_rally.id if primary_resolved_rally else None,
                    event_name=primary_resolved_rally.canonical_name if primary_resolved_rally else (query.target_rally_names[0] if query.target_rally_names else None),
                )

                resolutions[f"stage:{raw_stage}"] = stage_res
                if len(raw_stages) == 1:
                    resolutions["stage"] = stage_res

                if stage_res.is_ambiguous:
                    if stage_res.strategy == "plausible_candidates" and stage_res.candidate_options:
                        question = f'Did you mean "{stage_res.candidate_options[0].canonical_name}"?'
                    else:
                        question = f'Which stage named "{raw_stage.strip()}" do you mean?'

                    return EntityResolutionResult.clarification(
                        parsed_query=query,
                        clarification_question=question,
                        candidates=stage_res.candidate_options,
                        resolutions=resolutions,
                    )

                if stage_res.resolved_candidate is not None:
                    resolved_stages.append(stage_res.resolved_candidate.canonical_name)
                    stage_num = (stage_res.resolved_candidate.metadata or {}).get("stageNumber") or (stage_res.resolved_candidate.metadata or {}).get("stage_number")
                    if stage_num:
                        resolved_stage_numbers.append(str(stage_num))
                else:
                    if query.intent == SearchIntent.SEARCH_VIDEO_ACTIONS and len(query.stage_names) == 1:
                        return EntityResolutionResult.failure(
                            f'We couldn\'t confidently identify that stage ("{raw_stage.strip()}").',
                            parsed_query=query,
                        )
                    resolved_stages.append(raw_stage.strip())

            working_query = working_query.model_copy(
                update={
                    "stage_names": resolved_stages,
                    "stage_numbers": resolved_stage_numbers if resolved_stage_numbers else working_query.stage_numbers,
                }
            )

        # =========================================================================
        # STEP 3: RESOLVE DRIVERS USING EVENT / YEAR CONTEXT
        # =========================================================================
        raw_drivers = query.driver_names
        if raw_drivers:
            for raw_driver in raw_drivers:
                if not raw_driver.strip():
                    continue
                driver_res = await self._resolve_driver(
                    raw_driver.strip(),
                    event_id=primary_resolved_rally.id if primary_resolved_rally else None,
                    event_name=primary_resolved_rally.canonical_name if primary_resolved_rally else (query.target_rally_names[0] if query.target_rally_names else None),
                    year=query.years[0] if len(query.years) == 1 else None,
                    years=query.years,
                    person_role=query.person_role,
                )

                resolutions[f"driver:{raw_driver}"] = driver_res
                if len(raw_drivers) == 1:
                    resolutions["driver"] = driver_res

                if driver_res.is_ambiguous:
                    if driver_res.strategy == "plausible_candidates" and driver_res.candidate_options:
                        question = f'Did you mean "{driver_res.candidate_options[0].canonical_name}"?'
                    else:
                        question = f'Which driver named "{raw_driver.strip()}" do you mean?'

                    return EntityResolutionResult.clarification(
                        parsed_query=query,
                        clarification_question=question,
                        candidates=driver_res.candidate_options,
                        resolutions=resolutions,
                    )

                if driver_res.resolved_candidate is not None:
                    cand = driver_res.resolved_candidate
                    meta = cand.metadata or {}
                    driver_id = meta.get("driverId") or meta.get("driver_id")
                    codriver_id = meta.get("codriverId") or meta.get("codriver_id")

                    driver_id_clean = str(driver_id).strip() if driver_id is not None and str(driver_id).strip().lower() != "null" else None
                    codriver_id_clean = str(codriver_id).strip() if codriver_id is not None and str(codriver_id).strip().lower() != "null" else None

                    match working_query.person_role:
                        case PersonRole.DRIVER:
                            if driver_id_clean:
                                resolved_driver_ids.append(driver_id_clean)
                        case PersonRole.CO_DRIVER:
                            if codriver_id_clean:
                                resolved_driver_ids.append(codriver_id_clean)
                        case PersonRole.ANY:
                            if driver_id_clean:
                                resolved_driver_ids.append(driver_id_clean)
                            if codriver_id_clean:
                                resolved_driver_ids.append(codriver_id_clean)
                            if not resolved_driver_ids:
                                resolved_driver_ids.append(cand.id)

                    resolved_drivers.append(cand.canonical_name)
                else:
                    is_driver_required_intent = query.intent in (
                        SearchIntent.SEARCH_DRIVER_VIDEOS,
                        SearchIntent.SEARCH_DRIVER_RALLIES,
                    )
                    if is_driver_required_intent:
                        return EntityResolutionResult.failure(
                            f'We couldn\'t confidently identify that driver ("{raw_driver.strip()}").',
                            parsed_query=query,
                        )
                    resolved_drivers.append(raw_driver.strip())

            working_query = working_query.model_copy(
                update={"driver_ids": resolved_driver_ids, "driver_names": resolved_drivers}
            )

        # =========================================================================
        # STEP 4: RESOLVE CITIES / LOCATIONS
        # =========================================================================
        raw_cities = query.cities
        if raw_cities:
            for raw_city in raw_cities:
                if not raw_city.strip() or raw_city.strip().upper() == "ALL":
                    continue
                city_res = await self._resolve_city(
                    raw_city.strip(),
                    country=query.countries[0] if len(query.countries) == 1 else None,
                    target_rally_name=primary_resolved_rally.canonical_name if primary_resolved_rally else (query.target_rally_names[0] if query.target_rally_names else None),
                )

                resolutions[f"city:{raw_city}"] = city_res
                if len(raw_cities) == 1:
                    resolutions["city"] = city_res

                if city_res.is_ambiguous:
                    if city_res.strategy == "plausible_candidates" and city_res.candidate_options:
                        question = f'Did you mean "{city_res.candidate_options[0].canonical_name}"?'
                    else:
                        question = f'Which location named "{raw_city.strip()}" do you mean?'

                    return EntityResolutionResult.clarification(
                        parsed_query=query,
                        clarification_question=question,
                        candidates=city_res.candidate_options,
                        resolutions=resolutions,
                    )

                if city_res.resolved_candidate is not None:
                    if city_res.resolved_candidate.type == EntityType.RALLY:
                        resolved_rallies.append(city_res.resolved_candidate.canonical_name)
                    else:
                        resolved_cities.append(city_res.resolved_candidate.canonical_name)
                elif city_res.strategy != "none":
                    resolved_cities.append(raw_city.strip())

            working_query = working_query.model_copy(
                update={"cities": resolved_cities, "rally_names": resolved_rallies, "event_names": resolved_rallies}
            )

        all_candidates: list[EntityCandidate] = []
        for res in resolutions.values():
            if res.candidate_options:
                for cand in res.candidate_options:
                    if cand.id not in {c.id for c in all_candidates}:
                        all_candidates.append(cand)
            elif res.resolved_candidate:
                if res.resolved_candidate.id not in {c.id for c in all_candidates}:
                    all_candidates.append(res.resolved_candidate)

        return EntityResolutionResult(
            parsed_query=query,
            resolved_query=working_query,
            requires_clarification=False,
            candidates=all_candidates,
            resolutions=resolutions,
        )

    async def _resolve_rally(
        self,
        phrase: str,
        *,
        year: int | None = None,
        years: list[int] | None = None,
        country: str | None = None,
        countries: list[str] | None = None,
        city: str | None = None,
        is_video_search: bool = False,
    ) -> EntityResolution:
        effective_year = year if year is not None else (years[0] if (years and len(years) == 1) else None)
        effective_country = country if country is not None else (countries[0] if (countries and len(countries) == 1) else None)
        years_key = ",".join(str(y) for y in years) if years else (str(effective_year) if effective_year is not None else "")
        countries_key = ",".join(countries) if countries else (effective_country or "")
        cache_key = f"rally:{phrase.lower()}:{years_key}:{countries_key}:{city or ''}:{is_video_search}"

        if cache_key in self._resolution_cache:
            return self._resolution_cache[cache_key]

        phrase_year = extract_year(phrase)
        lookup_year = phrase_year if phrase_year is not None else effective_year

        candidates = await self.repository.lookup_rallies(
            phrase,
            year=lookup_year,
            country=effective_country,
            city=city,
            limit=35,
        )

        if not candidates and lookup_year is not None:
            candidates = await self.repository.lookup_rallies(
                phrase,
                year=None,
                country=effective_country,
                city=city,
                limit=35,
            )

        if not candidates:
            res = EntityResolution(
                type=EntityType.RALLY,
                raw_phrase=phrase,
                confidence=0.0,
                strategy="none",
            )
            self._resolution_cache[cache_key] = res
            return res

        # A year embedded in the entity phrase identifies the edition. A
        # separate query year remains a downstream search filter and must not
        # penalize the correctly retrieved entity during identity scoring.
        identity_years = [phrase_year] if phrase_year is not None else years
        scored = self._score_candidates(
            phrase,
            candidates,
            year=phrase_year if phrase_year is not None else effective_year,
            years=identity_years,
        )

        has_explicit_years = (effective_year is not None) or bool(years) or (extract_year(phrase) is not None)
        if not has_explicit_years and len(scored) > 1:
            top_name = normalize(scored[0].canonical_name)
            second_name = normalize(scored[1].canonical_name)

            base_top = strip_year(top_name)
            base_second = strip_year(second_name)

            if base_top and base_top == base_second:
                if not is_video_search:
                    res = EntityResolution(
                        type=EntityType.RALLY,
                        raw_phrase=phrase,
                        confidence=0.5,
                        strategy="multi_year_ambiguity",
                        is_ambiguous=True,
                        candidate_options=scored[:5],
                    )
                    self._resolution_cache[cache_key] = res
                    return res

        policy = self._evaluate_candidate_selection(phrase, scored)
        self._resolution_cache[cache_key] = policy
        return policy

    async def _resolve_driver(
        self,
        phrase: str,
        *,
        event_id: str | None = None,
        event_name: str | None = None,
        year: int | None = None,
        years: list[int] | None = None,
        person_role: PersonRole = PersonRole.ANY,
    ) -> EntityResolution:
        effective_year = year if year is not None else (years[0] if (years and len(years) == 1) else None)
        years_key = ",".join(str(y) for y in years) if years else (str(effective_year) if effective_year is not None else "")
        role_key = person_role.value if isinstance(person_role, PersonRole) else str(person_role)
        cache_key = f"driver:{phrase.lower()}:{event_id or ''}:{event_name or ''}:{years_key}:{role_key}"

        if cache_key in self._resolution_cache:
            return self._resolution_cache[cache_key]

        candidates = await self.repository.lookup_drivers(
            phrase,
            event_id=event_id,
            event_name=event_name,
            year=effective_year,
            person_role=person_role,
            limit=50,
        )

        if not candidates:
            res = EntityResolution(
                type=EntityType.DRIVER,
                raw_phrase=phrase,
                confidence=0.0,
                strategy="none",
            )
            self._resolution_cache[cache_key] = res
            return res

        scored = self._score_candidates(phrase, candidates, year=year)

        clean_lower = phrase.strip().lower()
        is_partial_name = " " not in clean_lower

        if is_partial_name and len(scored) > 1:
            res = EntityResolution(
                type=EntityType.DRIVER,
                raw_phrase=phrase,
                confidence=0.5,
                strategy="partial_name_ambiguity",
                is_ambiguous=True,
                candidate_options=scored[:5],
            )
            self._resolution_cache[cache_key] = res
            return res

        policy = self._evaluate_candidate_selection(phrase, scored)
        self._resolution_cache[cache_key] = policy
        return policy

    async def _resolve_stage(
        self,
        phrase: str,
        *,
        event_id: str | None = None,
        event_name: str | None = None,
    ) -> EntityResolution:
        cache_key = f"stage:{phrase.lower()}:{event_id or ''}:{event_name or ''}"
        if cache_key in self._resolution_cache:
            return self._resolution_cache[cache_key]

        candidates = await self.repository.lookup_stages(
            phrase,
            event_id=event_id,
            event_name=event_name,
            limit=35,
        )

        if not candidates:
            res = EntityResolution(
                type=EntityType.STAGE,
                raw_phrase=phrase,
                confidence=0.0,
                strategy="none",
            )
            self._resolution_cache[cache_key] = res
            return res

        scored = self._score_candidates(phrase, candidates)
        policy = self._evaluate_candidate_selection(phrase, scored)
        self._resolution_cache[cache_key] = policy
        return policy

    async def _resolve_city(
        self,
        phrase: str,
        *,
        country: str | None = None,
        target_rally_name: str | None = None,
    ) -> EntityResolution:
        cache_key = f"city:{phrase.lower()}:{country or ''}:{target_rally_name or ''}"
        if cache_key in self._resolution_cache:
            return self._resolution_cache[cache_key]

        if target_rally_name is None:
            rally_matches = await self.repository.lookup_rallies(phrase, limit=5)
            city_matches = await self.repository.lookup_cities(phrase, country=country, limit=5)

            if rally_matches and city_matches:
                combined = city_matches + rally_matches
                res = EntityResolution(
                    type=EntityType.CITY,
                    raw_phrase=phrase,
                    confidence=0.5,
                    strategy="location_vs_event_ambiguity",
                    is_ambiguous=True,
                    candidate_options=combined[:5],
                )
                self._resolution_cache[cache_key] = res
                return res

        candidates = await self.repository.lookup_cities(
            phrase,
            country=country,
            limit=25,
        )

        if not candidates:
            if target_rally_name is None:
                rally_matches = await self.repository.lookup_rallies(phrase, limit=5)
                scored_rallies = self._score_candidates(phrase, rally_matches) if rally_matches else []
                if scored_rallies:
                    top_rally = scored_rallies[0]
                    if top_rally.score >= self.min_confidence_threshold:
                        if len(scored_rallies) == 1 or (top_rally.score - scored_rallies[1].score) >= self.min_score_gap:
                            res = EntityResolution(
                                type=EntityType.RALLY,
                                raw_phrase=phrase,
                                resolved_candidate=top_rally,
                                confidence=top_rally.score,
                                strategy="clear_winner",
                            )
                            self._resolution_cache[cache_key] = res
                            return res
                    plausible = [r for r in scored_rallies if r.score >= 0.60]
                    if plausible:
                        res = EntityResolution(
                            type=EntityType.RALLY,
                            raw_phrase=phrase,
                            confidence=plausible[0].score,
                            strategy="plausible_candidates",
                            is_ambiguous=True,
                            candidate_options=plausible[:5],
                        )
                        self._resolution_cache[cache_key] = res
                        return res

            res = EntityResolution(
                type=EntityType.CITY,
                raw_phrase=phrase,
                confidence=0.0,
                strategy="none",
            )
            self._resolution_cache[cache_key] = res
            return res

        scored = self._score_candidates(phrase, candidates)
        policy = self._evaluate_candidate_selection(phrase, scored)
        self._resolution_cache[cache_key] = policy
        return policy

    def _score_candidates(
        self,
        phrase: str,
        candidates: list[EntityCandidate],
        *,
        year: int | None = None,
        years: list[int] | None = None,
    ) -> list[EntityCandidate]:
        scored: list[EntityCandidate] = []
        effective_years = years if (years and len(years) > 0) else ([year] if year is not None else [])

        for c in candidates:
            meta = c.metadata or {}
            candidate_year = meta.get("year")
            in_context = bool(meta.get("inContext"))
            year_match = candidate_year is not None and candidate_year in effective_years

            is_person = c.type == EntityType.DRIVER
            scoring_name = (
                str(meta.get("matchedSearchableName"))
                if is_person and meta.get("matchedSearchableName")
                else c.canonical_name
            )

            base_score = compute_composite_score(
                query_phrase=phrase,
                candidate_name=scoring_name,
                is_person=is_person,
            )

            score = compute_composite_score(
                query_phrase=phrase,
                candidate_name=scoring_name,
                query_year=candidate_year if year_match else (effective_years[0] if effective_years else year),
                candidate_year=candidate_year,
                in_context=in_context,
                is_person=is_person,
            )

            updated_metadata = dict(meta)
            updated_metadata["baseScore"] = base_score

            scored.append(
                c.copy_with(
                    score=score,
                    metadata=updated_metadata,
                )
            )

        scored.sort(key=lambda item: item.score, reverse=True)
        return scored

    def _evaluate_candidate_selection(
        self,
        phrase: str,
        scored_candidates: list[EntityCandidate],
    ) -> EntityResolution:
        if not scored_candidates:
            return EntityResolution(
                type=EntityType.RALLY,
                raw_phrase=phrase,
                confidence=0.0,
                strategy="none",
            )

        top = scored_candidates[0]
        top_score = top.score

        # Distinct account identities with same effective person name
        if top.type == EntityType.DRIVER and top_score >= self.min_confidence_threshold:
            top_meta = top.metadata or {}
            top_identity = str(top_meta.get("accountId") or top.id)
            top_matched_name = str(top_meta.get("matchedSearchableName") or top.canonical_name)

            duplicate_identities: list[EntityCandidate] = []
            for candidate in scored_candidates:
                if candidate.type != EntityType.DRIVER:
                    continue
                cand_meta = candidate.metadata or {}
                cand_identity = str(cand_meta.get("accountId") or candidate.id)
                cand_matched_name = str(cand_meta.get("matchedSearchableName") or candidate.canonical_name)

                if (
                    cand_identity != top_identity
                    and normalize(cand_matched_name) == normalize(top_matched_name)
                    and abs(candidate.score - top_score) <= 1e-6
                ):
                    duplicate_identities.append(candidate)

            if duplicate_identities:
                return EntityResolution(
                    type=top.type,
                    raw_phrase=phrase,
                    confidence=top_score,
                    strategy="duplicate_person_identity",
                    is_ambiguous=True,
                    candidate_options=([top] + duplicate_identities)[:5],
                )

        if top_score < self.min_confidence_threshold:
            is_plausible = top_score >= 0.50
            return EntityResolution(
                type=top.type,
                raw_phrase=phrase,
                confidence=top_score,
                strategy="plausible_candidates" if is_plausible else "below_threshold",
                is_ambiguous=is_plausible,
                candidate_options=scored_candidates[:5] if is_plausible else [],
            )

        if len(scored_candidates) == 1:
            return EntityResolution(
                type=top.type,
                raw_phrase=phrase,
                resolved_candidate=top,
                confidence=top_score,
                strategy="unique_match",
            )

        runner_up = scored_candidates[1]
        runner_up_score = runner_up.score
        gap = top_score - runner_up_score

        top_meta = top.metadata or {}
        runner_up_meta = runner_up.metadata or {}
        base_top = float(top_meta.get("baseScore", top_score))
        base_runner_up = float(runner_up_meta.get("baseScore", runner_up_score))
        base_gap = base_top - base_runner_up

        if gap >= self.min_score_gap or (
            top_score >= self.min_confidence_threshold and base_gap >= self.min_score_gap
        ):
            return EntityResolution(
                type=top.type,
                raw_phrase=phrase,
                resolved_candidate=top,
                confidence=top_score,
                strategy="clear_winner",
            )

        return EntityResolution(
            type=top.type,
            raw_phrase=phrase,
            confidence=top_score,
            strategy="insufficient_gap",
            is_ambiguous=True,
            candidate_options=[
                c for c in scored_candidates
                if c.score >= self.min_confidence_threshold - 0.10
            ],
        )
