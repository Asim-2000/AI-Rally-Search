# 🎙️ Phase 5B.1.1 Hardened Live Voice Search Benchmark Report (SYNTHETIC)
**Generated**: 2026-08-27T00:37:21.556291
**Benchmark Type**: `synthetic` (Real Audio Execution)
**STT Model**: `whisper-1`
**Total Multilingual Audio Samples**: 38 (across 19 languages)

## 📊 Before vs. After Benchmark Comparison
| Metric | Baseline | Hardened | Delta | Gate Target | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Word Error Rate (WER)** | 26.6% | 22.9% | -3.7% | N/A | ℹ️ Informational |
| **Raw Entity Accuracy** | 71.3% | 96.7% | +25.4% | N/A | ℹ️ Informational |
| **Post-Recovery Entity Accuracy** | 71.3% | 98.0% | +26.7% | >= 95% | ✅ PASSED |
| **Intent Accuracy** | 50.0% | 52.6% | +2.6% | >= 95% | ❌ FAILED |
| **Filter F1 Score** | 0.43 | 0.44 | +0.01 | >= 0.90 | ❌ FAILED |
| **Semantic Exact Match** | 28.9% | 28.9% | +0.0% | N/A | ℹ️ Informational |
| **Search Semantic Success Rate** | **42.1%** | **39.5%** | **-2.6%** | >= 90% | **❌ FAILED** |
| **STT Latency (p50)** | 984 ms | 982 ms | -2ms | N/A | ℹ️ Informational |
| **End-to-End Latency (p50)** | 3429 ms | 3604 ms | +175ms | N/A | ℹ️ Informational |

## 🛑 Failure Attribution Breakdown
| Primary Failure Stage | Count | Percentage |
| :--- | :---: | :---: |
| `NONE` | 15 | 39.5% |
| `STT_LANGUAGE_FAILURE` | 0 | 0.0% |
| `STT_TRANSCRIPTION_ERROR` | 0 | 0.0% |
| `STT_ENTITY_CORRUPTION` | 0 | 0.0% |
| `LLM_INTENT_ERROR` | 18 | 47.4% |
| `LLM_FILTER_ERROR` | 4 | 10.5% |
| `LLM_UNNECESSARY_CLARIFICATION` | 1 | 2.6% |
| `ENTITY_RESOLUTION_FAILURE` | 0 | 0.0% |
| `DB_EXECUTION_FAILURE` | 0 | 0.0% |

## 🌍 Per-Language Diagnostics (All 19 Supported Languages)
| Language | Samples | WER | Post-Rec Entity Acc | Intent Acc | Filter F1 | Semantic Exact | Search Success | STT p50 | E2E p50 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| English (EN) | 2 | 0.0% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 912ms | 2545ms |
| German (DE) | 2 | 7.1% | 100.0% | 50.0% | 0.40 | 0.0% | **50.0%** | 1456ms | 4329ms |
| French (FR) | 2 | 7.1% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 1182ms | 3275ms |
| Spanish (ES) | 2 | 0.0% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 741ms | 5249ms |
| Italian (IT) | 2 | 21.4% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 1358ms | 3219ms |
| Portuguese (PT) | 2 | 8.3% | 100.0% | 50.0% | 0.40 | 0.0% | **50.0%** | 1242ms | 3207ms |
| Dutch (NL) | 2 | 13.9% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 1212ms | 3762ms |
| Polish (PL) | 2 | 7.1% | 100.0% | 50.0% | 0.33 | 0.0% | **50.0%** | 812ms | 2702ms |
| Norwegian (Bokmål) (NB) | 2 | 16.7% | 100.0% | 50.0% | 0.25 | 0.0% | **0.0%** | 711ms | 4843ms |
| Latvian (LV) | 2 | 40.0% | 87.5% | 50.0% | 0.50 | 50.0% | **50.0%** | 1438ms | 3675ms |
| Czech (CS) | 2 | 14.3% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 1377ms | 5130ms |
| Croatian (HR) | 2 | 14.3% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 2289ms | 4314ms |
| Lithuanian (LT) | 2 | 50.0% | 100.0% | 50.0% | 0.25 | 0.0% | **0.0%** | 1317ms | 4150ms |
| Slovak (SK) | 2 | 21.4% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 982ms | 3459ms |
| Urdu (UR) | 2 | 54.2% | 87.5% | 50.0% | 0.25 | 0.0% | **50.0%** | 1396ms | 5400ms |
| Arabic (AR) | 2 | 46.1% | 100.0% | 50.0% | 0.50 | 50.0% | **50.0%** | 1430ms | 3623ms |
| Swahili (SW) | 2 | 7.7% | 100.0% | 100.0% | 0.93 | 50.0% | **50.0%** | 860ms | 3746ms |
| Welsh (CY) | 2 | 43.3% | 100.0% | 50.0% | 0.25 | 0.0% | **0.0%** | 1319ms | 6082ms |
| Irish (GA) | 2 | 61.1% | 87.5% | 50.0% | 0.25 | 0.0% | **0.0%** | 1529ms | 8285ms |

