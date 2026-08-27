# 🎙️ Phase 5B Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T02:20:28.104767
**Benchmark Type**: `synthetic` (Real Audio Execution)
**Total Samples**: 38

## 📊 Executive Summary
| Metric | Measured Value | Gate Target | Gate Status |
| :--- | :---: | :---: | :---: |
| **Search Semantic Success Rate** | **92.1%** | >= 90.0% | ✅ PASSED |
| **Post-Recovery Entity Accuracy** | 96.7% | >= 95.0% | ✅ PASSED |
| **Raw STT Entity Accuracy** | 96.7% | N/A | ℹ️ Informational |
| **Intent Accuracy** | 100.0% | >= 95.0% | ✅ PASSED |
| **Filter F1 Score** | 0.94 | >= 0.90 | ✅ PASSED |
| **False-Positive Entity Resolution Rate** | **0.0%** | <= 1.0% | ✅ PASSED |
| **Raw Semantic Success Rate** | 42.1% | N/A | ℹ️ Baseline |
| **Word Error Rate (WER)** | 21.1% | N/A | ℹ️ Informational |
| **STT Latency (p50 / p95)** | 1000 ms / 1981 ms | N/A | ℹ️ Informational |
| **End-to-End Latency (p50 / p95)** | 3749 ms / 5588 ms | N/A | ℹ️ Informational |
| **Missing Audio Files** | 0 / 38 | 0 | ✅ NONE |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Raw Ent Acc | Rec Ent Acc | Intent Acc | Filter F1 | Raw Success | Search Success | FP Rate | STT p50/p95 | E2E p50/p95 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 0.0% | 990/990ms | 3685/3685ms |
| German (DE) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 2321/2321ms | 5588/5588ms |
| French (FR) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1184/1184ms | 3412/3412ms |
| Spanish (ES) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1981/1981ms | 4900/4900ms |
| Italian (IT) | 2 | 21.4% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1400/1400ms | 4091/4091ms |
| Portuguese (PT) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 2118/2118ms | 4331/4331ms |
| Dutch (NL) | 2 | 13.9% | 100.0% | 100.0% | 100.0% | 1.00 | 0.0% | **100.0%** | 0.0% | 1400/1400ms | 3500/3500ms |
| Polish (PL) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 0.0% | 963/963ms | 3740/3740ms |
| Norwegian (Bokmål) (NB) | 2 | 36.1% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 0.0% | 1233/1233ms | 5569/5569ms |
| Latvian (LV) | 2 | 40.0% | 87.5% | 87.5% | 100.0% | 0.83 | 0.0% | **100.0%** | 0.0% | 882/882ms | 3710/3710ms |
| Czech (CS) | 2 | 14.3% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 827/827ms | 3510/3510ms |
| Croatian (HR) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1446/1446ms | 4485/4485ms |
| Lithuanian (LT) | 2 | 40.0% | 100.0% | 100.0% | 100.0% | 0.93 | 0.0% | **50.0%** | 0.0% | 1381/1381ms | 5078/5078ms |
| Slovak (SK) | 2 | 21.4% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1440/1440ms | 4660/4660ms |
| Urdu (UR) | 2 | 79.2% | 75.0% | 75.0% | 100.0% | 0.75 | 50.0% | **100.0%** | 0.0% | 1687/1687ms | 7176/7176ms |
| Arabic (AR) | 2 | 39.0% | 75.0% | 75.0% | 100.0% | 0.93 | 0.0% | **50.0%** | 0.0% | 1609/1609ms | 6565/6565ms |
| Swahili (SW) | 2 | 22.0% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 0.0% | 1472/1472ms | 4878/4878ms |
| Welsh (CY) | 2 | 16.7% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1039/1039ms | 3482/3482ms |
| Irish (GA) | 2 | 36.1% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **50.0%** | 0.0% | 1236/1236ms | 4335/4335ms |

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
- **Latency**: STT: 949ms | LLM: 2286ms | ER: 1ms | DB: 392ms | **Total: 3685ms**

