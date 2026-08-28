# PY-3 query-understanding benchmarks

`fixtures/golden_176_v1.json` is generated from the current Dart
`test/eval/query_benchmark_cases.dart` by
`flutter test test/eval/export_query_understanding_fixture_test.dart`.
Do not edit expected answers in the JSON to improve a model score.

Run the hermetic baseline from `backend/`:

```sh
.venv/bin/python -m scripts.run_query_understanding_benchmark \
  --config benchmarks/query_understanding/config.mock.json
```

Copy `config.example.json`, set arbitrary provider/model entries, and expose the
corresponding API key environment variables for opt-in live runs. Each run writes
JSON (authoritative), JSONL (one raw record per case), and Markdown. `BASELINE_V1`
files are never selected as overwrite targets by prompt-tuning code; preserve or
rename a baseline before intentionally re-running the same matrix entry.

The evaluator accepts `canonical_hook` and `database_hook` callables. This keeps
PY-2 Entity Search and deterministic repositories unchanged while allowing live
benchmark wiring to return canonical outcome classes and canonical DB result IDs.
