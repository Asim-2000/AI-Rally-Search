# LLM Evaluation Benchmark Report

**Provider:** `mock` | **Model:** `mock-parser-v1` | **Date:** `2026-08-26T21:11:14.349801`

## Executive Summary

| Metric | Value |
| :--- | :--- |
| **Total Queries** | `21` |
| **Successful Parses** | `21` |
| **Clarification Triggers** | `0` |
| **Overall Quality Score** | **`94.3%`** |
| **Overall Correctness Score** | **`100.0%`** |

## Pillar 1: Cost Metrics

| Metric | Value |
| :--- | :--- |
| Total Tokens | `840` (`315` prompt + `525` completion) |
| Total Cost (USD) | `$0.000000` |
| Average Cost / Query | `$0.000000` |
| Estimated Cost / 1,000 Queries | `$0.0000` |

## Pillar 2: Latency Distribution

| Metric | LLM Parse Latency | Total End-to-End Latency |
| :--- | :--- | :--- |
| **Mean** | `0.0 ms` | `0.0 ms` |
| **P50 (Median)** | `0 ms` | `0 ms` |
| **P90** | `0 ms` | `0 ms` |
| **P95** | `0 ms` | `0 ms` |
| **Max** | `1 ms` | `1 ms` |

## Pillar 3: Correctness & Pillar 4: Accuracy

| Dimension | Evaluation Metric | Score |
| :--- | :--- | :--- |
| **Correctness** | Schema Adherence | `100.0%` |
| **Correctness** | DB Execution Safety | `100.0%` |
| **Accuracy** | Intent Classification | `95.2%` |
| **Accuracy** | Exact Match (All Fields) | `85.7%` |
| **Accuracy** | Slot / Entity Accuracy | `92.9%` |
| **Accuracy** | Clarification Precision | `95.2%` |

## Category Breakdown

| Category | Queries | Exact Match | Intent Acc | Avg Latency | Avg Cost |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Action Highlights | 7 | 86% | 100% | 0 ms | $0.000000 |
| Driver Participation | 2 | 100% | 100% | 0 ms | $0.000000 |
| Driver Wins | 2 | 100% | 100% | 0 ms | $0.000000 |
| Driver Videos | 1 | 100% | 100% | 0 ms | $0.000000 |
| Rally Search | 3 | 100% | 100% | 0 ms | $0.000000 |
| Rally Winner | 1 | 100% | 100% | 0 ms | $0.000000 |
| Rally Leaderboard | 1 | 100% | 100% | 0 ms | $0.000000 |
| Leaderboards | 2 | 100% | 100% | 0 ms | $0.000000 |
| Contextual Queries | 1 | 0% | 100% | 0 ms | $0.000000 |
| Ambiguity & Clarification | 1 | 0% | 0% | 0 ms | $0.000000 |
