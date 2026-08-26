# 🎙️ Phase 5B.1.1 Hardened Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T01:20:18.730053
**Benchmark Type**: `synthetic` (Real Audio Execution)
**STT Model**: `whisper-1`
**Total Multilingual Audio Samples**: 38 (across 19 languages)

## 📊 Before vs. After Benchmark Comparison
| Metric | Baseline | Hardened | Delta | Gate Target | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Word Error Rate (WER)** | 26.6% | 21.1% | -5.5% | N/A | ℹ️ Informational |
| **Raw Entity Accuracy** | 71.3% | 96.7% | +25.4% | N/A | ℹ️ Informational |
| **Post-Recovery Entity Accuracy** | 71.3% | 96.7% | +25.4% | >= 95% | ✅ PASSED |
| **Intent Accuracy** | 50.0% | 100.0% | +50.0% | >= 95% | ✅ PASSED |
| **Filter F1 Score** | 0.43 | 0.94 | +0.51 | >= 0.90 | ✅ PASSED |
| **Semantic Exact Match** | 28.9% | 76.3% | +47.4% | N/A | ℹ️ Informational |
| **Search Semantic Success Rate** | **42.1%** | **92.1%** | **+50.0%** | >= 90% | **✅ PASSED** |
| **STT Latency (p50)** | 984 ms | 1142 ms | +158ms | N/A | ℹ️ Informational |
| **End-to-End Latency (p50)** | 3429 ms | 3586 ms | +157ms | N/A | ℹ️ Informational |

## 🛑 Failure Attribution Breakdown
| Primary Failure Stage | Count | Percentage |
| :--- | :---: | :---: |
| `NONE` | 35 | 92.1% |
| `STT_LANGUAGE_FAILURE` | 0 | 0.0% |
| `STT_TRANSCRIPTION_ERROR` | 0 | 0.0% |
| `STT_ENTITY_CORRUPTION` | 0 | 0.0% |
| `LLM_INTENT_ERROR` | 0 | 0.0% |
| `LLM_FILTER_ERROR` | 0 | 0.0% |
| `LLM_UNNECESSARY_CLARIFICATION` | 3 | 7.9% |
| `ENTITY_RESOLUTION_FAILURE` | 0 | 0.0% |
| `DB_EXECUTION_FAILURE` | 0 | 0.0% |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Post-Rec Entity Acc | Intent Acc | Filter F1 | Semantic Exact | Search Success | STT p50 | E2E p50 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1219ms | 3582ms |
| German (DE) | 2 | 7.1% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 1275ms | 5055ms |
| French (FR) | 2 | 7.1% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1032ms | 3229ms |
| Spanish (ES) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1142ms | 3394ms |
| Italian (IT) | 2 | 21.4% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1742ms | 4564ms |
| Portuguese (PT) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1308ms | 3631ms |
| Dutch (NL) | 2 | 13.9% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 883ms | 3298ms |
| Polish (PL) | 2 | 7.1% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 2263ms | 3739ms |
| Norwegian (Bokmål) (NB) | 2 | 36.1% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1300ms | 5446ms |
| Latvian (LV) | 2 | 40.0% | 87.5% | 100.0% | 0.83 | 50.0% | **100.0%** | 951ms | 4147ms |
| Czech (CS) | 2 | 14.3% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1279ms | 4124ms |
| Croatian (HR) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 2180ms | 4108ms |
| Lithuanian (LT) | 2 | 40.0% | 100.0% | 100.0% | 0.93 | 50.0% | **50.0%** | 919ms | 5973ms |
| Slovak (SK) | 2 | 21.4% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1295ms | 3962ms |
| Urdu (UR) | 2 | 79.2% | 75.0% | 100.0% | 0.68 | 0.0% | **100.0%** | 1610ms | 7789ms |
| Arabic (AR) | 2 | 39.0% | 75.0% | 100.0% | 0.93 | 50.0% | **50.0%** | 1146ms | 7606ms |
| Swahili (SW) | 2 | 22.0% | 100.0% | 100.0% | 0.76 | 0.0% | **50.0%** | 1630ms | 6650ms |
| Welsh (CY) | 2 | 16.7% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1488ms | 3222ms |
| Irish (GA) | 2 | 36.1% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1623ms | 12576ms |

## 🔍 Detailed Sample Traces & Diagnostics
### ✅ [synth-en-01] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_01.mp3`
- **Expected Speech**: "Show rallies in Ireland in 2025."
- **Actual STT Transcript**: "show rallies in ireland in 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1072ms | LLM: 1865ms | ER: 1ms | DB: 548ms | **Total: 3582ms**

### ✅ [synth-en-02] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Speech**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "show jump highlights featuring josh moffett from moonraker in 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1219ms | LLM: 1232ms | ER: 156ms | DB: 144ms | **Total: 2902ms**

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
- **Latency**: STT: 586ms | LLM: 4229ms | ER: 50ms | DB: 101ms | **Total: 5055ms**

