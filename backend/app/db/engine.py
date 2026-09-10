from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine, create_async_engine

from ..config import get_settings
from ..observability import Phase, current_timings

_engine: AsyncEngine | None = None


def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        settings = get_settings()
        if not settings.db_host or not settings.db_name or not settings.db_user:
            raise RuntimeError("Database configuration is incomplete")
        # A pooled engine. The previous NullPool opened a fresh TCP + TLS +
        # MySQL auth handshake on every request, measured at ~178 ms each
        # against the production host; a checked-out pooled connection costs
        # ~30 ms. `pool_pre_ping` covers connections the server closed while
        # idle, and `pool_recycle` stays below the usual wait_timeout so a
        # stale connection is never handed to a request.
        #
        # Async connections must still never leak across event loops: the
        # engine is created lazily per process, and every worker process
        # therefore builds its own pool.
        _engine = create_async_engine(
            settings.database_url,
            pool_size=settings.db_pool_size,
            max_overflow=settings.db_max_overflow,
            pool_timeout=settings.db_pool_timeout_seconds,
            pool_recycle=settings.db_pool_recycle_seconds,
            pool_pre_ping=True,
        )
    return _engine


async def dispose_engine() -> None:
    global _engine
    if _engine is not None:
        await _engine.dispose()
        _engine = None


async def get_connection() -> AsyncIterator[AsyncConnection]:
    """Yields a pooled connection, recording checkout cost as `db_connect`.

    Dependency resolution runs before the handler body, so without this
    measurement the connection cost lands outside every in-handler timer.
    """
    timings = current_timings()
    if timings is None:
        async with get_engine().connect() as connection:
            yield connection
        return
    with timings.measure(Phase.DB_CONNECT):
        context = get_engine().connect()
        connection = await context.__aenter__()
    try:
        yield connection
    finally:
        await context.__aexit__(None, None, None)
