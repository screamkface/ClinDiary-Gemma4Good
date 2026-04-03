from sqlalchemy.orm import Session

from app.models.user import User
from app.repositories.timeline_repository import TimelineRepository
from app.services.profile_context import resolve_user_profile


class TimelineService:
    def __init__(self, db: Session) -> None:
        self.timeline_repository = TimelineRepository(db)

    def list_events(self, user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            return []
        return self.timeline_repository.list_for_patient(profile.id)