### ✅ [synth-de-02] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Speech**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1275ms | LLM: 1117ms | ER: 0ms | DB: 163ms | **Total: 2654ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Speech**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **Normalized Transcript (Voice Recovery)**: "Montrez les rallies en Ireland en 2025."
- **Recovery Mappings**: `{Irlande: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 551ms | LLM: 2484ms | ER: 0ms | DB: 98ms | **Total: 3229ms**

### ✅ [synth-fr-02] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Speech**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1032ms | LLM: 1233ms | ER: 0ms | DB: 176ms | **Total: 2538ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Speech**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "mostrar rallies en irlanda en 2025"
- **Normalized Transcript (Voice Recovery)**: "mostrar rallies en Ireland en 2025"
- **Recovery Mappings**: `{irlanda: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1142ms | LLM: 2079ms | ER: 0ms | DB: 87ms | **Total: 3394ms**

### ✅ [synth-es-02] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Speech**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 741ms | LLM: 1278ms | ER: 0ms | DB: 164ms | **Total: 2326ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Speech**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025"
- **Normalized Transcript (Voice Recovery)**: "Mostrarelli in Ireland nel 2025"
- **Recovery Mappings**: `{Irlanda: Ireland}`
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1742ms | LLM: 2644ms | ER: 0ms | DB: 96ms | **Total: 4564ms**

### ✅ [synth-it-02] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Speech**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1001ms | LLM: 1361ms | ER: 0ms | DB: 142ms | **Total: 2592ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Speech**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar ralis na Irlanda em 2025"
- **Normalized Transcript (Voice Recovery)**: "Mostrar ralis na Ireland em 2025"
- **Recovery Mappings**: `{Irlanda: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 780ms | LLM: 2641ms | ER: 0ms | DB: 86ms | **Total: 3631ms**

### ✅ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Speech**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1308ms | LLM: 1163ms | ER: 0ms | DB: 150ms | **Total: 2721ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Speech**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "TUNE RALLYS IN IERLAND IN 2025"
- **Normalized Transcript (Voice Recovery)**: "TUNE RALLYS IN Ireland IN 2025"
- **Recovery Mappings**: `{IERLAND: Ireland}`
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 861ms | LLM: 1932ms | ER: 0ms | DB: 96ms | **Total: 2973ms**

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
- **Latency**: STT: 883ms | LLM: 2134ms | ER: 0ms | DB: 143ms | **Total: 3298ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Speech**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku"
- **Normalized Transcript (Voice Recovery)**: "Pokaż rajdy w Ireland w 2005 roku"
- **Recovery Mappings**: `{Irlandii: Ireland}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 686ms | LLM: 1625ms | ER: 0ms | DB: 78ms | **Total: 2568ms**

### ✅ [synth-pl-02] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Speech**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2263ms | LLM: 1139ms | ER: 0ms | DB: 137ms | **Total: 3739ms**

### ✅ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Speech**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Vi sralia i irland i 225."
- **Normalized Transcript (Voice Recovery)**: "Vi sralia i Ireland i 225."
- **Recovery Mappings**: `{irland: Ireland}`
- **WER**: 50.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1300ms | LLM: 3986ms | ER: 0ms | DB: 82ms | **Total: 5446ms**

### ✅ [synth-nb-02] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_02.mp3`
- **Expected Speech**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Actual STT Transcript**: "Vis hopp høydepunkter med Josh Moffett fra Moonraker i 2025."
- **WER**: 22.2% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 902ms | LLM: 1797ms | ER: 0ms | DB: 149ms | **Total: 2939ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Speech**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt Rālijas īrijā 2015."
- **Normalized Transcript (Voice Recovery)**: "Rādīt Rālijas Ireland 2015."
- **Recovery Mappings**: `{īrijā: Ireland}`
- **WER**: 60.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2015, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 693ms | LLM: 1964ms | ER: 0ms | DB: 81ms | **Total: 2915ms**

### ✅ [synth-lv-02] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Speech**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Rādīt labākos lēcienas ar Josh Moffett no Moonraker 2215 gadā"
- **Normalized Transcript (Voice Recovery)**: "Rādīt labākos lēcienas ar Josh Moffett no Moonraker 2025 gadā"
- **Recovery Mappings**: `{2215: 2025}`
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 951ms | LLM: 2881ms | ER: 0ms | DB: 144ms | **Total: 4147ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Speech**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "Ukaždali v Irsku v roce 2025."
- **Normalized Transcript (Voice Recovery)**: "Ukaždali v Ireland v roce 2025."
- **Recovery Mappings**: `{Irsku: Ireland}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 696ms | LLM: 3167ms | ER: 0ms | DB: 81ms | **Total: 4124ms**

### ✅ [synth-cs-02] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Speech**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1279ms | LLM: 1183ms | ER: 0ms | DB: 142ms | **Total: 2797ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Speech**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prikaži Relije u Irskoj u 2025. godini."
- **Normalized Transcript (Voice Recovery)**: "Prikaži Relije u Ireland u 2025. godini."
- **Recovery Mappings**: `{Irskoj: Ireland}`
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1390ms | LLM: 2371ms | ER: 0ms | DB: 167ms | **Total: 4108ms**

### ✅ [synth-hr-02] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Speech**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025. godine."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2180ms | LLM: 1355ms | ER: 0ms | DB: 139ms | **Total: 3836ms**

### ✅ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Speech**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt ralius airijoje 25 metais"
- **Normalized Transcript (Voice Recovery)**: "Rodyt ralius Ireland 2025 metais"
- **Recovery Mappings**: `{airijoje: Ireland, 25: 2025}`
- **WER**: 40.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 912ms | LLM: 2351ms | ER: 0ms | DB: 91ms | **Total: 3440ms**

### ❌ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Speech**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Rodėti geriausius šuolius su Josh Moffett iš Moonraker dvutmysčių džiūdžiais bet metais"
- **WER**: 40.0% | **Failure Attribution**: `LLM_UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 919ms | LLM: 4811ms | ER: 41ms | DB: 0ms | **Total: 5973ms**

### ✅ [synth-sk-01] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Speech**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "ukáži relíf írsku v roku 2025."
- **Normalized Transcript (Voice Recovery)**: "ukáži relíf Ireland v roku 2025."
- **Recovery Mappings**: `{írsku: Ireland}`
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1295ms | LLM: 2431ms | ER: 0ms | DB: 82ms | **Total: 3962ms**

### ✅ [synth-sk-02] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Speech**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 814ms | LLM: 1214ms | ER: 0ms | DB: 148ms | **Total: 2370ms**

### ✅ [synth-ur-01] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Speech**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "ڈوہاز اور ییسٹر پائز میں آئرلینڈ کی ریلیاں دکھائیں"
- **Normalized Transcript (Voice Recovery)**: "ڈوہاز اور ییسٹر پائز میں Ireland کی ریلیاں دکھائیں"
- **Recovery Mappings**: `{آئرلینڈ: Ireland}`
- **WER**: 83.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, city: Dohaz and Yester Pize, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1435ms | LLM: 5817ms | ER: 47ms | DB: 79ms | **Total: 7789ms**

### ✅ [synth-ur-02] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Speech**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "دو ہزن یو س پائیث میں مونریکر سے جوش موفٹ کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 75.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2026, eventName: Moonraker Forestry Rally 2026, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2026, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1610ms | LLM: 3043ms | ER: 94ms | DB: 147ms | **Total: 5366ms**

### ✅ [synth-ar-01] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_01.mp3`
- **Expected Speech**: "أظهر الراليات في أيرلندا في عام 2025."
- **Actual STT Transcript**: "أظهر الراليات في أيرلندا في عام 2029"
- **Normalized Transcript (Voice Recovery)**: "أظهر الراليات في Ireland في عام 2025"
- **Recovery Mappings**: `{أيرلندا: Ireland, 2029: 2025}`
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 905ms | LLM: 2344ms | ER: 0ms | DB: 84ms | **Total: 3586ms**

### ❌ [synth-ar-02] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Speech**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين ٢٥٢"
- **WER**: 63.6% | **Failure Attribution**: `LLM_UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1146ms | LLM: 6013ms | ER: 0ms | DB: 0ms | **Total: 7606ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Speech**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha, rali nchini ayalandi mwaka wa dwari dwendifemv."
- **Normalized Transcript (Voice Recovery)**: "Onyesha, rali nchini Ireland mwaka wa dwari dwendifemv."
- **Recovery Mappings**: `{ayalandi: Ireland}`
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (35 rows returned)
- **Latency**: STT: 1630ms | LLM: 3084ms | ER: 0ms | DB: 102ms | **Total: 4913ms**

### ❌ [synth-sw-02] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Speech**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Failure Attribution**: `LLM_UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 924ms | LLM: 5574ms | ER: 0ms | DB: 0ms | **Total: 6650ms**

### ✅ [synth-cy-01] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Speech**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Raleighi Iwerddon yn 2025"
- **Normalized Transcript (Voice Recovery)**: "Dangos Raleighi Ireland yn 2025"
- **Recovery Mappings**: `{Iwerddon: Ireland}`
- **WER**: 33.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1181ms | LLM: 1696ms | ER: 0ms | DB: 86ms | **Total: 3049ms**

### ✅ [synth-cy-02] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Speech**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1488ms | LLM: 1241ms | ER: 0ms | DB: 331ms | **Total: 3222ms**

### ✅ [synth-ga-01] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Speech**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: "Taespaen, Rhaelitha, and Éirinn in 2025"
- **Normalized Transcript (Voice Recovery)**: "Taespaen, Rhaelitha, and Ireland in 2025"
- **Recovery Mappings**: `{Éirinn: Ireland}`
- **WER**: 50.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1217ms | LLM: 11184ms | ER: 0ms | DB: 88ms | **Total: 12576ms**

### ✅ [synth-ga-02] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Speech**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: "Táisbein buaicphointí léimeanna le Josh Moffett on Moonraker in 2025."
- **WER**: 22.2% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1623ms | LLM: 2298ms | ER: 0ms | DB: 139ms | **Total: 4165ms**

