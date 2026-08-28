from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass(frozen=True)
class TelemetryEvent:
    name: str
    attributes: dict[str, Any] = field(default_factory=dict)


class TelemetrySink(Protocol):
    def record(self, event: TelemetryEvent) -> None: ...


class NullTelemetry:
    def record(self, event: TelemetryEvent) -> None:
        return None


class InMemoryTelemetry:
    def __init__(self) -> None:
        self.events: list[TelemetryEvent] = []

    def record(self, event: TelemetryEvent) -> None:
        self.events.append(event)
