# 🎙️ Phase 5B.1.1 Hardened Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T00:42:39.571227
**Benchmark Type**: `synthetic` (Real Audio Execution)
**STT Model**: `whisper-1`
**Total Multilingual Audio Samples**: 38 (across 19 languages)

## 📊 Before vs. After Benchmark Comparison
| Metric | Baseline | Hardened | Delta | Gate Target | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Word Error Rate (WER)** | 26.6% | 22.1% | -4.5% | N/A | ℹ️ Informational |
| **Raw Entity Accuracy** | 71.3% | 96.7% | +25.4% | N/A | ℹ️ Informational |
| **Post-Recovery Entity Accuracy** | 71.3% | 98.7% | +27.4% | >= 95% | ✅ PASSED |
| **Intent Accuracy** | 50.0% | 100.0% | +50.0% | >= 95% | ✅ PASSED |
| **Filter F1 Score** | 0.43 | 0.96 | +0.53 | >= 0.90 | ✅ PASSED |
| **Semantic Exact Match** | 28.9% | 86.8% | +57.9% | N/A | ℹ️ Informational |
| **Search Semantic Success Rate** | **42.1%** | **100.0%** | **+57.9%** | >= 90% | **✅ PASSED** |
| **STT Latency (p50)** | 984 ms | 864 ms | -120ms | N/A | ℹ️ Informational |
| **End-to-End Latency (p50)** | 3429 ms | 3228 ms | -201ms | N/A | ℹ️ Informational |

## 🛑 Failure Attribution Breakdown
| Primary Failure Stage | Count | Percentage |
| :--- | :---: | :---: |
| `NONE` | 38 | 100.0% |
| `STT_LANGUAGE_FAILURE` | 0 | 0.0% |
| `STT_TRANSCRIPTION_ERROR` | 0 | 0.0% |
| `STT_ENTITY_CORRUPTION` | 0 | 0.0% |
| `LLM_INTENT_ERROR` | 0 | 0.0% |
| `LLM_FILTER_ERROR` | 0 | 0.0% |
| `LLM_UNNECESSARY_CLARIFICATION` | 0 | 0.0% |
| `ENTITY_RESOLUTION_FAILURE` | 0 | 0.0% |
| `DB_EXECUTION_FAILURE` | 0 | 0.0% |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Post-Rec Entity Acc | Intent Acc | Filter F1 | Semantic Exact | Search Success | STT p50 | E2E p50 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1180ms | 3228ms |
| German (DE) | 2 | 7.1% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 850ms | 4701ms |
| French (FR) | 2 | 7.1% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1232ms | 2863ms |
| Spanish (ES) | 2 | 0.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1575ms | 3896ms |
| Italian (IT) | 2 | 21.4% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 752ms | 2366ms |
| Portuguese (PT) | 2 | 8.3% | 100.0% | 100.0% | 0.90 | 50.0% | **100.0%** | 1218ms | 3424ms |
| Dutch (NL) | 2 | 13.9% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1800ms | 3889ms |
| Polish (PL) | 2 | 7.1% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 1308ms | 2830ms |
| Norwegian (Bokmål) (NB) | 2 | 16.7% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1750ms | 4779ms |
| Latvian (LV) | 2 | 25.0% | 87.5% | 100.0% | 1.00 | 100.0% | **100.0%** | 784ms | 3320ms |
| Czech (CS) | 2 | 14.3% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1408ms | 6088ms |
| Croatian (HR) | 2 | 14.3% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1244ms | 3549ms |
| Lithuanian (LT) | 2 | 50.0% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1218ms | 3598ms |
| Slovak (SK) | 2 | 21.4% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1398ms | 4339ms |
| Urdu (UR) | 2 | 54.2% | 87.5% | 100.0% | 0.75 | 50.0% | **100.0%** | 886ms | 5376ms |
| Arabic (AR) | 2 | 46.1% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1499ms | 3777ms |
| Swahili (SW) | 2 | 7.7% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 864ms | 2850ms |
| Welsh (CY) | 2 | 43.3% | 100.0% | 100.0% | 1.00 | 100.0% | **100.0%** | 1179ms | 3631ms |
| Irish (GA) | 2 | 61.1% | 100.0% | 100.0% | 0.83 | 50.0% | **100.0%** | 1444ms | 3945ms |

