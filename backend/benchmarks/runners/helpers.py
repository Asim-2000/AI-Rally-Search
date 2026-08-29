from __future__ import annotations

import os
from dotenv import dotenv_values
from app.config import get_settings


def get_benchmark_api_keys() -> dict[str, str]:
    settings = get_settings()
    env_merged = {**dotenv_values("../.env"), **dotenv_values(".env"), **os.environ}

    openai_key = settings.openai_api_key.get_secret_value() or env_merged.get("OPENAI_API_KEY", "")
    claude_key = (
        settings.anthropic_api_key.get_secret_value()
        or env_merged.get("CLAUDE_API_KEY", "")
        or env_merged.get("ANTHROPIC_API_KEY", "")
    )
    gemini_key = settings.gemini_api_key.get_secret_value() or env_merged.get("GEMINI_API_KEY", "")

    return {
        "openai": openai_key,
        "claude": claude_key,
        "gemini": gemini_key,
    }
