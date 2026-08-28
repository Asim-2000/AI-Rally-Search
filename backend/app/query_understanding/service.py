import asyncio
import time

from .models import FailureKind, QueryUnderstandingResult, TokenUsage
from .prompt import FEW_SHOT_VERSION, PROMPT_VERSION, SCHEMA_VERSION
from .provider import ProviderError, ProviderTimeout, QueryUnderstandingProvider
from .telemetry import NullTelemetry, TelemetryEvent, TelemetrySink
from .validator import OutputValidationError, validate_provider_output


class QueryUnderstandingService:
    def __init__(self, provider: QueryUnderstandingProvider, telemetry: TelemetrySink | None = None):
        self.provider = provider
        self.telemetry = telemetry or NullTelemetry()

    async def parse(self, natural_language_query: str, *, language: str | None = None) -> QueryUnderstandingResult:
        if not natural_language_query.strip():
            raise ValueError("natural_language_query must not be empty")
        started = time.perf_counter()
        provider_ms = validation_ms = 0.0
        provider_retries = schema_retries = 0
        attempts = 0
        last_raw: str | None = None
        last_usage = TokenUsage()
        last_metadata: dict = {}
        max_attempts = self.provider.config.max_retries + 1

        while attempts < max_attempts:
            attempts += 1
            provider_started = time.perf_counter()
            try:
                response = await asyncio.wait_for(
                    self.provider.parse_raw(natural_language_query, language=language),
                    timeout=self.provider.config.timeout_seconds,
                )
                provider_ms += (time.perf_counter() - provider_started) * 1000
                last_raw, last_usage, last_metadata = response.raw_response, response.usage, response.metadata
            except (asyncio.TimeoutError, TimeoutError, ProviderTimeout) as exc:
                provider_ms += (time.perf_counter() - provider_started) * 1000
                if attempts < max_attempts:
                    provider_retries += 1
                    continue
                return self._failure(FailureKind.TIMEOUT, str(exc) or "provider timed out", started, attempts, provider_retries, schema_retries, provider_ms, validation_ms, last_raw, last_usage, last_metadata)
            except ProviderError as exc:
                provider_ms += (time.perf_counter() - provider_started) * 1000
                if attempts < max_attempts:
                    provider_retries += 1
                    continue
                return self._failure(FailureKind.PROVIDER_ERROR, str(exc), started, attempts, provider_retries, schema_retries, provider_ms, validation_ms, last_raw, last_usage, last_metadata)

            validation_started = time.perf_counter()
            try:
                query = validate_provider_output(last_raw)
                validation_ms += (time.perf_counter() - validation_started) * 1000
                result = QueryUnderstandingResult(
                    query=query, provider=self.provider.config.provider, model=self.provider.config.model,
                    prompt_version=PROMPT_VERSION, schema_version=SCHEMA_VERSION, few_shot_version=FEW_SHOT_VERSION,
                    raw_response=last_raw, attempts=attempts, provider_retries=provider_retries,
                    schema_retries=schema_retries, provider_latency_ms=provider_ms,
                    validation_latency_ms=validation_ms, total_latency_ms=(time.perf_counter() - started) * 1000,
                    usage=last_usage, metadata=last_metadata,
                )
                self.telemetry.record(TelemetryEvent("query_understanding.success", {"provider": result.provider, "model": result.model, "attempts": attempts}))
                return result
            except OutputValidationError as exc:
                validation_ms += (time.perf_counter() - validation_started) * 1000
                if attempts < max_attempts:
                    schema_retries += 1
                    continue
                return self._failure(exc.kind, str(exc), started, attempts, provider_retries, schema_retries, provider_ms, validation_ms, last_raw, last_usage, last_metadata)

        raise AssertionError("unreachable")

    def _failure(self, kind: FailureKind, error: str, started: float, attempts: int, provider_retries: int, schema_retries: int, provider_ms: float, validation_ms: float, raw: str | None, usage: TokenUsage, metadata: dict) -> QueryUnderstandingResult:
        result = QueryUnderstandingResult(
            provider=self.provider.config.provider, model=self.provider.config.model,
            prompt_version=PROMPT_VERSION, schema_version=SCHEMA_VERSION, few_shot_version=FEW_SHOT_VERSION,
            raw_response=raw, failure_kind=kind, error=error, attempts=attempts,
            provider_retries=provider_retries, schema_retries=schema_retries,
            provider_latency_ms=provider_ms, validation_latency_ms=validation_ms,
            total_latency_ms=(time.perf_counter() - started) * 1000, usage=usage, metadata=metadata,
        )
        self.telemetry.record(TelemetryEvent("query_understanding.failure", {"provider": result.provider, "model": result.model, "kind": kind.value, "attempts": attempts}))
        return result
