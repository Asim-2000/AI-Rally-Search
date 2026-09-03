from __future__ import annotations

import re
import uuid
from contextlib import contextmanager
from contextvars import ContextVar
from typing import Iterator

from .timings import RequestTimings

_request_id: ContextVar[str | None] = ContextVar("rally_request_id", default=None)
_timings: ContextVar[RequestTimings | None] = ContextVar("rally_timings", default=None)

# A client-supplied correlation id is echoed into logs, so it is constrained to
# an opaque, bounded token. Anything else is replaced with a generated id
# rather than rejected: correlation is a convenience, never a request gate.
_SAFE_REQUEST_ID = re.compile(r"^[A-Za-z0-9._:-]{1,64}$")


def new_request_id() -> str:
    return uuid.uuid4().hex


def sanitize_request_id(candidate: str | None) -> str:
    if candidate and _SAFE_REQUEST_ID.match(candidate):
        return candidate
    return new_request_id()


def current_request_id() -> str | None:
    return _request_id.get()


def current_timings() -> RequestTimings | None:
    """The active collector, or None outside a request scope.

    Callers deep in the pipeline use this instead of threading a timings
    argument through every signature; when no scope is active (unit tests,
    scripts) they simply record nothing.
    """
    return _timings.get()


@contextmanager
def request_scope(request_id: str | None = None) -> Iterator[RequestTimings]:
    rid = sanitize_request_id(request_id)
    timings = RequestTimings(request_id=rid)
    id_token = _request_id.set(rid)
    timings_token = _timings.set(timings)
    try:
        yield timings
    finally:
        _timings.reset(timings_token)
        _request_id.reset(id_token)
