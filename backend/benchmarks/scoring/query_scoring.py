from __future__ import annotations

from typing import Any

LIST_FIELDS = (
    "rallyNames",
    "eventNames",
    "countries",
    "cities",
    "stageNames",
    "stageNumbers",
    "driverNames",
    "actionTypes",
    "years",
    "uploaders",
)

SCALAR_FIELDS = (
    "yearFrom",
    "yearTo",
    "personRole",
    "driverMatchMode",
    "requiresClarification",
)


def _norm(val: Any) -> str:
    return str(val).strip().casefold()


def _set_norm(vals: list[Any] | None) -> set[str]:
    if not vals:
        return set()
    return {_norm(v) for v in vals if v is not None and str(v).strip()}


def score_raw_query(
    expected: dict[str, Any],
    actual: dict[str, Any] | None,
    *,
    input_text: str = "",
    context_text: str = "",
) -> dict[str, Any]:
    """Scores raw parsed SearchQuery against gold expected SearchQuery BEFORE downstream recovery.
    """
    if actual is None:
        return {
            "schema_valid": False,
            "intent_match": False,
            "exact_match": False,
            "field_precision": 0.0,
            "field_recall": 0.0,
            "field_f1": 0.0,
            "entity_retention": 0.0,
            "wrong_field": False,
            "wrong_fields": [],
            "extra_fields": [],
            "true_hallucinations": [],
            "hallucinated_fields": [],
            "missing_fields": [],
            "multivalue_complete": False,
            "person_role_match": False,
            "match_mode_match": False,
            "tp": 0,
            "fp": 0,
            "fn": sum(len(v) if isinstance(v, list) else 1 for k, v in expected.items() if k != "intent"),
        }

    # Intent match
    exp_intent = expected.get("intent")
    act_intent = actual.get("intent")
    intent_match = (exp_intent == act_intent) if exp_intent else True

    # Check for wrong-field assignment (e.g. driver in rallyNames, rally in driverNames)
    all_exp_entities: dict[str, str] = {}
    for f in ("driverNames", "rallyNames", "stageNames", "countries", "cities", "actionTypes"):
        for val in expected.get(f) or []:
            all_exp_entities[_norm(val)] = f

    all_act_entities: dict[str, str] = {}
    for f in ("driverNames", "rallyNames", "stageNames", "countries", "cities", "actionTypes"):
        for val in actual.get(f) or []:
            all_act_entities[_norm(val)] = f

    wrong_fields: list[str] = []
    for ent_str, act_field in all_act_entities.items():
        if ent_str in all_exp_entities:
            exp_field = all_exp_entities[ent_str]
            if exp_field != act_field:
                wrong_fields.append(f"entity '{ent_str}' expected in {exp_field} but put in {act_field}")

    # Set overlap
    tp = fp = fn = 0
    missing_fields: list[str] = []
    extra_fields: list[str] = []
    true_hallucinations: list[str] = []

    full_context_str = f"{context_text} {input_text}".casefold()

    for field in LIST_FIELDS:
        e_set = _set_norm(expected.get(field))
        a_set = _set_norm(actual.get(field))
        tp += len(e_set & a_set)
        fn += len(e_set - a_set)
        if e_set - a_set:
            missing_fields.append(field)

        for act_val in (a_set - e_set):
            fp += 1
            # Check if this extra value exists anywhere in input/context text
            if act_val in full_context_str or any(tok in full_context_str for tok in act_val.split()):
                extra_fields.append(f"{field}:{act_val}")
            else:
                true_hallucinations.append(f"{field}:{act_val}")

    # Scalar fields
    for field in SCALAR_FIELDS:
        if field in expected and expected[field] is not None:
            exp_val = expected[field]
            act_val = actual.get(field)
            if exp_val == act_val:
                tp += 1
            else:
                fn += 1
                if act_val is not None:
                    fp += 1
                    extra_fields.append(f"{field}:{act_val}")
                missing_fields.append(field)
        elif actual.get(field) is not None:
            # Check default values that are benign
            if field == "personRole" and actual.get(field) == "ANY":
                pass
            elif field == "driverMatchMode" and actual.get(field) == "ANY":
                pass
            elif field == "requiresClarification" and actual.get(field) is False:
                pass
            else:
                fp += 1
                extra_fields.append(f"{field}:{actual.get(field)}")

    precision = tp / (tp + fp) if (tp + fp) > 0 else (1.0 if fn == 0 else 0.0)
    recall = tp / (tp + fn) if (tp + fn) > 0 else 1.0
    f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0

    # Entity retention rate
    exp_entity_count = sum(len(expected.get(f) or []) for f in ("driverNames", "rallyNames", "stageNames"))
    matched_entity_count = sum(
        len(_set_norm(expected.get(f)) & _set_norm(actual.get(f)))
        for f in ("driverNames", "rallyNames", "stageNames")
    )
    entity_retention = matched_entity_count / exp_entity_count if exp_entity_count > 0 else 1.0

    # Multi-value completeness
    mv_expected = any(len(expected.get(f) or []) > 1 for f in LIST_FIELDS)
    mv_complete = True
    if mv_expected:
        for f in LIST_FIELDS:
            e_len = len(expected.get(f) or [])
            if e_len > 1:
                a_len = len(actual.get(f) or [])
                if a_len < e_len:
                    mv_complete = False
                    break

    person_role_match = (actual.get("personRole") or "ANY") == (expected.get("personRole") or "ANY")
    match_mode_match = (actual.get("driverMatchMode") or "ANY") == (expected.get("driverMatchMode") or "ANY")

    exact_match = (
        intent_match
        and len(missing_fields) == 0
        and len(extra_fields) == 0
        and len(true_hallucinations) == 0
        and len(wrong_fields) == 0
        and person_role_match
        and match_mode_match
    )

    return {
        "schema_valid": True,
        "intent_match": intent_match,
        "exact_match": exact_match,
        "field_precision": round(precision, 4),
        "field_recall": round(recall, 4),
        "field_f1": round(f1, 4),
        "entity_retention": round(entity_retention, 4),
        "wrong_field": len(wrong_fields) > 0,
        "wrong_fields": wrong_fields,
        "extra_fields": sorted(set(extra_fields)),
        "true_hallucinations": sorted(set(true_hallucinations)),
        "hallucinated_fields": sorted(set(true_hallucinations + extra_fields)),
        "missing_fields": sorted(set(missing_fields)),
        "multivalue_complete": mv_complete,
        "person_role_match": person_role_match,
        "match_mode_match": match_mode_match,
        "tp": tp,
        "fp": fp,
        "fn": fn,
    }
