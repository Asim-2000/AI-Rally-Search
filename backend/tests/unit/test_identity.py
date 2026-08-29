from app.domain.person import CanonicalPerson

def test_account_bridges_roles():
    assert CanonicalPerson.identity(account_id=9,driver_id=1)==CanonicalPerson.identity(account_id=9,codriver_id=2,role="codriver")=="account:9"
def test_null_account_is_role_specific():
    assert CanonicalPerson.identity(driver_id=1)=="driver:1"
    assert CanonicalPerson.identity(codriver_id=1,role="codriver")=="codriver:1"

