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
    limit: int = Field(20, ge=1)
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

    @property
    def target_rally_name(self) -> str | None:
        return self.target_rally_names[0] if self.target_rally_names else None

    @property
    def driver_name(self) -> str | None:
        return self.driver_names[0] if self.driver_names else None

    @property
    def country(self) -> str | None:
        return self.countries[0] if self.countries else None

    @property
    def year(self) -> int | None:
        return self.years[0] if self.years else None

    def copy_with(
        self,
        *,
        intent: SearchIntent | None = None,
        rally_names: list[str] | None = None,
        event_names: list[str] | None = None,
        countries: list[str] | None = None,
        cities: list[str] | None = None,
        stage_names: list[str] | None = None,
        stage_numbers: list[str] | None = None,
        driver_names: list[str] | None = None,
        driver_ids: list[str] | None = None,
        action_types: list[str] | None = None,
        years: list[int] | None = None,
        year_from: int | None = ...,
        year_to: int | None = ...,
        uploaders: list[str] | None = None,
        driver_match_mode: MatchMode | None = None,
        person_role: PersonRole | None = None,
        limit: int | None = None,
        offset: int | None = None,
        **kwargs: Any,
    ) -> "SearchQuery":
        # Handle camelCase aliases from kwargs
        if "rallyNames" in kwargs:
            rally_names = kwargs["rallyNames"]
        if "eventNames" in kwargs:
            event_names = kwargs["eventNames"]
        if "stageNames" in kwargs:
            stage_names = kwargs["stageNames"]
        if "stageNumbers" in kwargs:
            stage_numbers = kwargs["stageNumbers"]
        if "driverNames" in kwargs:
            driver_names = kwargs["driverNames"]
        if "driverIds" in kwargs:
            driver_ids = kwargs["driverIds"]
        if "actionTypes" in kwargs:
            action_types = kwargs["actionTypes"]
        if "yearFrom" in kwargs:
            year_from = kwargs["yearFrom"]
        if "yearTo" in kwargs:
            year_to = kwargs["yearTo"]
        if "driverMatchMode" in kwargs:
            driver_match_mode = kwargs["driverMatchMode"]
        if "personRole" in kwargs:
            person_role = kwargs["personRole"]

        return SearchQuery(
            intent=intent if intent is not None else self.intent,
            rally_names=list(rally_names) if rally_names is not None else list(self.rally_names),
            event_names=list(event_names) if event_names is not None else list(self.event_names),
            countries=list(countries) if countries is not None else list(self.countries),
            cities=list(cities) if cities is not None else list(self.cities),
            stage_names=list(stage_names) if stage_names is not None else list(self.stage_names),
            stage_numbers=list(stage_numbers) if stage_numbers is not None else list(self.stage_numbers),
            driver_names=list(driver_names) if driver_names is not None else list(self.driver_names),
            driver_ids=list(driver_ids) if driver_ids is not None else list(self.driver_ids),
            action_types=list(action_types) if action_types is not None else list(self.action_types),
            years=list(years) if years is not None else list(self.years),
            year_from=self.year_from if year_from is ... else year_from,
            year_to=self.year_to if year_to is ... else year_to,
            uploaders=list(uploaders) if uploaders is not None else list(self.uploaders),
            driver_match_mode=driver_match_mode if driver_match_mode is not None else self.driver_match_mode,
            person_role=person_role if person_role is not None else self.person_role,
            limit=limit if limit is not None else self.limit,
            offset=offset if offset is not None else self.offset,
        )

    def copyWith(self, **kwargs: Any) -> "SearchQuery":
        return self.copy_with(**kwargs)

