import json
import re

from ..models import ProviderResponse, TokenUsage
from ..provider import QueryUnderstandingProvider


class MockProvider(QueryUnderstandingProvider):
    """Hermetic deterministic adapter; explicit responses override the small smoke parser."""
    def __init__(self, config, responses: dict[str, str] | None = None):
        super().__init__(config)
        self.responses = responses or {}

    async def parse_raw(self, natural_language_query: str, *, language: str | None = None) -> ProviderResponse:
        raw = self.responses.get(natural_language_query)
        if raw is None:
            raw = json.dumps(self._parse(natural_language_query))
        return ProviderResponse(raw_response=raw, usage=TokenUsage(input_tokens=15, output_tokens=25, total_tokens=40), metadata={"deterministic": True})

    @staticmethod
    def _parse(text: str) -> dict:
        lower = text.lower()
        intent = "SEARCH_RALLIES"
        if any(x in lower for x in ("jump", "drift", "crash", "spin")):
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
        elif any(x in lower for x in ("participat", "competed", "entered", " drove")):
            intent = "SEARCH_DRIVER_RALLIES"
        years = [int(v) for v in re.findall(r"\b(?:19|20)\d{2}\b", text)]
        countries = [name for name in ("Ireland", "Poland", "Latvia", "Lithuania", "Spain", "France", "Finland") if name.lower() in lower]
        actions = [name for name in ("jump", "drift", "crash", "spin", "donut") if name in lower]
        drivers = [name for name in ("Josh Moffett", "Sam Moffett", "Philip Squires", "Kris Meeke", "Craig Breen") if name.lower() in lower]
        return {"intent": intent, "countries": countries, "years": years, "driverNames": drivers, "actionTypes": actions}
