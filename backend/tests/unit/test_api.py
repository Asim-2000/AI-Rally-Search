from httpx import ASGITransport, AsyncClient
from app.main import app
from app.api.v1.search import get_repository

class _NoopRepository:
    async def search(self, query): raise AssertionError("validation should run first")

async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app),base_url="http://test") as client:
        response=await client.get("/health")
    assert response.status_code == 200 and response.json()=={"status":"ok"}

async def test_machine_readable_validation_error():
    app.dependency_overrides[get_repository]=lambda:_NoopRepository()
    try:
        async with AsyncClient(transport=ASGITransport(app=app),base_url="http://test") as client:
            response=await client.post("/v1/search",json={"intent":"NOT_AN_INTENT"})
        assert response.status_code==422 and response.json()["error"]["code"]=="VALIDATION_ERROR"
    finally:
        app.dependency_overrides.clear()
