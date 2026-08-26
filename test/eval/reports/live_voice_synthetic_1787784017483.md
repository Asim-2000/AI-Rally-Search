# 🎙️ Phase 5B.1.1 Hardened Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T00:40:17.501824
**Benchmark Type**: `synthetic` (Real Audio Execution)
**STT Model**: `whisper-1`
**Total Multilingual Audio Samples**: 38 (across 19 languages)

## 📊 Before vs. After Benchmark Comparison
| Metric | Baseline | Hardened | Delta | Gate Target | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Word Error Rate (WER)** | 26.6% | 22.3% | -4.3% | N/A | ℹ️ Informational |
| **Raw Entity Accuracy** | 71.3% | 96.7% | +25.4% | N/A | ℹ️ Informational |
| **Post-Recovery Entity Accuracy** | 71.3% | 98.0% | +26.7% | >= 95% | ✅ PASSED |
| **Intent Accuracy** | 50.0% | 97.4% | +47.4% | >= 95% | ✅ PASSED |
| **Filter F1 Score** | 0.43 | 0.91 | +0.48 | >= 0.90 | ✅ PASSED |
| **Semantic Exact Match** | 28.9% | 73.7% | +44.8% | N/A | ℹ️ Informational |
| **Search Semantic Success Rate** | **42.1%** | **84.2%** | **+42.1%** | >= 90% | **❌ FAILED** |
| **STT Latency (p50)** | 984 ms | 889 ms | -95ms | N/A | ℹ️ Informational |
| **End-to-End Latency (p50)** | 3429 ms | 3191 ms | -238ms | N/A | ℹ️ Informational |

## 🛑 Failure Attribution Breakdown
| Primary Failure Stage | Count | Percentage |
| :--- | :---: | :---: |
| `NONE` | 32 | 84.2% |
| `STT_LANGUAGE_FAILURE` | 0 | 0.0% |
| `STT_TRANSCRIPTION_ERROR` | 0 | 0.0% |
| `STT_ENTITY_CORRUPTION` | 0 | 0.0% |
| `LLM_INTENT_ERROR` | 1 | 2.6% |
| `LLM_FILTER_ERROR` | 4 | 10.5% |
| `LLM_UNNECESSARY_CLARIFICATION` | 1 | 2.6% |
| `ENTITY_RESOLUTION_FAILURE` | 0 | 0.0% |
| `DB_EXECUTION_FAILURE` | 0 | 0.0% |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Post-Rec Entity Acc | Intent Acc | Filter F1 | Semantic Exact | Search Success | STT p50 | E2E p50 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 859ms | 3148ms |
| German (DE) | 2 | 7.1% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 709ms | 3632ms |
| French (FR) | 2 | 7.1% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1163ms | 3326ms |
| Spanish (ES) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1283ms | 2626ms |
| Italian (IT) | 2 | 21.4% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1317ms | 3342ms |
| Portuguese (PT) | 2 | 8.3% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 1262ms | 2815ms |
| Dutch (NL) | 2 | 13.9% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 996ms | 3555ms |
| Polish (PL) | 2 | 7.1% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 1277ms | 2688ms |
| Norwegian (Bokmål) (NB) | 2 | 16.7% | 100.0% | 100.0% | 0.75 | 50.0% | **50.0%** | 1125ms | 3505ms |
| Latvian (LV) | 2 | 30.0% | 87.5% | 100.0% | 1.00 | 100.0% | **100.0%** | 837ms | 3086ms |
| Czech (CS) | 2 | 14.3% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 862ms | 4401ms |
| Croatian (HR) | 2 | 14.3% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1948ms | 4757ms |
| Lithuanian (LT) | 2 | 50.0% | 100.0% | 100.0% | 0.75 | 50.0% | **50.0%** | 1262ms | 3725ms |
| Slovak (SK) | 2 | 21.4% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1074ms | 3326ms |
| Urdu (UR) | 2 | 54.2% | 87.5% | 100.0% | 0.75 | 50.0% | **100.0%** | 1544ms | 5764ms |
| Arabic (AR) | 2 | 46.1% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 967ms | 3227ms |
| Swahili (SW) | 2 | 7.7% | 100.0% | 100.0% | 0.93 | 50.0% | **50.0%** | 1275ms | 3743ms |
| Welsh (CY) | 2 | 43.3% | 100.0% | 100.0% | 0.75 | 50.0% | **50.0%** | 648ms | 6018ms |
| Irish (GA) | 2 | 61.1% | 87.5% | 50.0% | 0.68 | 0.0% | **0.0%** | 1048ms | 8322ms |

