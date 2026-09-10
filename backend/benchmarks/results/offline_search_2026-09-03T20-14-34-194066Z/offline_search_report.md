# Offline Search Benchmark Report

Generated: 2026-09-03T20-14-34-194066Z

## Primary safety gate
- **wrong_confident: 0** (gate: must be 0)

## Parser metrics
- Corpus size: 41
- Intent accuracy: 100.0% (24/24)
- Field F1: 1.000
- Entity resolution accuracy: 100.0% (14/14)
- Clarification accuracy: 100.0% (3/3)
- Safe unsupported rate: 100.0% (5/5)
- Special-query accuracy: 100.0% (9/9)
- OFFLINE_COVERAGE_RATE: 88.9% (24/27 answerable produced results)

## Execution parity (offline SQLite vs online MySQL oracle)
- Cases matched: 16/16

## Connectivity fallback
- ONLINE: onlineAuthoritative
- OFFLINE: offlineLocal
- TIMEOUT: lowBandwidthLocal
- BACKEND_ERROR: backendUnreachableLocal

## Voice offline
- Cloud voice offline: NO
- On-device voice offline: DEVICE_DEPENDENT
