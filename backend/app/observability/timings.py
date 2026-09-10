from __future__ import annotations

import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any, Iterator


class Phase(StrEnum):
    """The phases of one search request, in pipeline order.

    Every value maps 1:1 onto a `<phase>_ms` key in the emitted timing record,
    so adding a phase here is the only edit needed to surface a new number.
    """

    # Time spent in FastAPI dependency resolution before the handler body runs.
    # This is where the per-request DB connection is opened, so it must be
    # measured separately or it disappears from the breakdown entirely.
    DEPENDENCIES = "dependencies"
    DB_CONNECT = "db_connect"
    QUERY_UNDERSTANDING = "query_understanding"
    GEMINI = "gemini"
    EXTERNAL_API = "external_api"
    DETERMINISTIC_RECOVERY = "deterministic_recovery"
    ENTITY_RESOLUTION = "entity_resolution"
    SEARCH_PLAN = "search_plan"
    REPOSITORY_DB = "repository_db"
    SERIALIZATION = "serialization"


@dataclass
class RequestTimings:
    """Accumulates per-phase durations for one request.

    Durations accumulate, so a phase entered twice (a provider retry, two DB
    round-trips) reports the summed time rather than only the last span. The
    collector is deliberately allocation-light: measuring adds two
    `perf_counter` reads and a float add per phase.
    """

    request_id: str
    started: float = field(default_factory=time.perf_counter)
    phases: dict[str, float] = field(default_factory=dict)
    attributes: dict[str, Any] = field(default_factory=dict)
    _handler_done: float | None = field(default=None, repr=False)

    def add(self, phase: Phase | str, duration_ms: float) -> None:
        key = str(phase)
        self.phases[key] = self.phases.get(key, 0.0) + max(0.0, duration_ms)

    @contextmanager
    def measure(self, phase: Phase | str) -> Iterator[None]:
        started = time.perf_counter()
        try:
            yield
        finally:
            self.add(phase, (time.perf_counter() - started) * 1000)

    def mark_handler_complete(self) -> None:
        """Marks the instant the handler returned its response model.

        Response serialization happens after that point but still inside the
        request, so the middleware turns this mark into `serialization_ms`.
        """
        self._handler_done = time.perf_counter()

    def close_serialization(self) -> None:
        done = getattr(self, "_handler_done", None)
        if done is not None:
            self.add(Phase.SERIALIZATION, (time.perf_counter() - done) * 1000)

    def set(self, key: str, value: Any) -> None:
        """Records a non-timing attribute (model used, intent, flags).

        Values are expected to be small scalars. Raw query text must never be
        passed here — see the module docstring in `observability/__init__`.
        """
        self.attributes[key] = value

    def update(self, **values: Any) -> None:
        self.attributes.update(values)

    @property
    def total_ms(self) -> float:
        return (time.perf_counter() - self.started) * 1000

    def snapshot(self, *, total_ms: float | None = None) -> dict[str, Any]:
        """The flat record written to logs and (in debug mode) the response."""
        record: dict[str, Any] = {"request_id": self.request_id}
        record["total_backend_ms"] = round(
            self.total_ms if total_ms is None else total_ms, 1
        )
        for phase in Phase:
            value = self.phases.get(str(phase))
            if value is not None:
                record[f"{phase}_ms"] = round(value, 1)
        record.update(self.attributes)
        return record