### ✅ [synth-en-02] English (`en-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Transcript**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "show jump highlights featuring josh moffett from moonraker in 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 990ms | LLM: 2166ms | ER: 133ms | DB: 154ms | **Total: 3492ms**

### ✅ [synth-de-01] German (`de-DE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Transcript**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeige Release in Irland im Jahr 2025"
- **Normalized Transcript**: "Zeige Release in Ireland im Jahr 2025"
- **Domain Anchor Mappings**: `{Irland: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, years: [2025], year: 2025, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1147ms | LLM: 4325ms | ER: 0ms | DB: 112ms | **Total: 5588ms**

### ✅ [synth-de-02] German (`de-DE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2321ms | LLM: 1966ms | ER: 0ms | DB: 237ms | **Total: 4535ms**

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
- **Latency**: STT: 635ms | LLM: 1878ms | ER: 0ms | DB: 119ms | **Total: 2679ms**

### ✅ [synth-fr-02] French (`fr-FR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1184ms | LLM: 1980ms | ER: 0ms | DB: 237ms | **Total: 3412ms**

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
- **Latency**: STT: 1981ms | LLM: 2814ms | ER: 0ms | DB: 93ms | **Total: 4900ms**

### ✅ [synth-es-02] Spanish (`es-ES`)
- **Audio Asset ID**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1000ms | LLM: 2065ms | ER: 0ms | DB: 169ms | **Total: 3252ms**

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
- **Latency**: STT: 737ms | LLM: 2855ms | ER: 0ms | DB: 101ms | **Total: 3749ms**

### ✅ [synth-it-02] Italian (`it-IT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1400ms | LLM: 2511ms | ER: 0ms | DB: 169ms | **Total: 4091ms**

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
- **Latency**: STT: 778ms | LLM: 2174ms | ER: 0ms | DB: 174ms | **Total: 3134ms**

### ✅ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2118ms | LLM: 1943ms | ER: 0ms | DB: 210ms | **Total: 4331ms**

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
- **Latency**: STT: 848ms | LLM: 2203ms | ER: 0ms | DB: 105ms | **Total: 3160ms**

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
- **Latency**: STT: 1400ms | LLM: 1898ms | ER: 0ms | DB: 194ms | **Total: 3500ms**

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
- **Latency**: STT: 963ms | LLM: 2491ms | ER: 0ms | DB: 86ms | **Total: 3740ms**

### ✅ [synth-pl-02] Polish (`pl-PL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 688ms | LLM: 2513ms | ER: 0ms | DB: 148ms | **Total: 3524ms**

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
- **Latency**: STT: 1183ms | LLM: 4215ms | ER: 0ms | DB: 93ms | **Total: 5569ms**

### ✅ [synth-nb-02] Norwegian (Bokmål) (`nb-NO`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nb_02.mp3`
- **Expected Transcript**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Actual STT Transcript**: "Vis hopp høydepunkter med Josh Moffett fra Moonraker i 2025."
- **WER**: 22.2% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1233ms | LLM: 2557ms | ER: 0ms | DB: 180ms | **Total: 3977ms**

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
- **Latency**: STT: 878ms | LLM: 2109ms | ER: 0ms | DB: 85ms | **Total: 3244ms**

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
- **Latency**: STT: 882ms | LLM: 2512ms | ER: 0ms | DB: 148ms | **Total: 3710ms**

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
- **Latency**: STT: 567ms | LLM: 2682ms | ER: 0ms | DB: 88ms | **Total: 3510ms**

### ✅ [synth-cs-02] Czech (`cs-CZ`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 827ms | LLM: 2222ms | ER: 0ms | DB: 150ms | **Total: 3335ms**

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
- **Latency**: STT: 871ms | LLM: 2268ms | ER: 0ms | DB: 89ms | **Total: 3423ms**

### ✅ [synth-hr-02] Croatian (`hr-HR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025. godine."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1446ms | LLM: 2698ms | ER: 0ms | DB: 169ms | **Total: 4485ms**

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
- **Latency**: STT: 884ms | LLM: 1896ms | ER: 0ms | DB: 85ms | **Total: 2934ms**