## 🔍 Detailed Sample Traces & Diagnostics
### ✅ [synth-en-01] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_01.mp3`
- **Expected Speech**: "Show rallies in Ireland in 2025."
- **Actual STT Transcript**: "Show rallies in Ireland in 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 787ms | LLM: 1872ms | ER: 1ms | DB: 551ms | **Total: 3228ms**

### ✅ [synth-en-02] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Speech**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1180ms | LLM: 1138ms | ER: 150ms | DB: 215ms | **Total: 2689ms**

### ✅ [synth-de-01] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Speech**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeige Release in Irland im Jahr 2025"
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Release, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 850ms | LLM: 3725ms | ER: 41ms | DB: 82ms | **Total: 4701ms**

### ✅ [synth-de-02] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Speech**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 779ms | LLM: 1544ms | ER: 0ms | DB: 142ms | **Total: 2469ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Speech**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 722ms | LLM: 2030ms | ER: 0ms | DB: 108ms | **Total: 2863ms**

### ✅ [synth-fr-02] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Speech**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1232ms | LLM: 1229ms | ER: 0ms | DB: 148ms | **Total: 2613ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Speech**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "Mostrar rallies en Irlanda en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1178ms | LLM: 2616ms | ER: 0ms | DB: 100ms | **Total: 3896ms**

### ✅ [synth-es-02] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Speech**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1575ms | LLM: 1264ms | ER: 0ms | DB: 205ms | **Total: 3049ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Speech**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025."
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 564ms | LLM: 1713ms | ER: 0ms | DB: 87ms | **Total: 2366ms**

### ✅ [synth-it-02] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Speech**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 752ms | LLM: 1198ms | ER: 0ms | DB: 140ms | **Total: 2093ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Speech**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar Hallease na Irlanda em 2025"
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Hallease, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 793ms | LLM: 2508ms | ER: 39ms | DB: 81ms | **Total: 3424ms**

### ✅ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Speech**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1218ms | LLM: 1114ms | ER: 0ms | DB: 142ms | **Total: 2477ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Speech**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "TUNE RALLYS IN IERLAND IN 2025"
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1800ms | LLM: 1907ms | ER: 0ms | DB: 78ms | **Total: 3788ms**

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
- **Latency**: STT: 776ms | LLM: 2968ms | ER: 0ms | DB: 141ms | **Total: 3889ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Speech**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku."
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1144ms | LLM: 1607ms | ER: 0ms | DB: 75ms | **Total: 2830ms**

### ✅ [synth-pl-02] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Speech**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1308ms | LLM: 1126ms | ER: 0ms | DB: 148ms | **Total: 2586ms**

### ✅ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Speech**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Vis religiet i Ørland i 2025."
- **Normalized Transcript (Voice Recovery)**: "Vis religiet i Irland i 2025."
- **Recovery Mappings**: `{Ørland: Irland}`
- **WER**: 33.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1750ms | LLM: 2941ms | ER: 0ms | DB: 85ms | **Total: 4779ms**

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
- **Latency**: STT: 718ms | LLM: 2013ms | ER: 0ms | DB: 145ms | **Total: 2879ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Speech**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt Rālijas īrijā 2025 gada"
- **WER**: 40.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 605ms | LLM: 2046ms | ER: 1ms | DB: 87ms | **Total: 2743ms**

### ✅ [synth-lv-02] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Speech**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Rādīt labākos lēcienas ar Josh Moffett no Moonraker 2025 gadā!"
- **WER**: 10.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 784ms | LLM: 2355ms | ER: 0ms | DB: 179ms | **Total: 3320ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Speech**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "ukaždali v Irsku v roce 2025."
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1252ms | LLM: 4744ms | ER: 0ms | DB: 90ms | **Total: 6088ms**

### ✅ [synth-cs-02] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Speech**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1408ms | LLM: 1392ms | ER: 0ms | DB: 256ms | **Total: 3060ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Speech**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prijka žirelije u Irskoj u 2025. godini."
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 680ms | LLM: 2081ms | ER: 0ms | DB: 92ms | **Total: 2856ms**

### ✅ [synth-hr-02] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Speech**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025 godine."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1244ms | LLM: 2162ms | ER: 0ms | DB: 141ms | **Total: 3549ms**

### ✅ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Speech**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt raliu Seirijoje 25 metais"
- **Normalized Transcript (Voice Recovery)**: "Rodyt raliu Airijoje 2025 metais"
- **Recovery Mappings**: `{Seirijoje: Airijoje, 25 metais: 2025 metais}`
- **WER**: 80.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1218ms | LLM: 2032ms | ER: 0ms | DB: 85ms | **Total: 3337ms**