## 🔍 Detailed Sample Traces & Diagnostics
### ✅ [synth-en-01] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_01.mp3`
- **Expected Speech**: "Show rallies in Ireland in 2025."
- **Actual STT Transcript**: "Show rallies in Ireland in 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 732ms | LLM: 1291ms | ER: 0ms | DB: 508ms | **Total: 2545ms**

### ❌ [synth-en-02] English (`en-GB`)
- **Audio File**: `test/eval/audio/synthetic/en_02.mp3`
- **Expected Speech**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **Actual STT Transcript**: "Show jump highlights featuring Josh Moffett from Moonraker in 2025."
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 912ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2250ms**

### ✅ [synth-de-01] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_01.mp3`
- **Expected Speech**: "Zeige Rallyes in Irland im Jahr 2025."
- **Actual STT Transcript**: "Zeige Release in Irland im Jahr 2025"
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Release, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1065ms | LLM: 3138ms | ER: 44ms | DB: 78ms | **Total: 4329ms**

### ❌ [synth-de-02] German (`de-DE`)
- **Audio File**: `test/eval/audio/synthetic/de_02.mp3`
- **Expected Speech**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **Actual STT Transcript**: "Zeige Sprung-Highlights mit Josh Moffett von der Moonraker im Jahr 2025."
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1456ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2759ms**

### ✅ [synth-fr-01] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_01.mp3`
- **Expected Speech**: "Montrez les rallyes en Irlande en 2025."
- **Actual STT Transcript**: "Montrez les rallies en Irlande en 2025."
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1182ms | LLM: 1999ms | ER: 0ms | DB: 90ms | **Total: 3275ms**

### ❌ [synth-fr-02] French (`fr-FR`)
- **Audio File**: `test/eval/audio/synthetic/fr_02.mp3`
- **Expected Speech**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **Actual STT Transcript**: "Montrez les meilleurs sauts de Josh Moffett au Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 987ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2266ms**

### ✅ [synth-es-01] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_01.mp3`
- **Expected Speech**: "Mostrar rallies en Irlanda en 2025."
- **Actual STT Transcript**: "Mostrar rallies en Irlanda en 2025."
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 535ms | LLM: 4638ms | ER: 0ms | DB: 74ms | **Total: 5249ms**

### ❌ [synth-es-02] Spanish (`es-ES`)
- **Audio File**: `test/eval/audio/synthetic/es_02.mp3`
- **Expected Speech**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **Actual STT Transcript**: "Mostrar momentos destacados de saltos con Josh Moffett de Moonraker en 2025."
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 741ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3127ms**

### ✅ [synth-it-01] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_01.mp3`
- **Expected Speech**: "Mostra i rally in Irlanda nel 2025."
- **Actual STT Transcript**: "Mostrarelli in Irlanda nel 2025."
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 890ms | LLM: 2241ms | ER: 0ms | DB: 85ms | **Total: 3219ms**

### ❌ [synth-it-02] Italian (`it-IT`)
- **Audio File**: `test/eval/audio/synthetic/it_02.mp3`
- **Expected Speech**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025."
- **Actual STT Transcript**: "Mostra i salti migliori di Josh Moffett al Moonraker nel 2025"
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1358ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2552ms**

