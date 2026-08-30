from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncConnection

from ...db.engine import get_connection
from ...services.offline_snapshot import build_snapshot

router = APIRouter(prefix="/v1/offline")


@router.get("/snapshot")
async def offline_snapshot(
    segment: Literal["core", "full"] = Query(
        "full",
        description="'core' omits video metadata (~2-4 MB); 'full' includes it.",
    ),
    connection: AsyncConnection = Depends(get_connection),
) -> dict:
    """Compact, read-only snapshot of public rally data for offline SQLite.

    The device never touches MySQL; this authenticated backend endpoint is the
    only offline data channel. No DB credentials, API secrets, emails or PII are
    included.
    """
    return await build_snapshot(connection, segment=segment)
