# 🎙️ Phase 5B Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T01:39:20.296355
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
| **Raw Semantic Success Rate** | 39.5% | N/A | ℹ️ Baseline |
| **Word Error Rate (WER)** | 21.1% | N/A | ℹ️ Informational |
| **STT Latency (p50 / p95)** | 1135 ms / 1958 ms | N/A | ℹ️ Informational |
| **End-to-End Latency (p50 / p95)** | 3244 ms / 6133 ms | N/A | ℹ️ Informational |
| **Missing Audio Files** | 0 / 38 | 0 | ✅ NONE |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Raw Ent Acc | Rec Ent Acc | Intent Acc | Filter F1 | Raw Success | Search Success | FP Rate | STT p50/p95 | E2E p50/p95 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 0.0% | 805/805ms | 2441/2441ms |
| German (DE) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 0.0% | 1453/1453ms | 4313/4313ms |
| French (FR) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1184/1184ms | 2834/2834ms |
| Spanish (ES) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1299/1299ms | 2519/2519ms |
| Italian (IT) | 2 | 21.4% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1044/1044ms | 3058/3058ms |
| Portuguese (PT) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1203/1203ms | 2645/2645ms |
| Dutch (NL) | 2 | 13.9% | 100.0% | 100.0% | 100.0% | 1.00 | 0.0% | **100.0%** | 0.0% | 843/843ms | 3158/3158ms |
| Polish (PL) | 2 | 7.1% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 0.0% | 2233/2233ms | 3661/3661ms |
| Norwegian (Bokmål) (NB) | 2 | 36.1% | 100.0% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 0.0% | 1298/1298ms | 5373/5373ms |
| Latvian (LV) | 2 | 40.0% | 87.5% | 87.5% | 100.0% | 0.83 | 0.0% | **100.0%** | 0.0% | 892/892ms | 3462/3462ms |
| Czech (CS) | 2 | 14.3% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1388/1388ms | 4050/4050ms |
| Croatian (HR) | 2 | 0.0% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 776/776ms | 3582/3582ms |
| Lithuanian (LT) | 2 | 40.0% | 100.0% | 100.0% | 100.0% | 0.93 | 0.0% | **50.0%** | 0.0% | 1517/1517ms | 5503/5503ms |
| Slovak (SK) | 2 | 21.4% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 2044/2044ms | 3890/3890ms |
| Urdu (UR) | 2 | 79.2% | 75.0% | 75.0% | 100.0% | 0.75 | 50.0% | **100.0%** | 0.0% | 1137/1137ms | 6644/6644ms |
| Arabic (AR) | 2 | 39.0% | 75.0% | 75.0% | 100.0% | 0.93 | 0.0% | **50.0%** | 0.0% | 1958/1958ms | 5185/5185ms |
| Swahili (SW) | 2 | 22.0% | 100.0% | 100.0% | 100.0% | 0.76 | 0.0% | **50.0%** | 0.0% | 1135/1135ms | 4417/4417ms |
| Welsh (CY) | 2 | 16.7% | 100.0% | 100.0% | 100.0% | 1.00 | 50.0% | **100.0%** | 0.0% | 1202/1202ms | 2614/2614ms |
| Irish (GA) | 2 | 36.1% | 100.0% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 0.0% | 1852/1852ms | 9813/9813ms |

## 🏷️ Entity Resolution Outcome Breakdown
| Outcome Category | Count | Percentage | Description |
| :--- | :---: | :---: | :--- |
| `AUTO_RESOLVED_CORRECT` | 35 | 92.1% | Ambiguous/fuzzy token correctly matched database entity. |
| `AUTO_RESOLVED_INCORRECT` | 0 | 0.0% | CRITICAL FAILURE: Confidently mapped to incorrect database entity. |
| `CLARIFICATION_REQUIRED_CORRECTLY` | 0 | 0.0% | Genuinely ambiguous token triggered interactive clarification. |
| `UNNECESSARY_CLARIFICATION` | 3 | 7.9% | Clear unambiguous token triggered unnecessary clarification. |
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
| `LLM_FILTER` | 0 | 0.0% | LLM omitted or hallucinated filter parameters. |
| `ENTITY_RETRIEVAL` | 0 | 0.0% | Database entity candidate lookup failed to retrieve true match. |
| `ENTITY_SCORING` | 0 | 0.0% | Entity resolver scored wrong candidate higher than true candidate. |
| `AMBIGUITY_POLICY` | 3 | 7.9% | System triggered unnecessary interactive clarification on clear query. |
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
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 635ms | LLM: 1217ms | ER: 31ms | DB: 452ms | **Total: 2441ms**