### ✅ [synth-pt-01] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_01.mp3`
- **Expected Speech**: "Mostrar ralis na Irlanda em 2025."
- **Actual STT Transcript**: "Mostrar Hallease na Irlanda em 2025"
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Hallease, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 655ms | LLM: 2437ms | ER: 38ms | DB: 74ms | **Total: 3207ms**

### ❌ [synth-pt-02] Portuguese (`pt-PT`)
- **Audio File**: `test/eval/audio/synthetic/pt_02.mp3`
- **Expected Speech**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025."
- **Actual STT Transcript**: "Mostrar destaques de saltos com Josh Moffett no Moonraker em 2025"
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1242ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2793ms**

### ✅ [synth-nl-01] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_01.mp3`
- **Expected Speech**: "Toon rally's in Ierland in 2025."
- **Actual STT Transcript**: "TUNE RALLYS IN IERLAND IN 2025"
- **WER**: 16.7% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 1212ms | LLM: 2478ms | ER: 0ms | DB: 71ms | **Total: 3762ms**

### ❌ [synth-nl-02] Dutch (`nl-NL`)
- **Audio File**: `test/eval/audio/synthetic/nl_02.mp3`
- **Expected Speech**: "Toon spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Actual STT Transcript**: "Doen spronghoogtepunten met Josh Moffett van Moonraker in 2025."
- **Normalized Transcript (Voice Recovery)**: "Doen sprong hoogtepunten met Josh Moffett van Moonraker in 2025."
- **Recovery Mappings**: `{spronghoogtepunten: sprong hoogtepunten}`
- **WER**: 11.1% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 706ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3407ms**

### ✅ [synth-pl-01] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_01.mp3`
- **Expected Speech**: "Pokaż rajdy w Irlandii w 2025 roku."
- **Actual STT Transcript**: "Pokaż rajdy w Irlandii w 2005 roku."
- **WER**: 14.3% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2005, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 609ms | LLM: 2017ms | ER: 0ms | DB: 74ms | **Total: 2702ms**

### ❌ [synth-pl-02] Polish (`pl-PL`)
- **Audio File**: `test/eval/audio/synthetic/pl_02.mp3`
- **Expected Speech**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **Actual STT Transcript**: "Pokaż najciekawsze skoki z udziałem Josha Moffetta z Moonraker w 2025 roku."
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 812ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2689ms**

### ❌ [synth-nb-01] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_01.mp3`
- **Expected Speech**: "Vis rallyer i Irland i 2025."
- **Actual STT Transcript**: "Vis religiet i Ørland i 2025."
- **WER**: 33.3% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, city: Ørland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 640ms | LLM: 2685ms | ER: 124ms | DB: 82ms | **Total: 3534ms**

### ❌ [synth-nb-02] Norwegian (Bokmål) (`nb-NO`)
- **Audio File**: `test/eval/audio/synthetic/nb_02.mp3`
- **Expected Speech**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Actual STT Transcript**: "Vis hopphøydepunkter med Josh Moffett fra Moonraker i 2025."
- **Normalized Transcript (Voice Recovery)**: "Vis hopp høydepunkter med Josh Moffett fra Moonraker i 2025."
- **Recovery Mappings**: `{hopphøydepunkter: hopp høydepunkter}`
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 711ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4843ms**

### ✅ [synth-lv-01] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_01.mp3`
- **Expected Speech**: "Rādīt rallijus Īrijā 2025. gadā."
- **Actual STT Transcript**: "Rādīt Rālijas īrijā 2025-gadā"
- **WER**: 60.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 631ms | LLM: 1938ms | ER: 0ms | DB: 81ms | **Total: 2652ms**

### ❌ [synth-lv-02] Latvian (`lv-LV`)
- **Audio File**: `test/eval/audio/synthetic/lv_02.mp3`
- **Expected Speech**: "Rādīt labākos lēcienus ar Josh Moffett no Moonraker 2025. gadā."
- **Actual STT Transcript**: "Radīt labākos lēcienas ar Josh Moffett no Moonraker 2025 gadā!"
- **WER**: 20.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1438ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3675ms**