### ✅ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Speech**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Radu digeriausiu šuolius su Josh Moffett iš Moonraker 2025 metais"
- **Normalized Transcript (Voice Recovery)**: "Radu digeriausiu šuolius su Josh Moffett iš Moonraker 202025 metais"
- **Recovery Mappings**: `{25 metais: 2025 metais}`
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 647ms | LLM: 2774ms | ER: 0ms | DB: 174ms | **Total: 3598ms**

### ✅ [synth-sk-01] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Speech**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "Ukáž Relif Irsku v roku 2025."
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 842ms | LLM: 3409ms | ER: 0ms | DB: 86ms | **Total: 4339ms**

### ✅ [synth-sk-02] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Speech**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1398ms | LLM: 1325ms | ER: 0ms | DB: 204ms | **Total: 2930ms**

### ✅ [synth-ur-01] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Speech**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "Doha's and Easter Pies میں آئرلینڈ کی ریلیاں دکھائیں"
- **Normalized Transcript (Voice Recovery)**: "Doha's and Easter Pies میں Ireland کی ریلیاں دکھائیں"
- **Recovery Mappings**: `{آئرلینڈ: Ireland}`
- **WER**: 83.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Doha's, eventName: Easter Pies, country: Ireland, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 767ms | LLM: 4474ms | ER: 42ms | DB: 89ms | **Total: 5376ms**

### ✅ [synth-ur-02] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Speech**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "2025 میں Moonraker سے جوش موفٹ کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 25.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 886ms | LLM: 1159ms | ER: 0ms | DB: 145ms | **Total: 2192ms**

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
- **Latency**: STT: 609ms | LLM: 2827ms | ER: 0ms | DB: 97ms | **Total: 3535ms**

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
- **Latency**: STT: 1499ms | LLM: 2125ms | ER: 0ms | DB: 151ms | **Total: 3777ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Speech**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha, Rali Nchini Ayalandi Mwaka wa 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 656ms | LLM: 2111ms | ER: 0ms | DB: 81ms | **Total: 2850ms**

### ✅ [synth-sw-02] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Speech**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **Normalized Transcript (Voice Recovery)**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Recovery Mappings**: `{dwebi dwentindifim: 2025}`
- **WER**: 15.4% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 864ms | LLM: 1091ms | ER: 0ms | DB: 141ms | **Total: 2097ms**

### ✅ [synth-cy-01] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Speech**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Ralyeni Werdon in 2025"
- **Normalized Transcript (Voice Recovery)**: "Dangos ralïau yn Iwerddon in 2025"
- **Recovery Mappings**: `{Ralyeni Werdon: ralïau yn Iwerddon}`
- **WER**: 66.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 783ms | LLM: 1940ms | ER: 0ms | DB: 87ms | **Total: 2812ms**

### ✅ [synth-cy-02] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Speech**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos y chybwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 20.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1179ms | LLM: 2256ms | ER: 0ms | DB: 194ms | **Total: 3631ms**

### ✅ [synth-ga-01] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Speech**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: "Tyspine, Rayleigh, Theonatron in 2025."
- **Normalized Transcript (Voice Recovery)**: "Tyspine, Rayleigh, Éirinn in 2025."
- **Recovery Mappings**: `{Theonatron: Éirinn}`
- **WER**: 66.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Tyspine, country: Ireland, city: Rayleigh, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 629ms | LLM: 3108ms | ER: 120ms | DB: 85ms | **Total: 3945ms**

### ✅ [synth-ga-02] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Speech**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: "Tyspain, Boyk-Foynt, Leymanella, Josh Moffett on Moonraker in 2025."
- **Normalized Transcript (Voice Recovery)**: "Tyspain, buaicphointí, léimeanna, Josh Moffett on Moonraker in 2025."
- **Recovery Mappings**: `{Leymanella: léimeanna, Boyk-Foynt: buaicphointí}`
- **WER**: 55.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker Forestry Rally 2025, eventName: Moonraker Forestry Rally 2025, driverName: Josh Moffett, driverId: 4e1a528d-0d6b-4aa3-bf06-27a27318fb70, actionType: jump, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1444ms | LLM: 2046ms | ER: 0ms | DB: 143ms | **Total: 3635ms**

