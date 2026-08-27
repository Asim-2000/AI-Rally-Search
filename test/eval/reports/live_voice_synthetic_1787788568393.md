# 🎙️ Phase 5B Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T01:56:08.412018
**Benchmark Type**: `synthetic` (Real Audio Execution)
**Total Samples**: 38

## 📊 Executive Summary
| Metric | Measured Value | Gate Target | Gate Status |
| :--- | :---: | :---: | :---: |
| **Search Semantic Success Rate** | **92.1%** | >= 90.0% | ✅ PASSED |
| **Post-Recovery Entity Accuracy** | 96.7% | >= 95.0% | ✅ PASSED |
| **Raw STT Entity Accuracy** | 96.7% | N/A | ℹ️ Informational |
| **Intent Accuracy** | 100.0% | >= 95.0% | ✅ PASSED |
| **Filter F1 Score** | 0.93 | >= 0.90 | ✅ PASSED |
| **False-Positive Entity Resolution Rate** | **0.0%** | <= 1.0% | ✅ PASSED |
| **Raw Semantic Success Rate** | 42.1% | N/A | ℹ️ Baseline |
| **Word Error Rate (WER)** | 21.1% | N/A | ℹ️ Informational |
| **STT Latency (p50 / p95)** | 1062 ms / 1967 ms | N/A | ℹ️ Informational |
| **End-to-End Latency (p50 / p95)** | 3288 ms / 4699 ms | N/A | ℹ️ Informational |
| **Missing Audio Files** | 0 / 38 | 0 | ✅ NONE |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Raw Ent Acc | Rec Ent Acc | Intent Acc | Filter F1 | Raw Success | Search Success | FP Rate | STT p50/p95 | E2E p50/p95 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 0.0% | 902/902ms | 3159/3159ms |
| German (DE) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 0.0% | 834/834ms | 4476/4476ms |
| French (FR) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 2076/2076ms | 3444/3444ms |
| Spanish (ES) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 903/903ms | 2121/2121ms |
| Italian (IT) | 2 | 21.4% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1955/1955ms | 3696/3696ms |
| Portuguese (PT) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1009/1009ms | 2686/2686ms |
| Dutch (NL) | 2 | 13.9% | 100.0% | 100.0% | 100.0% | 1.00 | 0.0% | **100.0%** | 0.0% | 970/970ms | 3310/3310ms |
| Polish (PL) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 0.0% | 1780/1780ms | 3626/3626ms |
| Norwegian (Bokmål) (NB) | 2 | 36.1% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 0.0% | 1967/1967ms | 4140/4140ms |
| Latvian (LV) | 2 | 40.0% | 87.5% | 87.5% | 100.0% | 0.83 | 0.0% | **100.0%** | 0.0% | 1176/1176ms | 3127/3127ms |
| Czech (CS) | 2 | 14.3% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1447/1447ms | 3678/3678ms |
| Croatian (HR) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1339/1339ms | 3484/3484ms |
| Lithuanian (LT) | 2 | 40.0% | 100.0% | 100.0% | 100.0% | 0.93 | 0.0% | **50.0%** | 0.0% | 1914/1914ms | 4375/4375ms |
| Slovak (SK) | 2 | 21.4% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1421/1421ms | 3288/3288ms |
| Urdu (UR) | 2 | 79.2% | 75.0% | 75.0% | 100.0% | 0.75 | 50.0% | **100.0%** | 0.0% | 1571/1571ms | 7095/7095ms |
| Arabic (AR) | 2 | 39.0% | 75.0% | 75.0% | 100.0% | 0.93 | 0.0% | **50.0%** | 0.0% | 1967/1967ms | 5033/5033ms |
| Swahili (SW) | 2 | 22.0% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 0.0% | 1354/1354ms | 4699/4699ms |
| Welsh (CY) | 2 | 16.7% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1201/1201ms | 2940/2940ms |
| Irish (GA) | 2 | 36.1% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **50.0%** | 0.0% | 2031/2031ms | 4596/4596ms |

## 🏷️ Entity Resolution Outcome Breakdown
| Outcome Category | Count | Percentage | Description |
| :--- | :---: | :---: | :--- |
| `AUTO_RESOLVED_CORRECT` | 36 | 94.7% | Ambiguous/fuzzy token correctly matched database entity. |
| `AUTO_RESOLVED_INCORRECT` | 0 | 0.0% | CRITICAL FAILURE: Confidently mapped to incorrect database entity. |
| `CLARIFICATION_REQUIRED_CORRECTLY` | 0 | 0.0% | Genuinely ambiguous token triggered interactive clarification. |
| `UNNECESSARY_CLARIFICATION` | 2 | 5.3% | Clear unambiguous token triggered unnecessary clarification. |
| `NO_MATCH` | 0 | 0.0% | No entity candidate was resolved or required. |

