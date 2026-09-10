from __future__ import annotations

import asyncio
import json
from typing import Any

import httpx

from ...observability import Phase, current_timings
from ..provider import ProviderError, ProviderTimeout

# One process-wide client, so provider calls reuse a warm TLS connection.
#
# This replaces a `urllib.request.urlopen` call dispatched to a worker thread,
# which established a fresh DNS + TCP + TLS connection for every single model
# call. Measured against the production Gemini endpoint, that per-call
# handshake had a pathological tail: over 25 sequential calls the p50 was
# ~500 ms but 2 calls exceeded 20 s, i.e. ~8% of model calls blew straight
# through any 4 s budget. The same 25 calls over a keep-alive httpx client had
# a max of 729 ms. Connection reuse is the fix; the timeout below is the
# backstop.
_client: httpx.AsyncClient | None = None
_client_lock = asyncio.Lock()

_LIMITS = httpx.Limits(
    max_connections=20,
    max_keepalive_connections=10,
    keepalive_expiry=60.0,
)


async def get_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        async with _client_lock:
            if _client is None or _client.is_closed:
                _client = httpx.AsyncClient(limits=_LIMITS, http2=False)
    return _client


async def close_client() -> None:
    global _client
    if _client is not None and not _client.is_closed:
        await _client.aclose()
    _client = None


async def post_json(
    url: str,
    body: dict[str, Any],
    headers: dict[str, str],
    timeout: float,
    *,
    params: dict[str, str] | None = None,
    phase: Phase | str = Phase.EXTERNAL_API,
) -> dict[str, Any]:
    """POSTs JSON over the shared pooled client.

    `timeout` is applied per-phase (connect/read/write) rather than to the
    whole operation, so a stalled connect fails fast instead of consuming the
    entire budget before the request is even sent.
    """
    client = await get_client()
    timings = current_timings()
    limits = httpx.Timeout(timeout, connect=min(timeout, 10.0))
    try:
        if timings is not None:
            with timings.measure(phase):
                response = await client.post(
                    url, params=params, json=body, headers=headers, timeout=limits
                )
        else:
            response = await client.post(
                url, params=params, json=body, headers=headers, timeout=limits
            )
    except httpx.TimeoutException as exc:
        raise ProviderTimeout(str(exc) or "provider request timed out") from exc
    except httpx.HTTPError as exc:
        raise ProviderError(str(exc)) from exc

    if response.status_code < 200 or response.status_code >= 300:
        detail = response.text
        raise ProviderError(f"HTTP {response.status_code}: {detail[:1000]}")
    try:
        return response.json()
    except (json.JSONDecodeError, ValueError) as exc:
        raise ProviderError(f"provider returned non-JSON body: {exc}") from exc
