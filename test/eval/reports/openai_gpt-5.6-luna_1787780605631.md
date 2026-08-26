# LLM Query Parser Evaluation Report

**Provider:** `OPENAI` | **Model:** `gpt-5.6-luna` | **Evaluated At:** `2026-08-26T23:43:25.616424`

## Executive Summary

| Metric | Score | Target | Status |
|---|---|---|---|
| **Intent Accuracy** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Filter Precision** | 100.0% | ≥ 90.0% | ✅ PASS |
| **Filter Recall** | 100.0% | ≥ 90.0% | ✅ PASS |
| **Filter F1 Score** | 100.0% | ≥ 90.0% | ✅ PASS |
| **Exact Match Rate** | 100.0% | ≥ 85.0% | ✅ PASS |
| **Compound Completeness** | 100.0% | ≥ 85.0% | ✅ PASS |
| **Clarification Accuracy** | 100.0% | ≥ 90.0% | ✅ PASS |
| **Hallucination Rate** | 0.0% | ≤ 2.0% | ✅ PASS |
| **Entity Preservation** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Production Weighted Score** | **100.0%** | ≥ 90.0% | ✅ PASS |

## Latency & Economics

| Metric | Value |
|---|---|
| Total Test Cases | 304 |
| Mean Latency | 1813.4 ms |
| P50 (Median) Latency | 1773 ms |
| P95 Latency | 2459 ms |
| Total Tokens (Prompt / Completion) | 1384618 (1342717 / 41901) |
| Total Evaluation Cost | N/A |
| Estimated Cost / 1,000 Queries | N/A |

## Per-Language Performance Breakdown

| Language | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| `EN` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1742 ms |
| `DE` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1791 ms |
| `FR` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1822 ms |
| `ES` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1663 ms |
| `IT` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1906 ms |
| `PT` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1829 ms |
| `NL` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1650 ms |
| `PL` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1675 ms |
| `NB` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1795 ms |
| `LV` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1919 ms |
| `CS` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1931 ms |
| `HR` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2045 ms |
| `LT` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1971 ms |
| `SK` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1925 ms |
| `UR` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1817 ms |
| `AR` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1663 ms |
| `SW` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1858 ms |
| `CY` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1692 ms |
| `GA` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 1760 ms |

## Category Performance Breakdown

| Category | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| Rally Discovery | 57 | 100.0% | 100.0% | 100.0% | 100.0% | 1845 ms |
| Driver Participations | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1893 ms |
| Driver Wins | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1833 ms |
| Rally Results | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1512 ms |
| Rally Leaderboard | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1733 ms |
| Driver Videos | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1800 ms |
| Video Actions | 57 | 100.0% | 100.0% | 100.0% | 100.0% | 1850 ms |
| Compound Search | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1552 ms |
| Uploaders | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 2096 ms |
| Global Leaderboards | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1827 ms |
| Clarification | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 2171 ms |
| Code Switching | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1510 ms |

## Per-Slot Extraction Metrics

| Slot | Expected | Extracted | Correct | Precision | Recall | F1 |
|---|---|---|---|---|---|---|
| `driverName` | 114 | 114 | 114 | 100.0% | 100.0% | 100.0% |
| `rallyName` | 152 | 152 | 152 | 100.0% | 100.0% | 100.0% |
| `actionType` | 95 | 95 | 95 | 100.0% | 100.0% | 100.0% |
| `country` | 19 | 19 | 19 | 100.0% | 100.0% | 100.0% |
| `city` | 19 | 19 | 19 | 100.0% | 100.0% | 100.0% |
| `stageName` | 19 | 19 | 19 | 100.0% | 100.0% | 100.0% |
| `year` | 95 | 95 | 95 | 100.0% | 100.0% | 100.0% |
| `limit` | 19 | 285 | 19 | 6.7% | 100.0% | 12.5% |

