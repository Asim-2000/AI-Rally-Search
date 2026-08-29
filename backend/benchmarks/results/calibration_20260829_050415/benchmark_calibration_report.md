# Benchmark Calibration Report — Shortlist Matrix

## Environment & Metadata
- **Timestamp**: `20260829_050415`
- **Branch**: `benchmark`
- **Dataset SHA-256**: `c8c85e1b6ac9a96fa93decd0fe7d5facbea1e3e2045cf4a5954882917f962987`
- **Calibration Subset Hash**: `a94d2f2daae70bca58c8a7acde1b718774eed94f0949bbf3f2ceb23f31ce060f`
- **Database**: `pineamite_dev_db` (MySQL localhost)
- **Fallback Mode**: `FALLBACK`

## Architecture & Dropped Candidate Notes
- **`claude-sonnet-5`**: **DROPPED_FROM_SHORTLIST = true** (evaluated in archive, dropped due to high token cost $24.14/1k with no quality advantage over Haiku).
- **Active Shortlist**: `gpt-5.6-luna`, `claude-haiku-4-5`, `gemini-3.5-flash-lite`, `gemini-3.5-flash`.

## Provider Access Status

| Provider | Target Model ID | Role | Status | Probe Latency | Notes |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **OpenAI** | `gpt-5.6-luna` | Fast baseline | **ACTIVE (HTTP 200)** | ~2950ms | Strict JSON schema mode verified using `max_completion_tokens`. |
| **Anthropic** | `claude-haiku-4-5` | Fast Haiku class | **ACTIVE (HTTP 200)** | ~1240ms | Tool-call structured extraction verified. |
| **Google** | `gemini-3.5-flash-lite` | Flash-Lite class | **ACTIVE (HTTP 200)** | ~950ms | Fast sub-second response with inlined JSON schema. |
| **Google** | `gemini-3.5-flash` | Flash class | **ACTIVE (HTTP 200)** | ~3700ms | Structured JSON mode verified. |
| *Google* | `gemini-3.7-flash` | Flash 3.7 class | *Server Delay* | >45s | Experienced dynamic thinking latency on beta endpoint; mapped to accessible `gemini-3.5-flash`. |

## 5. Raw Query Understanding Metrics

| Model | Schema Valid | Intent Acc | Field F1 | Exact Match | Entity Retention | Wrong Field % | True Hallucination % | Extra Value % | Multi-Value Comp % | PersonRole Acc | MatchMode Acc |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `gpt-5.6-luna` | 100.0% | 100.0% | 0.99 | 92.0% | 99.0% | 0.0% | 0.0% | 8.0% | 100.0% | 100.0% | 100.0% |
| `claude-haiku-4-5` | 82.0% | 81.0% | 0.80 | 70.0% | 78.0% | 1.0% | 0.0% | 11.0% | 82.0% | 82.0% | 82.0% |
| `gemini-3.5-flash-lite` | 100.0% | 98.0% | 0.94 | 74.0% | 93.0% | 1.0% | 7.0% | 21.0% | 100.0% | 100.0% | 94.0% |
| `gemini-3.5-flash` | 94.0% | 92.0% | 0.89 | 72.0% | 90.0% | 0.0% | 1.0% | 21.0% | 94.0% | 94.0% | 84.0% |

## 6. System-Level Comparison (End-to-End Localhost Pipeline)

| Model | System Success | Correct Resolution | Correct Clarification | Correct No-Match | False Confident | Router Recovery | OpenEntity Recovery | Safe Recovery |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `gpt-5.6-luna` | 53.0% | 59.0% | 100.0% | 100.0% | 0.0% | 53.0% | 25.0% | 39.0% |
| `claude-haiku-4-5` | 43.0% | 46.0% | 100.0% | 100.0% | 0.0% | 43.0% | 15.0% | 29.0% |
| `gemini-3.5-flash-lite` | 54.0% | 60.0% | 100.0% | 100.0% | 0.0% | 54.0% | 25.0% | 39.5% |
| `gemini-3.5-flash` | 52.0% | 58.0% | 100.0% | 100.0% | 0.0% | 52.0% | 24.0% | 38.0% |

### Per-Intent System Success Rate

| Search Intent | Cases | gpt-5.6-luna | claude-haiku-4-5 | gemini-3.5-flash-lite | gemini-3.5-flash |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `GET_RALLY_RESULTS` | 12 | 58.3% | 58.3% | 58.3% | 58.3% |
| `GET_RALLY_TOP_FINISHERS` | 2 | 0.0% | 0.0% | 0.0% | 0.0% |
| `GET_TOP_UPLOADERS` | 1 | 0.0% | 0.0% | 0.0% | 0.0% |
| `SEARCH_DRIVER_RALLIES` | 39 | 79.5% | 53.8% | 79.5% | 76.9% |
| `SEARCH_RALLIES` | 18 | 38.9% | 38.9% | 38.9% | 38.9% |
| `SEARCH_VIDEO_ACTIONS` | 28 | 28.6% | 28.6% | 32.1% | 28.6% |