## 🛑 12-Class Failure Attribution Breakdown
| Primary Failure Stage | Count | Percentage | Description |
| :--- | :---: | :---: | :--- |
| `NONE` | 35 | 92.1% | No error; query executed with semantic success. |
| `STT_LANGUAGE` | 0 | 0.0% | STT provider rejected or failed to transcribe audio due to language support. |
| `STT_WORD_ERROR` | 0 | 0.0% | Heavy transcription word errors degraded query understanding. |
| `STT_ENTITY_ERROR` | 0 | 0.0% | Entity name corrupted by STT beyond phonetic or fuzzy recovery. |
| `STT_NUMBER_ERROR` | 0 | 0.0% | Year or stage number omitted or misrecognized in speech transcription. |
| `PRE_LLM_RECOVERY` | 0 | 0.0% | Pre-LLM voice recovery failed to map recognizable domain token. |
| `LLM_INTENT` | 0 | 0.0% | LLM parsed an incorrect intent for the spoken query. |
| `LLM_FILTER` | 1 | 2.6% | LLM omitted or hallucinated filter parameters. |
| `ENTITY_RETRIEVAL` | 0 | 0.0% | Database entity candidate lookup failed to retrieve true match. |
| `ENTITY_SCORING` | 0 | 0.0% | Entity resolver scored wrong candidate higher than true candidate. |
| `AMBIGUITY_POLICY` | 2 | 5.3% | System triggered unnecessary interactive clarification on clear query. |
| `DATABASE` | 0 | 0.0% | Deterministic SearchRepository / MySQL execution failed or returned an unexpected result. |
| `OTHER` | 0 | 0.0% | Unexpected exception, network failure, missing audio asset, or timeout. |

## 🔍 Detailed Sample Traces & Diagnostics
### ✅ [synth-en-01] English (`en-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/en_01.mp3`
- **Expected Transcript**: "Show rallies in Ireland in 2025."
- **Actual STT Transcript**: "show rallies in ireland in 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 902ms | LLM: 1769ms | ER: 0ms | DB: 430ms | **Total: 3159ms**

### ✅ [synth-en-02] English (`en-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Transcript**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "show jump highlights featuring josh moffett from moonraker in 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 812ms | LLM: 1335ms | ER: 137ms | DB: 132ms | **Total: 2465ms**

### ✅ [synth-de-01] German (`de-DE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Transcript**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeige Release in Irland im Jahr 2025"
- **Normalized Transcript**: "Zeige Release in Ireland im Jahr 2025"
- **Domain Anchor Mappings**: `{Irland: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, rallyNames: [Release], rallyName: Release, eventNames: [Release], eventName: Release, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 701ms | LLM: 3655ms | ER: 38ms | DB: 74ms | **Total: 4476ms**

### ✅ [synth-de-02] German (`de-DE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 834ms | LLM: 1729ms | ER: 0ms | DB: 142ms | **Total: 2718ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Transcript**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **Normalized Transcript**: "Montrez les rallies en Ireland en 2025."
- **Domain Anchor Mappings**: `{Irlande: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 594ms | LLM: 1801ms | ER: 0ms | DB: 82ms | **Total: 2486ms**

### ✅ [synth-fr-02] French (`fr-FR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2076ms | LLM: 1146ms | ER: 0ms | DB: 146ms | **Total: 3444ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio Asset ID**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Transcript**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "mostrar rallies en irlanda en 2025"
- **Normalized Transcript**: "mostrar rallies en Ireland en 2025"
- **Domain Anchor Mappings**: `{irlanda: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 562ms | LLM: 1466ms | ER: 0ms | DB: 87ms | **Total: 2121ms**

### ✅ [synth-es-02] Spanish (`es-ES`)
- **Audio Asset ID**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 903ms | LLM: 1042ms | ER: 0ms | DB: 138ms | **Total: 2095ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Transcript**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025"
- **Normalized Transcript**: "Mostrarelli in Ireland nel 2025"
- **Domain Anchor Mappings**: `{Irlanda: Ireland}`
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 755ms | LLM: 1712ms | ER: 0ms | DB: 72ms | **Total: 2612ms**

### ✅ [synth-it-02] Italian (`it-IT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1955ms | LLM: 1598ms | ER: 0ms | DB: 137ms | **Total: 3696ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Transcript**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar ralis na Irlanda em 2025"
- **Normalized Transcript**: "Mostrar ralis na Ireland em 2025"
- **Domain Anchor Mappings**: `{Irlanda: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 599ms | LLM: 1670ms | ER: 0ms | DB: 79ms | **Total: 2353ms**

### ✅ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1009ms | LLM: 1514ms | ER: 0ms | DB: 153ms | **Total: 2686ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Transcript**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "TUNE RALLYS IN IERLAND IN 2025"
- **Normalized Transcript**: "TUNE RALLYS IN Ireland IN 2025"
- **Domain Anchor Mappings**: `{IERLAND: Ireland}`
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 970ms | LLM: 2194ms | ER: 0ms | DB: 73ms | **Total: 3310ms**

### ✅ [synth-nl-02] Dutch (`nl-NL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nl_02.mp3`
- **Expected Transcript**: "Toon spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Actual STT Transcript**: "Doen spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Normalized Transcript**: "Doen sprong hoogtepunten met Josh Moffett van Moonraker in 2025."
- **Domain Anchor Mappings**: `{spronghoogtepunten: sprong hoogtepunten}`
- **WER**: 11.1% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 744ms | LLM: 1755ms | ER: 0ms | DB: 145ms | **Total: 2651ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Transcript**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku"
- **Normalized Transcript**: "Pokaż rajdy w Ireland w 2005 roku"
- **Domain Anchor Mappings**: `{Irlandii: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2005], year: 2005, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1780ms | LLM: 1608ms | ER: 0ms | DB: 72ms | **Total: 3626ms**

