from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncConnection
from ...db.engine import get_connection
from ...domain.results import SearchResponse
from ...domain.search_query import SearchQuery
from ...repositories.search_repository import SearchRepository

router = APIRouter(prefix="/v1")

async def get_repository(connection: AsyncConnection = Depends(get_connection)) -> SearchRepository:
    return SearchRepository(connection)

@router.post("/search", response_model=SearchResponse, response_model_by_alias=True)
async def search(query: SearchQuery, repository: SearchRepository = Depends(get_repository)) -> SearchResponse:
    return await repository.search(query)

