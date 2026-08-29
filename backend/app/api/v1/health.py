from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from ...entity_search.warmup import get_entity_count, is_entity_search_ready

router = APIRouter()


class HealthResponse(BaseModel):
    status: str = "ok"


class ReadinessResponse(BaseModel):
    ready: bool
    entityIndexReady: bool = Field(..., alias="entityIndexReady")
    entityCount: int | None = Field(default=None, alias="entityCount")

    model_config = {
        "populate_by_name": True,
    }


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    """Liveness probe: returns 200 OK immediately if the process is running."""
    return HealthResponse(status="ok")


@router.get("/ready", response_model=ReadinessResponse, response_model_by_alias=True)
async def ready() -> ReadinessResponse | JSONResponse:
    """Readiness probe: returns 200 OK when the database and OpenEntity index are ready, or 503 if still warming."""
    if is_entity_search_ready():
        count = get_entity_count()
        return ReadinessResponse(
            ready=True,
            entityIndexReady=True,
            entityCount=count,
        )
    return JSONResponse(
        status_code=503,
        content={"ready": False, "entityIndexReady": False},
    )