### ✅ [synth-cs-01] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_01.mp3`
- **Expected Speech**: "Ukaž rally v Irsku v roce 2025."
- **Actual STT Transcript**: "ukaždali v Irsku v roce 2025."
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 892ms | LLM: 4158ms | ER: 0ms | DB: 75ms | **Total: 5130ms**

### ❌ [synth-cs-02] Czech (`cs-CZ`)
- **Audio File**: `test/eval/audio/synthetic/cs_02.mp3`
- **Expected Speech**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **Actual STT Transcript**: "Ukaž nejlepší skoky s Joshem Moffettem z Moonraker v roce 2025."
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1377ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4837ms**

### ✅ [synth-hr-01] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_01.mp3`
- **Expected Speech**: "Prikaži relije u Irskoj u 2025. godini."
- **Actual STT Transcript**: "Prijka žirelije u Irskoj u 2025. godini."
- **WER**: 28.6% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 730ms | LLM: 2175ms | ER: 0ms | DB: 107ms | **Total: 3014ms**

### ❌ [synth-hr-02] Croatian (`hr-HR`)
- **Audio File**: `test/eval/audio/synthetic/hr_02.mp3`
- **Expected Speech**: "Prikaži najbolje skokove s Joshem Moffettom s Moonrakera 2025. godine."
- **Actual STT Transcript**: "Prikaži najbolje skokove s Joshem Moffettom s Moonraker-a 2025 godine."
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 2289ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4314ms**

### ❌ [synth-lt-01] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_01.mp3`
- **Expected Speech**: "Rodyti ralius Airijoje 2025 metais."
- **Actual STT Transcript**: "Rodyt raliu Seirijoje 25 metais"
- **WER**: 80.0% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, city: Seirijai, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1273ms | LLM: 2662ms | ER: 125ms | DB: 87ms | **Total: 4150ms**

### ❌ [synth-lt-02] Lithuanian (`lt-LT`)
- **Audio File**: `test/eval/audio/synthetic/lt_02.mp3`
- **Expected Speech**: "Rodyti geriausius šuolius su Josh Moffett iš Moonraker 2025 metais."
- **Actual STT Transcript**: "Radu digeriausiu šuolius su Josh Moffett iš Moonraker 2025 metais"
- **WER**: 20.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1317ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3875ms**

### ✅ [synth-sk-01] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_01.mp3`
- **Expected Speech**: "Ukáž rely v Írsku v roku 2025."
- **Actual STT Transcript**: "Ukáž Relif Irsku v roku 2025."
- **WER**: 42.9% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 982ms | LLM: 2395ms | ER: 0ms | DB: 81ms | **Total: 3459ms**

### ❌ [synth-sk-02] Slovak (`sk-SK`)
- **Audio File**: `test/eval/audio/synthetic/sk_02.mp3`
- **Expected Speech**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **Actual STT Transcript**: "Ukáž najlepšie skoky s Joshom Moffettom z Moonraker v roku 2025."
- **WER**: 0.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 784ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 2106ms**

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
- **Latency**: STT: 871ms | LLM: 4414ms | ER: 36ms | DB: 75ms | **Total: 5400ms**

### ❌ [synth-ur-02] Urdu (`ur-PK`)
- **Audio File**: `test/eval/audio/synthetic/ur_02.mp3`
- **Expected Speech**: "2025 میں Moonraker سے Josh Moffett کی جمپس کے ہائی لائٹس دکھائیں۔"
- **Actual STT Transcript**: "2025 میں Moonraker سے جوش موفٹ کی جمپس کے ہائی لائٹس دکھائیں"
- **WER**: 25.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1396ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4047ms**

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
- **Latency**: STT: 1333ms | LLM: 2132ms | ER: 0ms | DB: 155ms | **Total: 3623ms**

