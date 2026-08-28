# Frozen EE-1 response inventory (not implemented in PY-1)

Source of truth: `lib/services/friendly_response_service.dart` and
`lib/services/special_query_matcher.dart`. FastAPI must not invoke these yet.

Frozen categories: `weather`, `greeting`, `thanks`, `identity`, `capabilities`,
`joke`, `alive`, `rallyOpinion`, `unsupported`, `noResults`, `parseFailure`,
`networkError`, `timeout`, `serverError`, and `emptyVoice`.

Frozen machine codes: `SEARCH_NO_RESULTS`, `QUERY_PARSE_FAILED`, `NETWORK_ERROR`,
`REQUEST_TIMEOUT`, `SERVER_ERROR`, `EMPTY_TRANSCRIPT`, and `UNSUPPORTED_QUERY`.