## 🔍 Detailed Sample Traces & Diagnostics
### ✅ [synth-en-01] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_01.mp3`
- **Expected Speech**: "Show rallies in Ireland in 2025."
- **Actual STT Transcript**: "Show rallies in Ireland in 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 859ms | LLM: 1716ms | ER: 1ms | DB: 549ms | **Total: 3148ms**

### ✅ [synth-en-02] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Speech**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 734ms | LLM: 1289ms | ER: 145ms | DB: 156ms | **Total: 2329ms**

### ✅ [synth-de-01] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Speech**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeige Release in Irland im Jahr 2025"
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Release, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 634ms | LLM: 2873ms | ER: 39ms | DB: 83ms | **Total: 3632ms**

### ✅ [synth-de-02] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Speech**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 709ms | LLM: 1332ms | ER: 0ms | DB: 153ms | **Total: 2197ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Speech**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1163ms | LLM: 2058ms | ER: 0ms | DB: 102ms | **Total: 3326ms**

### ✅ [synth-fr-02] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Speech**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 712ms | LLM: 1399ms | ER: 0ms | DB: 144ms | **Total: 2257ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Speech**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "Mostrar rallies en Irlanda en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1057ms | LLM: 1335ms | ER: 0ms | DB: 91ms | **Total: 2485ms**

### ✅ [synth-es-02] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Speech**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1283ms | LLM: 1152ms | ER: 0ms | DB: 188ms | **Total: 2626ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Speech**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025."
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 761ms | LLM: 2487ms | ER: 0ms | DB: 91ms | **Total: 3342ms**

### ✅ [synth-it-02] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Speech**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1317ms | LLM: 1379ms | ER: 0ms | DB: 144ms | **Total: 2843ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Speech**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar Hallease na Irlanda em 2025"
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Hallease, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 568ms | LLM: 1986ms | ER: 40ms | DB: 91ms | **Total: 2689ms**

### ✅ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Speech**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1262ms | LLM: 1403ms | ER: 0ms | DB: 146ms | **Total: 2815ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Speech**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "TUNE RALLYS IN IERLAND IN 2025"
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 889ms | LLM: 2569ms | ER: 0ms | DB: 94ms | **Total: 3555ms**

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
- **Latency**: STT: 996ms | LLM: 2302ms | ER: 0ms | DB: 140ms | **Total: 3440ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Speech**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku."
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1277ms | LLM: 1315ms | ER: 0ms | DB: 93ms | **Total: 2688ms**

### ✅ [synth-pl-02] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Speech**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 668ms | LLM: 1091ms | ER: 0ms | DB: 161ms | **Total: 1924ms**

### ❌ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Speech**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Vis religiet i Ørland i 2025."
- **WER**: 33.3% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, city: Ørland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 695ms | LLM: 2552ms | ER: 130ms | DB: 89ms | **Total: 3470ms**

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
- **Latency**: STT: 1125ms | LLM: 2200ms | ER: 0ms | DB: 177ms | **Total: 3505ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Speech**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt Rālijas īrijā 2025 gada"
- **WER**: 40.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 837ms | LLM: 1974ms | ER: 0ms | DB: 100ms | **Total: 2914ms**

### ✅ [synth-lv-02] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Speech**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Radīt labākos lēcienas ar Josh Moffett no Moonraker 2025 gadā!"
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 768ms | LLM: 2176ms | ER: 0ms | DB: 140ms | **Total: 3086ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Speech**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "ukaždali v Irsku v roce 2025."
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 666ms | LLM: 3641ms | ER: 0ms | DB: 90ms | **Total: 4401ms**

