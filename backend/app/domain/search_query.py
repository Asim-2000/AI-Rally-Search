from enum import StrEnum
from typing import Any
from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator, model_validator
from .search_intent import SearchIntent


class MatchMode(StrEnum):
    ANY = "ANY"
    ALL = "ALL"


class PersonRole(StrEnum):
    ANY = "ANY"
    DRIVER = "DRIVER"
    CO_DRIVER = "CO_DRIVER"


class SearchQuery(BaseModel):
    """Exact structured counterpart of lib/models/search_query.dart."""
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    intent: SearchIntent
    rally_names: list[str] = Field(default_factory=list, alias="rallyNames")
    event_names: list[str] = Field(default_factory=list, alias="eventNames")
    countries: list[str] = Field(default_factory=list)
    cities: list[str] = Field(default_factory=list)
    stage_names: list[str] = Field(default_factory=list, alias="stageNames")
    stage_numbers: list[str] = Field(default_factory=list, alias="stageNumbers")
    driver_names: list[str] = Field(default_factory=list, alias="driverNames")
    driver_ids: list[str] = Field(default_factory=list, alias="driverIds")
    action_types: list[str] = Field(default_factory=list, alias="actionTypes")
    years: list[int] = Field(default_factory=list)
    year_from: int | None = Field(None, alias="yearFrom")
    year_to: int | None = Field(None, alias="yearTo")
    uploaders: list[str] = Field(default_factory=list)
    driver_match_mode: MatchMode = Field(MatchMode.ANY, alias="driverMatchMode")
    person_role: PersonRole = Field(PersonRole.ANY, alias="personRole")
    limit: int = Field(20, ge=1, le=100)
    offset: int = Field(0, ge=0)

    @model_validator(mode="before")
    @classmethod
    def singular_compatibility(cls, value: Any) -> Any:
        if not isinstance(value, dict):
            return value
        data = dict(value)
        pairs = {
            "rallyName": "rallyNames", "eventName": "eventNames", "country": "countries",
            "city": "cities", "stageName": "stageNames", "stageNumber": "stageNumbers",
            "driverName": "driverNames", "driverId": "driverIds", "actionType": "actionTypes",
            "year": "years", "uploader": "uploaders",
        }
        for singular, plural in pairs.items():
            if not data.get(plural) and singular in data:
                raw = data.pop(singular)
                if raw is not None and str(raw).strip() and str(raw).lower() != "null":
                    data[plural] = [raw]
            else:
                data.pop(singular, None)
        return data

    @field_validator("rally_names", "event_names", "countries", "cities", "stage_names",
                     "stage_numbers", "driver_names", "driver_ids", "action_types", "uploaders")
    @classmethod
    def clean_strings(cls, values: list[str]) -> list[str]:
        return [v.strip() for v in values if v.strip() and v.strip().lower() != "null"]

    @model_validator(mode="after")
    def valid_range(self) -> "SearchQuery":
        if self.year_from is not None and self.year_to is not None and self.year_from > self.year_to:
            raise ValueError("yearFrom must be less than or equal to yearTo")
        return self

    @property
    def target_rally_names(self) -> list[str]:
        return self.rally_names or self.event_names

