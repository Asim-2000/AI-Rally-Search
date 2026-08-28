from app.domain.results import SearchResponse

def canonical_ids(response: SearchResponse) -> list[str]:
    keys={"rally":"event_id","participation":"rally_id","classification":"id","video_action":"id","video":"video_id","uploader":"uploader_id","driver_wins":"person_id"}
    return [str(getattr(item,keys[item.kind])) for item in response.results]

def assert_exact_parity(dart: dict, python: SearchResponse) -> None:
    expected=[str(x) for x in dart["canonicalIds"]]
    actual=canonical_ids(python)
    assert actual==expected, {"expected":expected,"actual":actual}
    assert python.total_count==dart["totalCount"]

