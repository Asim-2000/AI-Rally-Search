from typing import Any
from pydantic import BaseModel, ConfigDict, Field

from ..domain.referent_context import ResultReferentContext
from ..domain.search_query import PersonRole, SearchQuery


class SearchContext(BaseModel):
    """Contextual metadata passed into LLM query parsers to disambiguate relative queries,
    resolve coreferences/pronouns (e.g. 'him', 'it', 'that rally'), and provide locale hints.

    Strictly mirrors SearchContext in lib/services/llm/llm_query_parser.dart.
    """
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    current_year: int | None = Field(default=None, alias="currentYear")
    active_rally: str | None = Field(default=None, alias="activeRally")
    active_driver: str | None = Field(default=None, alias="activeDriver")
    locale: str | None = None
    language_code: str | None = Field(default=None, alias="languageCode")
    referents: ResultReferentContext = Field(default_factory=ResultReferentContext)
    previous_query: SearchQuery | None = Field(default=None, alias="previousQuery")
    extra: dict[str, Any] = Field(default_factory=dict)

    def format_prompt_context(self) -> str:
        """Formats compact referent context into clear, concise prompt annotations for LLMs."""
        lines: list[str] = []
        if self.current_year is not None:
            lines.append(f"[Context: current calendar year is {self.current_year}]")

        rally = self.active_rally or self.referents.active_rally or self.referents.last_selected_rally
        if rally and rally.strip():
            lines.append(f'[Context: active rally is "{rally.strip()}"]')

        driver = self.active_driver or self.referents.active_driver or self.referents.last_selected_driver
        if driver and driver.strip():
            role_info = ""
            if self.referents.active_person_role is not None and self.referents.active_person_role != PersonRole.ANY:
                role_info = f" (role: {self.referents.active_person_role.value})"
            lines.append(f'[Context: active driver is "{driver.strip()}"{role_info}]')

        if self.referents.last_winner and self.referents.last_winner.strip():
            winner_id_info = (
                f" (driverId: {self.referents.last_winner_driver_id})"
                if self.referents.last_winner_driver_id
                else ""
            )
            lines.append(f'[Context: last winner is "{self.referents.last_winner.strip()}"{winner_id_info}]')

        if self.referents.active_drivers and len(self.referents.active_drivers) > 1:
            drivers_str = ", ".join(f'"{d}"' for d in self.referents.active_drivers)
            lines.append(f"[Context: candidate active drivers are: {drivers_str}]")

        if self.referents.active_rallies and len(self.referents.active_rallies) > 1:
            rallies_str = ", ".join(f'"{r}"' for r in self.referents.active_rallies)
            lines.append(f"[Context: candidate active rallies are: {rallies_str}]")

        if self.previous_query is not None:
            prev_filters: list[str] = []
            if self.previous_query.rally_names:
                prev_filters.append(f"rally: {', '.join(self.previous_query.rally_names)}")
            if self.previous_query.driver_names:
                prev_filters.append(f"driver: {', '.join(self.previous_query.driver_names)}")
            if self.previous_query.person_role != PersonRole.ANY:
                prev_filters.append(f"role: {self.previous_query.person_role.value}")
            if self.previous_query.countries:
                prev_filters.append(f"countries: {', '.join(self.previous_query.countries)}")
            if self.previous_query.years:
                prev_filters.append(f"years: {', '.join(str(y) for y in self.previous_query.years)}")
            if self.previous_query.action_types:
                prev_filters.append(f"actions: {', '.join(self.previous_query.action_types)}")
            if prev_filters:
                lines.append(f"[Context: previous query filters were: {' | '.join(prev_filters)}]")

        effective_locale = self.locale or self.language_code
        if effective_locale and effective_locale.strip():
            lines.append(f'[Context: app locale is "{effective_locale.strip()}"]')

        if not lines:
            return ""
        return "\n".join(lines) + "\n"
