from .search_intent import SearchIntent
from .search_query import MatchMode, SearchQuery


def generate_interpreted_summary(query: SearchQuery) -> str:
    """Generates a clean, user-facing interpreted summary from the structured SearchQuery

    without making an additional LLM call.
    Strictly mirrors QueryOutputValidator.generateInterpretedSummary in Dart.
    """
    parts: list[str] = []

    match query.intent:
        case SearchIntent.SEARCH_RALLIES:
            parts.append("Searching rally events")
        case SearchIntent.SEARCH_DRIVER_RALLIES:
            parts.append("Searching driver participations")
        case SearchIntent.SEARCH_DRIVER_WINS:
            parts.append("Searching driver victories")
        case SearchIntent.GET_RALLY_RESULTS:
            parts.append("Getting 1st place rally winner")
        case SearchIntent.GET_RALLY_TOP_FINISHERS:
            parts.append("Getting rally leaderboard")
        case SearchIntent.SEARCH_VIDEO_ACTIONS:
            if query.action_types:
                parts.append(f"Showing {', '.join(query.action_types)} highlights")
            else:
                parts.append("Showing action highlights")
        case SearchIntent.SEARCH_DRIVER_VIDEOS:
            parts.append("Searching driver videos")
        case SearchIntent.GET_TOP_UPLOADERS:
            parts.append("Getting top uploaders")
        case SearchIntent.GET_TOP_DRIVERS_BY_WINS:
            parts.append("Getting career wins leaderboard")

    filters: list[str] = []
    if query.driver_names:
        if query.driver_match_mode == MatchMode.ALL:
            filters.append(f"Drivers: {' AND '.join(query.driver_names)}")
        else:
            filters.append(f"Drivers: {', '.join(query.driver_names)}")

    if query.target_rally_names:
        filters.append(f"Rallies: {', '.join(query.target_rally_names)}")
    if query.countries:
        filters.append(f"Countries: {', '.join(query.countries)}")
    if query.cities:
        filters.append(f"Cities: {', '.join(query.cities)}")
    if query.stage_names:
        filters.append(f"Stages: {', '.join(query.stage_names)}")
    if query.stage_numbers:
        filters.append(f"Stage Numbers: {', '.join(query.stage_numbers)}")

    if query.years:
        filters.append(f"Years: {', '.join(str(y) for y in query.years)}")
    elif query.year_from is not None and query.year_to is not None:
        filters.append(f"Years: {query.year_from}–{query.year_to}")
    elif query.year_from is not None:
        filters.append(f"Years: >= {query.year_from}")
    elif query.year_to is not None:
        filters.append(f"Years: <= {query.year_to}")

    if not filters:
        return "".join(parts)
    return f"{''.join(parts)} | {' | '.join(filters)}"