### ✅ [synth-en-02] English (`en-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Transcript**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "show jump highlights featuring josh moffett from moonraker in 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 805ms | LLM: 1253ms | ER: 141ms | DB: 144ms | **Total: 2396ms**

### ✅ [synth-de-01] German (`de-DE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Transcript**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeige Release in Irland im Jahr 2025"
- **Normalized Transcript**: "Zeige Release in Ireland im Jahr 2025"
- **Domain Anchor Mappings**: `{Irland: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Release, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1273ms | LLM: 2914ms | ER: 38ms | DB: 85ms | **Total: 4313ms**

### ✅ [synth-de-02] German (`de-DE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1453ms | LLM: 1039ms | ER: 0ms | DB: 138ms | **Total: 2634ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Transcript**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **Normalized Transcript**: "Montrez les rallies en Ireland en 2025."
- **Domain Anchor Mappings**: `{Irlande: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1098ms | LLM: 1591ms | ER: 0ms | DB: 80ms | **Total: 2834ms**

### ✅ [synth-fr-02] French (`fr-FR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1184ms | LLM: 1013ms | ER: 0ms | DB: 139ms | **Total: 2340ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio Asset ID**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Transcript**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "mostrar rallies en irlanda en 2025"
- **Normalized Transcript**: "mostrar rallies en Ireland en 2025"
- **Domain Anchor Mappings**: `{irlanda: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 969ms | LLM: 1135ms | ER: 0ms | DB: 79ms | **Total: 2186ms**

### ✅ [synth-es-02] Spanish (`es-ES`)
- **Audio Asset ID**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1299ms | LLM: 1047ms | ER: 0ms | DB: 147ms | **Total: 2519ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Transcript**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025"
- **Normalized Transcript**: "Mostrarelli in Ireland nel 2025"
- **Domain Anchor Mappings**: `{Irlanda: Ireland}`
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 543ms | LLM: 2396ms | ER: 0ms | DB: 80ms | **Total: 3058ms**

### ✅ [synth-it-02] Italian (`it-IT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1044ms | LLM: 1213ms | ER: 0ms | DB: 139ms | **Total: 2400ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Transcript**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar ralis na Irlanda em 2025"
- **Normalized Transcript**: "Mostrar ralis na Ireland em 2025"
- **Domain Anchor Mappings**: `{Irlanda: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1203ms | LLM: 1125ms | ER: 0ms | DB: 78ms | **Total: 2409ms**

### ✅ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1150ms | LLM: 1290ms | ER: 0ms | DB: 146ms | **Total: 2645ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Transcript**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "TUNE RALLYS IN IERLAND IN 2025"
- **Normalized Transcript**: "TUNE RALLYS IN Ireland IN 2025"
- **Domain Anchor Mappings**: `{IERLAND: Ireland}`
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 843ms | LLM: 2159ms | ER: 0ms | DB: 79ms | **Total: 3083ms**

### ✅ [synth-nl-02] Dutch (`nl-NL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nl_02.mp3`
- **Expected Transcript**: "Toon spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Actual STT Transcript**: "Doen spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Normalized Transcript**: "Doen sprong hoogtepunten met Josh Moffett van Moonraker in 2025."
- **Domain Anchor Mappings**: `{spronghoogtepunten: sprong hoogtepunten}`
- **WER**: 11.1% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 803ms | LLM: 2216ms | ER: 0ms | DB: 136ms | **Total: 3158ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Transcript**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku"
- **Normalized Transcript**: "Pokaż rajdy w Ireland w 2005 roku"
- **Domain Anchor Mappings**: `{Irlandii: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1130ms | LLM: 1881ms | ER: 0ms | DB: 82ms | **Total: 3244ms**

### ✅ [synth-pl-02] Polish (`pl-PL`)
- **Audio Asset ID**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2233ms | LLM: 1133ms | ER: 0ms | DB: 139ms | **Total: 3661ms**

### ✅ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Transcript**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Vi sralia i irland i 225."
- **Normalized Transcript**: "Vi sralia i Ireland i 225."
- **Domain Anchor Mappings**: `{irland: Ireland}`
- **WER**: 50.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (35 rows returned)
- **Latency**: STT: 1127ms | LLM: 4116ms | ER: 0ms | DB: 87ms | **Total: 5373ms**

### ✅ [synth-nb-02] Norwegian (Bokmål) (`nb-NO`)
- **Audio Asset ID**: `test/eval/audio/synthetic/nb_02.mp3`
- **Expected Transcript**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Actual STT Transcript**: "Vis hopp høydepunkter med Josh Moffett fra Moonraker i 2025."
- **WER**: 22.2% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1298ms | LLM: 1912ms | ER: 2ms | DB: 138ms | **Total: 3354ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Transcript**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt Rālijas īrijā 2015."
- **Normalized Transcript**: "Rādīt Rālijas Ireland 2015."
- **Domain Anchor Mappings**: `{īrijā: Ireland}`
- **WER**: 60.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2015, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 778ms | LLM: 1778ms | ER: 0ms | DB: 81ms | **Total: 2814ms**

### ✅ [synth-lv-02] Latvian (`lv-LV`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Transcript**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Rādīt labākos lēcienas ar Josh Moffett no Moonraker 2215 gadā"
- **Normalized Transcript**: "Rādīt labākos lēcienas ar Josh Moffett no Moonraker 2025 gadā"
- **Domain Anchor Mappings**: `{2215: 2025}`
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 892ms | LLM: 2172ms | ER: 0ms | DB: 203ms | **Total: 3462ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Transcript**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "Ukaždali v Irsku v roce 2025."
- **Normalized Transcript**: "Ukaždali v Ireland v roce 2025."
- **Domain Anchor Mappings**: `{Irsku: Ireland}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1388ms | LLM: 2352ms | ER: 0ms | DB: 114ms | **Total: 4050ms**

### ✅ [synth-cs-02] Czech (`cs-CZ`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1264ms | LLM: 1242ms | ER: 0ms | DB: 175ms | **Total: 2848ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Transcript**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prikaži Relije u Irskoj u 2025. godini."
- **Normalized Transcript**: "Prikaži Relije u Ireland u 2025. godini."
- **Domain Anchor Mappings**: `{Irskoj: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 763ms | LLM: 2549ms | ER: 0ms | DB: 92ms | **Total: 3582ms**

### ✅ [synth-hr-02] Croatian (`hr-HR`)
- **Audio Asset ID**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025. godine."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 776ms | LLM: 1297ms | ER: 0ms | DB: 140ms | **Total: 2392ms**

### ✅ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Transcript**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt ralius airijoje 25 metais"
- **Normalized Transcript**: "Rodyt ralius Ireland 2025 metais"
- **Domain Anchor Mappings**: `{airijoje: Ireland, 25: 2025}`
- **WER**: 40.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1197ms | LLM: 1611ms | ER: 0ms | DB: 85ms | **Total: 2968ms**

### ❌ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio Asset ID**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Transcript**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Rodėti geriausius šuolius su Josh Moffett iš Moonraker dvutmysčių džiūdžiais bet metais"
- **WER**: 40.0% | **Failure Attribution**: `AMBIGUITY_POLICY`
- **Entity Resolution Outcome**: `UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1517ms | LLM: 3769ms | ER: 43ms | DB: 0ms | **Total: 5503ms**

### ✅ [synth-sk-01] Slovak (`sk-SK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Transcript**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "ukáži relíf írsku v roku 2025."
- **Normalized Transcript**: "ukáži relíf Ireland v roku 2025."
- **Domain Anchor Mappings**: `{írsku: Ireland}`
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 718ms | LLM: 2909ms | ER: 0ms | DB: 91ms | **Total: 3890ms**

### ✅ [synth-sk-02] Slovak (`sk-SK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2044ms | LLM: 1019ms | ER: 0ms | DB: 141ms | **Total: 3380ms**

### ✅ [synth-ur-01] Urdu (`ur-PK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Transcript**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "ڈوہاز اور ییسٹر پائز میں آئرلینڈ کی ریلیاں دکھائیں"
- **Normalized Transcript**: "ڈوہاز اور ییسٹر پائز میں Ireland کی ریلیاں دکھائیں"
- **Domain Anchor Mappings**: `{آئرلینڈ: Ireland}`
- **WER**: 83.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, city: Dohaz and Yester Pies, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 696ms | LLM: 5557ms | ER: 122ms | DB: 79ms | **Total: 6644ms**

### ✅ [synth-ur-02] Urdu (`ur-PK`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Transcript**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "دو ہزن یو س پائیث میں مونریکر سے جوش موفٹ کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 75.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1137ms | LLM: 4647ms | ER: 0ms | DB: 146ms | **Total: 6133ms**

### ✅ [synth-ar-01] Arabic (`ar-QA`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ar_01.mp3`
- **Expected Transcript**: "أظهر الراليات في أيرلندا في عام 2025."
- **Actual STT Transcript**: "أظهر الراليات في أيرلندا في عام 2029"
- **Normalized Transcript**: "أظهر الراليات في Ireland في عام 2025"
- **Domain Anchor Mappings**: `{أيرلندا: Ireland, 2029: 2025}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1958ms | LLM: 1794ms | ER: 0ms | DB: 83ms | **Total: 4018ms**

### ❌ [synth-ar-02] Arabic (`ar-QA`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Transcript**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين ٢٥٢"
- **WER**: 63.6% | **Failure Attribution**: `AMBIGUITY_POLICY`
- **Entity Resolution Outcome**: `UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1458ms | LLM: 3524ms | ER: 0ms | DB: 0ms | **Total: 5185ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Transcript**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha, rali nchini ayalandi mwaka wa dwari dwendifemv."
- **Normalized Transcript**: "Onyesha, rali nchini Ireland mwaka wa dwari dwendifemv."
- **Domain Anchor Mappings**: `{ayalandi: Ireland}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (35 rows returned)
- **Latency**: STT: 743ms | LLM: 3471ms | ER: 0ms | DB: 91ms | **Total: 4417ms**

### ❌ [synth-sw-02] Swahili (`sw-KE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Failure Attribution**: `AMBIGUITY_POLICY`
- **Entity Resolution Outcome**: `UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1135ms | LLM: 2855ms | ER: 0ms | DB: 0ms | **Total: 3997ms**

### ✅ [synth-cy-01] Welsh (`cy-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Transcript**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Raleighi Iwerddon yn 2025"
- **Normalized Transcript**: "Dangos Raleighi Ireland yn 2025"
- **Domain Anchor Mappings**: `{Iwerddon: Ireland}`
- **WER**: 33.3% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 721ms | LLM: 1635ms | ER: 0ms | DB: 82ms | **Total: 2442ms**

### ✅ [synth-cy-02] Welsh (`cy-GB`)
- **Audio Asset ID**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Transcript**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1202ms | LLM: 1268ms | ER: 0ms | DB: 138ms | **Total: 2614ms**

### ✅ [synth-ga-01] Irish (`ga-IE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Transcript**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: "Taespaen, Rhaelitha, and Éirinn in 2025"
- **Normalized Transcript**: "Taespaen, Rhaelitha, and Ireland in 2025"
- **Domain Anchor Mappings**: `{Éirinn: Ireland}`
- **WER**: 50.0% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Taespaen, eventName: Rhaelitha, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1852ms | LLM: 7766ms | ER: 39ms | DB: 82ms | **Total: 9813ms**

### ✅ [synth-ga-02] Irish (`ga-IE`)
- **Audio Asset ID**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Transcript**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: "Táisbein buaicphointí léimeanna le Josh Moffett on Moonraker in 2025."
- **WER**: 22.2% | **Failure Attribution**: `NONE`
- **Entity Resolution Outcome**: `AUTO_RESOLVED_CORRECT`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1004ms | LLM: 2303ms | ER: 0ms | DB: 204ms | **Total: 3517ms**

