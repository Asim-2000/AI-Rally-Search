"""Pure deterministic state reducer for conversational search sessions.

Strictly mirrors GeneralSearchScreen and SearchConversationSession state transitions.
"""

from .conversation_session import SearchConversationSession
from .referent_context import ResultReferentContext
from .results import SearchResponse
from .search_query import SearchQuery


def calculate_inherited_and_refined_fields(
    previous_query: SearchQuery,
    parsed_query: SearchQuery,
) -> tuple[set[str], set[str]]:
    """Determines which fields were inherited vs refined in this turn,

    matching lib/screens/general_search_screen.dart lines 246-287.
    """
    inherited: set[str] = set()
    refinements: set[str] = set()

    if parsed_query.rally_names:
        if previous_query.rally_names and previous_query.rally_names[0].lower() == parsed_query.rally_names[0].lower():
            inherited.add("rally")
        else:
            refinements.add("rally")

    if parsed_query.driver_names:
        if previous_query.driver_names and previous_query.driver_names[0].lower() == parsed_query.driver_names[0].lower():
            inherited.add("driver")
        else:
            refinements.add("driver")

    if parsed_query.action_types:
        refinements.add("action")

    if parsed_query.countries:
        if previous_query.countries and previous_query.countries[0].lower() == parsed_query.countries[0].lower():
            inherited.add("country")
        else:
            refinements.add("country")

    if parsed_query.years:
        if previous_query.years and previous_query.years[0] == parsed_query.years[0]:
            inherited.add("year")
        else:
            refinements.add("year")

    return inherited, refinements


def reduce_turn(
    session: SearchConversationSession,
    *,
    query: SearchQuery,
    referents: ResultReferentContext,
    title: str,
    response: SearchResponse | None = None,
    interpreted_summary: str | None = None,
) -> SearchConversationSession:
    """Pure deterministic reducer producing next SearchConversationSession from a completed turn."""
    inherited, refinements = calculate_inherited_and_refined_fields(session.active_query, query)
    return session.record_turn(
        query=query,
        referents=referents,
        title=title,
        response=response,
        interpreted_summary=interpreted_summary,
        inherited=inherited,
        refinements=refinements,
    )
