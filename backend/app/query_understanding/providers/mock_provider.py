import json
import re
from typing import Any

from ..models import ProviderResponse, TokenUsage
from ..provider import QueryUnderstandingProvider



class MockProvider(QueryUnderstandingProvider):
    """Hermetic deterministic adapter; explicit responses override the small smoke parser."""
    def __init__(self, config, responses: dict[str, str] | None = None):
        super().__init__(config)
        self.responses = responses or {}

    async def parse_raw(
        self,
        natural_language_query: str,
        *,
        language: str | None = None,
        context: Any = None,
    ) -> ProviderResponse:
        raw = self.responses.get(natural_language_query)
        if raw is None:
            raw = json.dumps(self._parse(natural_language_query, context=context))
        return ProviderResponse(raw_response=raw, usage=TokenUsage(input_tokens=15, output_tokens=25, total_tokens=40), metadata={"deterministic": True})

    @staticmethod
    def _parse(text: str, context: Any = None) -> dict:
        lower = text.lower().strip()

        # Check for conversational pronoun / missing referent clarification conditions
        if any(w in lower for w in ("who won it", "who won that", "who won?")):
            active_rally = getattr(context, "active_rally", None)
            if not active_rally and hasattr(context, "referents"):
                active_rally = context.referents.active_rally
            if not active_rally:
                return {
                    "intent": "GET_RALLY_RESULTS",
                    "requiresClarification": True,
                    "clarificationQuestion": "Which rally do you want to see the winner for?",
                    "rallyNames": [], "eventNames": [], "countries": [], "cities": [],
                    "stageNames": [], "stageNumbers": [], "driverNames": [], "driverIds": [],
                    "actionTypes": [], "years": [], "uploaders": [],
                }

        if any(w in lower for w in ("videos of him", "show videos of him", "clips of him", "his videos")):
            ref = getattr(context, "referents", None)
            if ref and not ref.last_winner and len(ref.active_drivers) > 1:
                return {
                    "intent": "SEARCH_DRIVER_VIDEOS",
                    "requiresClarification": True,
                    "clarificationQuestion": "Which driver do you mean?",
                    "rallyNames": [], "eventNames": [], "countries": [], "cities": [],
                    "stageNames": [], "stageNumbers": [], "driverNames": [], "driverIds": [],
                    "actionTypes": [], "years": [], "uploaders": [],
                }
            driver = None
            if ref:
                driver = ref.last_winner or ref.active_driver
            if not driver and hasattr(context, "active_driver"):
                driver = context.active_driver
            if not driver:
                return {
                    "intent": "SEARCH_DRIVER_VIDEOS",
                    "requiresClarification": True,
                    "clarificationQuestion": "Which driver do you want to see videos of?",
                    "rallyNames": [], "eventNames": [], "countries": [], "cities": [],
                    "stageNames": [], "stageNumbers": [], "driverNames": [], "driverIds": [],
                    "actionTypes": [], "years": [], "uploaders": [],
                }

        intent = "SEARCH_RALLIES"
        if any(x in lower for x in ("jump", "drift", "crash", "spin", "highlight", "action", "moment")):
            intent = "SEARCH_VIDEO_ACTIONS"
        elif "video" in lower or "clip" in lower:
            intent = "SEARCH_DRIVER_VIDEOS"
        elif "top uploader" in lower or "most upload" in lower:
            intent = "GET_TOP_UPLOADERS"
        elif "most wins" in lower or "top drivers" in lower:
            intent = "GET_TOP_DRIVERS_BY_WINS"
        elif "top finish" in lower or "leaderboard" in lower or "full results" in lower:
            intent = "GET_RALLY_TOP_FINISHERS"
        elif "who won" in lower or "winner of" in lower:
            intent = "GET_RALLY_RESULTS"
        elif " won" in lower or "wins" in lower:
            intent = "SEARCH_DRIVER_WINS"
        elif any(x in lower for x in ("participat", "competed", "entered", "drove", "driven", "co-drove", "co-driven", "co-driver", "codriver")):
            intent = "SEARCH_DRIVER_RALLIES"

        years = [int(v) for v in re.findall(r"\b(?:19|20)\d{2}\b", text)]
        countries = [name for name in ("Ireland", "Poland", "Latvia", "Lithuania", "Spain", "France", "Finland", "Scotland", "United Kingdom", "Portugal") if name.lower() in lower]
        actions = [name for name in ("jump", "drift", "crash", "spin", "donut") if name in lower]
        drivers = [name for name in ("Josh Moffett", "Sam Moffett", "Philip Squires", "Kris Meeke", "Craig Breen", "Max Freeman") if name.lower() in lower]

        # Extract rally name
        rallies: list[str] = []
        if "donegal international rally" in lower:
            rallies = ["Donegal International Rally"]
        elif "donegal" in lower:
            rallies = ["Donegal Rally"] if "rally" in lower else ["Donegal"]
        elif "moonraker" in lower:
            rallies = ["Moonraker"]
        elif "trackrod" in lower:
            rallies = ["Trackrod Rally"]
        elif "get jerky" in lower:
            rallies = ["Get Jerky"]

        person_role = "ANY"
        if any(w in lower for w in ("co-drove", "co-driven", "co-driver", "codriver", "navigator")):
            person_role = "CO_DRIVER"
        elif any(w in lower for w in ("driven by", "drove in", "as driver", "where he drove")):
            person_role = "DRIVER"

        driver_match_mode = "ALL" if ("both" in lower or "all drivers" in lower) else "ANY"

        # Context-aware adjustments
        if context is not None:
            ref = getattr(context, "referents", None)
            prev_q = getattr(context, "previous_query", None)

            if "who won" in lower:
                r_name = getattr(context, "active_rally", None) or (ref.active_rally if ref else None) or (prev_q.target_rally_name if prev_q else None)
                if r_name:
                    rallies = [r_name]
                    extracted_yrs = [int(v) for v in re.findall(r"\b(?:19|20)\d{2}\b", r_name)]
                    if extracted_yrs and not years:
                        years = extracted_yrs
                if prev_q and prev_q.years and not years:
                    years = list(prev_q.years)
                intent = "GET_RALLY_RESULTS"

            elif any(w in lower for w in ("videos of him", "show videos of him", "his videos")):
                d_name = (ref.last_winner if ref else None) or (ref.active_driver if ref else None) or getattr(context, "active_driver", None)
                if d_name and not drivers:
                    drivers = [d_name]
                intent = "SEARCH_DRIVER_VIDEOS"

            if any(w in lower for w in ("only show jumps", "only jumps", "just jumps")):
                actions = ["jump"]
                r_name = (ref.active_rally if ref else None) or getattr(context, "active_rally", None) or (prev_q.target_rally_name if prev_q else None)
                if r_name and not rallies:
                    rallies = [r_name]
                d_name = (ref.active_driver if ref else None) or (ref.last_winner if ref else None) or getattr(context, "active_driver", None) or (prev_q.driver_name if prev_q else None)
                if d_name and not drivers:
                    drivers = [d_name]
                if prev_q and prev_q.years and not years:
                    years = list(prev_q.years)
                intent = "SEARCH_VIDEO_ACTIONS"

            elif any(w in lower for w in ("only drifts", "only show drifts")):
                actions = ["drift"]
                r_name = (ref.active_rally if ref else None) or getattr(context, "active_rally", None) or (prev_q.target_rally_name if prev_q else None)
                if r_name and not rallies:
                    rallies = [r_name]
                d_name = (ref.active_driver if ref else None) or (ref.last_winner if ref else None) or getattr(context, "active_driver", None) or (prev_q.driver_name if prev_q else None)
                if d_name and not drivers:
                    drivers = [d_name]
                if prev_q and prev_q.years and not years:
                    years = list(prev_q.years)
                intent = "SEARCH_VIDEO_ACTIONS"

            elif any(w in lower for w in ("also drift", "add drift", "and drift")):
                prev_actions = list(prev_q.action_types) if prev_q else []
                if "drift" not in prev_actions:
                    prev_actions.append("drift")
                actions = prev_actions
                r_name = (ref.active_rally if ref else None) or getattr(context, "active_rally", None) or (prev_q.target_rally_name if prev_q else None)
                if r_name and not rallies:
                    rallies = [r_name]
                d_name = (ref.active_driver if ref else None) or (ref.last_winner if ref else None) or getattr(context, "active_driver", None) or (prev_q.driver_name if prev_q else None)
                if d_name and not drivers:
                    drivers = [d_name]
                if prev_q and prev_q.years and not years:
                    years = list(prev_q.years)
                intent = "SEARCH_VIDEO_ACTIONS"


            if "forget the driver" in lower or "remove driver" in lower:
                drivers = []
                r_name = (ref.active_rally if ref else None) or (prev_q.rally_names[0] if prev_q and prev_q.rally_names else None)
                if r_name and not rallies:
                    rallies = [r_name]
                if prev_q:
                    if prev_q.years and not years:
                        years = list(prev_q.years)
                    if prev_q.action_types and not actions:
                        actions = list(prev_q.action_types)
                    if prev_q.intent:
                        intent = prev_q.intent.value if hasattr(prev_q.intent, "value") else str(prev_q.intent)

            if "what about 2024" in lower or "in 2024" in lower:
                r_name = (ref.active_rally if ref else None) or (prev_q.rally_names[0] if prev_q and prev_q.rally_names else None)
                if r_name and not rallies:
                    rallies = [r_name]
                d_name = (ref.active_driver if ref else None) or (prev_q.driver_names[0] if prev_q and prev_q.driver_names else None)
                if d_name and not drivers:
                    drivers = [d_name]
                if prev_q:
                    if prev_q.action_types and not actions:
                        actions = list(prev_q.action_types)
                    if prev_q.intent:
                        intent = prev_q.intent.value if hasattr(prev_q.intent, "value") else str(prev_q.intent)


        return {
            "intent": intent,
            "countries": countries,
            "years": years,
            "driverNames": drivers,
            "actionTypes": actions,
            "rallyNames": rallies,
            "personRole": person_role,
            "driverMatchMode": driver_match_mode,
        }

