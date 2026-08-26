# 🎙️ Phase 5B.1.1 Hardened Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T01:01:13.395832
**Benchmark Type**: `synthetic` (Real Audio Execution)
**STT Model**: `whisper-1`
**Total Multilingual Audio Samples**: 38 (across 19 languages)

## 📊 Before vs. After Benchmark Comparison
| Metric | Baseline | Hardened | Delta | Gate Target | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Word Error Rate (WER)** | 26.6% | 22.3% | -4.3% | N/A | ℹ️ Informational |
| **Raw Entity Accuracy** | 71.3% | 96.7% | +25.4% | N/A | ℹ️ Informational |
| **Post-Recovery Entity Accuracy** | 71.3% | 96.7% | +25.4% | >= 95% | ✅ PASSED |
| **Intent Accuracy** | 50.0% | 97.4% | +47.4% | >= 95% | ✅ PASSED |
| **Filter F1 Score** | 0.43 | 0.90 | +0.47 | >= 0.90 | ❌ FAILED |
| **Semantic Exact Match** | 28.9% | 73.7% | +44.8% | N/A | ℹ️ Informational |
| **Search Semantic Success Rate** | **42.1%** | **81.6%** | **+39.5%** | >= 90% | **❌ FAILED** |
| **STT Latency (p50)** | 984 ms | 1150 ms | +166ms | N/A | ℹ️ Informational |
| **End-to-End Latency (p50)** | 3429 ms | 3649 ms | +220ms | N/A | ℹ️ Informational |

## 🛑 Failure Attribution Breakdown
| Primary Failure Stage | Count | Percentage |
| :--- | :---: | :---: |
| `NONE` | 31 | 81.6% |
| `STT_LANGUAGE_FAILURE` | 0 | 0.0% |
| `STT_TRANSCRIPTION_ERROR` | 0 | 0.0% |
| `STT_ENTITY_CORRUPTION` | 0 | 0.0% |
| `LLM_INTENT_ERROR` | 1 | 2.6% |
| `LLM_FILTER_ERROR` | 5 | 13.2% |
| `LLM_UNNECESSARY_CLARIFICATION` | 1 | 2.6% |
| `ENTITY_RESOLUTION_FAILURE` | 0 | 0.0% |
| `DB_EXECUTION_FAILURE` | 0 | 0.0% |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Post-Rec Entity Acc | Intent Acc | Filter F1 | Semantic Exact | Search Success | STT p50 | E2E p50 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1461ms | 3824ms |
| German (DE) | 2 | 7.1% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 1391ms | 7285ms |
| French (FR) | 2 | 7.1% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1247ms | 2939ms |
| Spanish (ES) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1231ms | 3368ms |
| Italian (IT) | 2 | 21.4% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1337ms | 2824ms |
| Portuguese (PT) | 2 | 8.3% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 1281ms | 3700ms |
| Dutch (NL) | 2 | 13.9% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1351ms | 3846ms |
| Polish (PL) | 2 | 7.1% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 2154ms | 3414ms |
| Norwegian (Bokmål) (NB) | 2 | 16.7% | 100.0% | 100.0% | 0.75 | 50.0% | **50.0%** | 808ms | 4554ms |
| Latvian (LV) | 2 | 30.0% | 87.5% | 100.0% | 1.00 | 100.0% | **100.0%** | 959ms | 3534ms |
| Czech (CS) | 2 | 14.3% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1458ms | 4944ms |
| Croatian (HR) | 2 | 14.3% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1850ms | 4912ms |
| Lithuanian (LT) | 2 | 50.0% | 100.0% | 100.0% | 0.75 | 50.0% | **50.0%** | 1344ms | 3649ms |
| Slovak (SK) | 2 | 21.4% | 100.0% | 100.0% | 0.75 | 50.0% | **50.0%** | 1183ms | 5092ms |
| Urdu (UR) | 2 | 54.2% | 87.5% | 100.0% | 0.75 | 50.0% | **50.0%** | 2248ms | 4666ms |
| Arabic (AR) | 2 | 46.1% | 75.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1150ms | 3975ms |
| Swahili (SW) | 2 | 7.7% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1166ms | 4044ms |
| Welsh (CY) | 2 | 43.3% | 100.0% | 100.0% | 0.75 | 50.0% | **50.0%** | 1432ms | 4056ms |
| Irish (GA) | 2 | 61.1% | 87.5% | 50.0% | 0.68 | 0.0% | **0.0%** | 912ms | 6031ms |

## 🔍 Detailed Sample Traces & Diagnostics
### ✅ [synth-en-01] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_01.mp3`
- **Expected Speech**: "Show rallies in Ireland in 2025."
- **Actual STT Transcript**: "Show rallies in Ireland in 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1461ms | LLM: 1923ms | ER: 0ms | DB: 426ms | **Total: 3824ms**

### ✅ [synth-en-02] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Speech**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "Show Jump Highlights featuring Josh Moffett from Moonraker in 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 998ms | LLM: 1541ms | ER: 150ms | DB: 137ms | **Total: 2830ms**

