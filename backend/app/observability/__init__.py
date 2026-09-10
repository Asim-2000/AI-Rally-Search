"""Latency observability: request identity, phase timings, structured logs.

Nothing in here records raw user text, credentials, or result payloads. The
only free-form value that ever reaches a log line is the request id, which the
client generates and which carries no user data.
"""

from .request_context import (
    current_request_id,
    current_timings,
    new_request_id,
    request_scope,
)
from .timings import Phase, RequestTimings

__all__ = [
    "Phase",
    "RequestTimings",
    "current_request_id",
    "current_timings",
    "new_request_id",
    "request_scope",
]
