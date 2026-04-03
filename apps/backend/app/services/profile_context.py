from __future__ import annotations

from app.models.user import User


def resolve_user_profile(user: User):
    return getattr(user, "active_profile", None) or user.profile
