from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from .api.v1.conversation import router as conversation_router
from .api.v1.health import router as health_router
from .api.v1.offline import router as offline_router
from .api.v1.query_understanding import router as query_understanding_router
from .api.v1.search import router as search_router
from .api.v1.voice import router as voice_router
from .db.engine import dispose_engine, get_engine
from .domain.errors import ApiError, ErrorCode
from .entity_search.warmup import (
    cancel_background_entity_search_warmup,
    start_background_entity_search_warmup,
)
from .observability.logging import configure_logging
from .observability.middleware import timing_middleware
from .query_understanding.providers.http import close_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Lift app loggers above uvicorn's default config. Without this the
    # OpenEntity warm-up and per-request timing lines never reach stdout, which
    # is why cold-start cost was previously invisible in production.
    configure_logging()
    # Non-blocking OpenEntity background warm-up
    engine = get_engine()
    start_background_entity_search_warmup(engine)
    try:
        yield
    finally:
        await cancel_background_entity_search_warmup()
        await close_client()
        await dispose_engine()


app = FastAPI(title="AI Rally Search deterministic backend", version="0.1.0", lifespan=lifespan)
app.middleware("http")(timing_middleware)
app.include_router(health_router)
app.include_router(search_router)
app.include_router(offline_router)
app.include_router(query_understanding_router)
app.include_router(conversation_router)
app.include_router(voice_router)


@app.exception_handler(RequestValidationError)
async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
    body = ApiError(code=ErrorCode.VALIDATION_ERROR, message="Request validation failed", details=exc.errors()).model_dump(mode="json")
    return JSONResponse(status_code=422, content={"error": body})


@app.exception_handler(SQLAlchemyError)
async def database_error(_: Request, __: SQLAlchemyError) -> JSONResponse:
    body = ApiError(code=ErrorCode.DATABASE_ERROR, message="Database operation failed").model_dump(mode="json")
    return JSONResponse(status_code=503, content={"error": body})
