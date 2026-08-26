# 🎙️ Phase 5B.1 Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T00:26:44.069823
**Benchmark Type**: `synthetic` (Real Audio Execution)
**STT Model**: `whisper-1`
**Total Multilingual Audio Samples**: 38 (across 19 languages)

## 📊 Global Aggregate Summary
| Metric | Value |
| :--- | :--- |
| **Word Error Rate (WER)** | 26.6% |
| **Entity Accuracy** | 71.3% |
| **Intent Accuracy** | 50.0% |
| **Filter F1 Score** | 0.43 |
| **Semantic Exact Match** | 28.9% |
| **Search Semantic Success Rate** | **42.1%** |
| **STT Latency (p50 / p95)** | **984ms / 1789ms** |
| **End-to-End Latency (p50 / p95)** | **3429ms / 5136ms** |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Entity Acc | Intent Acc | Filter F1 | Semantic Exact | Search Success | STT p50/p95 | E2E p50/p95 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 50.0% | 0.50 | 50.0% | 50.0% | 1365/1365ms | 2854/2854ms |
| German (DE) | 2 | 14.3% | 92.9% | 0.0% | 0.00 | 0.0% | 0.0% | 1461/1461ms | 4063/4063ms |
| French (FR) | 2 | 7.1% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1065/1065ms | 3210/3210ms |
| Spanish (ES) | 2 | 0.0% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 822/822ms | 2811/2811ms |
| Italian (IT) | 2 | 21.4% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1353/1353ms | 4445/4445ms |
| Portuguese (PT) | 2 | 8.3% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1201/1201ms | 3631/3631ms |
| Dutch (NL) | 2 | 30.6% | 42.9% | 50.0% | 0.50 | 50.0% | 50.0% | 909/909ms | 4062/4062ms |
| Polish (PL) | 2 | 7.1% | 83.3% | 50.0% | 0.33 | 0.0% | 50.0% | 933/933ms | 2210/2210ms |
| Norwegian (Bokmål) (NB) | 2 | 25.0% | 92.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1997/1997ms | 3524/3524ms |
| Latvian (LV) | 2 | 35.0% | 92.9% | 100.0% | 0.76 | 0.0% | 50.0% | 2263/2263ms | 4955/4955ms |
| Czech (CS) | 2 | 7.1% | 83.3% | 50.0% | 0.50 | 50.0% | 50.0% | 714/714ms | 2855/2855ms |
| Croatian (HR) | 2 | 7.1% | 83.3% | 50.0% | 0.50 | 50.0% | 50.0% | 1577/1577ms | 3308/3308ms |
| Lithuanian (LT) | 2 | 55.0% | 42.9% | 50.0% | 0.50 | 50.0% | 50.0% | 1516/1516ms | 6250/6250ms |
| Slovak (SK) | 2 | 14.3% | 33.3% | 50.0% | 0.50 | 50.0% | 50.0% | 985/985ms | 3774/3774ms |
| Urdu (UR) | 2 | 50.0% | 92.9% | 50.0% | 0.25 | 0.0% | 50.0% | 1309/1309ms | 5136/5136ms |
| Arabic (AR) | 2 | 50.6% | 7.1% | 100.0% | 0.76 | 0.0% | 50.0% | 1155/1155ms | 7285/7285ms |
| Swahili (SW) | 2 | 29.1% | 92.9% | 50.0% | 0.33 | 0.0% | 50.0% | 984/984ms | 4877/4877ms |
| Welsh (CY) | 2 | 43.3% | 42.9% | 50.0% | 0.25 | 0.0% | 0.0% | 1789/1789ms | 4614/4614ms |
| Irish (GA) | 2 | 100.0% | 0.0% | 0.0% | 0.00 | 0.0% | 0.0% | 738/738ms | 738/738ms |

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
- **Latency**: STT: 873ms | LLM: 1501ms | ER: 0ms | DB: 456ms | **Total: 2854ms**

### ❌ [synth-en-02] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Speech**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "show jump highlights featuring Josh Moffett from Moonraker in 2025"
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1365ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2815ms**

### ❌ [synth-de-01] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Speech**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeiger Release in Irland im Jahr 2025"
- **WER**: 28.6% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchRallies`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 676ms | LLM: 3381ms | ER: 0ms | DB: 0ms | **Total: 4063ms**

### ❌ [synth-de-02] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Speech**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprunghighlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1461ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3437ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Speech**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **WER**: 14.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 656ms | LLM: 1896ms | ER: 0ms | DB: 107ms | **Total: 2661ms**

### ❌ [synth-fr-02] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Speech**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1065ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3210ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Speech**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "mostrar rallies en Irlanda en 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 751ms | LLM: 1917ms | ER: 0ms | DB: 141ms | **Total: 2811ms**

### ❌ [synth-es-02] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Speech**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 822ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2738ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Speech**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025"
- **WER**: 42.9% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1050ms | LLM: 2634ms | ER: 0ms | DB: 88ms | **Total: 3776ms**

### ❌ [synth-it-02] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Speech**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1353ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4445ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Speech**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar rallies na Irlanda em 2025"
- **WER**: 16.7% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1201ms | LLM: 2339ms | ER: 0ms | DB: 88ms | **Total: 3631ms**

### ❌ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Speech**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 753ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2018ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Speech**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "Tune rallies in Ireland in 2025."
- **WER**: 50.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 664ms | LLM: 3310ms | ER: 0ms | DB: 85ms | **Total: 4062ms**

### ❌ [synth-nl-02] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_02.mp3`
- **Expected Speech**: "Toon spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Actual STT Transcript**: "Doen spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **WER**: 11.1% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 909ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3485ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Speech**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku."
- **WER**: 14.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 599ms | LLM: 1339ms | ER: 0ms | DB: 81ms | **Total: 2023ms**

