# PY-1.1 parity closure report

- Shared fixture schema: `1.0`
- Dart ↔ Python: **32/32 exact** ordered IDs and totals
- RAW DB ↔ Dart ↔ Python: **10/10 exact**
- Python hermetic: **16 passed** (`12 live_db` excluded)
- Python live DB: **12 passed**
- Dart structured runner: **1 runner test passed**, executing 32 fixtures
- Pagination groups: actions and videos both have stable cross-runtime pages,
  no within-page duplicates, no overlap, and identical totals.
- Zero-result cases: exact, including role-incompatible person/video/action cases.
- Known product semantic: `UPLOADERS_FILTER_CURRENTLY_UNUSED`; frozen unchanged.
- Performance observation: `SEARCH_VIDEO_ACTIONS` remains approximately one second
  average and is a later optimization candidate. No tuning was performed.

The corpus and audits cover all nine intents, but the requested named identity
matrix is not complete: current co-driver-only cases are frozen; selection of
driver-only, dual-role account-backed, null-account driver, and null-account
co-driver fixtures was blocked because the execution environment refused to
expose newly queried live profile identifiers. Those identities must be supplied
or explicitly approved before the PY-1.1 gate can be declared complete.

Recommendation: **PARITY BLOCKED**.

