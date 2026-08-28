from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError
from .api.v1.health import router as health_router
from .api.v1.search import router as search_router
from .api.v1.query_understanding import router as query_understanding_router
from .domain.errors import ApiError, ErrorCode

app = FastAPI(title="AI Rally Search deterministic backend", version="0.1.0")
app.include_router(health_router)
app.include_router(search_router)
app.include_router(query_understanding_router)

@app.exception_handler(RequestValidationError)
async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
    body=ApiError(code=ErrorCode.VALIDATION_ERROR,message="Request validation failed",details=exc.errors()).model_dump(mode="json")
    return JSONResponse(status_code=422,content={"error":body})

@app.exception_handler(SQLAlchemyError)
async def database_error(_: Request, __: SQLAlchemyError) -> JSONResponse:
    body=ApiError(code=ErrorCode.DATABASE_ERROR,message="Database operation failed").model_dump(mode="json")
    return JSONResponse(status_code=503,content={"error":body})
