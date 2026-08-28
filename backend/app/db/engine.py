from collections.abc import AsyncIterator
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine, create_async_engine
from sqlalchemy.pool import NullPool
from ..config import get_settings

_engine: AsyncEngine | None = None

def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        settings = get_settings()
        if not settings.db_host or not settings.db_name or not settings.db_user:
            raise RuntimeError("Database configuration is incomplete")
        # Async connections must never leak across worker/event-loop boundaries.
        _engine = create_async_engine(settings.database_url, poolclass=NullPool)
    return _engine

async def get_connection() -> AsyncIterator[AsyncConnection]:
    async with get_engine().connect() as connection:
        yield connection
