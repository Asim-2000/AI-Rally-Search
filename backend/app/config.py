from functools import lru_cache
from typing import Any
from pydantic import SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    # Pinned per-provider default models. Only the explicit
    # QUERY_UNDERSTANDING_MODEL wins over these; there is deliberately no
    # fallback to a stale/unbenchmarked model or to a legacy provider-specific
    # env var (e.g. OPENAI_MODEL/GEMINI_MODEL). Gemini is pinned to the single
    # benchmarked production model.
    _PINNED_MODELS = {
        "gemini": "gemini-3.5-flash-lite",
        "google": "gemini-3.5-flash-lite",
    }

    @model_validator(mode="before")
    @classmethod
    def _apply_env_fallbacks(cls, data: Any) -> Any:
        if isinstance(data, dict):
            # Only the explicit QUERY_UNDERSTANDING_* variables are authoritative.
            # Stale legacy selectors (LLM_PROVIDER / OPENAI_MODEL / GEMINI_MODEL /
            # ANTHROPIC_MODEL) are intentionally NOT consulted for selection.
            provider = data.get("query_understanding_provider") or data.get("QUERY_UNDERSTANDING_PROVIDER")
            if provider:
                data.setdefault("query_understanding_provider", provider)
                has_explicit_model = data.get("query_understanding_model") or data.get("QUERY_UNDERSTANDING_MODEL")
                if not has_explicit_model:
                    pinned = cls._PINNED_MODELS.get(str(provider).lower())
                    if pinned:
                        data.setdefault("query_understanding_model", pinned)
            fb = data.get("entity_search_fallback_mode") or data.get("ENTITY_SEARCH_FALLBACK_MODE")
            if fb:
                data.setdefault("entity_search_fallback_mode", fb)
        return data

    db_host: str = ""
    db_port: int = 3306
    db_name: str = ""
    db_user: str = ""
    db_password: SecretStr = SecretStr("")
    db_use_ssl: bool = False
    entity_search_fallback_mode: str = "FALLBACK"
    query_understanding_provider: str = "mock"
    query_understanding_model: str = "mock-parser-v1"
    # The mock parser must never activate silently in production. It is only
    # permitted when explicitly opted in (tests set this true, or construct the
    # MockProvider directly). See _build_query_service.
    allow_mock_query_understanding: bool = False
    query_understanding_temperature: float = 0.0
    query_understanding_timeout_seconds: float = 30.0
    query_understanding_max_retries: int = 2
    openai_api_key: SecretStr = SecretStr("")
    openai_base_url: str = "https://api.openai.com/v1"
    gemini_api_key: SecretStr = SecretStr("")
    gemini_base_url: str = "https://generativelanguage.googleapis.com/v1beta"
    anthropic_api_key: SecretStr = SecretStr("")
    anthropic_base_url: str = "https://api.anthropic.com/v1"
    speech_provider: str = "openai"
    speech_model: str = "whisper-1"
    speech_timeout_seconds: float = 30.0
    speech_dynamic_top3_enabled: bool = False
    speech_preprocessing_strategy: str = "raw"

    @field_validator("entity_search_fallback_mode")
    @classmethod
    def _validate_fallback_mode(cls, v: str) -> str:
        if not v:
            return "FALLBACK"
        clean = str(v).strip().upper()
        if clean not in ("OFF", "SHADOW", "FALLBACK"):
            raise ValueError(
                f"Unsupported ENTITY_SEARCH_FALLBACK_MODE: '{v}'. "
                "Supported modes are: OFF, SHADOW, FALLBACK."
            )
        return clean

    @property
    def database_url(self) -> str:
        from urllib.parse import quote_plus
        return (
            f"mysql+asyncmy://{quote_plus(self.db_user)}:"
            f"{quote_plus(self.db_password.get_secret_value())}@"
            f"{self.db_host}:{self.db_port}/{self.db_name}?charset=utf8mb4"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
