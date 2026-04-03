from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.password_reset_token import PasswordResetToken
from app.models.refresh_token import RefreshToken
from app.models.user import User


class UserRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_email(self, email: str) -> User | None:
        stmt = (
            select(User)
            .options(joinedload(User.profile), joinedload(User.onboarding_status))
            .where(User.email == email.lower())
        )
        return self.db.scalar(stmt)

    def get_by_google_subject(self, google_subject: str) -> User | None:
        stmt = (
            select(User)
            .options(joinedload(User.profile), joinedload(User.onboarding_status))
            .where(User.google_subject == google_subject)
        )
        return self.db.scalar(stmt)

    def get_by_id(self, user_id: UUID) -> User | None:
        stmt = (
            select(User)
            .options(joinedload(User.profile), joinedload(User.onboarding_status))
            .where(User.id == user_id)
        )
        return self.db.scalar(stmt)

    def add(self, user: User) -> User:
        self.db.add(user)
        return user

    def delete(self, user: User) -> None:
        self.db.delete(user)

    def touch_last_login(self, user: User, when: datetime) -> None:
        user.last_login = when

    def get_refresh_token(self, jti: str) -> RefreshToken | None:
        return self.db.scalar(select(RefreshToken).where(RefreshToken.jti == jti))

    def add_refresh_token(self, token: RefreshToken) -> RefreshToken:
        self.db.add(token)
        return token

    def get_password_reset_token(self, token_hash: str) -> PasswordResetToken | None:
        stmt = select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
        return self.db.scalar(stmt)

    def add_password_reset_token(self, token: PasswordResetToken) -> PasswordResetToken:
        self.db.add(token)
        return token
