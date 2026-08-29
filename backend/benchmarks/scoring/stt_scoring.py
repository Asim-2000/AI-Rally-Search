from __future__ import annotations

import re
from typing import Any


def _normalize_text(text: str) -> str:
    t = text.lower()
    t = re.sub(r"[^\w\s]", "", t)
    return " ".join(t.split())


def compute_wer(reference: str, hypothesis: str) -> float:
    ref_words = _normalize_text(reference).split()
    hyp_words = _normalize_text(hypothesis).split()
    if not ref_words:
        return 0.0 if not hyp_words else 1.0

    d = [[0] * (len(hyp_words) + 1) for _ in range(len(ref_words) + 1)]
    for i in range(len(ref_words) + 1):
        d[i][0] = i
    for j in range(len(hyp_words) + 1):
        d[0][j] = j

    for i in range(1, len(ref_words) + 1):
        for j in range(1, len(hyp_words) + 1):
            if ref_words[i - 1] == hyp_words[j - 1]:
                d[i][j] = d[i - 1][j - 1]
            else:
                d[i][j] = min(
                    d[i - 1][j] + 1,      # deletion
                    d[i][j - 1] + 1,      # insertion
                    d[i - 1][j - 1] + 1,  # substitution
                )
    return d[len(ref_words)][len(hyp_words)] / len(ref_words)


def score_stt_result(reference_text: str, transcript: str | None, entities: list[dict[str, str]]) -> dict[str, Any]:
    if transcript is None:
        return {
            "wer": 1.0,
            "entity_preservation_rate": 0.0,
            "entities_found": 0,
            "entities_total": len(entities),
            "entity_breakdown": {},
        }

    wer = compute_wer(reference_text, transcript)
    norm_hyp = _normalize_text(transcript)

    found_count = 0
    breakdown: dict[str, dict[str, int]] = {}

    for ent in entities:
        t = ent.get("type", "UNKNOWN")
        val = _normalize_text(ent.get("text", ""))
        breakdown.setdefault(t, {"found": 0, "total": 0})
        breakdown[t]["total"] += 1
        if val in norm_hyp:
            found_count += 1
            breakdown[t]["found"] += 1

    epr = found_count / len(entities) if entities else 1.0
    return {
        "wer": round(wer, 4),
        "entity_preservation_rate": round(epr, 4),
        "entities_found": found_count,
        "entities_total": len(entities),
        "entity_breakdown": breakdown,
    }
