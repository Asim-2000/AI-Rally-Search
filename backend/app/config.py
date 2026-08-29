from functools import lru_cache
from typing import Any
from pydantic import SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    @model_validator(mode="before")
    @classmethod
    def _apply_env_fallbacks(cls, data: Any) -> Any:
        if isinstance(data, dict):
            provider = data.get("query_understanding_provider") or data.get("QUERY_UNDERSTANDING_PROVIDER") or data.get("llm_provider") or data.get("LLM_PROVIDER")
            if provider:
                data.setdefault("query_understanding_provider", provider)
                p_lower = str(provider).lower()
                if p_lower == "openai":
                    m = data.get("query_understanding_model") or data.get("QUERY_UNDERSTANDING_MODEL") or data.get("openai_model") or data.get("OPENAI_MODEL") or "gpt-4o-mini"
                    data.setdefault("query_understanding_model", m)
                elif p_lower in ("gemini", "google"):
                    m = data.get("query_understanding_model") or data.get("QUERY_UNDERSTANDING_MODEL") or data.get("gemini_model") or data.get("GEMINI_MODEL") or "gemini-3.6-flash"
                    data.setdefault("query_understanding_model", m)
                elif p_lower == "anthropic":
                    m = data.get("query_understanding_model") or data.get("QUERY_UNDERSTANDING_MODEL") or data.get("anthropic_model") or data.get("ANTHROPIC_MODEL") or "claude-3-5-sonnet-20241022"
                    data.setdefault("query_understanding_model", m)
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