### ❌ [synth-pl-02] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Speech**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 933ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2210ms**

### ✅ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Speech**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Viss rallye i Irland i 2.25"
- **WER**: 50.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1027ms | LLM: 2401ms | ER: 0ms | DB: 94ms | **Total: 3524ms**

### ❌ [synth-nb-02] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_02.mp3`
- **Expected Speech**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Actual STT Transcript**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1997ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3272ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Speech**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt ralijas īrijā 2015."
- **WER**: 60.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2015, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2015, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 2263ms | LLM: 2610ms | ER: 0ms | DB: 80ms | **Total: 4955ms**

### ❌ [synth-lv-02] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Speech**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2215 gadā!"
- **WER**: 10.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Parsed Filters**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 1303ms | LLM: 2555ms | ER: 41ms | DB: 0ms | **Total: 3903ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Speech**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "UKAZ Rally v Irsku v roce 2025"
- **WER**: 14.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 576ms | LLM: 2177ms | ER: 0ms | DB: 96ms | **Total: 2855ms**

### ❌ [synth-cs-02] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Speech**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 714ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2695ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Speech**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prikaži rallye u Irskoj u 2025. godini."
- **WER**: 14.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1577ms | LLM: 1632ms | ER: 0ms | DB: 96ms | **Total: 3308ms**

### ❌ [synth-hr-02] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Speech**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025 godine."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1404ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3175ms**

### ✅ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Speech**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt ralius eirijoje 25 metais"
- **WER**: 60.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 781ms | LLM: 2361ms | ER: 0ms | DB: 85ms | **Total: 3229ms**

### ❌ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Speech**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Radu digeriausius šuolius su Josh Moffett iš Moonraker dvutmysį dvideusiais bet metais"
- **WER**: 50.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1516ms | LLM: 4732ms | ER: 0ms | DB: 0ms | **Total: 6250ms**

### ✅ [synth-sk-01] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Speech**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "Ukáž Rally v Irsku v roku 2025."
- **WER**: 28.6% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 861ms | LLM: 2810ms | ER: 0ms | DB: 100ms | **Total: 3774ms**

### ❌ [synth-sk-02] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Speech**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 985ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3429ms**

### ✅ [synth-ur-01] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_01.mp3`
- **Expected Speech**: "2025 میں آئرلینڈ کی ریلیاں دکھائیں۔"
- **Actual STT Transcript**: "Doha's and Easter Pies میں آئرلینڈ کی ریلیاں دکھائیں"
- **WER**: 83.3% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, rallyName: Doha's and Easter Pies, country: Ireland, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Doha's and Easter Pies, country: Ireland, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1309ms | LLM: 3706ms | ER: 39ms | DB: 77ms | **Total: 5136ms**

### ❌ [synth-ur-02] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Speech**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "2005 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 16.7% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 844ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2806ms**

### ✅ [synth-ar-01] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_01.mp3`
- **Expected Speech**: "أظهر الراليات في أيرلندا في عام 2025."
- **Actual STT Transcript**: "أظهر الراليات في إيرلندا في عام 2029"
- **WER**: 28.6% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2029, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2029, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1155ms | LLM: 2275ms | ER: 0ms | DB: 85ms | **Total: 3518ms**

### ❌ [synth-ar-02] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Speech**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين هممو عشرين"
- **WER**: 72.7% | **Driver Preserved**: false | **Rally Preserved**: false | **Action Preserved**: true
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Parsed Filters**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 929ms | LLM: 6355ms | ER: 0ms | DB: 0ms | **Total: 7285ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Speech**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Unyesha, Rally Nchini Ayalandi Mwaka wa 2020"
- **WER**: 42.9% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2020, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2020, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 984ms | LLM: 2905ms | ER: 0ms | DB: 84ms | **Total: 3974ms**

### ❌ [synth-sw-02] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Speech**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 876ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4877ms**

### ❌ [synth-cy-01] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Speech**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Rally Anywhere Done in 2025"
- **WER**: 66.7% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Parsed Filters**: `{intent: SEARCH_RALLIES, rallyName: Rally Anywhere Done, year: 2025, limit: 20, offset: 0}`
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Rally Anywhere Done, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1789ms | LLM: 2697ms | ER: 46ms | DB: 80ms | **Total: 4614ms**

### ❌ [synth-cy-02] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Speech**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos y chybwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 20.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1273ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3168ms**

### ❌ [synth-ga-01] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Speech**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: ""
- **WER**: 100.0% | **Driver Preserved**: true | **Rally Preserved**: true | **Action Preserved**: true
- **Parsed Intent**: `null` (Expected: `searchRallies`)
- **Parsed Filters**: `null`
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 738ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 738ms**
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
- **Latency**: STT: 522ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 522ms**
- ⚠️ **Diagnostic Note**: STT Error: Exception: STT HTTP 400: {"error":{"message":"Language 'ga' is not supported.","type":"invalid_request_error","param":"language","code":"unsupported_language"},"usage":{"type":"duration","seconds":0}}

