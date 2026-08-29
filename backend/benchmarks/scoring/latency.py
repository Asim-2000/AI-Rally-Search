from __future__ import annotations

import math
import statistics
from typing import Any


def summarize_latencies(latencies: list[float]) -> dict[str, float]:
    vals = sorted(latencies)
    if not vals:
        return {"avg": 0.0, "p50": 0.0, "p90": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}

    n = len(vals)

    def p(q: float) -> float:
        idx = max(0, min(n - 1, math.ceil(q * n) - 1))
        return vals[idx]

    return {
        "avg": round(statistics.fmean(vals), 2),
        "p50": round(p(0.50), 2),
        "p90": round(p(0.90), 2),
        "p95": round(p(0.95), 2),
        "p99": round(p(0.99), 2),
        "max": round(max(vals), 2),
    }
