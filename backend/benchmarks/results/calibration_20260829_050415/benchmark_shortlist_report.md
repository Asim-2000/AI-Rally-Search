# Benchmark Shortlist Report — Executive Summary

- **Timestamp**: `20260829_050415`
- **Cases Evaluated**: 100 stratified calibration cases
- **Active Candidates**: `gpt-5.6-luna`, `claude-haiku-4-5`, `gemini-3.5-flash-lite`, `gemini-3.5-flash`
- **Dropped**: `claude-sonnet-5` (DROPPED_FROM_SHORTLIST = true)

## Executive Ranking

1. 🥇 **`gemini-3.5-flash-lite`**: Best Overall Efficiency (950ms p50 latency, $0.32/1k searches, 58.0% system success, 100% schema validity).
2. 🥈 **`gpt-5.6-luna`**: Best Raw Extraction Precision (0.98 Field F1, 88.0% exact match, $1.08/1k searches).
3. 🥉 **`claude-haiku-4-5`**: Best Anthropic Tier Baseline (1240ms p50 latency, 0.96 Field F1, $1.51/1k searches).

## Recommendation for Full Benchmark
Advance the 3 top candidates (`gemini-3.5-flash-lite`, `gpt-5.6-luna`, `claude-haiku-4-5`) to the complete 392-case run.
