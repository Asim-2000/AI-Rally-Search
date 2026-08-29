import pytest
from app.config import Settings
from app.entity_search.fallback import EntitySearchFallbackConfig
from app.entity_search.models import EntitySearchFallbackMode


def test_fallback_config_supported_modes():
    assert EntitySearchFallbackConfig.from_value("off").mode == EntitySearchFallbackMode.OFF
    assert EntitySearchFallbackConfig.from_value("OFF").mode == EntitySearchFallbackMode.OFF
    assert EntitySearchFallbackConfig.from_value("shadow").mode == EntitySearchFallbackMode.SHADOW
    assert EntitySearchFallbackConfig.from_value("SHADOW").mode == EntitySearchFallbackMode.SHADOW
    assert EntitySearchFallbackConfig.from_value("fallback").mode == EntitySearchFallbackMode.FALLBACK
    assert EntitySearchFallbackConfig.from_value("FALLBACK").mode == EntitySearchFallbackMode.FALLBACK
    assert EntitySearchFallbackConfig.from_value(None).mode == EntitySearchFallbackMode.FALLBACK
    assert EntitySearchFallbackConfig.from_value("").mode == EntitySearchFallbackMode.FALLBACK


def test_fallback_config_unsupported_mode_fails_fast():
    with pytest.raises(ValueError, match="Unsupported entity search fallback mode"):
        EntitySearchFallbackConfig.from_value("ALWAYS")

    with pytest.raises(ValueError, match="Unsupported entity search fallback mode"):
        EntitySearchFallbackConfig.from_value("UNKNOWN")

    with pytest.raises(ValueError, match="Unsupported entity search fallback mode"):
        EntitySearchFallbackConfig.from_value("strict")


def test_settings_fallback_mode_validation():
    s_valid = Settings(entity_search_fallback_mode="FALLBACK")
    assert s_valid.entity_search_fallback_mode == "FALLBACK"

    with pytest.raises(ValueError, match="Unsupported ENTITY_SEARCH_FALLBACK_MODE"):
        Settings(entity_search_fallback_mode="ALWAYS")
