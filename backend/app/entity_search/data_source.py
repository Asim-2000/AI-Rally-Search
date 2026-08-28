from __future__ import annotations

from typing import Any, Protocol
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine
from .models import CanonicalSearchEntity, SearchEntityType


class IEntitySearchDataSource(Protocol):
    async def load_entities(self) -> list[CanonicalSearchEntity]:
        ...


class StaticDataSource:
    def __init__(self, entities: list[CanonicalSearchEntity]) -> None:
        self._entities = list(entities)

    async def load_entities(self) -> list[CanonicalSearchEntity]:
        return self._entities


class MySqlEntitySearchDataSource:
    """Live relational database entity search data source."""

    def __init__(self, *, engine: AsyncEngine | None = None, connection: AsyncConnection | None = None) -> None:
        self._engine = engine
        self._connection = connection

    async def load_entities(self) -> list[CanonicalSearchEntity]:
        if self._connection is not None:
            return await self._load_with_conn(self._connection)
        elif self._engine is not None:
            async with self._engine.connect() as conn:
                return await self._load_with_conn(conn)
        else:
            from ..db.engine import get_engine
            async with get_engine().connect() as conn:
                return await self._load_with_conn(conn)

    async def _load_with_conn(self, conn: AsyncConnection) -> list[CanonicalSearchEntity]:
        # 1. Rally events
        rallies_res = await conn.execute(text("""
            SELECT event_id, event_name, country, city,
                   YEAR(start_date) AS event_year
            FROM rally_events
            WHERE event_name IS NOT NULL AND TRIM(event_name) <> '';
        """))
        rally_rows = [dict(row._mapping) for row in rallies_res.fetchall()]

        # 2. Driver & Co-driver profiles
        people_res = await conn.execute(text("""
            SELECT account_id, driver_id AS profile_id, full_name, country,
                   'driver' AS person_role
            FROM user_driver_profile
            WHERE driver_id IS NOT NULL AND full_name IS NOT NULL AND TRIM(full_name) <> ''
            UNION ALL
            SELECT account_id, codriver_id AS profile_id, full_name, country,
                   'co_driver' AS person_role
            FROM user_codriver_profile
            WHERE codriver_id IS NOT NULL AND full_name IS NOT NULL AND TRIM(full_name) <> '';
        """))
        person_rows = [dict(row._mapping) for row in people_res.fetchall()]

        # 3. Stages
        stages_res = await conn.execute(text("""
            SELECT stg.stage_id, stg.stage_name, stg.stage_number, stg.event_id,
                   ev.event_name
            FROM rally_stages stg
            LEFT JOIN rally_events ev ON ev.event_id = stg.event_id
            WHERE stg.stage_name IS NOT NULL AND TRIM(stg.stage_name) <> '';
        """))
        stage_rows = [dict(row._mapping) for row in stages_res.fetchall()]

        # 4. Uploaders
        uploaders_res = await conn.execute(text("""
            SELECT fp.fan_id, fp.account_id, ua.user_name, fp.full_name, ua.email
            FROM user_fan_profile fp
            LEFT JOIN user_account ua ON ua.id = fp.account_id
            WHERE COALESCE(NULLIF(TRIM(ua.user_name), ''),
                           NULLIF(TRIM(fp.full_name), ''),
                           NULLIF(TRIM(ua.email), '')) IS NOT NULL;
        """))
        uploader_rows = [dict(row._mapping) for row in uploaders_res.fetchall()]

        entities: list[CanonicalSearchEntity] = []

        # Rallies
        for row in rally_rows:
            event_id = str(row.get("event_id") or "")
            event_name = str(row.get("event_name") or "")
            year_val = row.get("event_year")
            entities.append(
                CanonicalSearchEntity(
                    canonical_id=event_id,
                    canonical_name=event_name,
                    entity_type=SearchEntityType.RALLY,
                    metadata={
                        "eventId": event_id,
                        "year": int(year_val) if year_val is not None and str(year_val).isdigit() else None,
                        "country": str(row.get("country")) if row.get("country") else None,
                        "city": str(row.get("city")) if row.get("city") else None,
                    },
                )
            )

        # People
        people_by_account: dict[str, dict[str, Any]] = {}
        for row in person_rows:
            account_id = str(row.get("account_id") or "").strip()
            if account_id.lower() == "none" or account_id.lower() == "null":
                account_id = ""
            profile_id = str(row.get("profile_id") or "").strip()
            profile_name = str(row.get("full_name") or "").strip()
            role = str(row.get("person_role") or "")
            country = str(row.get("country")) if row.get("country") else None

            if not account_id:
                if not profile_id or not profile_name:
                    continue
                is_driver = role == "driver"
                canonical_id = f"person:driver:{profile_id}" if is_driver else f"person:codriver:{profile_id}"
                entities.append(
                    CanonicalSearchEntity(
                        canonical_id=canonical_id,
                        canonical_name=profile_name,
                        entity_type=SearchEntityType.PERSON,
                        metadata={
                            "accountId": None,
                            "driverId": profile_id if is_driver else None,
                            "codriverId": None if is_driver else profile_id,
                            "role": "driver" if is_driver else "co_driver",
                            "country": country,
                            "canonicalDisplayName": profile_name,
                            "searchableNames": [profile_name],
                            "identityKind": "driver" if is_driver else "codriver",
                        },
                    )
                )
                continue

            current = people_by_account.setdefault(
                account_id,
                {
                    "country": country,
                    "role": role,
                    "driverNames": set(),
                    "codriverNames": set(),
                    "driverId": None,
                    "codriverId": None,
                },
            )
            if role == "driver":
                current["driverId"] = profile_id
                if profile_name:
                    current["driverNames"].add(profile_name)
            else:
                current["codriverId"] = profile_id
                if profile_name:
                    current["codriverNames"].add(profile_name)

            if current["driverId"] is not None and current["codriverId"] is not None:
                current["role"] = "both"

        for acc_id, data in people_by_account.items():
            driver_names = sorted(data["driverNames"], key=lambda s: s.lower())
            codriver_names = sorted(data["codriverNames"], key=lambda s: s.lower())
            searchable_names = sorted(set(driver_names) | set(codriver_names), key=lambda s: s.lower())

            display_name = driver_names[0] if driver_names else (codriver_names[0] if codriver_names else "")
            entities.append(
                CanonicalSearchEntity(
                    canonical_id=f"person:account:{acc_id}",
                    canonical_name=display_name,
                    entity_type=SearchEntityType.PERSON,
                    metadata={
                        "accountId": acc_id,
                        "driverId": data["driverId"],
                        "codriverId": data["codriverId"],
                        "role": data["role"],
                        "country": data["country"],
                        "searchableNames": searchable_names,
                        "canonicalDisplayName": display_name,
                        "identityKind": "account",
                        "canonicalDisplayNamePolicy": "driver_profile_then_codriver_profile_lexical",
                    },
                )
            )

        # Stages
        for row in stage_rows:
            stage_id = str(row.get("stage_id") or "")
            stage_name = str(row.get("stage_name") or "")
            entities.append(
                CanonicalSearchEntity(
                    canonical_id=stage_id,
                    canonical_name=stage_name,
                    entity_type=SearchEntityType.STAGE,
                    metadata={
                        "stageId": stage_id,
                        "stageNumber": str(row.get("stage_number")) if row.get("stage_number") is not None else None,
                        "eventId": str(row.get("event_id")) if row.get("event_id") else None,
                        "eventName": str(row.get("event_name")) if row.get("event_name") else None,
                    },
                )
            )

        # Uploaders
        for row in uploader_rows:
            fan_id = str(row.get("fan_id") or "")
            user_name = str(row.get("user_name") or "").strip()
            full_name = str(row.get("full_name") or "").strip()
            email = str(row.get("email") or "").strip()

            display_name = user_name if user_name else (full_name if full_name else email)
            entities.append(
                CanonicalSearchEntity(
                    canonical_id=fan_id,
                    canonical_name=display_name,
                    entity_type=SearchEntityType.UPLOADER,
                    metadata={
                        "fanId": fan_id,
                        "accountId": str(row.get("account_id")) if row.get("account_id") else None,
                        "username": user_name,
                        "fullName": full_name,
                    },
                )
            )

        return entities
