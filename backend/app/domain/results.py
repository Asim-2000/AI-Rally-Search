from datetime import datetime
from typing import Annotated, Literal, Union
from pydantic import BaseModel, ConfigDict, Field
from .search_intent import SearchIntent


class ResultBase(BaseModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

class RallyResultItem(ResultBase):
    kind: Literal["rally"] = "rally"
    event_id: str
    event_name: str
    status: str | None = None
    country: str | None = None
    city: str | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    stages_count: int = 0

class ParticipationItem(ResultBase):
    kind: Literal["participation"] = "participation"
    rally_id: str
    event_name: str
    person_id: str | None = None
    driver_name: str
    role: str | None = None
    pos_overall: int | None = None

class ClassificationItem(ResultBase):
    kind: Literal["classification"] = "classification"
    id: int
    rally_id: str
    event_name: str
    driver_id: str | None = None
    driver_name: str
    pos_overall: int

class VideoActionItem(ResultBase):
    kind: Literal["video_action"] = "video_action"
    id: int
    video_id: int
    action_type_id: int | None = None
    action_type: str
    stream_id: int | None = None

class VideoItem(ResultBase):
    kind: Literal["video"] = "video"
    video_id: int
    stream_id: int | None = None
    driver_id: str | None = None
    driver_name: str | None = None

class UploaderItem(ResultBase):
    kind: Literal["uploader"] = "uploader"
    uploader_id: str
    account_id: str | None = None
    uploader_name: str
    upload_count: int

class DriverWinsItem(ResultBase):
    kind: Literal["driver_wins"] = "driver_wins"
    person_id: str
    driver_name: str
    win_count: int

SearchItem = Annotated[Union[RallyResultItem, ParticipationItem, ClassificationItem,
                             VideoActionItem, VideoItem, UploaderItem, DriverWinsItem],
                       Field(discriminator="kind")]

class SearchResponse(BaseModel):
    intent: SearchIntent
    results: list[SearchItem]
    total_count: int
    has_more: bool
    limit: int
    offset: int
