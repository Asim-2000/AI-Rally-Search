from __future__ import annotations

import json
import logging
import os
import sys
from typing import Any

TIMING_LOGGER = "app.latency"

_logger = logging.getLogger(TIMING_LOGGER)

# Keys that may never appear in a timing record, whatever a caller passes.
# Raw query text is the important one: timing lines are shipped to whatever
# aggregator the platform provides, and search text is user content.
_FORBIDDEN_KEYS = frozenset(
    {"query", "raw_query", "text", "transcript", "api_key", "authorization", "password", "session"}
)


class JsonFormatter(logging.Formatter):
    """One JSON object per line, so timing records stay machine-queryable."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        extra = getattr(record, "timing", None)
        if isinstance(extra, dict):
            payload.update(extra)
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str, separators=(",", ":"))


def structured_logs_enabled() -> bool:
    return os.getenv("LOG_FORMAT", "json").strip().lower() == "json"


def configure_logging() -> None:
    """Installs the JSON handler and lifts app loggers to INFO.

    Without this the warm-up and timing loggers are silently swallowed by
    uvicorn's default config, which is why cold-start cost was previously
    invisible in production logs.
    """
    level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").strip().upper(), logging.INFO)
    handler = logging.StreamHandler(sys.stdout)
    if structured_logs_enabled():
        handler.setFormatter(JsonFormatter())
    else:
        handler.setFormatter(logging.Formatter("%(levelname)s %(name)s %(message)s"))
    root = logging.getLogger("app")
    root.handlers = [handler]
    root.setLevel(level)
    root.propagate = False


def sanitize(record: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in record.items() if k.lower() not in _FORBIDDEN_KEYS}


def log_request_timing(record: dict[str, Any], *, message: str = "search_timing") -> None:
    """Emits one structured timing line.

    Overhead is a dict copy and a `json.dumps` of ~15 small scalars, on the
    order of tens of microseconds against a request measured in hundreds of
    milliseconds.
    """
    if not _logger.isEnabledFor(logging.INFO):
        return
    _logger.info(message, extra={"timing": sanitize(record)})
