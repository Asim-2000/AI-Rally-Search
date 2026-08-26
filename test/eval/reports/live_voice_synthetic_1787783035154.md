# 🎙️ Phase 5B.1 Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T00:23:55.166085
**Benchmark Type**: `synthetic` (Real Audio Execution)
**STT Model**: `whisper-1`
**Total Multilingual Audio Samples**: 38 (across 19 languages)

## 📊 Global Aggregate Summary
| Metric | Value |
| :--- | :--- |
| **Word Error Rate (WER)** | 26.6% |
| **Entity Accuracy** | 71.3% |
| **Intent Accuracy** | 52.6% |
| **Filter F1 Score** | 0.46 |
| **Semantic Exact Match** | 31.6% |
| **Search Semantic Success Rate** | **44.7%** |
| **STT Latency (p50 / p95)** | **963ms / 1928ms** |
| **End-to-End Latency (p50 / p95)** | **3417ms / 5385ms** |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Entity Acc | Intent Acc | Filter F1 | Semantic Exact | Search Success | STT p50/p95 | E2E p50/p95 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 50.0% | 0.50 | 50.0% | 50.0% | 1171/1171ms | 3451/3451ms |
| German (DE) | 2 | 14.3% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1508/1508ms | 5485/5485ms |
| French (FR) | 2 | 7.1% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 792/792ms | 2986/2986ms |
| Spanish (ES) | 2 | 0.0% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1382/1382ms | 4920/4920ms |
| Italian (IT) | 2 | 21.4% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1132/1132ms | 2750/2750ms |
| Portuguese (PT) | 2 | 8.3% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 750/750ms | 2104/2104ms |
| Dutch (NL) | 2 | 30.6% | 42.9% | 50.0% | 0.50 | 50.0% | 50.0% | 2170/2170ms | 5385/5385ms |
| Polish (PL) | 2 | 7.1% | 83.3% | 50.0% | 0.33 | 0.0% | 50.0% | 1808/1808ms | 4082/4082ms |
| Norwegian (Bokmål) (NB) | 2 | 25.0% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1159/1159ms | 3746/3746ms |
| Latvian (LV) | 2 | 35.0% | 92.9% | 100.0% | 0.76 | 0.0% | 50.0% | 1928/1928ms | 4147/4147ms |
| Czech (CS) | 2 | 7.1% | 83.3% | 50.0% | 0.50 | 50.0% | 50.0% | 901/901ms | 3146/3146ms |
| Croatian (HR) | 2 | 7.1% | 83.3% | 50.0% | 0.50 | 50.0% | 50.0% | 963/963ms | 3597/3597ms |
| Lithuanian (LT) | 2 | 55.0% | 42.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1049/1049ms | 8573/8573ms |
| Slovak (SK) | 2 | 14.3% | 33.3% | 50.0% | 0.50 | 50.0% | 50.0% | 1159/1159ms | 3921/3921ms |
| Urdu (UR) | 2 | 50.0% | 92.9% | 50.0% | 0.25 | 0.0% | 50.0% | 1472/1472ms | 4911/4911ms |
| Arabic (AR) | 2 | 50.6% | 7.1% | 50.0% | 0.33 | 0.0% | 50.0% | 852/852ms | 5194/5194ms |
| Swahili (SW) | 2 | 29.1% | 92.9% | 100.0% | 0.76 | 0.0% | 50.0% | 1602/1602ms | 4981/4981ms |
| Welsh (CY) | 2 | 43.3% | 42.9% | 50.0% | 0.25 | 0.0% | 0.0% | 2284/2284ms | 4880/4880ms |
| Irish (GA) | 2 | 100.0% | 0.0% | 0.0% | 0.00 | 0.0% | 0.0% | 887/887ms | 888/888ms |

## 🔍 Detailed Sample Traces & Diagnostics
### ✅ [synth-en-01] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_01.mp3`
- **Expected Speech**: "Show rallies in Ireland in 2025."
- **Actual STT Transcript**: "Show rallies in Ireland in 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1143ms | LLM: 1748ms | ER: 1ms | DB: 541ms | **Total: 3451ms**

### ❌ [synth-en-02] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Speech**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "show jump highlights featuring Josh Moffett from Moonraker in 2025"
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1171ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3220ms**

### ✅ [synth-de-01] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Speech**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeiger Release in Irland im Jahr 2025"
- **WER**: 28.6% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1336ms | LLM: 4042ms | ER: 0ms | DB: 104ms | **Total: 5485ms**

### ❌ [synth-de-02] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Speech**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprunghighlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1508ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4231ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Speech**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **WER**: 14.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 754ms | LLM: 2151ms | ER: 0ms | DB: 80ms | **Total: 2986ms**

### ❌ [synth-fr-02] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Speech**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 792ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2177ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Speech**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "mostrar rallies en Irlanda en 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 631ms | LLM: 2524ms | ER: 0ms | DB: 87ms | **Total: 3244ms**

### ❌ [synth-es-02] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Speech**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1382ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4920ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Speech**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025"
- **WER**: 42.9% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1132ms | LLM: 1534ms | ER: 0ms | DB: 81ms | **Total: 2750ms**

### ❌ [synth-it-02] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Speech**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 836ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2035ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Speech**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar rallies na Irlanda em 2025"
- **WER**: 16.7% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 643ms | LLM: 1013ms | ER: 0ms | DB: 76ms | **Total: 1734ms**

