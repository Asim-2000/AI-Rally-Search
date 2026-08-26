# LLM Query Parser Evaluation Report

**Provider:** `OPENAI` | **Model:** `gpt-5.6-luna` | **Evaluated At:** `2026-08-26T23:22:06.477596`

## Executive Summary

| Metric | Score | Target | Status |
|---|---|---|---|
| **Intent Accuracy** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Filter Precision** | 96.1% | ≥ 90.0% | ✅ PASS |
| **Filter Recall** | 96.4% | ≥ 90.0% | ✅ PASS |
| **Filter F1 Score** | 96.2% | ≥ 90.0% | ✅ PASS |
| **Exact Match Rate** | 93.4% | ≥ 85.0% | ✅ PASS |
| **Compound Completeness** | 95.4% | ≥ 85.0% | ✅ PASS |
| **Clarification Accuracy** | 100.0% | ≥ 90.0% | ✅ PASS |
| **Hallucination Rate** | 2.3% | ≤ 2.0% | ❌ FAIL |
| **Entity Preservation** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Production Weighted Score** | **96.3%** | ≥ 90.0% | ✅ PASS |

## Latency & Economics

| Metric | Value |
|---|---|
| Total Test Cases | 304 |
| Mean Latency | 2319.6 ms |
| P50 (Median) Latency | 2257 ms |
| P95 Latency | 3417 ms |
| Total Tokens (Prompt / Completion) | 1160659 (1114431 / 46228) |
| Total Evaluation Cost | N/A |
| Estimated Cost / 1,000 Queries | N/A |

## Per-Language Performance Breakdown

| Language | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| `EN` | 16 | 100.0% | 93.8% | 96.4% | 100.0% | 2149 ms |
| `DE` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2085 ms |
| `FR` | 16 | 100.0% | 93.8% | 98.2% | 100.0% | 2533 ms |
| `ES` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2341 ms |
| `IT` | 16 | 100.0% | 93.8% | 96.4% | 100.0% | 1970 ms |
| `PT` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2207 ms |
| `NL` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2139 ms |
| `PL` | 16 | 100.0% | 75.0% | 85.7% | 87.5% | 2403 ms |
| `NB` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2261 ms |
| `LV` | 16 | 100.0% | 93.8% | 96.4% | 100.0% | 2259 ms |
| `CS` | 16 | 100.0% | 87.5% | 92.9% | 93.8% | 2526 ms |
| `HR` | 16 | 100.0% | 75.0% | 85.7% | 87.5% | 2689 ms |
| `LT` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2373 ms |
| `SK` | 16 | 100.0% | 81.3% | 89.3% | 87.5% | 2412 ms |
| `UR` | 16 | 100.0% | 93.8% | 96.4% | 100.0% | 2451 ms |
| `AR` | 16 | 100.0% | 93.8% | 96.4% | 100.0% | 2431 ms |
| `SW` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2386 ms |
| `CY` | 16 | 100.0% | 100.0% | 100.0% | 100.0% | 2162 ms |
| `GA` | 16 | 100.0% | 93.8% | 94.7% | 100.0% | 2295 ms |

## Category Performance Breakdown

| Category | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| Rally Discovery | 57 | 100.0% | 84.2% | 88.3% | 100.0% | 2550 ms |
| Driver Participations | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 2124 ms |
| Driver Wins | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 2188 ms |
| Rally Results | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 1925 ms |
| Rally Leaderboard | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 2146 ms |
| Driver Videos | 19 | 100.0% | 78.9% | 78.9% | 100.0% | 2408 ms |
| Video Actions | 57 | 100.0% | 98.2% | 99.3% | 98.2% | 2450 ms |
| Compound Search | 19 | 100.0% | 89.5% | 97.4% | 89.5% | 1725 ms |
| Uploaders | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 2426 ms |
| Global Leaderboards | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 2470 ms |
| Clarification | 19 | 100.0% | 100.0% | 100.0% | 100.0% | 2573 ms |
| Code Switching | 19 | 100.0% | 78.9% | 94.7% | 78.9% | 2128 ms |

## Per-Slot Extraction Metrics

