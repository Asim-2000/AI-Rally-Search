from __future__ import annotations

from typing import Any
from ..domain.search_query import PersonRole
from .models import CanonicalSearchEntity


def is_person_role_eligible(
    metadata: dict[str, Any] | None,
    requested_role: PersonRole | str | None,
) -> bool:
    """Exact counterpart of Dart EntitySearchLookupAdapter.isPersonRoleEligible."""
    if metadata is None:
        return True

    driver_id = metadata.get("driverId") or metadata.get("driver_id")
    codriver_id = metadata.get("codriverId") or metadata.get("codriver_id")

    has_driver = (
        driver_id is not None
        and str(driver_id).strip() != ""
        and str(driver_id).strip().lower() != "null"
    )
    has_codriver = (
        codriver_id is not None
        and str(codriver_id).strip() != ""
        and str(codriver_id).strip().lower() != "null"
    )

    if requested_role is None:
        return True

    role_str = requested_role.value if isinstance(requested_role, PersonRole) else str(requested_role)
    role_str_lower = role_str.lower()

    if role_str_lower in ("driver", "personrole.driver") or role_str_lower.endswith(".driver"):
        return has_driver
    elif role_str_lower in ("co_driver", "codriver", "personrole.codriver", "personrole.co_driver") or "codriver" in role_str_lower:
        return has_codriver
    else:  # ANY
        return has_driver or has_codriver


def is_candidate_role_allowed(
    entity: CanonicalSearchEntity | Any,
    requested_role: PersonRole | str | None,
) -> bool:
    """Candidate generator role constraint checker matching Dart _roleAllowed."""
    if requested_role is None:
        return True

    role_str = requested_role.value if isinstance(requested_role, PersonRole) else str(requested_role)
    role_str_lower = role_str.lower()
    if role_str_lower.endswith(".any") or role_str_lower == "any":
        return True

    metadata = getattr(entity, "metadata", None)
    if isinstance(entity, dict):
        metadata = entity
    elif metadata is None and isinstance(getattr(entity, "source", None), CanonicalSearchEntity):
        metadata = entity.source.metadata

    if metadata is None:
        return True

    # If entity has a high-level role field
    role = str(metadata.get("role", "")).lower()
    if role == "both":
        return True

    driver_id = metadata.get("driverId") or metadata.get("driver_id")
    codriver_id = metadata.get("codriverId") or metadata.get("codriver_id")
    has_driver = (
        driver_id is not None
        and str(driver_id).strip() != ""
        and str(driver_id).strip().lower() != "null"
    )
    has_codriver = (
        codriver_id is not None
        and str(codriver_id).strip() != ""
        and str(codriver_id).strip().lower() != "null"
    )

    if role_str_lower.endswith(".driver") or role_str_lower == "driver":
        return has_driver or role == "driver"
    else:
        return has_codriver or role == "co_driver"
