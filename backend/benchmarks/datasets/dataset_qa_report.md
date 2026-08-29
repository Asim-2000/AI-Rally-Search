# Dataset QA Report

- **Dataset Path**: `benchmarks/datasets/query_understanding_gold.jsonl`
- **Dataset SHA-256 Hash**: `b7fd39226592281c565c0e835c16b460654f43cd2da4bc09655a5abf06972662`
- **Total Cases**: 392
- **Validation Status**: `PASS`
- **DB-Validated Cases**: 392/392
- **Immutable Regression Cases Found**: 7/7

## Distribution by Canonical Intent

| Search Intent | Case Count |
| :--- | :---: |
| `GET_RALLY_RESULTS` | 35 |
| `GET_RALLY_TOP_FINISHERS` | 14 |
| `GET_TOP_DRIVERS_BY_WINS` | 10 |
| `GET_TOP_UPLOADERS` | 11 |
| `SEARCH_DRIVER_RALLIES` | 77 |
| `SEARCH_DRIVER_VIDEOS` | 20 |
| `SEARCH_DRIVER_WINS` | 30 |
| `SEARCH_RALLIES` | 72 |
| `SEARCH_VIDEO_ACTIONS` | 123 |

## Distribution by Category

| Category | Case Count |
| :--- | :---: |
| `ambiguity/clarification` | 30 |
| `conversation/referents` | 40 |
| `entity_heavy` | 60 |
| `immutable_regression` | 7 |
| `multi_filter` | 60 |
| `multi_value` | 40 |
| `noisy/phonetic` | 50 |
| `realistic/adversarial` | 20 |
| `simple_filter` | 45 |
| `video/action` | 40 |

## Generation Source & Confidence

- **Sources**: {'manual_regression': 7, 'template_db_derived': 385}
- **Confidence Breakdown**: {'high': 392}

## Errors & Warnings

- **Errors (0)**:
  - None
- **Warnings (0)**:
  - None