| Slot | Expected | Extracted | Correct | Precision | Recall | F1 |
|---|---|---|---|---|---|---|
| `driverName` | 114 | 114 | 103 | 90.4% | 90.4% | 90.4% |
| `rallyName` | 152 | 157 | 152 | 96.8% | 100.0% | 98.4% |
| `actionType` | 95 | 95 | 95 | 100.0% | 100.0% | 100.0% |
| `country` | 19 | 21 | 19 | 90.5% | 100.0% | 95.0% |
| `city` | 19 | 14 | 11 | 78.6% | 57.9% | 66.7% |
| `stageName` | 19 | 19 | 19 | 100.0% | 100.0% | 100.0% |
| `year` | 95 | 95 | 95 | 100.0% | 100.0% | 100.0% |
| `limit` | 19 | 285 | 19 | 6.7% | 100.0% | 12.5% |

## Failure Diagnostic Samples

### `[EN-02]` "Rallies in Donegal."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Donegal}`
- **Actual:** Intent=`searchRallies`, Filters=`{rally: "Donegal"}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "rallyName" with value "Donegal"
  - **`missingFilter`**: Missing expected filter "city" (expected "Donegal")

### `[FR-02]` "Rallyes à Donegal."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Donegal}`
- **Actual:** Intent=`searchRallies`, Filters=`{country: "Ireland", city: "Donegal"}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "country" with value "Ireland"

### `[IT-02]` "Rally a Donegal."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Donegal}`
- **Actual:** Intent=`searchRallies`, Filters=`{rally: "Donegal"}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "rallyName" with value "Donegal"
  - **`missingFilter`**: Missing expected filter "city" (expected "Donegal")

### `[PL-02]` "Rajdy w Donegal."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Donegal}`
- **Actual:** Intent=`searchRallies`, Filters=`{rally: "Donegal"}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "rallyName" with value "Donegal"
  - **`missingFilter`**: Missing expected filter "city" (expected "Donegal")

### `[PL-08]` "Znajdź filmy z Philipem Squires."
- **Category:** `Driver Videos` (easy)
- **Expected:** Intent=`searchDriverVideos`, Filters=`{driverName: Philip Squires}`
- **Actual:** Intent=`searchDriverVideos`, Filters=`{driver: "Philipem Squires"}`
- **Failures:**
  - **`incorrectFilterValue`**: Slot "driverName" mismatch: expected "Philip Squires", got "Philipem Squires"

### `[PL-12]` "Pokaż skoki Josha Moffetta z Moonraker w 2025 roku."
- **Category:** `Compound Search` (easy)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: jump, driverName: Josh Moffett, rallyName: Moonraker, year: 2025}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{driver: "Josha Moffetta", rally: "Moonraker", action: "jump", year: 2025}`
- **Failures:**
  - **`incorrectFilterValue`**: Slot "driverName" mismatch: expected "Josh Moffett", got "Josha Moffetta"

### `[PL-16]` "Pokaż jumps Josha Moffetta z Moonraker w 2025"
- **Category:** `Code Switching` (easy)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: jump, driverName: Josh Moffett, rallyName: Moonraker, year: 2025}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{driver: "Josha Moffetta", rally: "Moonraker", action: "jump", year: 2025}`
- **Failures:**
  - **`incorrectFilterValue`**: Slot "driverName" mismatch: expected "Josh Moffett", got "Josha Moffetta"

### `[LV-02]` "Ralliji Donegālā."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Donegal}`
- **Actual:** Intent=`searchRallies`, Filters=`{rally: "Donegālā"}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "rallyName" with value "Donegālā"
  - **`missingFilter`**: Missing expected filter "city" (expected "Donegal")

### `[CS-08]` "Najdi videa Philipa Squires."
- **Category:** `Driver Videos` (easy)
- **Expected:** Intent=`searchDriverVideos`, Filters=`{driverName: Philip Squires}`
- **Actual:** Intent=`searchDriverVideos`, Filters=`{driver: "Philipa Squires"}`
- **Failures:**
  - **`incorrectFilterValue`**: Slot "driverName" mismatch: expected "Philip Squires", got "Philipa Squires"

### `[CS-16]` "Ukaž jumps Joshe Moffetta z Moonraker v roce 2025"
- **Category:** `Code Switching` (easy)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: jump, driverName: Josh Moffett, rallyName: Moonraker, year: 2025}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{driver: "Joshe Moffetta", rally: "Moonraker", action: "jump", year: 2025}`
- **Failures:**
  - **`incorrectFilterValue`**: Slot "driverName" mismatch: expected "Josh Moffett", got "Joshe Moffetta"