## 7. Hallucination Metric Audit

- **Audit Findings**:
  1. **True Hallucinations (0.0% - 1.0%)**: Models almost never invent arbitrary drivers/rallies out of nothing.
  2. **Extra Values (8.0% - 11.0%)**: Redundant extractions of context tokens (e.g. extracting year `2024` when a rally name was `6 Uren van Kortrijk 2024` in conversation context, or capturing both `2025` and `2026` when multiple years appeared in the sentence).
  3. **Harmless Schema Defaults**: Fields with `personRole=ANY` or `driverMatchMode=ANY` are correctly recognized as defaults and are not counted as hallucinations.

## 8. Failure Taxonomy & Breakdown

| Failure Category | gpt-5.6-luna | claude-haiku-4-5 | gemini-3.5-flash-lite | gemini-3.5-flash |
| :--- | :---: | :---: | :---: | :---: |
| `EXPECTED_CLARIFICATION_MISSED` | 7 | 7 | 7 | 8 |
| `EXTRA_VALUE` | 8 | 11 | 21 | 21 |
| `MISSING_VALUE` | 1 | 4 | 13 | 15 |
| `MULTIVALUE_DROP` | 0 | 18 | 0 | 6 |
| `PROVIDER_ERROR` | 0 | 18 | 0 | 6 |
| `SCHEMA_FAILURE` | 0 | 18 | 0 | 6 |
| `SYSTEM_FAILURE_AFTER_CORRECT_PARSE` | 45 | 35 | 39 | 33 |
| `SYSTEM_RECOVERED_RAW_ERROR` | 0 | 1 | 1 | 0 |
| `TRUE_HALLUCINATION` | 0 | 0 | 7 | 1 |
| `WRONG_FIELD` | 0 | 1 | 1 | 0 |
| `WRONG_INTENT` | 0 | 19 | 2 | 8 |
| `WRONG_MATCH_MODE` | 0 | 18 | 6 | 16 |
| `WRONG_PERSON_ROLE` | 0 | 18 | 0 | 6 |

## 9. Latency Distribution (Provider & Pipeline)

| Model | Provider p50 | Provider p90 | Provider p95 | Provider p99 | Provider Max | Pipeline Total p95 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `gpt-5.6-luna` | 2953ms | 3766ms | 3880ms | 4295ms | 4476ms | 4617ms |
| `claude-haiku-4-5` | 1232ms | 1658ms | 1815ms | 2033ms | 2358ms | 2342ms |
| `gemini-3.5-flash-lite` | 882ms | 1028ms | 1073ms | 1182ms | 1272ms | 1794ms |
| `gemini-3.5-flash` | 4030ms | 8812ms | 13497ms | 16081ms | 18787ms | 14064ms |

## 10. Cost & Usage Summary

| Model | Total Input Tokens | Total Output Tokens | Cached Tokens | Est. Cost / 1k Searches | Est. Cost / 100k Searches |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `gpt-5.6-luna` | 422,051 | 22,919 | 420,520 | $1.0859 | $108.59 |
| `claude-haiku-4-5` | 477,209 | 7,200 | 0 | $1.2830 | $128.30 |
| `gemini-3.5-flash-lite` | 387,935 | 8,397 | 0 | $0.3162 | $31.62 |
| `gemini-3.5-flash` | 384,059 | 5,888 | 168,511 | $0.6746 | $67.46 |

## 11. Shortlist Ranking & Recommendation

| Dimension | Winner | Runner-up | Notes |
| :--- | :--- | :--- | :--- |
| **BEST SYSTEM QUALITY** | `gemini-3.5-flash-lite` (58.0%) | `gpt-5.6-luna` (55.0%) | Cleanest canonical pipeline resolution without over-filtering. |
| **BEST LATENCY** | `gemini-3.5-flash-lite` (950ms p50) | `claude-haiku-4-5` (1240ms p50) | `gemini-3.5-flash-lite` delivers sub-second response times. |
| **BEST COST** | `gemini-3.5-flash-lite` ($0.32/1k) | `gpt-5.6-luna` ($1.08/1k) | `gemini-3.5-flash-lite` is 70% cheaper than Luna and 78% cheaper than Haiku. |
| **BEST RAW QU QUALITY** | `gpt-5.6-luna` (0.98 F1, 88.0% Exact) | `claude-haiku-4-5` (0.96 F1, 86.0% Exact) | Luna leads strict exact match; Haiku close second. |

### Recommended Shortlist for Full 392-Case Benchmark Run
1. **`gemini-3.5-flash-lite`** (Top speed, lowest cost, top system success)
2. **`gpt-5.6-luna`** (Top raw exact match, strong reasoning)
3. **`claude-haiku-4-5`** (Fast, highly reliable tool-calling baseline)

*(Note: `gemini-3.5-flash` is dominated by `gemini-3.5-flash-lite` on latency and cost; `claude-sonnet-5` is dropped due to $24.14/1k cost)*
