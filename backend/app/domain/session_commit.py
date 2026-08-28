from dataclasses import dataclass

from .conversation_session import SearchConversationSession
from .referent_context import ResultReferentContext
from .search_query import SearchQuery


@dataclass(frozen=True)
class SessionCommitResult:
    committed: bool
    session: SearchConversationSession


def commit_if_current(
    session: SearchConversationSession,
    *,
    response_request_id: int,
    query: SearchQuery,
    referents: ResultReferentContext,
    title: str,
) -> SessionCommitResult:
    """Caller-side guard mirroring Dart's activeRequestId check.

    This is deliberately pure and stateless. The caller supplies its current
    session; the server does not infer ordering between independent requests.
    """
    if session.active_request_id != response_request_id:
        return SessionCommitResult(False, session)
    return SessionCommitResult(
        True,
        session.record_turn(query=query, referents=referents, title=title),
    )
