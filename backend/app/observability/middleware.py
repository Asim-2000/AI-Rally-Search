from __future__ import annotations

import time
from collections.abc import Awaitable, Callable

from fastapi import Request, Response

from .logging import log_request_timing
from .request_context import request_scope

REQUEST_ID_HEADER = "X-Request-Id"
SERVER_TIMING_HEADER = "X-Backend-Total-Ms"


async def timing_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    """Wraps every request in a timing scope.

    This is the only place that measures the *true* backend total: it starts
    before FastAPI resolves dependencies (where the DB connection is opened)
    and stops after the response is rendered, so dependency and serialization
    cost can no longer hide outside the reported number.
    """
    started = time.perf_counter()
    header_id = request.headers.get(REQUEST_ID_HEADER)
    with request_scope(header_id) as timings:
        timings.update(path=request.url.path, method=request.method)
        request.state.timings = timings
        request.state.request_id = timings.request_id
        try:
            response = await call_next(request)
        except Exception:
            total_ms = (time.perf_counter() - started) * 1000
            timings.set("outcome", "exception")
            log_request_timing(timings.snapshot(total_ms=total_ms))
            raise
        timings.close_serialization()
        total_ms = (time.perf_counter() - started) * 1000
        timings.set("status_code", response.status_code)
        record = timings.snapshot(total_ms=total_ms)
        log_request_timing(record)
        response.headers[REQUEST_ID_HEADER] = timings.request_id
        response.headers[SERVER_TIMING_HEADER] = f"{total_ms:.1f}"
        return response
