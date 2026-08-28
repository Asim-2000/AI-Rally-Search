from typing import Any


CANONICAL_FIELDS = {
    "intent", "rallyNames", "eventNames", "countries", "cities", "stageNames", "stageNumbers",
    "driverNames", "driverIds", "actionTypes", "years", "yearFrom", "yearTo", "uploaders",
    "driverMatchMode", "personRole", "limit", "offset",
}


def normalize_payload(payload: dict[str, Any]) -> dict[str, Any]:
    """Add schema defaults only; never guess, rename, or silently discard fields."""
    result = dict(payload)
    for name in (
        "rallyNames", "eventNames", "countries", "cities", "stageNames", "stageNumbers",
        "driverNames", "driverIds", "actionTypes", "years", "uploaders",
    ):
        result.setdefault(name, [])
    result.setdefault("driverMatchMode", "ANY")
    result.setdefault("personRole", "ANY")
    result.setdefault("limit", 20)
    result.setdefault("offset", 0)
    return result
