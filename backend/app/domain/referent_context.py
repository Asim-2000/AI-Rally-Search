from typing import Any
from pydantic import BaseModel, ConfigDict, Field

from .results import (
    ClassificationItem,
    DriverWinsItem,
    ParticipationItem,
    RallyResultItem,
    SearchResponse,
    VideoActionItem,
    VideoItem,
)
from .search_intent import SearchIntent
from .search_query import PersonRole


class ResultReferentContext(BaseModel):
    """Encapsulates entities established by database search results, entity resolutions,
    or explicit user selections during a conversational search session.

    Strictly mirrors lib/models/result_referent_context.dart.
    """
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    active_rally: str | None = Field(default=None, alias="activeRally")
    active_rally_id: str | None = Field(default=None, alias="activeRallyId")
    active_rallies: list[str] = Field(default_factory=list, alias="activeRallies")

    active_driver: str | None = Field(default=None, alias="activeDriver")
    active_driver_id: str | None = Field(default=None, alias="activeDriverId")
    active_drivers: list[str] = Field(default_factory=list, alias="activeDrivers")

    active_person_role: PersonRole | None = Field(default=None, alias="activePersonRole")

    active_stage: str | None = Field(default=None, alias="activeStage")
    active_stage_number: str | None = Field(default=None, alias="activeStageNumber")

    last_winner: str | None = Field(default=None, alias="lastWinner")
    last_winner_driver_id: str | None = Field(default=None, alias="lastWinnerDriverId")

    last_selected_driver: str | None = Field(default=None, alias="lastSelectedDriver")
    last_selected_driver_id: str | None = Field(default=None, alias="lastSelectedDriverId")

    last_selected_rally: str | None = Field(default=None, alias="lastSelectedRally")
    last_selected_rally_id: str | None = Field(default=None, alias="lastSelectedRallyId")

    metadata: dict[str, Any] = Field(default_factory=dict)

    def copy_with(
        self,
        *,
        active_rally: str | None = None,
        active_rally_id: str | None = None,
        active_rallies: list[str] | None = None,
        active_driver: str | None = None,
        active_driver_id: str | None = None,
        active_drivers: list[str] | None = None,
        active_person_role: PersonRole | None = None,
        active_stage: str | None = None,
        active_stage_number: str | None = None,
        last_winner: str | None = None,
        last_winner_driver_id: str | None = None,
        last_selected_driver: str | None = None,
        last_selected_driver_id: str | None = None,
        last_selected_rally: str | None = None,
        last_selected_rally_id: str | None = None,
        metadata: dict[str, Any] | None = None,
        clear_active_rally: bool = False,
        clear_active_driver: bool = False,
        clear_active_person_role: bool = False,
        clear_active_stage: bool = False,
        clear_last_winner: bool = False,
    ) -> "ResultReferentContext":
        return ResultReferentContext(
            active_rally=None if clear_active_rally else (active_rally if active_rally is not None else self.active_rally),
            active_rally_id=None if clear_active_rally else (active_rally_id if active_rally_id is not None else self.active_rally_id),
            active_rallies=[] if clear_active_rally else (active_rallies if active_rallies is not None else list(self.active_rallies)),
            active_driver=None if clear_active_driver else (active_driver if active_driver is not None else self.active_driver),
            active_driver_id=None if clear_active_driver else (active_driver_id if active_driver_id is not None else self.active_driver_id),
            active_drivers=[] if clear_active_driver else (active_drivers if active_drivers is not None else list(self.active_drivers)),
            active_person_role=None if clear_active_person_role else (active_person_role if active_person_role is not None else self.active_person_role),
            active_stage=None if clear_active_stage else (active_stage if active_stage is not None else self.active_stage),
            active_stage_number=None if clear_active_stage else (active_stage_number if active_stage_number is not None else self.active_stage_number),
            last_winner=None if clear_last_winner else (last_winner if last_winner is not None else self.last_winner),
            last_winner_driver_id=None if clear_last_winner else (last_winner_driver_id if last_winner_driver_id is not None else self.last_winner_driver_id),
            last_selected_driver=last_selected_driver if last_selected_driver is not None else self.last_selected_driver,
            last_selected_driver_id=last_selected_driver_id if last_selected_driver_id is not None else self.last_selected_driver_id,
            last_selected_rally=last_selected_rally if last_selected_rally is not None else self.last_selected_rally,
            last_selected_rally_id=last_selected_rally_id if last_selected_rally_id is not None else self.last_selected_rally_id,
            metadata=dict(metadata) if metadata is not None else dict(self.metadata),
        )

    @classmethod
    def from_search_response(
        cls,
        response: SearchResponse,
        *,
        previous: "ResultReferentContext | None" = None,
        query_rally: str | None = None,
        query_driver: str | None = None,
        query_rallies: list[str] | None = None,
        query_drivers: list[str] | None = None,
        query_driver_ids: list[str] | None = None,
        query_rally_ids: list[str] | None = None,
        query_person_role: PersonRole | None = None,
    ) -> "ResultReferentContext":
        prev = previous or cls()
        active_rally = prev.active_rally
        active_rally_id = prev.active_rally_id
        active_rallies = list(prev.active_rallies)
        active_driver = prev.active_driver
        active_driver_id = prev.active_driver_id
        active_drivers = list(prev.active_drivers)
        active_person_role = prev.active_person_role
        if query_person_role is not None and query_person_role != PersonRole.ANY:
            active_person_role = query_person_role
        active_stage = prev.active_stage
        active_stage_number = prev.active_stage_number
        last_winner = prev.last_winner
        last_winner_driver_id = prev.last_winner_driver_id

        if query_rallies and len(query_rallies) > 0:
            active_rallies = list(query_rallies)
            active_rally = query_rallies[0]
        elif query_rally and query_rally.strip():
            active_rally = query_rally.strip()
            if active_rally not in active_rallies:
                active_rallies = [active_rally, *active_rallies]

        if query_rally_ids and len(query_rally_ids) > 0 and query_rally_ids[0]:
            active_rally_id = str(query_rally_ids[0])

        if query_drivers and len(query_drivers) > 0:
            active_drivers = list(query_drivers)
            active_driver = query_drivers[0]
            # ACC-3: pin the canonical driver identity so follow-ups reuse it
            # instead of re-resolving by fuzzy match. A new driver without a
            # resolved id clears the previous id rather than keeping a stale one.
            active_driver_id = (
                str(query_driver_ids[0])
                if query_driver_ids and query_driver_ids[0]
                else None
            )
        elif query_driver and query_driver.strip():
            active_driver = query_driver.strip()
            if active_driver not in active_drivers:
                active_drivers = [active_driver, *active_drivers]
            active_driver_id = (
                str(query_driver_ids[0])
                if query_driver_ids and query_driver_ids[0]
                else None
            )

        results = response.results
        if not results:
            return prev.copy_with(
                active_rally=active_rally,
                active_rally_id=active_rally_id,
                active_rallies=active_rallies,
                active_driver=active_driver,
                active_driver_id=active_driver_id,
                active_drivers=active_drivers,
                active_person_role=active_person_role,
            )

        match response.intent:
            case SearchIntent.GET_RALLY_RESULTS | SearchIntent.GET_RALLY_TOP_FINISHERS:
                finishers = [r for r in results if isinstance(r, ClassificationItem)]
                if finishers:
                    first = finishers[0]
                    last_winner = first.driver_name
                    if first.driver_id:
                        last_winner_driver_id = str(first.driver_id)
                    active_driver = first.driver_name
                    if first.event_name:
                        active_rally = first.event_name
                        active_rally_id = first.rally_id
                        if first.event_name not in active_rallies:
                            active_rallies = [first.event_name, *active_rallies]
                    all_drivers: list[str] = []
                    seen_drivers = set()
                    for f in finishers:
                        if f.driver_name and f.driver_name not in seen_drivers:
                            seen_drivers.add(f.driver_name)
                            all_drivers.append(f.driver_name)
                    active_drivers = all_drivers

            case SearchIntent.SEARCH_RALLIES:
                rallies = [r for r in results if isinstance(r, RallyResultItem)]
                if len(rallies) == 1:
                    active_rally = rallies[0].event_name
                    active_rally_id = rallies[0].event_id
                active_rallies = [r.event_name for r in rallies]

            case SearchIntent.SEARCH_DRIVER_RALLIES | SearchIntent.SEARCH_DRIVER_WINS:
                parts = [r for r in results if isinstance(r, ParticipationItem)]
                if parts:
                    first = parts[0]
                    if (not active_driver) and first.driver_name:
                        active_driver = first.driver_name
                    if len(parts) == 1 and first.event_name:
                        active_rally = first.event_name
                        active_rally_id = first.rally_id
                    seen_rallies = set()
                    rally_names: list[str] = []
                    for p in parts:
                        if p.event_name and p.event_name not in seen_rallies:
                            seen_rallies.add(p.event_name)
                            rally_names.append(p.event_name)
                    if rally_names:
                        active_rallies = rally_names

            case SearchIntent.SEARCH_VIDEO_ACTIONS:
                actions = [r for r in results if isinstance(r, VideoActionItem)]
                action_drivers = list(dict.fromkeys(
                    a.driver_name for a in actions if a.driver_name
                ))
                if len(action_drivers) == 1:
                    active_driver = action_drivers[0]
                action_rallies = list(dict.fromkeys(
                    a.event_name for a in actions if a.event_name
                ))
                if len(action_rallies) == 1:
                    active_rally = action_rallies[0]

            case SearchIntent.SEARCH_DRIVER_VIDEOS:
                vid_drivers: list[str] = []
                for v in results:
                    if isinstance(v, VideoItem) and v.driver_name:
                        if v.driver_name not in vid_drivers:
                            vid_drivers.append(v.driver_name)
                if len(vid_drivers) == 1:
                    active_driver = vid_drivers[0]

            case SearchIntent.GET_TOP_DRIVERS_BY_WINS:
                wins = [r for r in results if isinstance(r, DriverWinsItem)]
                if wins:
                    last_winner = wins[0].driver_name
                    active_driver = wins[0].driver_name
                    active_drivers = [w.driver_name for w in wins]

            case SearchIntent.GET_TOP_UPLOADERS:
                pass

        return ResultReferentContext(
            active_rally=active_rally,
            active_rally_id=active_rally_id,
            active_rallies=active_rallies,
            active_driver=active_driver,
            active_driver_id=active_driver_id,
            active_drivers=active_drivers,
            active_person_role=active_person_role,
            active_stage=active_stage,
            active_stage_number=active_stage_number,
            last_winner=last_winner,
            last_winner_driver_id=last_winner_driver_id,
            last_selected_driver=prev.last_selected_driver,
            last_selected_driver_id=prev.last_selected_driver_id,
            last_selected_rally=prev.last_selected_rally,
            last_selected_rally_id=prev.last_selected_rally_id,
            metadata=dict(prev.metadata),
        )
