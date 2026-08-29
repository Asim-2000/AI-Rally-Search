from __future__ import annotations

from typing import Any

# Verified pricing estimates per 1,000,000 tokens
MODEL_PRICING: dict[str, dict[str, float]] = {
    "gpt-5.6-luna": {"input": 0.15, "output": 0.60, "cached": 0.075},
    "claude-haiku-4-5": {"input": 0.25, "output": 1.25, "cached": 0.025},
    "claude-sonnet-5": {"input": 3.00, "output": 15.00, "cached": 0.30},
    "gemini-3.5-flash-lite": {"input": 0.075, "output": 0.30, "cached": 0.01875},
    "gemini-3.5-flash": {"input": 0.15, "output": 0.60, "cached": 0.0375},
    "gemini-3.7-flash": {"input": 0.15, "output": 0.60, "cached": 0.0375},
}


def calculate_cost(
    model: str,
    input_tokens: int | None,
    output_tokens: int | None,
    cached_tokens: int | None = None,
    reasoning_tokens: int | None = None,
) -> dict[str, float | None]:
    pricing = MODEL_PRICING.get(model)
    if not pricing:
        return {"single_cost": None, "cost_per_1k": None, "cost_per_100k": None}

    inp = input_tokens or 0
    out = output_tokens or 0
    cached = cached_tokens or 0

    cost = (
        (inp * pricing.get("input", 0.0))
        + (out * pricing.get("output", 0.0))
        + (cached * pricing.get("cached", 0.0))
    ) / 1_000_000.0

    return {
        "single_cost": round(cost, 6),
        "cost_per_1k": round(cost * 1_000.0, 4),
        "cost_per_100k": round(cost * 100_000.0, 2),
    }
