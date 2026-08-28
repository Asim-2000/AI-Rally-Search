from dataclasses import dataclass, field
from typing import Any
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection
from ..domain.search_query import PersonRole, SearchQuery

COUNTRIES = {
    "ireland": ["ireland", "ie", "irl", "republic of ireland"], "portugal": ["portugal", "pt", "prt"],
    "united kingdom": ["united kingdom", "uk", "gb", "gbr", "great britain", "england", "scotland", "wales"],
    "france": ["france", "fr", "fra"], "austria": ["austria", "at", "aut"],
    "norway": ["norway", "no", "nor"], "poland": ["poland", "pl", "pol"],
    "belgium": ["belgium", "be", "bel"], "spain": ["spain", "es", "esp"],
    "italy": ["italy", "it", "ita"], "latvia": ["latvia", "lv", "lva"],
    "czech republic": ["czech republic", "cz", "cze", "czechia"], "germany": ["germany", "de", "deu"],
    "kenya": ["kenya", "ke", "ken"], "croatia": ["croatia", "hr", "hrv"],
    "netherlands": ["netherlands", "nl", "nld", "holland"], "new zealand": ["new zealand", "nz", "nzl"],
    "lithuania": ["lithuania", "lt", "ltu"], "slovakia": ["slovakia", "sk", "svk"],
    "qatar": ["qatar", "qa", "qat"], "pakistan": ["pakistan", "pk", "pak"],
    "barbados": ["barbados", "bb", "brb"], "sweden": ["sweden", "se", "swe"],
    "finland": ["finland", "fi", "fin"], "estonia": ["estonia", "ee", "est"],
}
for key, aliases in list(COUNTRIES.items()):
    for alias in aliases:
        COUNTRIES.setdefault(alias, aliases)

@dataclass
class Filters:
    clauses: list[str] = field(default_factory=list)
    params: dict[str, Any] = field(default_factory=dict)
    index: int = 0

    def bind(self, value: Any, stem: str = "p") -> str:
        name = f"{stem}_{self.index}"; self.index += 1; self.params[name] = value
        return f":{name}"

    def dimension(self, expressions: list[str]) -> None:
        if expressions: self.clauses.append("(" + " OR ".join(expressions) + ")")

    def common(self, q: SearchQuery, ev: str = "ev", stages: bool = False) -> "Filters":
        aliases: list[str] = []
        for country in q.countries:
            clean = country.lower().strip()
            if clean != "all": aliases.extend(COUNTRIES.get(clean, [clean]))
        aliases = list(dict.fromkeys(aliases))
        country_expr = [f"LOWER({ev}.country) = {self.bind(x, 'country')}" for x in aliases]
        country_expr += [f"LOWER({ev}.country) LIKE {self.bind('%'+x.lower()+'%', 'country_like')}"
                         for x in q.countries if len(x.strip()) > 2 and x.upper() != "ALL"]
        self.dimension(country_expr)
        self.dimension([f"LOWER({ev}.city) LIKE {self.bind('%'+x.lower()+'%', 'city')}"
                        for x in q.cities if x.upper() != "ALL"])
        years = [f"COALESCE(YEAR({ev}.start_date), YEAR({ev}.end_date)) = {self.bind(y, 'year')}" for y in q.years]
        if q.year_from is not None and q.year_to is not None:
            years.append(f"COALESCE(YEAR({ev}.start_date), YEAR({ev}.end_date)) BETWEEN {self.bind(q.year_from, 'yf')} AND {self.bind(q.year_to, 'yt')}")
        elif q.year_from is not None: years.append(f"COALESCE(YEAR({ev}.start_date), YEAR({ev}.end_date)) >= {self.bind(q.year_from, 'yf')}")
        elif q.year_to is not None: years.append(f"COALESCE(YEAR({ev}.start_date), YEAR({ev}.end_date)) <= {self.bind(q.year_to, 'yt')}")
        self.dimension(years)
        self.dimension([f"(LOWER({ev}.event_name) LIKE {self.bind('%'+x.lower()+'%', 'rally')} OR {ev}.event_id = {self.bind(x.lower(), 'event_id')})" for x in q.target_rally_names])
        if stages:
            self.dimension([f"LOWER(stg.stage_name) LIKE {self.bind('%'+x.lower()+'%', 'stage')}" for x in q.stage_names])
            self.dimension([f"(stg.stage_number = {self.bind(x.lower().replace('ss','').strip(), 'stage_no')} OR LOWER(stg.stage_name) LIKE {self.bind('%stage '+x.lower().replace('ss','').strip()+'%', 'stage_no_like')})" for x in q.stage_numbers])
        return self

    def people(self, q: SearchQuery, dp: str = "dp", cdp: str = "cdp", el: str = "el") -> list[str]:
        expressions = []
        for raw in q.driver_ids:
            val = self.bind(raw, "person_id")
            d = f"({dp}.driver_id = {val} OR {el}.user_driver_id = {val})"
            c = f"({cdp}.codriver_id = {val} OR {el}.user_co_driver_id = {val})"
            expressions.append(d if q.person_role == PersonRole.DRIVER else c if q.person_role == PersonRole.CO_DRIVER else f"({d} OR {c})")
        for raw in q.driver_names:
            tokens = raw.lower().split()
            dparts = [f"LOWER({dp}.full_name) LIKE {self.bind('%'+t+'%', 'driver')}" for t in tokens]
            cparts = [f"LOWER({cdp}.full_name) LIKE {self.bind('%'+t+'%', 'codriver')}" for t in tokens]
            d = "(" + " AND ".join(dparts) + f" OR LOWER({dp}.nick_name) LIKE {self.bind('%'+raw.lower()+'%', 'driver_nick')} OR LOWER({el}.driver_link) LIKE {self.bind('%'+raw.lower()+'%', 'driver_link')})"
            c = "(" + " AND ".join(cparts) + f" OR LOWER({cdp}.nick_name) LIKE {self.bind('%'+raw.lower()+'%', 'codriver_nick')} OR LOWER({el}.co_driver_link) LIKE {self.bind('%'+raw.lower()+'%', 'codriver_link')})"
            expressions.append(d if q.person_role == PersonRole.DRIVER else c if q.person_role == PersonRole.CO_DRIVER else f"({d} OR {c})")
        return expressions

    @property
    def where(self) -> str: return "WHERE " + " AND ".join(self.clauses) if self.clauses else ""

async def rows(conn: AsyncConnection, sql: str, params: dict[str, Any]) -> list[dict[str, Any]]:
    result = await conn.execute(text(sql), params)
    return [dict(row) for row in result.mappings().all()]

async def count(conn: AsyncConnection, sql: str, params: dict[str, Any]) -> int:
    result = await conn.execute(text(sql), params)
    return int(result.scalar_one() or 0)

FINAL_STAGE = """(ev.event_id, CAST(stg.stage_number AS UNSIGNED)) IN (
 SELECT s2.event_id, MAX(CAST(s2.stage_number AS UNSIGNED)) FROM rally_stages s2
 JOIN rally_results r2 ON s2.stage_id=r2.stage_id AND s2.event_id=r2.rally_id GROUP BY s2.event_id)"""