### ✅ [synth-de-01] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Speech**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeige Release in Irland im Jahr 2025"
- **Normalized Transcript (Voice Recovery)**: "Zeige Release in Ireland im Jahr 2025"
- **Recovery Mappings**: `{Irland: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Release, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1297ms | LLM: 5860ms | ER: 40ms | DB: 84ms | **Total: 7285ms**

### ✅ [synth-de-02] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Speech**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1391ms | LLM: 1532ms | ER: 0ms | DB: 160ms | **Total: 3086ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Speech**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **Normalized Transcript (Voice Recovery)**: "Montrez les rallies en Irelande en 2025."
- **Recovery Mappings**: `{Irland: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 557ms | LLM: 2293ms | ER: 0ms | DB: 86ms | **Total: 2939ms**

### ✅ [synth-fr-02] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Speech**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1247ms | LLM: 1176ms | ER: 0ms | DB: 155ms | **Total: 2581ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Speech**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "Mostrar rallies en Irlanda en 2025."
- **Normalized Transcript (Voice Recovery)**: "Mostrar rallies en Ireland en 2025."
- **Recovery Mappings**: `{Irlanda: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1231ms | LLM: 2036ms | ER: 0ms | DB: 99ms | **Total: 3368ms**

### ✅ [synth-es-02] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Speech**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 822ms | LLM: 1230ms | ER: 0ms | DB: 137ms | **Total: 2191ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Speech**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025."
- **Normalized Transcript (Voice Recovery)**: "Mostrarelli in Ireland nel 2025."
- **Recovery Mappings**: `{Irlanda: Ireland}`
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 678ms | LLM: 2050ms | ER: 0ms | DB: 93ms | **Total: 2824ms**

### ✅ [synth-it-02] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Speech**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1337ms | LLM: 1330ms | ER: 0ms | DB: 135ms | **Total: 2806ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Speech**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar Hallease na Irlanda em 2025"
- **Normalized Transcript (Voice Recovery)**: "Mostrar Hallease na Ireland em 2025"
- **Recovery Mappings**: `{Irlanda: Ireland}`
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Hallease, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1194ms | LLM: 2352ms | ER: 39ms | DB: 112ms | **Total: 3700ms**

### ✅ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Speech**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1281ms | LLM: 1348ms | ER: 0ms | DB: 138ms | **Total: 2770ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Speech**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "TUNE RALLYS IN IERLAND IN 2025"
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 658ms | LLM: 2459ms | ER: 0ms | DB: 78ms | **Total: 3198ms**

### ✅ [synth-nl-02] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_02.mp3`
- **Expected Speech**: "Toon spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Actual STT Transcript**: "Doen spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Normalized Transcript (Voice Recovery)**: "Doen sprong hoogtepunten met Josh Moffett van Moonraker in 2025."
- **Recovery Mappings**: `{spronghoogtepunten: sprong hoogtepunten}`
- **WER**: 11.1% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1351ms | LLM: 2353ms | ER: 0ms | DB: 140ms | **Total: 3846ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Speech**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku."
- **Normalized Transcript (Voice Recovery)**: "Pokaż rajdy w Irelandii w 2005 roku."
- **Recovery Mappings**: `{Irland: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1029ms | LLM: 1998ms | ER: 0ms | DB: 73ms | **Total: 3104ms**

### ✅ [synth-pl-02] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Speech**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2154ms | LLM: 1121ms | ER: 0ms | DB: 135ms | **Total: 3414ms**

### ❌ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Speech**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Vis religiet i Ørland i 2025."
- **WER**: 33.3% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, city: Ørland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 604ms | LLM: 3756ms | ER: 110ms | DB: 80ms | **Total: 4554ms**

### ✅ [synth-nb-02] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_02.mp3`
- **Expected Speech**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Actual STT Transcript**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Normalized Transcript (Voice Recovery)**: "Vis hopp høydepunkter med Josh Moffett fra Moonraker i 2025."
- **Recovery Mappings**: `{hopphøydepunkter: hopp høydepunkter}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 808ms | LLM: 2205ms | ER: 0ms | DB: 144ms | **Total: 3160ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Speech**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt Rālijas īrijā 2025 gada"
- **WER**: 40.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 867ms | LLM: 1854ms | ER: 0ms | DB: 78ms | **Total: 2801ms**

### ✅ [synth-lv-02] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Speech**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Radīt labākos lēcienas ar Josh Moffett no Moonraker 2025 gadā!"
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 959ms | LLM: 2437ms | ER: 0ms | DB: 134ms | **Total: 3534ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Speech**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "ukaždali v Irsku v roce 2025."
- **Normalized Transcript (Voice Recovery)**: "ukaždali v Ireland v roce 2025."
- **Recovery Mappings**: `{Irsku: Ireland}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 786ms | LLM: 4084ms | ER: 0ms | DB: 73ms | **Total: 4944ms**

### ✅ [synth-cs-02] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Speech**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1458ms | LLM: 1207ms | ER: 0ms | DB: 132ms | **Total: 2800ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Speech**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prijka žirelije u Irskoj u 2025. godini."
- **Normalized Transcript (Voice Recovery)**: "Prijka žirelije u Ireland u 2025. godini."
- **Recovery Mappings**: `{Irskoj: Ireland}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1850ms | LLM: 2982ms | ER: 0ms | DB: 77ms | **Total: 4912ms**

### ✅ [synth-hr-02] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Speech**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025 godine."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 918ms | LLM: 3070ms | ER: 0ms | DB: 137ms | **Total: 4128ms**

### ❌ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Speech**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt raliu Seirijoje 25 metais"
- **WER**: 80.0% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, city: Seirijai, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1000ms | LLM: 2455ms | ER: 113ms | DB: 78ms | **Total: 3649ms**

### ✅ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Speech**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Radu digeriausiu šuolius su Josh Moffett iš Moonraker 2025 metais"
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1344ms | LLM: 2036ms | ER: 0ms | DB: 162ms | **Total: 3545ms**

### ❌ [synth-sk-01] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Speech**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "Ukáž Relif Irsku v roku 2025."
- **Normalized Transcript (Voice Recovery)**: "Ukáž Relif Ireland v roku 2025."
- **Recovery Mappings**: `{Irsku: Ireland}`
- **WER**: 42.9% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Circuit of Ireland Rally 2025, eventName: Circuit of Ireland Rally 2025, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (1 rows returned)
- **Latency**: STT: 1183ms | LLM: 3373ms | ER: 42ms | DB: 491ms | **Total: 5092ms**

### ✅ [synth-sk-02] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Speech**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 732ms | LLM: 1955ms | ER: 0ms | DB: 138ms | **Total: 2827ms**

### ❌ [synth-ur-01] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Speech**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "Doha's and Easter Pies میں آئرلینڈ کی ریلیاں دکھائیں"
- **Normalized Transcript (Voice Recovery)**: "Doha's and Easter Pies میں Ireland کی ریلیاں دکھائیں"
- **Recovery Mappings**: `{آئرلینڈ: Ireland}`
- **WER**: 83.3% | **Failure Attribution**: `LLM_UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Doha's and Easter Pies, country: Ireland, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 731ms | LLM: 3743ms | ER: 45ms | DB: 0ms | **Total: 4522ms**

### ✅ [synth-ur-02] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Speech**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "2025 میں Moonraker سے جوش موفٹ کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 25.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2248ms | LLM: 2277ms | ER: 0ms | DB: 137ms | **Total: 4666ms**

### ✅ [synth-ar-01] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_01.mp3`
- **Expected Speech**: "أظهر الراليات في أيرلندا في عام 2025."
- **Actual STT Transcript**: "أظهر الراليات في إيرلندا في عام 2029"
- **Normalized Transcript (Voice Recovery)**: "أظهر الراليات في Ireland في عام 2025"
- **Recovery Mappings**: `{إيرلندا: Ireland, 2029: 2025}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 554ms | LLM: 2554ms | ER: 0ms | DB: 80ms | **Total: 3190ms**

### ✅ [synth-ar-02] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Speech**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين ٢٠٢٥"
- **WER**: 63.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1150ms | LLM: 2659ms | ER: 0ms | DB: 164ms | **Total: 3975ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Speech**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha, Rali Nchini Ayalandi Mwaka wa 2025"
- **Normalized Transcript (Voice Recovery)**: "Onyesha, Rali Nchini Ireland Mwaka wa 2025"
- **Recovery Mappings**: `{Ayalandi: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1166ms | LLM: 2454ms | ER: 0ms | DB: 90ms | **Total: 3712ms**

### ✅ [synth-sw-02] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Speech**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 727ms | LLM: 3175ms | ER: 0ms | DB: 139ms | **Total: 4044ms**

### ❌ [synth-cy-01] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Speech**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Ralyeni Werdon in 2025"
- **WER**: 66.7% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Werdon, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1384ms | LLM: 2545ms | ER: 45ms | DB: 78ms | **Total: 4056ms**

### ✅ [synth-cy-02] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Speech**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos y chybwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1432ms | LLM: 2148ms | ER: 0ms | DB: 136ms | **Total: 3718ms**

### ❌ [synth-ga-01] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Speech**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: "Tyspine, Rayleigh, Theonatron in 2025."
- **WER**: 66.7% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Tyspine, Rayleigh, Theonatron, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 681ms | LLM: 4086ms | ER: 36ms | DB: 73ms | **Total: 4878ms**

### ❌ [synth-ga-02] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Speech**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: "Tyspain, Boyk-Foynt, Leymanella, Josh Moffett on Moonraker in 2025."
- **WER**: 55.6% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `searchDriverRallies` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_DRIVER_RALLIES, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 912ms | LLM: 5030ms | ER: 0ms | DB: 87ms | **Total: 6031ms**