### ❌ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Transcript**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Rodėti geriausius šuolius su Josh Moffett iš Moonraker dvutmysčių džiūdžiais bet metais"
- **WER**: 40.0% | **Failure Attribution**: `AMBIGUITY_POLICY`
- **Entity Resolution Outcome**: `UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyNames: [Moonraker], rallyName: Moonraker, driverNames: [Josh Moffett], driverName: Josh Moffett, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1381ms | LLM: 3482ms | ER: 43ms | DB: 0ms | **Total: 5078ms**

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
- **Latency**: STT: 634ms | LLM: 3089ms | ER: 0ms | DB: 92ms | **Total: 3985ms**

### ✅ [synth-sk-02] Slovak (`sk-SK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1440ms | LLM: 2909ms | ER: 0ms | DB: 145ms | **Total: 4660ms**

### ✅ [synth-ur-01] Urdu (`ur-PK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Transcript**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "ڈوہاز اور ییسٹر پائز میں آئرلینڈ کی ریلیاں دکھائیں"
- **Normalized Transcript**: "ڈوہاز اور ییسٹر پائز میں Ireland کی ریلیاں دکھائیں"
- **Domain Anchor Mappings**: `{آئرلینڈ: Ireland}`
- **WER**: 83.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, countries: [Ireland], country: Ireland, cities: [Dohaz, Yester Pies], city: Dohaz, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 858ms | LLM: 5811ms | ER: 242ms | DB: 81ms | **Total: 7176ms**

### ✅ [synth-ur-02] Urdu (`ur-PK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Transcript**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "دو ہزن یو س پائیث میں مونریکر سے جوش موفٹ کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 75.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1687ms | LLM: 3468ms | ER: 0ms | DB: 143ms | **Total: 5489ms**

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
- **Latency**: STT: 777ms | LLM: 3438ms | ER: 0ms | DB: 86ms | **Total: 4479ms**

### ❌ [synth-ar-02] Arabic (`ar-QA`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Transcript**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين ٢٥٢"
- **WER**: 63.6% | **Failure Attribution**: `AMBIGUITY_POLICY`
- **Entity Resolution Outcome**: `UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyNames: [Moonraker], rallyName: Moonraker, driverNames: [Josh Moffett], driverName: Josh Moffett, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1609ms | LLM: 4774ms | ER: 0ms | DB: 0ms | **Total: 6565ms**

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
- **Latency**: STT: 1153ms | LLM: 3576ms | ER: 0ms | DB: 86ms | **Total: 4878ms**

### ✅ [synth-sw-02] Swahili (`sw-KE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1472ms | LLM: 2850ms | ER: 0ms | DB: 149ms | **Total: 4486ms**

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
- **Latency**: STT: 668ms | LLM: 2382ms | ER: 0ms | DB: 90ms | **Total: 3216ms**

### ✅ [synth-cy-02] Welsh (`cy-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Transcript**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1039ms | LLM: 2285ms | ER: 0ms | DB: 152ms | **Total: 3482ms**

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
- **Latency**: STT: 1236ms | LLM: 3002ms | ER: 0ms | DB: 93ms | **Total: 4335ms**

### ✅ [synth-ga-02] Irish (`ga-IE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Transcript**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: "Táisbein buaicphointí léimeanna le Josh Moffett on Moonraker in 2025."
- **WER**: 22.2% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, years: [2025], year: 2025, rallyNames: [Moonraker Forestry Rally 2025], rallyName: Moonraker Forestry Rally 2025, eventNames: [Moonraker Forestry Rally 2025], eventName: Moonraker Forestry Rally 2025, driverNames: [Josh Moffett], driverName: Josh Moffett, driverIds: [4e1a528d-0d6b-4aa3-bf06-27a27318fb70], driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionTypes: [jump], actionType: jump, driverMatchMode: ANY, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 727ms | LLM: 2781ms | ER: 0ms | DB: 157ms | **Total: 3672ms**

