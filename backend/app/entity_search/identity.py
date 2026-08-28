from __future__ import annotations

from typing import Any
from ..domain.search_query import PersonRole


def format_canonical_person_id(*, account_id: str | None = None, driver_id: str | None = None,
                               codriver_id: str | None = None, role: str = "driver") -> str:
    """Canonical Person Identity Formatter.
    Identity classes:
    1. person:account:<account_id>
    2. person:driver:<driver_id>
    3. person:codriver:<codriver_id>
    """
    if account_id is not None and str(account_id).strip() and str(account_id).strip().lower() != "null":
        return f"person:account:{account_id}"
    if role == "driver" or (driver_id and not codriver_id):
        return f"person:driver:{driver_id}"
    return f"person:codriver:{codriver_id}"


def get_canonical_identity(candidate_or_metadata: Any, candidate_type: str | None = None) -> str:
    """Authoritative cross-role deduplication key."""
    if hasattr(candidate_or_metadata, "metadata") and hasattr(candidate_or_metadata, "id"):
        meta = candidate_or_metadata.metadata or {}
        c_type = getattr(candidate_or_metadata, "type", None)
        type_str = c_type.value if hasattr(c_type, "value") else str(c_type)
        if type_str in ("driver", "person", "EntityType.driver"):
            account_id = meta.get("accountId") or meta.get("account_id")
            if account_id and str(account_id).strip() and str(account_id).lower() != "null":
                return str(account_id)
            return str(candidate_or_metadata.id)
        return str(candidate_or_metadata.id)

    if isinstance(candidate_or_metadata, dict):
        account_id = candidate_or_metadata.get("accountId") or candidate_or_metadata.get("account_id")
        if account_id and str(account_id).strip() and str(account_id).lower() != "null":
            return str(account_id)
        return str(candidate_or_metadata.get("id", ""))

    return str(candidate_or_metadata)
