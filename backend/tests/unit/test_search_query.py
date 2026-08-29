import pytest
from pydantic import ValidationError
from app.domain.search_query import MatchMode, PersonRole, SearchQuery

def test_plural_fields_win_over_singular_compatibility():
    q=SearchQuery.model_validate({"intent":"SEARCH_RALLIES","countries":["Latvia","Estonia"],"country":"Ireland","year":2026})
    assert q.countries == ["Latvia","Estonia"] and q.years == [2026]

def test_all_active_fields():
    q=SearchQuery.model_validate({"intent":"SEARCH_VIDEO_ACTIONS","rallyNames":["Rally Latvia"],"eventNames":["Event"],"countries":["Latvia"],"cities":["Riga"],"stageNames":["Talsi"],"stageNumbers":["SS2"],"driverNames":["Jane Doe"],"driverIds":["7"],"actionTypes":["jump"],"years":[2025,2026],"yearFrom":2020,"yearTo":2026,"uploaders":["11"],"driverMatchMode":"ALL","personRole":"CO_DRIVER","limit":10,"offset":3})
    assert q.driver_match_mode is MatchMode.ALL and q.person_role is PersonRole.CO_DRIVER

def test_invalid_pagination_and_range():
    with pytest.raises(ValidationError): SearchQuery.model_validate({"intent":"SEARCH_RALLIES","limit":0})
    with pytest.raises(ValidationError): SearchQuery.model_validate({"intent":"SEARCH_RALLIES","yearFrom":2026,"yearTo":2025})

@pytest.mark.parametrize("intent",["SEARCH_RALLIES","SEARCH_DRIVER_RALLIES","SEARCH_DRIVER_WINS","GET_RALLY_RESULTS","GET_RALLY_TOP_FINISHERS","SEARCH_VIDEO_ACTIONS","SEARCH_DRIVER_VIDEOS","GET_TOP_UPLOADERS","GET_TOP_DRIVERS_BY_WINS"])
def test_exact_nine_intents(intent): assert SearchQuery(intent=intent).intent.value == intent