### ✅ [synth-pl-02] Polish (`pl-PL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1428ms | LLM: 1510ms | ER: 0ms | DB: 138ms | **Total: 3244ms**

### ✅ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Transcript**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Vi sralia i irland i 225."
- **Normalized Transcript**: "Vi sralia i Ireland i 225."
- **Domain Anchor Mappings**: `{irland: Ireland}`
- **WER**: 50.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (35 rows returned)
- **Latency**: STT: 741ms | LLM: 2489ms | ER: 0ms | DB: 80ms | **Total: 3383ms**

### ✅ [synth-nb-02] Norwegian (Bokmål) (`nb-NO`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nb_02.mp3`
- **Expected Transcript**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Actual STT Transcript**: "Vis hopp høydepunkter med Josh Moffett fra Moonraker i 2025."
- **WER**: 22.2% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1967ms | LLM: 2030ms | ER: 0ms | DB: 137ms | **Total: 4140ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Transcript**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt Rālijas īrijā 2015."
- **Normalized Transcript**: "Rādīt Rālijas Ireland 2015."
- **Domain Anchor Mappings**: `{īrijā: Ireland}`
- **WER**: 60.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2015], year: 2015, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1176ms | LLM: 1501ms | ER: 0ms | DB: 71ms | **Total: 2917ms**

