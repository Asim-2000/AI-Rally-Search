import json
import re
from typing import Any

from pydantic import ValidationError

from ..domain.search_query import SearchQuery
from .models import FailureKind
from .normalization import CANONICAL_FIELDS, normalize_payload

ALLOWED_ACTIONS = {"jump", "drift", "crash", "spin", "donut", "hairpin", "water splash", "start line", "near miss", "mechanical failure", "offroad", "stuck"}


class OutputValidationError(ValueError):
    def __init__(self, kind: FailureKind, message: str):
        super().__init__(message)
        self.kind = kind


def extract_json(raw: str) -> dict[str, Any]:
    text = raw.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text, flags=re.I)
    try:
        value = json.loads(text)
    except (json.JSONDecodeError, TypeError) as exc:
        raise OutputValidationError(FailureKind.INVALID_JSON, str(exc)) from exc
    if not isinstance(value, dict):
        raise OutputValidationError(FailureKind.INVALID_JSON, "provider output must be a JSON object")
    return value


def validate_provider_output(raw: str, *, allow_user_supplied_driver_ids: bool = False) -> SearchQuery:
    payload = extract_json(raw)
    unknown = sorted(set(payload) - CANONICAL_FIELDS)
    if unknown:
        raise OutputValidationError(FailureKind.SCHEMA_VALIDATION_FAILURE, f"unknown fields: {', '.join(unknown)}")
    if payload.get("driverIds") and not allow_user_supplied_driver_ids:
        raise OutputValidationError(FailureKind.SEMANTIC_VALIDATION_FAILURE, "the model may not supply driverIds")
    actions = payload.get("actionTypes", [])
    if not isinstance(actions, list) or any(action not in ALLOWED_ACTIONS for action in actions):
        raise OutputValidationError(FailureKind.SEMANTIC_VALIDATION_FAILURE, "unsupported actionTypes value")
    try:
        return SearchQuery.model_validate(normalize_payload(payload))
    except ValidationError as exc:
        raise OutputValidationError(FailureKind.SCHEMA_VALIDATION_FAILURE, str(exc)) from exc
