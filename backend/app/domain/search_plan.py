from __future__ import annotations

from enum import StrEnum
from typing import Any
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from .search_intent import SearchIntent
from .search_query import MatchMode, PersonRole


class ExecutionStrategy(StrEnum):
    RALLIES = "RALLIES"
    PARTICIPATIONS = "PARTICIPATIONS"
    DRIVER_WINS = "DRIVER_WINS"
    RALLY_RESULTS = "RALLY_RESULTS"
    TOP_FINISHERS = "TOP_FINISHERS"
    VIDEO_ACTIONS = "VIDEO_ACTIONS"
    DRIVER_VIDEOS = "DRIVER_VIDEOS"
    TOP_UPLOADERS = "TOP_UPLOADERS"
    TOP_DRIVERS_BY_WINS = "TOP_DRIVERS_BY_WINS"


INTENT_TO_STRATEGY: dict[SearchIntent, ExecutionStrategy] = {
    SearchIntent.SEARCH_RALLIES: ExecutionStrategy.RALLIES,
    SearchIntent.SEARCH_DRIVER_RALLIES: ExecutionStrategy.PARTICIPATIONS,
    SearchIntent.SEARCH_DRIVER_WINS: ExecutionStrategy.DRIVER_WINS,
    SearchIntent.GET_RALLY_RESULTS: ExecutionStrategy.RALLY_RESULTS,
    SearchIntent.GET_RALLY_TOP_FINISHERS: ExecutionStrategy.TOP_FINISHERS,
    SearchIntent.SEARCH_VIDEO_ACTIONS: ExecutionStrategy.VIDEO_ACTIONS,
    SearchIntent.SEARCH_DRIVER_VIDEOS: ExecutionStrategy.DRIVER_VIDEOS,
    SearchIntent.GET_TOP_UPLOADERS: ExecutionStrategy.TOP_UPLOADERS,
    SearchIntent.GET_TOP_DRIVERS_BY_WINS: ExecutionStrategy.TOP_DRIVERS_BY_WINS,
}


class SearchPlan(BaseModel):
    """Immutable, strongly validated execution plan for deterministic repository/SQL execution.

    Contains ONLY execution-ready canonical information.
    """
    model_config = ConfigDict(extra="forbid", frozen=True, populate_by_name=True)

    intent: SearchIntent
    strategy: ExecutionStrategy

    # Canonical event / rally identities
    event_ids: list[str] = Field(default_factory=list, alias="eventIds")
    rally_names: list[str] = Field(default_factory=list, alias="rallyNames")

    # Canonical person / driver identities
    driver_ids: list[str] = Field(default_factory=list, alias="driverIds")
    driver_names: list[str] = Field(default_factory=list, alias="driverNames")
    person_role: PersonRole = Field(PersonRole.ANY, alias="personRole")
    driver_match_mode: MatchMode = Field(MatchMode.ANY, alias="driverMatchMode")

    # Canonical stage identities
    stage_ids: list[str] = Field(default_factory=list, alias="stageIds")
    stage_names: list[str] = Field(default_factory=list, alias="stageNames")
    stage_numbers: list[str] = Field(default_factory=list, alias="stageNumbers")

    # Direct geographic / temporal / metadata filters
    countries: list[str] = Field(default_factory=list)
    cities: list[str] = Field(default_factory=list)
    years: list[int] = Field(default_factory=list)
    year_from: int | None = Field(None, alias="yearFrom")
    year_to: int | None = Field(None, alias="yearTo")

    # Media & action filters
    action_types: list[str] = Field(default_factory=list, alias="actionTypes")
    uploaders: list[str] = Field(default_factory=list)

    # Execution limits & pagination
    limit: int = Field(20, ge=1)
    offset: int = Field(0, ge=0)

    @field_validator(
        "event_ids",
        "rally_names",
        "driver_ids",
        "driver_names",
        "stage_ids",
        "stage_names",
        "stage_numbers",
        "countries",
        "cities",
        "action_types",
        "uploaders",
        mode="before",
    )
    @classmethod
    def clean_string_list(cls, values: Any) -> list[str]:
        if values is None:
            return []
        if isinstance(values, str):
            values = [values]
        cleaned = [
            str(v).strip()
            for v in values
            if v is not None and str(v).strip() and str(v).strip().lower() != "null"
        ]
        return cleaned

    @field_validator("years", mode="before")
    @classmethod
    def clean_years(cls, values: Any) -> list[int]:
        if values is None:
            return []
        if isinstance(values, (int, str)):
            values = [values]
        cleaned: list[int] = []
        for v in values:
            if v is not None:
                try:
                    cleaned.append(int(v))
                except (ValueError, TypeError):
                    continue
        return cleaned

    @model_validator(mode="after")
    def validate_plan(self) -> "SearchPlan":
        # 1. Verify strategy matches intent
        expected_strategy = INTENT_TO_STRATEGY.get(self.intent)
        if self.strategy != expected_strategy:
            raise ValueError(
                f"Incompatible strategy {self.strategy} for intent {self.intent} (expected {expected_strategy})"
            )

        # 2. Verify year range
        if self.year_from is not None and self.year_to is not None and self.year_from > self.year_to:
            raise ValueError("year_from must be less than or equal to year_to")

        # 3. Verify intent-specific filter compatibility
        if self.action_types and self.intent != SearchIntent.SEARCH_VIDEO_ACTIONS:
            raise ValueError(f"action_types not supported for intent {self.intent}")

        return self

    @property
    def target_rally_names(self) -> list[str]:
        """Convenience property for SQL generation matching SearchQuery."""
        return self.rally_names or self.event_ids

    @property
    def target_rally_name(self) -> str | None:
        return self.target_rally_names[0] if self.target_rally_names else None

    @property
    def driver_name(self) -> str | None:
        return self.driver_names[0] if self.driver_names else None

    @property
    def country(self) -> str | None:
        return self.countries[0] if self.countries else None

    @property
    def year(self) -> int | None:
        return self.years[0] if self.years else None
