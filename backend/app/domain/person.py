from pydantic import BaseModel


class CanonicalPerson(BaseModel):
    person_id: str
    account_id: str | None = None
    driver_id: str | None = None
    codriver_id: str | None = None

    @classmethod
    def identity(cls, *, account_id: object = None, driver_id: object = None,
                 codriver_id: object = None, role: str = "driver") -> str:
        if account_id is not None:
            return f"account:{account_id}"
        raw = driver_id if role == "driver" else codriver_id
        return f"{role}:{raw}"