### ❌ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Speech**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 750ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2104ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Speech**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "Tune rallies in Ireland in 2025."
- **WER**: 50.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 598ms | LLM: 4696ms | ER: 0ms | DB: 88ms | **Total: 5385ms**

### ❌ [synth-nl-02] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_02.mp3`
- **Expected Speech**: "Toon spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Actual STT Transcript**: "Doen spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **WER**: 11.1% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 2170ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4118ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Speech**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku."
- **WER**: 14.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1808ms | LLM: 2195ms | ER: 0ms | DB: 76ms | **Total: 4082ms**

### ❌ [synth-pl-02] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Speech**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 826ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2395ms**

### ✅ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Speech**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Viss rallye i Irland i 2.25"
- **WER**: 50.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1159ms | LLM: 2496ms | ER: 0ms | DB: 88ms | **Total: 3746ms**

### ❌ [synth-nb-02] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_02.mp3`
- **Expected Speech**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Actual STT Transcript**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1003ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3198ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Speech**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt ralijas īrijā 2015."
- **WER**: 60.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2015, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2015, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1928ms | LLM: 2144ms | ER: 0ms | DB: 73ms | **Total: 4147ms**

### ❌ [synth-lv-02] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Speech**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2215 gadā!"
- **WER**: 10.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Parsed Filters**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 905ms | LLM: 2633ms | ER: 39ms | DB: 0ms | **Total: 3579ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Speech**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "UKAZ Rally v Irsku v roce 2025"
- **WER**: 14.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 759ms | LLM: 1904ms | ER: 0ms | DB: 71ms | **Total: 2735ms**

### ❌ [synth-cs-02] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Speech**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 901ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3146ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Speech**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prikaži rallye u Irskoj u 2025. godini."
- **WER**: 14.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 856ms | LLM: 1764ms | ER: 0ms | DB: 86ms | **Total: 2709ms**

### ❌ [synth-hr-02] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Speech**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025 godine."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 963ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3597ms**

### ✅ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Speech**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt ralius eirijoje 25 metais"
- **WER**: 60.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1049ms | LLM: 2287ms | ER: 0ms | DB: 71ms | **Total: 3408ms**

### ❌ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Speech**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Radu digeriausius šuolius su Josh Moffett iš Moonraker dvutmysį dvideusiais bet metais"
- **WER**: 50.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 762ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 8573ms**

### ✅ [synth-sk-01] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Speech**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "Ukáž Rally v Irsku v roku 2025."
- **WER**: 28.6% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1159ms | LLM: 2148ms | ER: 0ms | DB: 80ms | **Total: 3389ms**

### ❌ [synth-sk-02] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Speech**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 783ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3921ms**

### ✅ [synth-ur-01] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Speech**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "Doha's and Easter Pies میں آئرلینڈ کی ریلیاں دکھائیں"
- **WER**: 83.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, rallyName: Doha's and Easter Pies, country: Ireland, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Doha's and Easter Pies, country: Ireland, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1208ms | LLM: 3591ms | ER: 35ms | DB: 74ms | **Total: 4911ms**

### ❌ [synth-ur-02] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Speech**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "2005 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 16.7% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1472ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3417ms**

### ✅ [synth-ar-01] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_01.mp3`
- **Expected Speech**: "أظهر الراليات في أيرلندا في عام 2025."
- **Actual STT Transcript**: "أظهر الراليات في إيرلندا في عام 2029"
- **WER**: 28.6% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2029, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2029, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 667ms | LLM: 2115ms | ER: 0ms | DB: 75ms | **Total: 2860ms**

### ❌ [synth-ar-02] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Speech**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين هممو عشرين"
- **WER**: 72.7% | **Driver Preserved**: false | **Rally Preserved**: false | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 852ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 5194ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Speech**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Unyesha, Rally Nchini Ayalandi Mwaka wa 2020"
- **WER**: 42.9% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2020, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2020, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1022ms | LLM: 2085ms | ER: 0ms | DB: 75ms | **Total: 3184ms**

### ❌ [synth-sw-02] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Speech**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Parsed Filters**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1602ms | LLM: 3378ms | ER: 0ms | DB: 0ms | **Total: 4981ms**

### ❌ [synth-cy-01] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Speech**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Rally Anywhere Done in 2025"
- **WER**: 66.7% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, rallyName: Rally Anywhere Done, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Rally Anywhere Done, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 665ms | LLM: 3011ms | ER: 89ms | DB: 92ms | **Total: 3859ms**

### ❌ [synth-cy-02] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Speech**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos y chybwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 20.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 2284ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4880ms**

### ❌ [synth-ga-01] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Speech**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: ""
- **WER**: 100.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchRallies`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 351ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 351ms**
- ⚠️ **Diagnostic Note**: STT Error: Exception: STT HTTP 400: {"error":{"message":"Language 'ga' is not supported.","type":"invalid_request_error","param":"language","code":"unsupported_language"},"usage":{"type":"duration","seconds":0}}

### ❌ [synth-ga-02] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Speech**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: ""
- **WER**: 100.0% | **Driver Preserved**: false | **Rally Preserved**: false | **Action Preserved**: false
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 887ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 888ms**
- ⚠️ **Diagnostic Note**: STT Error: Exception: STT HTTP 400: {"error":{"message":"Language 'ga' is not supported.","type":"invalid_request_error","param":"language","code":"unsupported_language"},"usage":{"type":"duration","seconds":0}}

