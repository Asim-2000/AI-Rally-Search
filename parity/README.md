# Deterministic parity fixtures

Schema `1.0` stores each structured `SearchQuery` once. Both runners consume the
same JSON bytes and emit JSONL with `caseId`, `intent`, `orderedCanonicalIds`,
`total`, `limit`, `offset`, `hasMore`, and `currentPage`.

Canonical IDs are: event ID for rally and participation; event ID for driver
wins; result ID for winner/classification; `rally_video_metadata.id` for actions;
`rally_videos.id` for videos; `rally_videos.uploader_user_id` for uploaders; and
the Dart API's `driver_id` (falling back to crew/name only for null profiles) for
the wins leaderboard.

The Dart runner is hosted by `flutter test` because the frozen Dart database
service imports Flutter through `flutter_dotenv`; no UI, LLM, resolver, voice, or
conversation path is involved.

Ordering is compared as returned. Rally ties, classification ties, uploader
count ties, and win-count ties are risks because current Dart SQL lacks a complete
tie-breaker. The comparator classifies order-only differences as
`UNDEFINED_ORDERING`; it never sorts results to make parity pass.

## Live identity fixture

`fixtures/v1/live_identities.private.json` is the local deterministic fixture.
It contains live canonical/role IDs and must never be copied into human-readable
reports. Reports use aliases only. Refresh is deliberate, never automatic:

```sh
PYTHONPATH=backend backend/.venv/bin/python \
  backend/scripts/refresh_live_identities.py \
  parity/fixtures/v1/live_identities.private.json

PYTHONPATH=backend backend/.venv/bin/python \
  backend/scripts/build_identity_matrix.py \
  parity/fixtures/v1/live_identities.private.json \
  parity/fixtures/v1/identity_matrix.json
```

Before every matrix run, execute `validate_live_identities.py`. It verifies the
fixture hash and current relational category predicates and fails with
`STALE_LIVE_IDENTITY_FIXTURE` rather than selecting a replacement.
