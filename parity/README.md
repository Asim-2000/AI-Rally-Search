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
