# PY-1 deterministic backend

## Dart → Pydantic mapping

| Dart active member | JSON / Pydantic field | Semantics |
|---|---|---|
| `intent` | `intent` | exactly one of nine intents |
| `rallyNames` | `rallyNames` / `rally_names` | OR; takes precedence over event names |
| `eventNames` | `eventNames` / `event_names` | backward-compatible rally dimension |
| `countries` | `countries` | OR with Dart country aliases |
| `cities` | `cities` | OR |
| `stageNames` | `stageNames` / `stage_names` | OR |
| `stageNumbers` | `stageNumbers` / `stage_numbers` | OR |
| `driverNames` | `driverNames` / `driver_names` | person dimension |
| `driverIds` | `driverIds` / `driver_ids` | person dimension |
| `actionTypes` | `actionTypes` / `action_types` | OR |
| `years` | `years` | OR with range expression |
| `yearFrom` | `yearFrom` / `year_from` | inclusive |
| `yearTo` | `yearTo` / `year_to` | inclusive |
| `uploaders` | `uploaders` | active model field; Dart SQL currently does not filter it |
| `driverMatchMode` | `driverMatchMode` / `driver_match_mode` | `ANY`/`ALL` |
| `personRole` | `personRole` / `person_role` | hard `ANY`/`DRIVER`/`CO_DRIVER` constraint |
| `limit` | `limit` | 1–100; Dart default 20 |
| `offset` | `offset` | non-negative; Dart default 0 |

The singular Dart constructor inputs (`rallyName`, `eventName`, `country`, `city`,
`stageName`, `stageNumber`, `driverName`, `driverId`, `actionType`, `year`, and
`uploader`) are accepted as input-only compatibility aliases and normalized to lists.

## Frozen EE-1 preparation

`SpecialQueryMatcher` remains in Dart and is not called by FastAPI. Frozen categories
and stable error codes are inventoried in `docs/ee1_special_responses.md`.

## Parity harness

`tests/parity/canonical.py` compares ordered canonical IDs and distinct totals, not
display values or counts alone. Live fixtures should feed the same structured JSON
to the Dart reference runner and `POST /v1/search`, then call `assert_exact_parity`.
Live tests are explicitly marked `live_db`; ordinary unit tests are hermetic.

The executable v1 corpus and final machine-readable report live in the repository
root under `parity/`. `KNOWN_PRODUCT_SEMANTIC:UPLOADERS_FILTER_CURRENTLY_UNUSED`
is intentionally preserved until a post-parity product decision.
