from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict, Field

from .referent_context import ResultReferentContext
from .results import SearchResponse
from .search_intent import SearchIntent
from .search_query import SearchQuery


class SessionTurnSnapshot(BaseModel):
    """Immutable snapshot of a single conversational turn in the history stack.

    Mirrors SessionTurnSnapshot in lib/models/conversational_search_session.dart.
    """
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    title: str
    query: SearchQuery
    referents: ResultReferentContext
    interpreted_summary: str | None = Field(default=None, alias="interpretedSummary")
    response: SearchResponse | None = None
    timestamp: datetime = Field(default_factory=datetime.now)


def _equalsIgnoreCase(a: str | None, b: str | None) -> bool:
    if a is None or b is None:
        return False
    return a.strip().lower() == b.strip().lower()


class SearchConversationSession(BaseModel):
    """State machine managing continuous conversational search sessions.

    Keeps query filter state (SearchQuery) strictly separate from result-derived
    referents (ResultReferentContext).

    Strictly mirrors lib/models/conversational_search_session.dart.
    """
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    active_query: SearchQuery = Field(
        default_factory=lambda: SearchQuery(intent=SearchIntent.SEARCH_RALLIES),
        alias="activeQuery",
    )
    previous_query: SearchQuery | None = Field(default=None, alias="previousQuery")
    referents: ResultReferentContext = Field(
        default_factory=ResultReferentContext,
        alias="referents",
    )
    history: list[SessionTurnSnapshot] = Field(default_factory=list, alias="history")
    inherited_fields: set[str] = Field(default_factory=set, alias="inheritedFields")
    current_refinement_fields: set[str] = Field(default_factory=set, alias="currentRefinementFields")
    active_request_id: int = Field(default=0, alias="activeRequestId")

    def copy_with(
        self,
        *,
        active_query: SearchQuery | None = None,
        previous_query: SearchQuery | None = None,
        referents: ResultReferentContext | None = None,
        history: list[SessionTurnSnapshot] | None = None,
        inherited_fields: set[str] | None = None,
        current_refinement_fields: set[str] | None = None,
        active_request_id: int | None = None,
    ) -> "SearchConversationSession":
        return SearchConversationSession(
            active_query=active_query if active_query is not None else self.active_query.model_copy(),
            previous_query=previous_query if previous_query is not None else (self.previous_query.model_copy() if self.previous_query else None),
            referents=referents if referents is not None else self.referents.model_copy(),
            history=list(history) if history is not None else list(self.history),
            inherited_fields=set(inherited_fields) if inherited_fields is not None else set(self.inherited_fields),
            current_refinement_fields=set(current_refinement_fields) if current_refinement_fields is not None else set(self.current_refinement_fields),
            active_request_id=active_request_id if active_request_id is not None else self.active_request_id,
        )

    def next_request(self) -> "SearchConversationSession":
        """Increments and returns the new active request ID for stale response protection."""
        return self.copy_with(active_request_id=self.active_request_id + 1)

    def record_turn(
        self,
        *,
        query: SearchQuery,
        referents: ResultReferentContext,
        title: str,
        response: SearchResponse | None = None,
        interpreted_summary: str | None = None,
        inherited: set[str] | None = None,
        refinements: set[str] | None = None,
    ) -> "SearchConversationSession":
        """Records a completed turn into the history stack and advances session state."""
        snapshot = SessionTurnSnapshot(
            title=title,
            query=query,
            referents=referents,
            interpreted_summary=interpreted_summary,
            response=response,
            timestamp=datetime.now(),
        )
        return SearchConversationSession(
            active_query=query,
            previous_query=self.active_query,
            referents=referents,
            history=[*self.history, snapshot],
            inherited_fields=set(inherited or set()),
            current_refinement_fields=set(refinements or set()),
            active_request_id=self.active_request_id,
        )

    def rollback_to(self, history_index: int) -> "SearchConversationSession":
        """Rolls back history to the specified index."""
        if history_index < 0 or history_index >= len(self.history):
            return self
        target = self.history[history_index]
        new_history = self.history[: history_index + 1]

        return SearchConversationSession(
            active_query=target.query,
            previous_query=self.history[history_index - 1].query if history_index > 0 else None,
            referents=target.referents,
            history=new_history,
            inherited_fields=set(),
            current_refinement_fields=set(),
            active_request_id=self.active_request_id + 1,
        )

    def remove_filter(self, *, field: str, value: Any) -> "SearchConversationSession":
        """Deterministically removes a specific filter value from the active SearchQuery.

        For instance: removing 'Ireland' from countries, or removing 'jump' from actionTypes.
        Also updates referents if the removed entity was the active referent.
        """
        q = self.active_query
        updated_query = q
        updated_referents = self.referents

        val_str = str(value).strip() if value is not None else None

        match field.lower():
            case "country" | "countries":
                country_list = [c for c in q.countries if not _equalsIgnoreCase(c, val_str)]
                updated_query = q.copyWith(countries=country_list)

            case "city" | "cities":
                city_list = [c for c in q.cities if not _equalsIgnoreCase(c, val_str)]
                updated_query = q.copyWith(cities=city_list)

            case "year" | "years":
                yr: int | None = None
                if isinstance(value, int):
                    yr = value
                elif val_str and val_str.isdigit():
                    yr = int(val_str)
                year_list = [y for y in q.years if y != yr]
                updated_query = q.copyWith(years=year_list)

            case "rally" | "rallies" | "rallynames" | "targetrallyname":
                rally_list = [r for r in q.rally_names if not _equalsIgnoreCase(r, val_str)]
                updated_query = q.copyWith(rallyNames=rally_list)
                if _equalsIgnoreCase(self.referents.active_rally, val_str):
                    updated_referents = self.referents.copy_with(clear_active_rally=True)

            case "driver" | "drivers" | "drivernames" | "drivername":
                driver_list = [d for d in q.driver_names if not _equalsIgnoreCase(d, val_str)]
                updated_query = q.copyWith(driverNames=driver_list)
                if _equalsIgnoreCase(self.referents.active_driver, val_str) or _equalsIgnoreCase(self.referents.last_winner, val_str):
                    updated_referents = self.referents.copy_with(clear_active_driver=True, clear_last_winner=True)

            case "action" | "actions" | "actiontypes" | "actiontype":
                action_list = [a for a in q.action_types if not _equalsIgnoreCase(a, val_str)]
                updated_query = q.copyWith(actionTypes=action_list)

            case "stage" | "stages" | "stagenames":
                stage_list = [s for s in q.stage_names if not _equalsIgnoreCase(s, val_str)]
                updated_query = q.copyWith(stageNames=stage_list)
                if _equalsIgnoreCase(self.referents.active_stage, val_str):
                    updated_referents = self.referents.copy_with(clear_active_stage=True)

        return self.copy_with(
            active_query=updated_query,
            referents=updated_referents,
            inherited_fields=set(self.inherited_fields),
            current_refinement_fields=set(self.current_refinement_fields),
            active_request_id=self.active_request_id + 1,
        )

    def add_filter(self, *, field: str, value: Any) -> "SearchConversationSession":
        """Deterministically adds a filter value (e.g. adding 'drift' alongside existing 'jump')."""
        q = self.active_query
        updated_query = q
        val_str = str(value).strip() if value is not None else None
        if not val_str:
            return self

        match field.lower():
            case "country" | "countries":
                country_list = list(q.countries)
                if not any(_equalsIgnoreCase(c, val_str) for c in country_list):
                    country_list.append(val_str)
                updated_query = q.copyWith(countries=country_list)

            case "city" | "cities":
                city_list = list(q.cities)
                if not any(_equalsIgnoreCase(c, val_str) for c in city_list):
                    city_list.append(val_str)
                updated_query = q.copyWith(cities=city_list)

            case "year" | "years":
                year_list = list(q.years)
                yr: int | None = None
                if isinstance(value, int):
                    yr = value
                elif val_str.isdigit():
                    yr = int(val_str)
                if yr is not None and yr not in year_list:
                    year_list.append(yr)
                updated_query = q.copyWith(years=year_list)

            case "rally" | "rallies" | "rallynames":
                rally_list = list(q.rally_names)
                if not any(_equalsIgnoreCase(r, val_str) for r in rally_list):
                    rally_list.append(val_str)
                updated_query = q.copyWith(rallyNames=rally_list)

            case "driver" | "drivers" | "drivernames":
                driver_list = list(q.driver_names)
                if not any(_equalsIgnoreCase(d, val_str) for d in driver_list):
                    driver_list.append(val_str)
                updated_query = q.copyWith(driverNames=driver_list)

            case "action" | "actions" | "actiontypes":
                action_list = list(q.action_types)
                if not any(_equalsIgnoreCase(a, val_str) for a in action_list):
                    action_list.append(val_str.lower())
                updated_query = q.copyWith(
                    intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
                    actionTypes=action_list,
                )

        new_refinements = set(self.current_refinement_fields)
        new_refinements.add(field)

        return self.copy_with(
            active_query=updated_query,
            current_refinement_fields=new_refinements,
            active_request_id=self.active_request_id + 1,
        )

    def clear_all(self) -> "SearchConversationSession":
        """Clears the session back to default initial state."""
        return SearchConversationSession(
            active_query=SearchQuery(intent=SearchIntent.SEARCH_RALLIES),
            previous_query=None,
            referents=ResultReferentContext(),
            history=[],
            inherited_fields=set(),
            current_refinement_fields=set(),
            active_request_id=self.active_request_id + 1,
        )
