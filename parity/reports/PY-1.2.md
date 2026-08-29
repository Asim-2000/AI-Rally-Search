# PY-1.2 live identity matrix closure

## Frozen aliases and category validation

| Alias | Category | Valid |
|---|---|---:|
| IDENTITY_DRIVER_ONLY_01 | DRIVER_ONLY_ACCOUNT_BACKED | yes |
| IDENTITY_CODRIVER_ONLY_01 | CODRIVER_ONLY_ACCOUNT_BACKED | yes |
| IDENTITY_DUAL_ROLE_01 | DUAL_ROLE_ACCOUNT_BACKED | yes |
| IDENTITY_NULL_DRIVER_01 | NULL_ACCOUNT_DRIVER | yes |
| IDENTITY_NULL_CODRIVER_01 | NULL_ACCOUNT_CODRIVER | yes |

## Participation role matrix

| Alias | DRIVER | CO_DRIVER | ANY | Union/isolation | RAW = Dart = Python |
|---|---:|---:|---:|---:|---:|
| IDENTITY_DRIVER_ONLY_01 | 9 | 0 | 9 | yes | yes |
| IDENTITY_CODRIVER_ONLY_01 | 0 | 2 | 2 | yes | yes |
| IDENTITY_DUAL_ROLE_01 | 5 | 11 | 11 | yes | yes |
| IDENTITY_NULL_DRIVER_01 | 1 | 0 | 1 | yes | yes |
| IDENTITY_NULL_CODRIVER_01 | 0 | 2 | 2 | yes | yes |

The dual-role fixture has five driver events, eleven codriver events, five in
their intersection, and eleven distinct ANY events. Thus ANY exactly equals the
deduplicated union of the two role sets.

The null-account fixtures have no same-normalized-name opposite-role profile in
the current database. More importantly, all searches use frozen role IDs: both
opposite-role searches return zero, and ANY equals only the valid role set.

## Direct video/action audit

All 30 direct video/action role cases match independent raw attribution through
`rally_video_metadata.entry_list_id → rally_entry_list`. The driver-only and
dual-role aliases have usable video/action data. The codriver-only and both
null-account aliases currently have no usable video/action data; exact zero is
accepted live truth.

## Gate

- Added identity matrix: **45/45 Dart ↔ Python exact**
- Independent identity audits: **45/45 RAW DB ↔ Dart ↔ Python exact**
- Existing core corpus: **32/32 exact**
- Existing independent audits: **10/10 exact**
- Total structured parity fixtures: **77**
- Total independently audited fixtures: **55**
- Unexplained mismatches: **0**

The private fixture stores selection timestamp, category predicates, canonical
identity, role IDs, and SHA-256 hash. Normal validation fails with
`STALE_LIVE_IDENTITY_FIXTURE`; replacement selection requires the explicit
refresh command documented in `parity/README.md`.

Recommendation: **GO TO PY-2**.

