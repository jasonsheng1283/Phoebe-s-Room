from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Phoebe's Room API"
    debug: bool = True
    family_code: str = "phoebe-home"
    database_path: str = "../data/phoebe.db"
    content_dir: str = "../content"
    llm_api_key: str = ""
    llm_base_url: str = "https://api.openai.com/v1"
    llm_model: str = "gpt-4o-mini"
    stt_model: str = "whisper-1"
    stt_mock: bool = True
    cors_origins: str = "*"

    @property
    def db_path(self) -> Path:
        return (Path(__file__).resolve().parent.parent / self.database_path).resolve()

    @property
    def content_path(self) -> Path:
        return (Path(__file__).resolve().parent.parent / self.content_dir).resolve()

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
