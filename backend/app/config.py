from functools import lru_cache
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    db_host: str = ""
    db_port: int = 3306
    db_name: str = ""
    db_user: str = ""
    db_password: SecretStr = SecretStr("")
    db_use_ssl: bool = False

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

