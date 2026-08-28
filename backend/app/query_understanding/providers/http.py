import asyncio
import json
import urllib.error
import urllib.request
from typing import Any

from ..provider import ProviderError, ProviderTimeout


async def post_json(url: str, body: dict[str, Any], headers: dict[str, str], timeout: float) -> dict[str, Any]:
    def send() -> dict[str, Any]:
        request = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return json.loads(response.read().decode())
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")
            raise ProviderError(f"HTTP {exc.code}: {detail[:1000]}") from exc
        except TimeoutError as exc:
            raise ProviderTimeout(str(exc)) from exc
        except (urllib.error.URLError, json.JSONDecodeError) as exc:
            raise ProviderError(str(exc)) from exc
    return await asyncio.to_thread(send)
