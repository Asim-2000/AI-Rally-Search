from __future__ import annotations

import asyncio
import logging
import time
from typing import TYPE_CHECKING
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine

from .data_source import MySqlEntitySearchDataSource
from .models import EntitySearchIndexStats
from .service import InMemoryEntitySearchService

if TYPE_CHECKING:
    pass

logger = logging.getLogger("app.entity_search.warmup")

_shared_entity_search_service: InMemoryEntitySearchService | None = None
_warmup_task: asyncio.Task[InMemoryEntitySearchService] | None = None
_warmup_lock = asyncio.Lock()
_is_ready: bool = False
_last_error: Exception | None = None


def is_entity_search_ready() -> bool:
    """Returns True if the OpenEntity index has completed warm-up and is ready to serve."""
    return _is_ready and _shared_entity_search_service is not None


def get_entity_index_stats() -> EntitySearchIndexStats | None:
    """Returns index statistics if the index is ready."""
    if _shared_entity_search_service is not None:
        return _shared_entity_search_service.index_stats
    return None


def get_entity_count() -> int | None:
    """Returns total indexed entity count if ready."""
    stats = get_entity_index_stats()
    if stats is not None:
        return stats.entity_count
    if _shared_entity_search_service is not None and hasattr(_shared_entity_search_service, "_index_by_id"):
        return len(_shared_entity_search_service._index_by_id)
    return None


async def _run_warmup(engine: AsyncEngine) -> InMemoryEntitySearchService:
    global _shared_entity_search_service, _is_ready, _last_error
    t_start = time.perf_counter()
    logger.info("OpenEntity background warm-up started")
    try:
        t_db_start = time.perf_counter()
        async with engine.connect() as conn:
            source = MySqlEntitySearchDataSource(connection=conn)
            entities = await source.load_entities()
        t_db_end = time.perf_counter()
        db_duration_ms = (t_db_end - t_db_start) * 1000.0
        logger.info(
            "OpenEntity DB entity fetch completed: %d entities in %.2f ms",
            len(entities),
            db_duration_ms,
        )

        t_idx_start = time.perf_counter()
        service = InMemoryEntitySearchService.from_entities(entities)
        t_idx_end = time.perf_counter()
        idx_duration_ms = (t_idx_end - t_idx_start) * 1000.0
        logger.info(
            "OpenEntity index construction completed in %.2f ms",
            idx_duration_ms,
        )

        _shared_entity_search_service = service
        _is_ready = True
        _last_error = None
        total_duration_ms = (t_idx_end - t_start) * 1000.0
        entity_count = service.index_stats.entity_count if service.index_stats else len(entities)
        logger.info(
            "OpenEntity ready: %d entities indexed (total warm-up time: %.2f ms)",
            entity_count,
            total_duration_ms,
        )
        return service
    except asyncio.CancelledError:
        logger.info("OpenEntity background warm-up cancelled")
        raise
    except Exception as exc:
        _is_ready = False
        _last_error = exc
        logger.error(
            "OpenEntity background warm-up failed: %s",
            exc,
            exc_info=True,
        )
        raise


def start_background_entity_search_warmup(engine: AsyncEngine) -> asyncio.Task[InMemoryEntitySearchService]:
    """Launches non-blocking background task to warm up the OpenEntity search index."""
    global _warmup_task
    if _shared_entity_search_service is not None and _is_ready:
        # Already warm
        loop = asyncio.get_running_loop()
        future = loop.create_future()
        future.set_result(_shared_entity_search_service)
        return future  # type: ignore

    if _warmup_task is not None and not _warmup_task.done():
        return _warmup_task

    _warmup_task = asyncio.create_task(_run_warmup(engine))
    return _warmup_task


async def cancel_background_entity_search_warmup() -> None:
    """Cancels and cleans up background warm-up task on application shutdown."""
    global _warmup_task
    if _warmup_task is not None and not _warmup_task.done():
        _warmup_task.cancel()
        try:
            await _warmup_task
        except (asyncio.CancelledError, Exception):
            pass
        _warmup_task = None


async def get_shared_entity_search_service(
    connection: AsyncConnection | None = None,
) -> InMemoryEntitySearchService:
    """Returns the singleton InMemoryEntitySearchService.

    If a background warm-up task is currently in progress, awaits that task to ensure
    only a single index is ever constructed. If no task is running and index is not yet built,
    builds it safely under an asyncio.Lock.
    """
    global _shared_entity_search_service, _is_ready, _last_error

    if _shared_entity_search_service is not None and _is_ready:
        return _shared_entity_search_service

    if _warmup_task is not None and not _warmup_task.done():
        logger.info("Request awaiting in-progress OpenEntity warm-up task...")
        try:
            service = await _warmup_task
            return service
        except Exception:
            # Task failed, will attempt fallback build below
            pass

    async with _warmup_lock:
        if _shared_entity_search_service is not None and _is_ready:
            return _shared_entity_search_service

        logger.info("Building OpenEntity index on-demand under lock...")
        if connection is not None:
            source = MySqlEntitySearchDataSource(connection=connection)
            entities = await source.load_entities()
        else:
            from ..db.engine import get_engine
            engine = get_engine()
            async with engine.connect() as conn:
                source = MySqlEntitySearchDataSource(connection=conn)
                entities = await source.load_entities()

        service = InMemoryEntitySearchService.from_entities(entities)
        _shared_entity_search_service = service
        _is_ready = True
        _last_error = None
        return _shared_entity_search_service


def reset_shared_entity_search_service() -> None:
    """Resets the singleton and readiness state (for testing)."""
    global _shared_entity_search_service, _warmup_task, _is_ready, _last_error
    if _warmup_task is not None and not _warmup_task.done():
        _warmup_task.cancel()
    _warmup_task = None
    _shared_entity_search_service = None
    _is_ready = False
    _last_error = None