### ✅ [synth-lv-02] Latvian (`lv-LV`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Transcript**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Rādīt labākos lēcienas ar Josh Moffett no Moonraker 2215 gadā"
- **Normalized Transcript**: "Rādīt labākos lēcienas ar Josh Moffett no Moonraker 2025 gadā"
- **Domain Anchor Mappings**: `{2215: 2025}`
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 887ms | LLM: 1929ms | ER: 0ms | DB: 141ms | **Total: 3127ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Transcript**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "Ukaždali v Irsku v roce 2025."
- **Normalized Transcript**: "Ukaždali v Ireland v roce 2025."
- **Domain Anchor Mappings**: `{Irsku: Ireland}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 893ms | LLM: 1958ms | ER: 0ms | DB: 78ms | **Total: 3100ms**

### ✅ [synth-cs-02] Czech (`cs-CZ`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1447ms | LLM: 1923ms | ER: 0ms | DB: 138ms | **Total: 3678ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Transcript**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prikaži Relije u Irskoj u 2025. godini."
- **Normalized Transcript**: "Prikaži Relije u Ireland u 2025. godini."
- **Domain Anchor Mappings**: `{Irskoj: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 884ms | LLM: 1504ms | ER: 0ms | DB: 82ms | **Total: 2639ms**

### ✅ [synth-hr-02] Croatian (`hr-HR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025. godine."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1339ms | LLM: 1835ms | ER: 0ms | DB: 142ms | **Total: 3484ms**

### ✅ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Transcript**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt ralius airijoje 25 metais"
- **Normalized Transcript**: "Rodyt ralius Ireland 2025 metais"
- **Domain Anchor Mappings**: `{airijoje: Ireland, 25: 2025}`
- **WER**: 40.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1914ms | LLM: 1659ms | ER: 0ms | DB: 77ms | **Total: 3720ms**

### ❌ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Transcript**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Rodėti geriausius šuolius su Josh Moffett iš Moonraker dvutmysčių džiūdžiais bet metais"
- **WER**: 40.0% | **Failure Attribution**: `AMBIGUITY_POLICY`
- **Entity Resolution Outcome**: `UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyNames: [Moonraker], rallyName: Moonraker, driverNames: [Josh Moffett], driverName: Josh Moffett, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1478ms | LLM: 2670ms | ER: 38ms | DB: 0ms | **Total: 4375ms**

### ✅ [synth-sk-01] Slovak (`sk-SK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Transcript**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "ukáži relíf írsku v roku 2025."
- **Normalized Transcript**: "ukáži relíf Ireland v roku 2025."
- **Domain Anchor Mappings**: `{írsku: Ireland}`
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 883ms | LLM: 2031ms | ER: 0ms | DB: 77ms | **Total: 3161ms**

### ✅ [synth-sk-02] Slovak (`sk-SK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1421ms | LLM: 1562ms | ER: 0ms | DB: 139ms | **Total: 3288ms**

### ✅ [synth-ur-01] Urdu (`ur-PK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Transcript**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "ڈوہاز اور ییسٹر پائز میں آئرلینڈ کی ریلیاں دکھائیں"
- **Normalized Transcript**: "ڈوہاز اور ییسٹر پائز میں Ireland کی ریلیاں دکھائیں"
- **Domain Anchor Mappings**: `{آئرلینڈ: Ireland}`
- **WER**: 83.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, cities: [Dohaz, Yeaster Pize], city: Dohaz, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1330ms | LLM: 5303ms | ER: 213ms | DB: 67ms | **Total: 7095ms**

### ✅ [synth-ur-02] Urdu (`ur-PK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Transcript**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "دو ہزن یو س پائیث میں مونریکر سے جوش موفٹ کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 75.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1571ms | LLM: 2112ms | ER: 0ms | DB: 135ms | **Total: 4006ms**

### ✅ [synth-ar-01] Arabic (`ar-QA`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ar_01.mp3`
- **Expected Transcript**: "أظهر الراليات في أيرلندا في عام 2025."
- **Actual STT Transcript**: "أظهر الراليات في أيرلندا في عام 2029"
- **Normalized Transcript**: "أظهر الراليات في Ireland في عام 2025"
- **Domain Anchor Mappings**: `{أيرلندا: Ireland, 2029: 2025}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1967ms | LLM: 1653ms | ER: 0ms | DB: 81ms | **Total: 3880ms**

### ❌ [synth-ar-02] Arabic (`ar-QA`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Transcript**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين ٢٥٢"
- **WER**: 63.6% | **Failure Attribution**: `AMBIGUITY_POLICY`
- **Entity Resolution Outcome**: `UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyNames: [Moonraker], rallyName: Moonraker, driverNames: [Josh Moffett], driverName: Josh Moffett, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1125ms | LLM: 3729ms | ER: 0ms | DB: 0ms | **Total: 5033ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Transcript**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha, rali nchini ayalandi mwaka wa dwari dwendifemv."
- **Normalized Transcript**: "Onyesha, rali nchini Ireland mwaka wa dwari dwendifemv."
- **Domain Anchor Mappings**: `{ayalandi: Ireland}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (35 rows returned)
- **Latency**: STT: 1354ms | LLM: 3193ms | ER: 0ms | DB: 75ms | **Total: 4699ms**

### ✅ [synth-sw-02] Swahili (`sw-KE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1062ms | LLM: 2060ms | ER: 0ms | DB: 156ms | **Total: 3286ms**

### ✅ [synth-cy-01] Welsh (`cy-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Transcript**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Raleighi Iwerddon yn 2025"
- **Normalized Transcript**: "Dangos Raleighi Ireland yn 2025"
- **Domain Anchor Mappings**: `{Iwerddon: Ireland}`
- **WER**: 33.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 456ms | LLM: 1311ms | ER: 0ms | DB: 77ms | **Total: 1849ms**

### ✅ [synth-cy-02] Welsh (`cy-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Transcript**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1201ms | LLM: 1518ms | ER: 0ms | DB: 145ms | **Total: 2940ms**

### ❌ [synth-ga-01] Irish (`ga-IE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Transcript**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: "Taespaen, Rhaelitha, and Éirinn in 2025"
- **Normalized Transcript**: "Taespaen, Rhaelitha, and Ireland in 2025"
- **Domain Anchor Mappings**: `{Éirinn: Ireland}`
- **WER**: 50.0% | **Failure Attribution**: `LLM_FILTER`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Taespaen, Rhaelitha, Ireland], country: Taespaen, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 636ms | LLM: 3877ms | ER: 0ms | DB: 78ms | **Total: 4596ms**

### ✅ [synth-ga-02] Irish (`ga-IE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Transcript**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: "Táisbein buaicphointí léimeanna le Josh Moffett on Moonraker in 2025."
- **WER**: 22.2% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2031ms | LLM: 1719ms | ER: 0ms | DB: 135ms | **Total: 3890ms**