### ❌ [synth-ar-02] Arabic (`ar-QA`)
- **Audio File**: `test/eval/audio/synthetic/ar_02.mp3`
- **Expected Speech**: "أظهر لقطات القفزات المميزة لـ Josh Moffett من Moonraker في 2025."
- **Actual STT Transcript**: "أظهر لقطات القفزات المميزة لجوش موفت من مون ريكر في عين ٢٠٢٥"
- **Normalized Transcript (Voice Recovery)**: "أظهر لقطات القفزات المميزة لJosh Moffett من Moonraker في عين ٢٠٢٥"
- **Recovery Mappings**: `{جوش موفت: Josh Moffett, مون ريكر: Moonraker}`
- **WER**: 63.6% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1430ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 3604ms**

### ✅ [synth-sw-01] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_01.mp3`
- **Expected Speech**: "Onyesha rali nchini Ayalandi mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha, Rali Nchini Ayalandi Mwaka wa 2025"
- **WER**: 0.0% | **Failure Attribution**: `NONE`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, country: Ireland, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (24 rows returned)
- **Latency**: STT: 658ms | LLM: 1714ms | ER: 0ms | DB: 78ms | **Total: 2453ms**

### ❌ [synth-sw-02] Swahili (`sw-KE`)
- **Audio File**: `test/eval/audio/synthetic/sw_02.mp3`
- **Expected Speech**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa 2025."
- **Actual STT Transcript**: "Onyesha matukio makuu ya miruko ya Josh Moffett kutoka Moonraker mwaka wa dwebi dwentindifim."
- **WER**: 15.4% | **Failure Attribution**: `LLM_UNNECESSARY_CLARIFICATION`
- **Parsed Intent**: `searchVideoActions` (Expected: `searchVideoActions`)
- **Resolved Query**: `{intent: SEARCH_VIDEO_ACTIONS, rallyName: Moonraker, driverName: Josh Moffett, actionType: jump, limit: 20, offset: 0}`
- **DB Execution**: FAILED
- **Latency**: STT: 860ms | LLM: 2845ms | ER: 38ms | DB: 0ms | **Total: 3746ms**

### ❌ [synth-cy-01] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_01.mp3`
- **Expected Speech**: "Dangos ralïau yn Iwerddon yn 2025."
- **Actual STT Transcript**: "Dangos Ralyeni Werdon in 2025"
- **WER**: 66.7% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Werdon, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 1147ms | LLM: 4825ms | ER: 37ms | DB: 71ms | **Total: 6082ms**

### ❌ [synth-cy-02] Welsh (`cy-GB`)
- **Audio File**: `test/eval/audio/synthetic/cy_02.mp3`
- **Expected Speech**: "Dangos uchafbwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **Actual STT Transcript**: "Dangos y chybwyntiau neidiau gyda Josh Moffett o Moonraker yn 2025."
- **WER**: 20.0% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1319ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 4664ms**

### ❌ [synth-ga-01] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_01.mp3`
- **Expected Speech**: "Taispeáin railíthe in Éirinn in 2025."
- **Actual STT Transcript**: "Tyspine, Rayleigh, Theonatron in 2025."
- **WER**: 66.7% | **Failure Attribution**: `LLM_FILTER_ERROR`
- **Parsed Intent**: `searchRallies` (Expected: `searchRallies`)
- **Resolved Query**: `{intent: SEARCH_RALLIES, rallyName: Tyspine, Rayleigh, Theonatron, year: 2025, limit: 20, offset: 0}`
- **DB Execution**: SUCCESS (0 rows returned)
- **Latency**: STT: 801ms | LLM: 4669ms | ER: 41ms | DB: 75ms | **Total: 5588ms**

### ❌ [synth-ga-02] Irish (`ga-IE`)
- **Audio File**: `test/eval/audio/synthetic/ga_02.mp3`
- **Expected Speech**: "Taispeáin buaicphointí léimeanna le Josh Moffett ó Moonraker in 2025."
- **Actual STT Transcript**: "Tyspain, Boyk-Foynt, Leymanella, Josh Moffett on Moonraker in 2025."
- **WER**: 55.6% | **Failure Attribution**: `LLM_INTENT_ERROR`
- **Parsed Intent**: `null` (Expected: `searchVideoActions`)
- **Resolved Query**: `null`
- **DB Execution**: FAILED
- **Latency**: STT: 1529ms | LLM: 0ms | ER: 0ms | DB: 0ms | **Total: 8285ms**