### ✅ [synth-cs-02] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Speech**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 862ms | LLM: 1292ms | ER: 0ms | DB: 142ms | **Total: 2300ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Speech**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prijka žirelije u Irskoj u 2025. godini."
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1948ms | LLM: 2469ms | ER: 0ms | DB: 91ms | **Total: 4509ms**

### ✅ [synth-hr-02] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Speech**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025 godine."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1325ms | LLM: 3279ms | ER: 0ms | DB: 150ms | **Total: 4757ms**

### ❌ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Speech**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt raliu Seirijoje 25 metais"
- **WER**: 80.0% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, city: Seirijai, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 575ms | LLM: 2622ms | ER: 445ms | DB: 79ms | **Total: 3725ms**

### ✅ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Speech**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Radu digeriausiu šuolius su Josh Moffett iš Moonraker 2025 metais"
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1262ms | LLM: 1776ms | ER: 0ms | DB: 145ms | **Total: 3188ms**

### ✅ [synth-sk-01] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Speech**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "Ukáž Relif Irsku v roku 2025."
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1074ms | LLM: 2140ms | ER: 0ms | DB: 107ms | **Total: 3326ms**

### ✅ [synth-sk-02] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Speech**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 804ms | LLM: 1883ms | ER: 0ms | DB: 142ms | **Total: 2833ms**

### ✅ [synth-ur-01] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Speech**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "Doha's and Easter Pies میں آئرلینڈ کی ریلیاں دکھائیں"
- **Normalized Transcript (Voice Recovery)**: "Doha's and Easter Pies میں Ireland کی ریلیاں دکھائیں"
- **Recovery Mappings**: `{آئرلینڈ: Ireland}`
- **WER**: 83.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Doha's and Easter Pies, country: Ireland, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1326ms | LLM: 4311ms | ER: 39ms | DB: 82ms | **Total: 5764ms**

### ✅ [synth-ur-02] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Speech**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "2025 میں Moonraker سے جوش موفٹ کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 25.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1544ms | LLM: 1464ms | ER: 0ms | DB: 180ms | **Total: 3191ms**

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
- **Latency**: STT: 741ms | LLM: 1899ms | ER: 0ms | DB: 88ms | **Total: 2730ms**

### ✅ [synth-ar-02] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Speech**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين ٢٠٢٥"
- **Normalized Transcript (Voice Recovery)**: "أظهر لقطات القفزات المميزة لJosh Moffett من Moonraker في عين ٢٠٢٥"
- **Recovery Mappings**: `{جوش موفت: Josh Moffett, مون ريكر: Moonraker}`
- **WER**: 63.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 967ms | LLM: 2114ms | ER: 0ms | DB: 143ms | **Total: 3227ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Speech**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha, Rali Nchini Ayalandi Mwaka wa 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1038ms | LLM: 1910ms | ER: 0ms | DB: 88ms | **Total: 3039ms**

### ❌ [synth-sw-02] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Speech**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Failure Attribution**: `LLM_UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1275ms | LLM: 2424ms | ER: 42ms | DB: 0ms | **Total: 3743ms**

### ❌ [synth-cy-01] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Speech**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Ralyeni Werdon in 2025"
- **WER**: 66.7% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Werdon, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 647ms | LLM: 5254ms | ER: 38ms | DB: 78ms | **Total: 6018ms**

### ✅ [synth-cy-02] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Speech**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos y chybwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 648ms | LLM: 2337ms | ER: 0ms | DB: 144ms | **Total: 3132ms**

### ❌ [synth-ga-01] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Speech**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: "Tyspine, Rayleigh, Theonatron in 2025."
- **WER**: 66.7% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Tyspine, Rayleigh, Theonatron, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 683ms | LLM: 3529ms | ER: 64ms | DB: 194ms | **Total: 4473ms**

### ❌ [synth-ga-02] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Speech**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: "Tyspain, Boyk-Foynt, Leymanella, Josh Moffett on Moonraker in 2025."
- **WER**: 55.6% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `searchDriverRallies` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_DRIVER_RALLIES, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1048ms | LLM: 7172ms | ER: 0ms | DB: 99ms | **Total: 8322ms**

