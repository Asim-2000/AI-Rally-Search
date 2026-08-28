from enum import StrEnum
from pydantic import BaseModel


class ErrorCode(StrEnum):
    VALIDATION_ERROR = "VALIDATION_ERROR"
    UNSUPPORTED_INTENT = "UNSUPPORTED_INTENT"
    INVALID_FILTER = "INVALID_FILTER"
    INVALID_PERSON_ROLE = "INVALID_PERSON_ROLE"
    INVALID_PAGINATION = "INVALID_PAGINATION"
    DATABASE_ERROR = "DATABASE_ERROR"

class ApiError(BaseModel):
    code: ErrorCode
    message: str
    details: list[dict] | None = None

